# NTFS Hibernation Choice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users explicitly choose whether to remove a detected Windows hibernation state before a read-write NTFS mount, while keeping the safe read-only refusal as the default.

**Architecture:** Keep detection and retry in `MountOperations`. The first mount always uses `norecover`; only a hibernation/dirty-state error can invoke an injected main-process confirmation callback. A confirmed retry uses a narrowly constructed `remove_hiberfile` argument, verifies the resulting mount and file probe, and records that the user chose the destructive recovery. A cancelled choice performs the existing verified read-only recovery path.

**Tech Stack:** TypeScript, Electron `dialog`, Node built-in tests, existing NTFS-3G/macFUSE command path.

---

### Task 1: Add a narrow user-choice mount policy

**Files:**
- Modify: `src/scripts/ntfs-manager/mount-policy.ts`
- Modify: `src/scripts/ntfs-manager/mount-operations.ts`
- Modify: `src/scripts/ntfs-manager.ts`
- Test: `tests/mount-policy.test.cjs`
- Test: `tests/mount-operations.test.cjs`

- [x] Add `buildHibernationRemovalArgs` that starts from the validated normal mount arguments, removes `-onorecover`, and adds only `-oremove_hiberfile`.
- [x] Inject `confirmHibernationRemoval(device, driverError)` into `MountOperations`; detect only hibernation/dirty/unsafe-state driver errors.
- [x] On a detected error, ask once. If cancelled, run existing verified read-only recovery and report that the hibernation state was retained. If confirmed, perform normal unmount/empty mount-point preparation, retry with the explicit removal args, and run the same state/file verification before marking success.
- [x] Create the callback in the main process with an Electron warning dialog explaining that the Windows resume state will be deleted, that Windows must be fully shut down first when possible, and that the alternative is read-only. Default to cancellation; never run `remove_hiberfile` for non-matching errors or automatic fallback.
- [x] Test argument construction, cancellation, confirmation, no confirmation for ordinary errors, and no repair command on the choice path.

### Task 2: Explain the choice in user-facing text

**Files:**
- Modify: `docs/NTFS_MOUNT_FIX.md`
- Modify: `src/docs/help.md`

- [x] Add warning copy and labels for retaining read-only versus deleting hibernation state and continuing. The current dialog follows the project's existing native-dialog language pattern and defaults to cancellation.
- [x] Document that deletion affects Windows resume/fast-startup state, does not delete ordinary user files, and is not a replacement for `chkdsk`.
- [x] State that the default remains retain-and-refuse-read-write, and that the new choice is only offered after a matching driver error.

### Task 3: Validate and update delivery records

**Files:**
- Modify: `docs/superpowers/plans/2026-09-29-ntfs-hibernation-choice.md`

- [x] Run `pnpm test`, `pnpm run build:stylus`, `bash -n ninja/nigate.sh`, and `git diff --check`.
- [x] Confirm tests keep child processes isolated and do not invoke real `diskutil`, `ntfs-3g`, `sudo`, or `ntfsfix`.
- [x] Record the completed checks and the remaining limitation that real-volume confirmation of the new choice is pending.

### Task 4: Use the next binary capacity unit at each threshold

**Files:**
- Create: `src/scripts/utils/capacity.ts`
- Modify: `src/html/index.html`
- Modify: `src/html/devices.html`
- Modify: `src/scripts/modules/devices/device-renderer.ts`
- Modify: `src/scripts/modules/devices/device-utils.ts`
- Modify: `src/scripts/renderer/devices.ts`
- Test: `tests/capacity.test.cjs`

- [x] Add one browser-safe global formatter using binary thresholds: B, KB, MB, GB, TB, PB; format 1 TB and above as TB rather than GB.
- [x] Load the formatter before every device renderer and route existing duplicate formatters through it.
- [x] Test values immediately below and at 1 TB, plus the PB transition and invalid/zero values.
