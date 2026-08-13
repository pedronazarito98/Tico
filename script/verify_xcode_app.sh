#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/load_version.sh" "$ROOT_DIR"

PROJECT_PATH="$ROOT_DIR/Tico.xcodeproj"
SCHEME_PATH="$PROJECT_PATH/xcshareddata/xcschemes/Tico.xcscheme"
SCHEME_NAME="Tico"
CONFIGURATION="Debug"
APP_NAME="Tico"
BUNDLE_ID="com.pedronazarito.Tico"
MIN_SYSTEM_VERSION="26.0"
APP_CATEGORY="public.app-category.productivity"
RESOURCE_BUNDLE_NAME="Tico_Tico.bundle"
HOST_ARCH="$(/usr/bin/uname -m)"

[[ -d "$PROJECT_PATH" ]]
[[ -f "$SCHEME_PATH" ]]

case "$HOST_ARCH" in
  arm64|x86_64) ;;
  *)
    echo "error: unsupported host architecture: $HOST_ARCH" >&2
    exit 2
    ;;
esac

OWNS_DERIVED_DATA=0
if [[ -n "${TICO_XCODE_DERIVED_DATA_PATH:-}" ]]; then
  DERIVED_DATA_PATH="$TICO_XCODE_DERIVED_DATA_PATH"
else
  DERIVED_DATA_PATH="$(/usr/bin/mktemp -d /private/tmp/TicoXcodeVerify.XXXXXXXX)"
  OWNS_DERIVED_DATA=1
fi

cleanup() {
  if [[ "$OWNS_DERIVED_DATA" -eq 1 ]]; then
    /bin/rm -rf -- "$DERIVED_DATA_PATH"
  fi
}
trap cleanup EXIT HUP INT TERM

/usr/bin/xcodebuild \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS,arch=$HOST_ARCH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
RESOURCE_BUNDLE="$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE_NAME"
ARCHIVE_PATH="$DERIVED_DATA_PATH/$APP_NAME.xcarchive"
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

[[ -d "$APP_BUNDLE" ]]
[[ -x "$APP_BINARY" ]]
[[ -f "$INFO_PLIST" ]]
[[ -f "$APP_BUNDLE/Contents/Resources/Tico.icns" ]]
[[ -d "$RESOURCE_BUNDLE" ]]

/usr/bin/plutil -lint "$INFO_PLIST"
[[ "$(/usr/bin/plutil -extract CFBundleDisplayName raw "$INFO_PLIST")" == "$APP_NAME" ]]
[[ "$(/usr/bin/plutil -extract CFBundleExecutable raw "$INFO_PLIST")" == "$APP_NAME" ]]
[[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" == "$BUNDLE_ID" ]]
[[ "$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" == "$MARKETING_VERSION" ]]
[[ "$(/usr/bin/plutil -extract CFBundleVersion raw "$INFO_PLIST")" == "$BUILD_NUMBER" ]]
[[ "$(/usr/bin/plutil -extract LSMinimumSystemVersion raw "$INFO_PLIST")" == "$MIN_SYSTEM_VERSION" ]]
[[ "$(/usr/bin/plutil -extract LSApplicationCategoryType raw "$INFO_PLIST")" == "$APP_CATEGORY" ]]

/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
/usr/bin/xcrun vtool -show-build "$APP_BINARY" \
  | /usr/bin/grep -Eq "minos[[:space:]]+$MIN_SYSTEM_VERSION"

/usr/bin/xcodebuild \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -archivePath "$ARCHIVE_PATH" \
  archive

ARCHIVED_INFO_PLIST="$ARCHIVED_APP/Contents/Info.plist"
ARCHIVED_BINARY="$ARCHIVED_APP/Contents/MacOS/$APP_NAME"

[[ -d "$ARCHIVED_APP" ]]
[[ -x "$ARCHIVED_BINARY" ]]
[[ -f "$ARCHIVED_INFO_PLIST" ]]
[[ -f "$ARCHIVED_APP/Contents/Resources/Tico.icns" ]]
[[ -d "$ARCHIVED_APP/Contents/Resources/$RESOURCE_BUNDLE_NAME" ]]

/usr/bin/plutil -lint "$ARCHIVED_INFO_PLIST"
[[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "$ARCHIVED_INFO_PLIST")" == "$BUNDLE_ID" ]]
[[ "$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$ARCHIVED_INFO_PLIST")" == "$MARKETING_VERSION" ]]
[[ "$(/usr/bin/plutil -extract CFBundleVersion raw "$ARCHIVED_INFO_PLIST")" == "$BUILD_NUMBER" ]]
[[ "$(/usr/bin/plutil -extract LSMinimumSystemVersion raw "$ARCHIVED_INFO_PLIST")" == "$MIN_SYSTEM_VERSION" ]]
[[ "$(/usr/bin/plutil -extract LSApplicationCategoryType raw "$ARCHIVED_INFO_PLIST")" == "$APP_CATEGORY" ]]

/usr/bin/codesign --verify --deep --strict "$ARCHIVED_APP"
/usr/bin/codesign -dv --verbose=4 "$ARCHIVED_APP" 2>&1 \
  | /usr/bin/grep -E "flags=.*runtime" >/dev/null
/usr/bin/file "$ARCHIVED_BINARY" | /usr/bin/grep -q "arm64"
/usr/bin/file "$ARCHIVED_BINARY" | /usr/bin/grep -q "x86_64"
/usr/bin/xcrun vtool -arch arm64 -show-build "$ARCHIVED_BINARY" \
  | /usr/bin/grep -Eq "minos[[:space:]]+$MIN_SYSTEM_VERSION"
/usr/bin/xcrun vtool -arch x86_64 -show-build "$ARCHIVED_BINARY" \
  | /usr/bin/grep -Eq "minos[[:space:]]+$MIN_SYSTEM_VERSION"

echo "Xcode app target verification"
echo "project: $PROJECT_PATH"
echo "scheme: $SCHEME_NAME"
echo "host architecture: $HOST_ARCH"
echo "app: $APP_BUNDLE"
echo "bundle identifier: $BUNDLE_ID"
echo "version: $MARKETING_VERSION ($BUILD_NUMBER)"
echo "minimum system version: macOS $MIN_SYSTEM_VERSION"
echo "application category: $APP_CATEGORY"
echo "resource bundle: $RESOURCE_BUNDLE_NAME"
echo "debug app strict deep signature: PASS"
echo "release archive (arm64 + x86_64, hardened runtime): PASS"
