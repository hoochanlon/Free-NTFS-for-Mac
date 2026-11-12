# Nigate

**Language / 言語 / 语言**: [English](README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

Nigate is a native macOS application for mounting NTFS volumes with read/write support.

Download the latest version from the [release tags](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags).

![](https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/src/imgs/example/demo.gif)

The demo shows a version older than 1.6.0. 

## Features

- SwiftUI app: live NTFS device detection, dependency checks, one-click mount, auto RW mount, status logs, sleep prevention, safety lock
- Multilingual UI: Simplified/Traditional Chinese, Japanese, English, German, and more
- **Dual mount backend**
  - **ntfs-3g (default / compatibility)**: MacFUSE + `ntfs-3g`; primary path for most users and unsigned builds
  - **FSKit (optional / native)**: Nigate FSKit extension with embedded NTFS engine; pick in **Settings → Mount Backend**

## Mount backends

| Backend | Needs | Notes |
| --- | --- | --- |
| ntfs-3g | MacFUSE, `ntfs-3g` | Default. Works with ad-hoc / local builds. |
| FSKit | macOS 15.4+, Nigate FSKit extension installed & enabled | Optional. No silent fallback to ntfs-3g on failure. |

Enable FSKit:

1. Build/install `Nigate.app` into `/Applications` (`./macos/Scripts/build.sh`); extension is under `Contents/Extensions`
2. **Without an Apple code-signing identity**, System Settings → File System Extensions **usually will not list Nigate** (ad-hoc builds are filtered there even if `pluginkit` already registered them)
3. Verify registration: `pluginkit -m -v -p com.apple.fskit.fsmodule | grep -i nigate`
4. With Developer ID / Development Team signing, the Settings row can appear; then set **Mount Backend** to **FSKit (Native)** in the app

Programmatic `FSClient.mountSingleVolume` needs a trusted signature with `com.apple.developer.fskit.mount`. Without a signing identity, keep **ntfs-3g** as the primary path.

## Important notes

> [!CAUTION]
> Stability depends on the storage device. Prefer reliable USB media.

- Mounting needs administrator privileges.
- Windows Fast Startup can block mounts — fully shut down Windows first.
- Gatekeeper may block unsigned builds; allow the app in **Privacy & Security**, do not disable Gatekeeper globally.
- Format is irreversible; `ntfsfix` is not a substitute for Windows `chkdsk`.

## Run & build

**Release app**: download from [tags](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags), move `Nigate.app` to Applications.

**From source** (macOS 14+, Swift 6 toolchain):

```sh
git clone https://github.com/hoochanlon/Free-NTFS-for-Mac.git
cd Free-NTFS-for-Mac
swift test
./dev.sh
```

**App bundle / DMG**:

```sh
./macos/Scripts/build.sh          # → dist/Nigate.app (ad-hoc signed)
./macos/Scripts/package-dmg.sh    # → dist/Nigate-1.6.0.dmg
```

Optional Developer ID + notarization:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/build.sh
```

## Layout

```text
Package.swift
macos/Sources/Nigate/              App (Domain / Infra / NTFS / App / UI)
macos/Sources/NigateFSKitCore/     Shared FSKit identity & mount-backend policy
macos/Sources/NigateFSKitExtension/ FSKit data plane (appex)
macos/Sources/NigateNTFSEngine/    Static-linked NTFS engine for the extension
Tests/NigateTests/
docs/README.md
```

## Acknowledgements

Thanks to everyone who contributed. See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).
