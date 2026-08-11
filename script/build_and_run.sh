#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
BUILD_CONFIGURATION="debug"
if [[ "$MODE" == "--release-package" || "$MODE" == "release-package" ]]; then
  BUILD_CONFIGURATION="release"
fi
PRODUCT_NAME="AirShortcut"
EXECUTABLE_NAME="AirShortcut"
PUBLIC_APP_NAME="Tico"
BUNDLE_ID="com.pedronazarito.AirShortcut"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$PUBLIC_APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
APP_ARCHIVE="$DIST_DIR/$PUBLIC_APP_NAME.zip"
DMG_ARCHIVE="$DIST_DIR/$PUBLIC_APP_NAME.dmg"
LEGACY_APP_BUNDLE="$DIST_DIR/$EXECUTABLE_NAME.app"
LEGACY_APP_ARCHIVE="$DIST_DIR/$EXECUTABLE_NAME.zip"
RESOURCE_BUNDLE_NAME="${PRODUCT_NAME}_${PRODUCT_NAME}.bundle"
ICON_FILE_NAME="Tico.icns"
TEMP_ROOT="$(/usr/bin/mktemp -d /private/tmp/Tico.XXXXXXXX)"
/bin/chmod 700 "$TEMP_ROOT"
STAGING_DIR="$TEMP_ROOT/staging"
STAGED_APP_BUNDLE="$STAGING_DIR/$PUBLIC_APP_NAME.app"
STAGED_CONTENTS="$STAGED_APP_BUNDLE/Contents"
STAGED_MACOS="$STAGED_CONTENTS/MacOS"
STAGED_RESOURCES="$STAGED_CONTENTS/Resources"
STAGED_BINARY="$STAGED_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$STAGED_CONTENTS/Info.plist"
RUN_DIR="$TEMP_ROOT/run"
RUN_APP_BUNDLE="$RUN_DIR/$PUBLIC_APP_NAME.app"
VERIFY_DIR="$TEMP_ROOT/verify"
VERIFY_APP_BUNDLE="$VERIFY_DIR/$PUBLIC_APP_NAME.app"
DMG_STAGING_DIR="$TEMP_ROOT/dmg-staging"
DMG_VERIFY_MOUNT="$TEMP_ROOT/dmg-mount"
DMG_ATTACHED=0

cleanup() {
  if [[ "$DMG_ATTACHED" -eq 1 ]]; then
    /usr/bin/hdiutil detach "$DMG_VERIFY_MOUNT" >/dev/null 2>&1 || true
  fi
  /bin/rm -rf -- "$TEMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

if [[ "$MODE" != "--package" && "$MODE" != "package" \
      && "$MODE" != "--release-package" && "$MODE" != "release-package" ]]; then
  pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
fi
cd "$ROOT_DIR"
if [[ "${AIRSHORTCUT_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  swift build --disable-sandbox -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME"
  BUILD_DIR="$(swift build --disable-sandbox -c "$BUILD_CONFIGURATION" --show-bin-path)"
else
  swift build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME"
  BUILD_DIR="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"
fi
BUILD_BINARY="$BUILD_DIR/$EXECUTABLE_NAME"
BUILD_RESOURCE_BUNDLE="$BUILD_DIR/$RESOURCE_BUNDLE_NAME"
BUILD_ICON="$BUILD_RESOURCE_BUNDLE/$ICON_FILE_NAME"

mkdir -p "$STAGED_MACOS" "$STAGED_RESOURCES"
cp "$BUILD_BINARY" "$STAGED_BINARY"
chmod +x "$STAGED_BINARY"
if [[ ! -d "$BUILD_RESOURCE_BUNDLE" ]]; then
  echo "missing SwiftPM resource bundle: $BUILD_RESOURCE_BUNDLE" >&2
  exit 1
fi
if [[ ! -f "$BUILD_ICON" ]]; then
  echo "missing app icon: $BUILD_ICON" >&2
  exit 1
fi
/usr/bin/ditto --norsrc \
  "$BUILD_RESOURCE_BUNDLE" \
  "$STAGED_RESOURCES/$RESOURCE_BUNDLE_NAME"
/usr/bin/ditto --norsrc "$BUILD_ICON" "$STAGED_RESOURCES/$ICON_FILE_NAME"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$PUBLIC_APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$PUBLIC_APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_FILE_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Pedro Nazarito</string>
</dict>
</plist>
PLIST

/usr/bin/xattr -cr "$STAGED_APP_BUNDLE"
/usr/bin/xattr -d com.apple.FinderInfo "$STAGED_APP_BUNDLE" 2>/dev/null || true
CODESIGN_IDENTITY="${AIRSHORTCUT_CODESIGN_IDENTITY:--}"
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  # An ordinary ad hoc signature gets a cdhash-only designated requirement,
  # which changes after every rebuild and breaks TCC permission continuity.
  # This explicit development-only requirement keeps AirShortcut recognizable.
  if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
    echo "warning: no Developer ID identity configured; producing a local-only release candidate" >&2
    codesign \
      --force \
      --deep \
      --sign - \
      --options runtime \
      --identifier "$BUNDLE_ID" \
      --requirements "=designated => identifier \"$BUNDLE_ID\"" \
      "$STAGED_APP_BUNDLE" >/dev/null
  else
    codesign \
      --force \
      --deep \
      --sign - \
      --identifier "$BUNDLE_ID" \
      --requirements "=designated => identifier \"$BUNDLE_ID\"" \
      "$STAGED_APP_BUNDLE" >/dev/null
  fi
else
  codesign \
    --force \
    --deep \
    --sign "$CODESIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    "$STAGED_APP_BUNDLE" >/dev/null
fi
/usr/bin/xattr -d com.apple.FinderInfo "$STAGED_APP_BUNDLE" 2>/dev/null || true
codesign --verify --deep --strict "$STAGED_APP_BUNDLE"

rm -rf "$APP_BUNDLE"
rm -rf "$LEGACY_APP_BUNDLE"
rm -rf "$DIST_DIR/.signed"
rm -f "$APP_ARCHIVE"
rm -f "$LEGACY_APP_ARCHIVE"
rm -f "$DMG_ARCHIVE"
mkdir -p "$DIST_DIR"
# The visible .app is convenient for local use. ZIP and DMG are distributable
# artifacts; the DMG also provides a standard drag-to-Applications flow.
/usr/bin/ditto --norsrc "$STAGED_APP_BUNDLE" "$APP_BUNDLE"
/usr/bin/ditto -c -k --norsrc --keepParent "$STAGED_APP_BUNDLE" "$APP_ARCHIVE"
/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/ditto -x -k "$APP_ARCHIVE" "$VERIFY_DIR"
/usr/bin/xattr -cr "$VERIFY_APP_BUNDLE"
codesign --verify --deep --strict "$VERIFY_APP_BUNDLE"

# Build a read-only compressed disk image with the conventional Applications
# alias. The app inside is copied from the already verified staging bundle, so
# the DMG does not change its code signature or compatibility identity.
mkdir -p "$DMG_STAGING_DIR"
/usr/bin/ditto --norsrc "$STAGED_APP_BUNDLE" "$DMG_STAGING_DIR/$PUBLIC_APP_NAME.app"
/bin/ln -s /Applications "$DMG_STAGING_DIR/Applications"
/usr/bin/hdiutil create \
  -quiet \
  -volname "$PUBLIC_APP_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_ARCHIVE"
/usr/bin/hdiutil verify "$DMG_ARCHIVE" >/dev/null
/bin/mkdir -p "$DMG_VERIFY_MOUNT"
/usr/bin/hdiutil attach \
  -readonly \
  -nobrowse \
  -noautoopen \
  -mountpoint "$DMG_VERIFY_MOUNT" \
  "$DMG_ARCHIVE" >/dev/null
DMG_ATTACHED=1
DMG_VERIFY_APP="$DMG_VERIFY_MOUNT/$PUBLIC_APP_NAME.app"
codesign --verify --deep --strict "$DMG_VERIFY_APP"
/usr/bin/plutil -lint "$DMG_VERIFY_APP/Contents/Info.plist"
[[ -L "$DMG_VERIFY_MOUNT/Applications" ]]
/usr/bin/hdiutil detach "$DMG_VERIFY_MOUNT" >/dev/null
DMG_ATTACHED=0
open_app() {
  # Launch Services may attach more metadata to the opened bundle. Run from a
  # clean temporary copy so the distributable zip stays untouched.
  mkdir -p "$RUN_DIR"
  /usr/bin/ditto --norsrc "$APP_BUNDLE" "$RUN_APP_BUNDLE"
  /usr/bin/xattr -cr "$RUN_APP_BUNDLE"
  codesign --verify --deep --strict "$RUN_APP_BUNDLE"
  /usr/bin/open -n "$RUN_APP_BUNDLE" "$@"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    ;;
  --package|package|--release-package|release-package)
    ;;
  --capture-diagnostic|capture-diagnostic)
    open_app --args --start-capture
    sleep 3
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    /usr/bin/log show --last 1m --info --style compact \
      --predicate "subsystem == \"$BUNDLE_ID\" && (category == \"Permissions\" || category == \"GlobalCapture\" || category == \"GlobalTrackpad\")"
    ;;
  --laboratory-verify|laboratory-verify)
    open_app --args --open-laboratory
    sleep 2
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    ;;
  --fallback-diagnostic|fallback-diagnostic)
    open_app --args --open-laboratory --force-trackpad-fallback
    sleep 2
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    /usr/bin/log show --last 1m --info --style compact \
      --predicate "subsystem == \"$BUNDLE_ID\" && category == \"GlobalTrackpad\""
    ;;
  *)
    echo "usage: $0 [run|--package|--release-package|--debug|--logs|--telemetry|--verify|--capture-diagnostic|--laboratory-verify|--fallback-diagnostic]" >&2
    exit 2
    ;;
esac

# Synced folders may reattach Finder metadata to the visible local bundle.
# Strict verification therefore happens on staging and on the zip after it is
# extracted to /private/tmp; the visible app is still cleaned for local use.
/usr/bin/xattr -cr "$APP_BUNDLE"
