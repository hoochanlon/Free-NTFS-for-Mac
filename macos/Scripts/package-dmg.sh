#!/bin/bash
set -euo pipefail

MACOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$MACOS_ROOT/.." && pwd)"
cd "$PROJECT_ROOT"

CONFIGURATION="${1:-release}"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARIZE="${NOTARIZE:-0}"
ASSET_DIR="$PROJECT_ROOT/dmg-assets"
DIST_DIR="$PROJECT_ROOT/dist"
STAGING_ROOT="$PROJECT_ROOT/.dmg-staging"
STAGING_DIR="$STAGING_ROOT/Nigate"
APP="$DIST_DIR/Nigate.app"
MOUNT_POINT=""

if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
  echo "Usage: $0 [release|debug]" >&2
  exit 2
fi

if [[ ! -d "$ASSET_DIR" ]]; then
  echo "DMG assets directory not found: $ASSET_DIR" >&2
  exit 1
fi

for command in hdiutil osascript sips; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to create a styled DMG." >&2
    exit 1
  fi
done

if [[ "$NOTARIZE" == "1" && ( -z "$SIGNING_IDENTITY" || -z "$NOTARY_PROFILE" ) ]]; then
  echo "NOTARIZE=1 requires DEVELOPER_ID_APPLICATION and NOTARY_PROFILE." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MACOS_ROOT/Info.plist")"
DMG_PATH="$DIST_DIR/Nigate-${VERSION}.dmg"
RW_DMG_PATH="$STAGING_ROOT/Nigate-${VERSION}-rw.dmg"
VOLUME_NAME="${DMG_VOLUME_NAME:-Nigate ${VERSION}}"
BACKGROUND_IMAGE="$STAGING_DIR/.background/dmg-background.png"
# 相对旧版 1024×760 按 0.75 等比缩小，图标与坐标同步缩放。
WINDOW_WIDTH=768
WINDOW_HEIGHT=570
WINDOW_X=120
WINDOW_Y=120

cleanup() {
  if [[ -n "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

if [[ "$NOTARIZE" == "1" ]]; then
  NOTARIZE=0 "$MACOS_ROOT/Scripts/build.sh" "$CONFIGURATION"
else
  "$MACOS_ROOT/Scripts/build.sh" "$CONFIGURATION"
fi

FSKIT_EXTENSION="$APP/Contents/Extensions/NigateFSKitExtension.appex"
if [[ ! -d "$FSKIT_EXTENSION" || ! -f "$FSKIT_EXTENSION/Contents/MacOS/NigateFSKitExtension" ]]; then
  echo "Built app does not contain a real FSKit extension bundle: $FSKIT_EXTENSION" >&2
  exit 1
fi

rm -rf "$STAGING_ROOT"
mkdir -p "$STAGING_DIR/.background" "$DIST_DIR"
cp -R "$APP" "$STAGING_DIR/Nigate.app"
cp -R "$ASSET_DIR"/. "$STAGING_DIR/"

# Finder only accepts a background picture from the mounted, writable image.
sips -s format png "$ASSET_DIR/dmg-background.svg" --out "$BACKGROUND_IMAGE" >/dev/null
rm -f "$STAGING_DIR/dmg-background.svg"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH" "$RW_DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$RW_DMG_PATH"

ATTACH_OUTPUT="$(hdiutil attach \
  -nobrowse \
  -noautoopen \
  -readwrite \
  "$RW_DMG_PATH")"
MOUNT_POINT="${ATTACH_OUTPUT##*$'\n'}"
MOUNT_POINT="${MOUNT_POINT##*$'\t'}"

if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Unable to find mounted DMG volume: $MOUNT_POINT" >&2
  exit 1
fi

osascript <<APPLESCRIPT
 tell application "Finder"
   tell disk "$VOLUME_NAME"
     open
     set theXOrigin to $WINDOW_X
     set theYOrigin to $WINDOW_Y
     set theWidth to $WINDOW_WIDTH
     set theHeight to $WINDOW_HEIGHT
     set theBottomRightX to (theXOrigin + theWidth)
     set theBottomRightY to (theYOrigin + theHeight)

     tell container window
       set current view to icon view
       set toolbar visible to false
       set sidebar width to 0
       set statusbar visible to true
       set bounds to {theXOrigin, theYOrigin, theBottomRightX, theBottomRightY}
     end tell

     set opts to the icon view options of container window
     tell opts
       set icon size to 96
       set text size to 12
       set arrangement to not arranged
     end tell
     set background picture of opts to file ".background:dmg-background.png"

     set position of item "Nigate.app" to {192, 188}
     set position of item "Applications" to {576, 188}
     set position of item "README.md" to {192, 398}
     set position of item "提示损坏？点我.command" to {576, 398}

     close
     open
     delay 2
     tell container window
       set bounds to {theXOrigin, theYOrigin, theBottomRightX, theBottomRightY}
     end tell
   end tell
 end tell
APPLESCRIPT

hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNT_POINT=""
hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "$DMG_PATH" >/dev/null

if [[ "$NOTARIZE" == "1" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

echo "Built $DMG_PATH"
