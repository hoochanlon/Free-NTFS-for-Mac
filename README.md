# Nigate

**Language / 言語 / 语言**: [English](README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

Nigate is a native macOS application built with Swift and SwiftUI for managing NTFS volumes. The repository has one Swift Package Manager entry point at the root; the former Electron/Node runtime is no longer used.

## Features

- Detect mounted and unmounted NTFS volumes and display mount state and capacity.
- Mount NTFS volumes read-write, restore read-only mounts, unmount, or eject devices.
- Repair with `ntfsfix`, rename volume labels, and manage automatic mounting.
- Store an administrator password in macOS Keychain when explicitly enabled.
- Provide dependency checks, an optional menu-bar mode, launch-at-login, sleep prevention, and localized settings.
- Format only a verified external physical whole disk. Formatting erases the entire disk and its partitions.

## Requirements

- macOS 14 or later.
- Swift 6 toolchain to build from source.
- For NTFS read-write mounting: MacFUSE and `ntfs-3g` (for example, install with Homebrew). `fswatch` is optional.

The app's dependency installer opens Terminal and may install Xcode Command Line Tools, Homebrew, MacFUSE, and `ntfs-3g`. macOS may require you to approve the filesystem extension in System Settings and restart. The installer does not disable Gatekeeper or change global macOS security settings.

## Build and run

Run these commands from the repository root:

```sh
swift test
swift build
./dev.sh
```

The SwiftPM entry point and app source are `Package.swift` and `macos/Sources/Nigate`. An equivalent development launcher is available at `./macos/Scripts/dev.sh`. To assemble a local `.app` bundle under `dist/Nigate.app`, run:

```sh
./macos/Scripts/build.sh          # release
./macos/Scripts/build.sh debug    # debug
```

The build script creates a locally ad-hoc-signed bundle; it does not notarize or package a distributable release.

## Safety and limitations

- **Formatting is destructive.** The app fails closed unless it can verify a complete external, physical, whole-disk target and confirm it is not the startup disk. Internal, virtual, disk-image, partition-only, unknown, incomplete, or negatively flagged targets are rejected. Back up the entire disk before formatting.
- **NTFS repair is best effort.** `ntfsfix` handles only limited NTFS issues and is not a replacement for Windows `chkdsk`.
- **Read-write mounts use `ntfs-3g`.** Compatibility and data integrity depend on the device, filesystem state, and macFUSE/driver versions. Keep backups. A volume left hibernated or in Windows Fast Startup state may not be safe to mount.
- The current tests exercise disk-safety and auto-mount decision logic. Real-device mounting, repair, and formatting require hardware integration testing and are not covered by the unit test suite.
- This repository provides a local build workflow, not a signed/notarized release pipeline.

## License

See [LICENSE](LICENSE) and [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).
