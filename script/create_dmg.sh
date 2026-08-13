#!/usr/bin/env bash
set -euo pipefail

PUBLIC_APP_NAME="Tico"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${1:-$ROOT_DIR/dist/$PUBLIC_APP_NAME.app}"
DMG_ARCHIVE="${2:-$ROOT_DIR/dist/$PUBLIC_APP_NAME.dmg}"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: app bundle not found: $APP_BUNDLE" >&2
  exit 2
fi

if [[ "$(basename "$APP_BUNDLE")" != "$PUBLIC_APP_NAME.app" ]]; then
  echo "error: expected a $PUBLIC_APP_NAME.app bundle" >&2
  exit 2
fi

TEMP_ROOT="$(/usr/bin/mktemp -d /private/tmp/TicoDmg.XXXXXXXX)"
/bin/chmod 700 "$TEMP_ROOT"
DMG_STAGING_DIR="$TEMP_ROOT/staging"
DMG_MOUNT_POINT="$TEMP_ROOT/mount"
TEMP_DMG_ARCHIVE="$TEMP_ROOT/$PUBLIC_APP_NAME.dmg"
DMG_ATTACHED=0

cleanup() {
  if [[ "$DMG_ATTACHED" -eq 1 ]]; then
    /usr/bin/hdiutil detach "$DMG_MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  /bin/rm -rf -- "$TEMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
/bin/mkdir -p "$DMG_STAGING_DIR" "$(dirname "$DMG_ARCHIVE")"
/usr/bin/ditto --norsrc "$APP_BUNDLE" "$DMG_STAGING_DIR/$PUBLIC_APP_NAME.app"
/bin/ln -s /Applications "$DMG_STAGING_DIR/Applications"
/usr/bin/hdiutil create \
  -quiet \
  -volname "$PUBLIC_APP_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -format UDZO \
  -ov \
  "$TEMP_DMG_ARCHIVE"

/usr/bin/hdiutil verify "$TEMP_DMG_ARCHIVE" >/dev/null
/bin/mkdir -p "$DMG_MOUNT_POINT"
/usr/bin/hdiutil attach \
  -readonly \
  -nobrowse \
  -noautoopen \
  -mountpoint "$DMG_MOUNT_POINT" \
  "$TEMP_DMG_ARCHIVE" >/dev/null
DMG_ATTACHED=1

MOUNTED_APP="$DMG_MOUNT_POINT/$PUBLIC_APP_NAME.app"
/usr/bin/codesign --verify --deep --strict "$MOUNTED_APP"
/usr/bin/plutil -lint "$MOUNTED_APP/Contents/Info.plist"
[[ -L "$DMG_MOUNT_POINT/Applications" ]]

/usr/bin/hdiutil detach "$DMG_MOUNT_POINT" >/dev/null
DMG_ATTACHED=0
/bin/mv -f -- "$TEMP_DMG_ARCHIVE" "$DMG_ARCHIVE"
