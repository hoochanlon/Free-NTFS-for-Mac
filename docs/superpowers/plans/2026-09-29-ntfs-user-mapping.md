# NTFS Current-User Mounting Implementation Plan

> **For agentic workers:** Execute these steps inline in the existing dedicated project checkout. The user has authorized implementation; no additional agent or approval is needed.

**Goal:** Make GUI NTFS mounts use the initiating ordinary user's identity and report success only after checking the actual mount and file operations.

**Architecture:** Keep the existing NTFSManager → MountOperations → SudoExecutor route. Put identity/options, mount-state inspection, and the disposable non-root write probe in small modules that can be tested without Electron or disk privileges. Preserve renderer auto-mount and manual read-only settings.

**Tech Stack:** TypeScript, Node's built-in test runner, Electron 28, macOS diskutil/mount, NTFS-3G/macFUSE.

---

## Scope and evidence

The completed A/B experiment in `../../PHASE2_REMOUNT_RESULTS.md` establishes the uid/gid parameter group as the fix on this machine. Tests must use multiple synthetic identities (501:20 and 502:80); production code must never contain a fixed user ID. No mask changes, driver replacement, filesystem repairs, forced unmounts, installation, or real-volume remounts are part of the initial source/build checks. The existing source checkout is clean and independent of the installed app.

### Task 1: Identity and safe arguments

Files: create `src/scripts/ntfs-manager/mount-policy.ts`, create `tests/mount-policy.test.cjs`, update `package.json`.

- [x] Add tests for ordinary users, changed UID/GID, missing identity APIs, root/elevated processes, invalid devices and unsafe mount paths/names.
- [x] Run the tests before implementing the missing module and confirm failure.
- [x] Resolve `process.getuid()/getgid()` and verify the effective identity before requesting sudo. Do not infer identity from environment variables or fall back to 501/20.
- [x] Build argv with `-olocal -oallow_other -oauto_xattr -ovolname=<name> -onoatime -onorecover -ouid=<uid> -ogid=<gid>` and separate device/mount-point arguments. Reject commas/control characters in option values.
- [x] Add the test script; run state/service tests with Node child-process permissions denied and filesystem-only tests separately. Run pnpm test and confirm the new tests pass.

### Task 2: Actual state and write verification

Files: create `src/scripts/ntfs-manager/mount-state.ts`, `src/scripts/ntfs-manager/write-verifier.ts`, and their matching `.test.cjs` files.

- [x] Parse exact mount entries, including spaces and parentheses in volume paths. Inspect diskutil plist through plutil using argv/stdin, without interpolating user-controlled shell text.
- [x] Check device/UUID, NTFS type, FUSE backend, mount point, and real writable flags. Require two consistent observations with a bounded settling period.
- [x] Probe create → write → reopen → seek/overwrite → truncate → append → fsync → readback → rename → unlink as the ordinary user in a unique temporary directory. Verify ownership and unchanged inode for in-place operations; remove only generated files.
- [x] Test state mismatches, stale read-only flags, delayed visibility, failed writes, correct byte/inode checks, and cleanup on real local temporary directories.

### Task 3: Integrate safe GUI mounting

Files: modify `src/scripts/ntfs-manager/mount-operations.ts` and `device-detector.ts`; add integration tests using mocked OS boundaries.

- [x] Use the new arguments at the actual GUI call site and retain password retry behavior.
- [x] Use ordinary unmount; stop on busy/error instead of swallowing failures. Verify unmounted state before starting another mount, and validate an empty, non-symlink mount directory.
- [x] Remove the outer 10-second Promise.race that incorrectly claimed cancellation while the privileged command was still running.
- [x] Serialize operations for each device; mark success only after actual-state and write checks. Keep failure state truthful.
- [x] Restore read-only with explicit `diskutil mount readOnly` and verify it before returning success.
- [x] In detection, preserve actual read-only state regardless of old marker files and correctly parse paths containing spaces.
- [x] Test changed identities on consecutive mounts, busy unmount, wrong UUID, root rejection, readonly restoration, no false-success markers, and duplicate-operation rejection.

### Task 4: CLI parity, build and delivery

Files: update `ninja/nigate.sh`, relevant README limitations, and add `docs/NTFS_MOUNT_FIX.md`.

- [x] Align CLI uid/gid, norecover, quoting and ordinary-unmount policy without running its dependency-installing watcher. Reject root startup.
- [x] Run `pnpm test`, `pnpm run build:stylus`, `bash -n ninja/nigate.sh`, and `git diff --check`. Inspect final diff for unintended files.
- [x] Record exact changed files, root cause, build/start and rollback commands, automated results, and a clear distinction between earlier manual A/B app tests and pending new-GUI regressions.
- [x] Keep the installed app/settings unchanged. Exception: an early test isolation defect reached a real normal eject; recover the verified volume read-only, fix isolation, and record the incident explicitly.

## Completion record

- Source implementation and planned automated checks are complete: 39 tests, TypeScript/Stylus builds, shell syntax and diff whitespace checks passed.
- Early mock isolation was defective; the incident and verified read-only recovery are documented in docs/NTFS_MOUNT_FIX.md. Subsequent service tests use injected commands, fictional device identifiers and Node-enforced child-process denial.
- The filesystem suite is separate because the Node permission model prohibits fsync; it touches only newly created os.tmpdir fixtures.
- Follow-up installation completed on 2026-09-29: the local arm64 build is installed in /Applications/Nigate.app, and GUI launch, dependency display, and read-only device identification passed. Original settings were restored after the app exited. New-GUI real-volume read/write mounting and application-save regressions remain unverified; historical manual B-group results are not relabeled as new-GUI results.
- Before committing, reran all 39 automated tests, TypeScript/Stylus builds, shell syntax validation and diff whitespace checks successfully.
