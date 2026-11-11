#!/bin/bash
set -euo pipefail

MACOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$MACOS_ROOT/.." && pwd)"
cd "$PROJECT_ROOT"

CONFIGURATION="${1:-release}"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARIZE="${NOTARIZE:-0}"
EXTENSION_PROJECT="$MACOS_ROOT/NigateFSKitExtension.xcodeproj"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

for command in swift xcodebuild codesign plutil ditto file; do
  require_command "$command"
done

if [[ ! -d "$EXTENSION_PROJECT" ]]; then
  printf 'FSKit extension project not found: %s\n' "$EXTENSION_PROJECT" >&2
  exit 1
fi

if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
  printf 'Usage: %s [release|debug]\n' "$0" >&2
  exit 2
fi

# SwiftPM 只负责主应用；FSKit 必须由 ExtensionKit target 生成真实 .appex。
swift build -c "$CONFIGURATION" --product Nigate
BIN_DIR="$(swift build --show-bin-path -c "$CONFIGURATION")"
APP_BINARY="$BIN_DIR/Nigate"

XCODE_CONFIGURATION="$(tr '[:lower:]' '[:upper:]' <<< "${CONFIGURATION:0:1}")${CONFIGURATION:1}"
XCODE_BUILD_ROOT="$PROJECT_ROOT/.build/xcode-${CONFIGURATION}"
XCODE_PRODUCT_DIR="$XCODE_BUILD_ROOT/Build/Products/$XCODE_CONFIGURATION"
xcodebuild \
  -project "$EXTENSION_PROJECT" \
  -target NigateFSKitExtension \
  -configuration "$XCODE_CONFIGURATION" \
  -sdk macosx \
  OBJROOT="$XCODE_BUILD_ROOT/Build/Intermediates" \
  SYMROOT="$XCODE_BUILD_ROOT/Build/Products" \
  CONFIGURATION_BUILD_DIR="$XCODE_PRODUCT_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
EXTENSION_PRODUCT="$XCODE_PRODUCT_DIR/NigateFSKitExtension.appex"

if [[ ! -f "$APP_BINARY" || ! -d "$EXTENSION_PRODUCT" ]]; then
  printf 'Build products are missing: app=%s extension=%s\n' "$APP_BINARY" "$EXTENSION_PRODUCT" >&2
  exit 1
fi

validate_macho_executable() {
  local executable="$1"
  local description

  if [[ ! -f "$executable" || ! -x "$executable" ]]; then
    printf 'Executable is missing or not executable: %s\n' "$executable" >&2
    exit 1
  fi
  description="$(file -b "$executable")"
  if [[ "$description" != Mach-O* ]]; then
    printf 'Expected a Mach-O executable at %s, got: %s\n' "$executable" "$description" >&2
    exit 1
  fi
}

validate_plist_value() {
  local plist="$1"
  local key_path="$2"
  local expected="$3"
  local actual

  actual="$(plutil -extract "$key_path" raw -o - "$plist")" || {
    printf 'Missing plist key %s in %s\n' "$key_path" "$plist" >&2
    exit 1
  }
  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected plist value %s=%s in %s; expected %s\n' \
      "$key_path" "$actual" "$plist" "$expected" >&2
    exit 1
  fi
}

APP="$PROJECT_ROOT/dist/Nigate.app"
EXTENSION="$APP/Contents/PlugIns/NigateFSKitExtension.appex"
APP_PLIST="$APP/Contents/Info.plist"
EXTENSION_PLIST="$EXTENSION/Contents/Info.plist"
EXTENSION_ENTITLEMENTS="$MACOS_ROOT/Sources/NigateFSKitExtension/NigateFSKitExtension.entitlements"
APP_ENTITLEMENTS="$MACOS_ROOT/Sources/Nigate/Nigate.entitlements"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

cp "$APP_BINARY" "$APP/Contents/MacOS/Nigate"
chmod +x "$APP/Contents/MacOS/Nigate"
cp "$MACOS_ROOT/Info.plist" "$APP_PLIST"
cp "$MACOS_ROOT/Sources/Nigate/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true
cp "$MACOS_ROOT/Sources/Nigate/Resources/AppIcon-white.icns" "$APP/Contents/Resources/AppIcon-white.icns" 2>/dev/null || true

if [[ -d "$BIN_DIR/Nigate_Nigate.bundle" ]]; then
  cp -R "$BIN_DIR/Nigate_Nigate.bundle" "$APP/Contents/Resources/"
fi

ditto "$EXTENSION_PRODUCT" "$EXTENSION"
EXTENSION_PLIST="$EXTENSION/Contents/Info.plist"
EXTENSION_BINARY="$EXTENSION/Contents/MacOS/NigateFSKitExtension"
validate_macho_executable "$APP/Contents/MacOS/Nigate"
validate_macho_executable "$EXTENSION_BINARY"

plutil -lint "$APP_PLIST" "$EXTENSION_PLIST"
validate_plist_value "$APP_PLIST" "CFBundlePackageType" "APPL"
validate_plist_value "$APP_PLIST" "LSMinimumSystemVersion" "14.0"
validate_plist_value "$EXTENSION_PLIST" "CFBundlePackageType" "XPC!"
validate_plist_value "$EXTENSION_PLIST" "CFBundleExecutable" "NigateFSKitExtension"
validate_plist_value "$EXTENSION_PLIST" "LSMinimumSystemVersion" "15.4"
validate_plist_value "$EXTENSION_PLIST" \
  "EXAppExtensionAttributes.EXExtensionPointIdentifier" "com.apple.fskit.fsmodule"
validate_plist_value "$EXTENSION_PLIST" \
  "EXAppExtensionAttributes.FSSupportsBlockResources" "true"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp \
    --entitlements "$EXTENSION_ENTITLEMENTS" \
    --sign "$SIGNING_IDENTITY" "$EXTENSION"
  if [[ -f "$APP_ENTITLEMENTS" ]]; then
    codesign --force --options runtime --timestamp \
      --entitlements "$APP_ENTITLEMENTS" \
      --sign "$SIGNING_IDENTITY" "$APP"
  else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
  fi
else
  printf '%s\n' 'Warning: DEVELOPER_ID_APPLICATION 未设置，使用 ad-hoc 签名。' >&2
  codesign --force \
    --entitlements "$EXTENSION_ENTITLEMENTS" \
    --sign - "$EXTENSION"
  if [[ -f "$APP_ENTITLEMENTS" ]]; then
    codesign --force --entitlements "$APP_ENTITLEMENTS" --sign - "$APP"
  else
    codesign --force --sign - "$APP"
  fi
fi

codesign --verify --deep --strict "$EXTENSION"
codesign --verify --deep --strict "$APP"

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -z "$SIGNING_IDENTITY" || -z "$NOTARY_PROFILE" ]]; then
    printf '%s\n' 'NOTARIZE=1 要求同时设置 DEVELOPER_ID_APPLICATION 和 NOTARY_PROFILE。' >&2
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

printf 'Built %s\n' "$APP"
