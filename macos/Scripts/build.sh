#!/bin/bash
set -euo pipefail

MACOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$MACOS_ROOT/.." && pwd)"
cd "$PROJECT_ROOT"

CONFIGURATION="${1:-release}"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARIZE="${NOTARIZE:-0}"

if [[ "$CONFIGURATION" == "debug" ]]; then
  SWIFT_FLAGS="-c debug"
  BIN_DIR="$PROJECT_ROOT/.build/debug"
else
  SWIFT_FLAGS="-c release"
  BIN_DIR="$PROJECT_ROOT/.build/release"
fi

swift build $SWIFT_FLAGS --product Nigate

APP="$PROJECT_ROOT/dist/Nigate.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
printf 'APPL????' > "$APP/Contents/PkgInfo"

cp "$BIN_DIR/Nigate" "$APP/Contents/MacOS/Nigate"
chmod +x "$APP/Contents/MacOS/Nigate"
cp "$MACOS_ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$MACOS_ROOT/Sources/Nigate/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true
cp "$MACOS_ROOT/Sources/Nigate/Resources/AppIcon-white.icns" "$APP/Contents/Resources/AppIcon-white.icns" 2>/dev/null || true

if [[ -d "$BIN_DIR/Nigate_Nigate.bundle" ]]; then
  cp -R "$BIN_DIR/Nigate_Nigate.bundle" "$APP/Contents/Resources/"
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
else
  echo "Warning: DEVELOPER_ID_APPLICATION 未设置，仅生成开发用 ad-hoc 签名。" >&2
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -z "$SIGNING_IDENTITY" || -z "$NOTARY_PROFILE" ]]; then
    echo "NOTARIZE=1 要求同时设置 DEVELOPER_ID_APPLICATION 和 NOTARY_PROFILE。" >&2
    exit 1
  fi
  ARCHIVE="$PROJECT_ROOT/dist/Nigate-notarization.zip"
  rm -f "$ARCHIVE"
  ditto -c -k --keepParent "$APP" "$ARCHIVE"
  xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi

echo "Built $APP"
