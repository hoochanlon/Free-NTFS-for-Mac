# Nigate

**Language / 言語 / 语言**: [English](README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

Nigate is a native macOS application for mounting NTFS volumes with read/write support.

Download the latest version from the [release tags](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags).

![](https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/src/imgs/example/demo.gif)

The demo shows a version older than 1.5.4. The interface may change as features are added.

## Features

- **Modern interface**: A clean SwiftUI interface with dark-mode support
- **Live monitoring**: Detects connected NTFS devices automatically
- **Dependency checks**: Checks for and helps install the required system dependencies
- **One-click mounting**: Mounts NTFS volumes in read/write mode when supported
- **Automatic read/write mounting**: Newly connected NTFS devices can be mounted automatically; devices explicitly set to read-only are respected
- **Status display**: Shows device state and operation logs clearly
- **Prevent sleep**: Keeps the Mac awake during long-running operations
- **Safety protection**: Hold the protection control for three seconds to disable automatic mounting, tray mode, and sleep prevention and avoid accidental operations
- **Multilingual interface**: Simplified Chinese, Traditional Chinese, Japanese, English, German, and more

## Important notes

> [!CAUTION]
> Stability and data integrity depend on the storage device. Use reliable USB storage with high-quality flash memory and stable read/write performance to reduce the risk of I/O errors, interrupted transfers, or device detection failures.

> [!IMPORTANT]
> **Read/write behavior:**
> - **Basic operations**: Copying, moving, deleting, and renaming files are supported as metadata-level operations.
> - **Editing and saving**: The GUI mounts NTFS volumes in read/write mode and maps file ownership to the current macOS user's `uid` / `gid`. Text and image files can be edited and saved in tested configurations, but compatibility depends on the editor and its save strategy.
> - **When saving fails**: Back up important data first. Edit a copy on the Mac and copy it back to the device when necessary. Editors that create a temporary file and rename it into place may work in some cases, but no workaround is guaranteed.

- **Administrator privileges**: Mounting requires administrator privileges and macOS will request a password.
- **Windows Fast Startup**: Mounting may fail if the device was used by Windows with Fast Startup enabled. Fully shut down Windows, or disable Fast Startup, before reconnecting the device.
- **Device names**: USB storage device names must not contain spaces or unsupported characters.
- **Gatekeeper**: macOS may block an unsigned application on first launch. Prefer the per-application approval in System Settings > Privacy & Security. Avoid disabling Gatekeeper globally unless you understand the security consequences.
- **Bootable USB devices**: A device previously used with Ventoy, WinPE, or another boot-media tool may take longer to mount in read/write mode.

## Running and development

### Run a released version

Download the latest application from the [release tags](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags), then move `Nigate.app` to the Applications folder and open it.

For an unsigned or ad-hoc signed build, macOS may require approval in System Settings > Privacy & Security. Mounting requires administrator privileges. Read/write mounting also requires MacFUSE and `ntfs-3g`; the dependency pane reports their status and provides the available installation flow.

### Run from source

Requirements:

- macOS 14 or later
- A Swift 6-compatible Swift Package Manager toolchain
- MacFUSE, `ntfs-3g`, and an NTFS storage device for real-device testing

Run the following commands from the repository root:

```sh
git clone https://github.com/hoochanlon/Free-NTFS-for-Mac.git
cd Free-NTFS-for-Mac
swift test
./dev.sh
```

`./dev.sh` and `./macos/Scripts/dev.sh` both launch Nigate through Swift Package Manager. The first build creates the `.build` directory.

### Build an application bundle

The default build creates a Release application at `dist/Nigate.app` and applies a local ad-hoc signature:

```sh
swift test
./macos/Scripts/build.sh
open dist/Nigate.app
```

Build a Debug application instead:

```sh
./macos/Scripts/build.sh debug
open dist/Nigate.app
```

`build.sh` copies `Info.plist`, the application icons, and Swift Package resources into the bundle before signing it. It does not provide Developer ID signing, notarization, or a release-publishing workflow automatically. A production release requires an Apple Developer certificate and notarization credentials.

If a `notarytool` keychain profile is already configured, enable signing and notarization with:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/build.sh
```

### Package a DMG

Build the Release application and create a DMG with the dedicated packaging script:

```sh
./macos/Scripts/package-dmg.sh
open dist/Nigate-1.6.0.dmg
```

Build a Debug DMG instead:

```sh
./macos/Scripts/package-dmg.sh debug
```

The script first calls `build.sh` to create `Nigate.app`, then places the application, the installation guide and helper script from `dmg-assets`, and an Applications shortcut into the DMG. The output name is derived from the version in `macos/Info.plist`, for example `dist/Nigate-1.6.0.dmg`.

The default output is a locally signed development DMG. For distribution, provide Developer ID signing and notarization settings; the packaging script passes these variables through to the application build:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/package-dmg.sh
```

DMG layout assets live in `dmg-assets`. You can edit the installation guide or helper files there; the script copies the directory contents into the root of the DMG on every build.

### Project structure

```text
Package.swift                         Swift Package Manager entry point
macos/Sources/Nigate/Domain            Data models and disk-safety policy
macos/Sources/Nigate/Infra             Shell, privilege, path, Keychain, and settings adapters
macos/Sources/Nigate/NTFS              Scanning, monitoring, mounting, repair, and dependencies
macos/Sources/Nigate/App               App state, lifecycle, and menu-bar coordination
macos/Sources/Nigate/UI                SwiftUI screens, sheets, and interactions
macos/Sources/Nigate/Resources         Help documents, locales, and application icons
Tests/NigateTests                      Disk-safety and automatic-mounting tests
docs/README.md                         Engineering structure and security boundaries
```

Before submitting changes, run at least `swift test` and `swift build`. Test disk-related features only with backed-up data and a dedicated test device. Formatting is irreversible, and `ntfsfix` is not a replacement for Windows `chkdsk`.

## Acknowledgements

Thanks to everyone who has contributed code, testing, and feedback. See the [acknowledgements](ACKNOWLEDGMENTS.md) for details.
