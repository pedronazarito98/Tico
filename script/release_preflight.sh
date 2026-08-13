#!/usr/bin/env bash
set -euo pipefail

PUBLIC_APP_NAME="Tico"
EXECUTABLE_NAME="Tico"
BUNDLE_ID="com.pedronazarito.Tico"
MIN_SYSTEM_VERSION="26.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/load_version.sh" "$ROOT_DIR"
ARCHIVE_PATH="${1:-$ROOT_DIR/dist/$PUBLIC_APP_NAME.zip}"
TEMP_ROOT="$(/usr/bin/mktemp -d /private/tmp/TicoPreflight.XXXXXXXX)"
DMG_ATTACHED=0
DMG_MOUNT_POINT="$TEMP_ROOT/dmg-mount"

cleanup() {
  if [[ "$DMG_ATTACHED" -eq 1 ]]; then
    /usr/bin/hdiutil detach "$DMG_MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  /bin/rm -rf -- "$TEMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "error: archive not found: $ARCHIVE_PATH" >&2
  echo "run ./script/build_and_run.sh --package first" >&2
  exit 2
fi

EXTRACT_DIR="$TEMP_ROOT/extracted"
EXTRACTED_APP="$EXTRACT_DIR/$PUBLIC_APP_NAME.app"
/bin/mkdir -p "$EXTRACT_DIR"
if [[ "$ARCHIVE_PATH" == *.dmg ]]; then
  /usr/bin/hdiutil verify "$ARCHIVE_PATH" >/dev/null
  /bin/mkdir -p "$DMG_MOUNT_POINT"
  /usr/bin/hdiutil attach \
    -readonly \
    -nobrowse \
    -noautoopen \
    -mountpoint "$DMG_MOUNT_POINT" \
    "$ARCHIVE_PATH" >/dev/null
  DMG_ATTACHED=1
  EXTRACTED_APP="$DMG_MOUNT_POINT/$PUBLIC_APP_NAME.app"
else
  /usr/bin/ditto -x -k "$ARCHIVE_PATH" "$EXTRACT_DIR"
fi

if [[ ! -d "$EXTRACTED_APP" ]]; then
  echo "error: archive does not contain $PUBLIC_APP_NAME.app at its root" >&2
  exit 3
fi

if [[ "$ARCHIVE_PATH" != *.dmg ]]; then
  /usr/bin/xattr -cr "$EXTRACTED_APP"
fi
/usr/bin/codesign --verify --deep --strict "$EXTRACTED_APP"

INFO_PLIST="$EXTRACTED_APP/Contents/Info.plist"
/usr/bin/plutil -lint "$INFO_PLIST"
DISPLAY_NAME="$(/usr/bin/plutil -extract CFBundleDisplayName raw "$INFO_PLIST")"
EXECUTABLE_NAME_IN_BUNDLE="$(/usr/bin/plutil -extract CFBundleExecutable raw "$INFO_PLIST")"
BUNDLE_ID_IN_BUNDLE="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$INFO_PLIST")"
MARKETING_VERSION_IN_BUNDLE="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
BUILD_NUMBER_IN_BUNDLE="$(/usr/bin/plutil -extract CFBundleVersion raw "$INFO_PLIST")"
MIN_SYSTEM_VERSION_IN_BUNDLE="$(/usr/bin/plutil -extract LSMinimumSystemVersion raw "$INFO_PLIST")"

if [[ "$DISPLAY_NAME" != "$PUBLIC_APP_NAME" ||
      "$EXECUTABLE_NAME_IN_BUNDLE" != "$EXECUTABLE_NAME" ||
      "$BUNDLE_ID_IN_BUNDLE" != "$BUNDLE_ID" ]]; then
  echo "error: bundle identity does not match the Tico contract" >&2
  exit 4
fi
if [[ "$MARKETING_VERSION_IN_BUNDLE" != "$MARKETING_VERSION" ||
      "$BUILD_NUMBER_IN_BUNDLE" != "$BUILD_NUMBER" ]]; then
  echo "error: bundle version does not match version.env" >&2
  exit 4
fi
if [[ "$MIN_SYSTEM_VERSION_IN_BUNDLE" != "$MIN_SYSTEM_VERSION" ]]; then
  echo "error: minimum system version must be macOS $MIN_SYSTEM_VERSION" >&2
  exit 4
fi

SIGNING_DETAILS="$(/usr/bin/codesign -dvvv "$EXTRACTED_APP" 2>&1)"
SIGNING_AUTHORITY="$(printf '%s\n' "$SIGNING_DETAILS" | /usr/bin/sed -n 's/^Authority=//p' | /usr/bin/head -n 1)"
SIGNING_FLAGS_LINE="$(printf '%s\n' "$SIGNING_DETAILS" | /usr/bin/sed -n '/^CodeDirectory .* flags=/p' | /usr/bin/head -n 1)"
DESIGNATED_REQUIREMENT="$(
  /usr/bin/codesign -d -r- "$EXTRACTED_APP" 2>&1 \
    | /usr/bin/sed -n \
      -e 's/^# \(designated =>.*\)$/\1/p' \
      -e '/^designated =>/p' \
    | /usr/bin/head -n 1
)"
UNSCOPED_AD_HOC_REQUIREMENT="designated => identifier \"$BUNDLE_ID\""

if [[ "$SIGNING_AUTHORITY" == Developer\ ID\ Application:* ]]; then
  SIGNING_MODE="developer-id"
else
  SIGNING_MODE="ad-hoc/development"
fi

if [[ "$SIGNING_MODE" == "ad-hoc/development" &&
      "$DESIGNATED_REQUIREMENT" == "$UNSCOPED_AD_HOC_REQUIREMENT" ]]; then
  echo "error: ad hoc designated requirement is scoped only by bundle identifier" >&2
  echo "rebuild without a custom requirement or use an explicit signing identity" >&2
  exit 5
fi

if [[ "$SIGNING_MODE" == "developer-id" ]]; then
  CODE_IDENTITY_SCOPE="signer-bound"
elif [[ "$DESIGNATED_REQUIREMENT" == *cdhash* ]]; then
  CODE_IDENTITY_SCOPE="build-specific ad hoc"
else
  CODE_IDENTITY_SCOPE="custom development identity"
fi

ENTITLEMENTS_FILE="$TEMP_ROOT/entitlements.plist"
if /usr/bin/codesign -d --entitlements "$ENTITLEMENTS_FILE" "$EXTRACTED_APP" >/dev/null 2>&1 &&
  [[ -s "$ENTITLEMENTS_FILE" ]]; then
  ENTITLEMENTS_STATUS="present (inspect with codesign before release)"
else
  ENTITLEMENTS_STATUS="none"
fi

HARDENED_RUNTIME="not-confirmed"
if [[ "$SIGNING_FLAGS_LINE" == *runtime* ]]; then
  HARDENED_RUNTIME="enabled"
fi

echo "Tico release preflight"
echo "archive: $ARCHIVE_PATH"
if [[ "$ARCHIVE_PATH" == *.dmg ]]; then
  echo "archive format: dmg (mounted read-only for verification)"
else
  echo "archive format: zip (extracted for verification)"
fi
echo "bundle source: temporary extraction or read-only mount"
echo "public name: $DISPLAY_NAME"
echo "technical executable: $EXECUTABLE_NAME_IN_BUNDLE"
echo "bundle identifier: $BUNDLE_ID_IN_BUNDLE"
echo "version: $MARKETING_VERSION_IN_BUNDLE ($BUILD_NUMBER_IN_BUNDLE)"
echo "minimum system version: macOS $MIN_SYSTEM_VERSION_IN_BUNDLE"
echo "strict deep signature: PASS"
echo "signing mode: $SIGNING_MODE"
echo "code identity scope: $CODE_IDENTITY_SCOPE"
echo "hardened runtime: $HARDENED_RUNTIME"
echo "entitlements: $ENTITLEMENTS_STATUS"
echo "notarization: not-attempted (no notarytool acceptance evidence inspected)"
echo "staple: not-validated"
echo "clean-machine execution: not-run"

if [[ "$SIGNING_MODE" == "ad-hoc/development" ]]; then
  echo "distribution decision: development-only; Gatekeeper acceptance and notarization are not claimed"
elif [[ "$HARDENED_RUNTIME" != "enabled" ]]; then
  echo "distribution decision: blocked; Developer ID artifact lacks confirmed Hardened Runtime"
else
  echo "distribution decision: pending notarization, staple validation, and clean-machine execution"
fi
