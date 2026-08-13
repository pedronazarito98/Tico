#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/load_version.sh" "$ROOT_DIR"
APP_BUNDLE="$ROOT_DIR/dist/Tico.app"
APP_ARCHIVE="$ROOT_DIR/dist/Tico.zip"
DMG_ARCHIVE="$ROOT_DIR/dist/Tico.dmg"
NOTARY_PROFILE="${TICO_NOTARYTOOL_PROFILE:-}"

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "TICO_NOTARYTOOL_PROFILE is required." >&2
  echo "Create a Keychain profile with xcrun notarytool store-credentials first." >&2
  exit 2
fi

if [[ ! -d "$APP_BUNDLE" || ! -f "$APP_ARCHIVE" ]]; then
  echo "missing release artifacts; run ./script/build_and_run.sh --release-package first" >&2
  exit 1
fi

SIGNATURE_AUTHORITY="$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 \
  | /usr/bin/sed -n 's/^Authority=//p' \
  | /usr/bin/head -1)"
if [[ "$SIGNATURE_AUTHORITY" != Developer\ ID\ Application:* ]]; then
  echo "Tico.app is not signed with a Developer ID Application certificate." >&2
  exit 1
fi

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
MARKETING_VERSION_IN_BUNDLE="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
BUILD_NUMBER_IN_BUNDLE="$(/usr/bin/plutil -extract CFBundleVersion raw "$INFO_PLIST")"
if [[ "$MARKETING_VERSION_IN_BUNDLE" != "$MARKETING_VERSION" ||
      "$BUILD_NUMBER_IN_BUNDLE" != "$BUILD_NUMBER" ]]; then
  echo "Tico.app version does not match version.env." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# Submit a temporary ZIP so the notary service emits a ticket for the app.
xcrun notarytool submit "$APP_ARCHIVE" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

# Recreate every distributed container from the stapled app.
/bin/rm -f "$APP_ARCHIVE"
/usr/bin/ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$APP_ARCHIVE"
"$ROOT_DIR/script/create_dmg.sh" "$APP_BUNDLE" "$DMG_ARCHIVE"

# The DMG is the outermost distributed container and receives its own
# Developer ID signature, notarization submission, and stapled ticket.
/usr/bin/codesign \
  --force \
  --sign "$SIGNATURE_AUTHORITY" \
  --timestamp \
  "$DMG_ARCHIVE"
/usr/bin/codesign --verify --verbose=2 "$DMG_ARCHIVE"
xcrun notarytool submit "$DMG_ARCHIVE" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait
xcrun stapler staple "$DMG_ARCHIVE"
xcrun stapler validate "$DMG_ARCHIVE"
/usr/bin/hdiutil verify "$DMG_ARCHIVE" >/dev/null

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/sbin/spctl -a -vv --type execute "$APP_BUNDLE"
/usr/sbin/spctl -a -vv --type open \
  --context context:primary-signature \
  "$DMG_ARCHIVE"

"$ROOT_DIR/script/release_preflight.sh" "$APP_ARCHIVE"
"$ROOT_DIR/script/release_preflight.sh" "$DMG_ARCHIVE"

echo "Notarized release ready: Tico $MARKETING_VERSION ($BUILD_NUMBER)"
echo "ZIP: $APP_ARCHIVE"
echo "DMG: $DMG_ARCHIVE"
