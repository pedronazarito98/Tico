#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_MODE=0
PRODUCT_NAME="Tico"
PUBLIC_APP_NAME="Tico"
BUNDLE_ID="com.pedronazarito.Tico"
source "$ROOT_DIR/script/load_version.sh" "$ROOT_DIR"
ARCHIVE_PATH="$ROOT_DIR/dist/$PUBLIC_APP_NAME.zip"
DMG_ARCHIVE_PATH="$ROOT_DIR/dist/$PUBLIC_APP_NAME.dmg"
TEST_LOG="$(/usr/bin/mktemp /private/tmp/Tico-ci-tests.XXXXXXXX)"
VERIFY_DIR=""
DMG_VERIFY_MOUNT=""
DMG_ATTACHED=0
SWIFT_ARGS=()

if [[ "${TICO_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  SWIFT_ARGS+=(--disable-sandbox)
fi

cleanup() {
  if [[ "$DMG_ATTACHED" -eq 1 ]]; then
    /usr/bin/hdiutil detach "$DMG_VERIFY_MOUNT" >/dev/null 2>&1 || true
  fi
  if [[ -n "$DMG_VERIFY_MOUNT" ]]; then
    /bin/rm -rf -- "$DMG_VERIFY_MOUNT"
  fi
  /bin/rm -f -- "$TEST_LOG"
  if [[ -n "$VERIFY_DIR" ]]; then
    /bin/rm -rf -- "$VERIFY_DIR"
  fi
}
trap cleanup EXIT HUP INT TERM

if [[ "${1:-}" == "--package" ]]; then
  PACKAGE_MODE=1
elif [[ $# -ne 0 ]]; then
  echo "usage: $0 [--package]" >&2
  exit 2
fi

step() {
  printf '\n==> %s\n' "$1"
}

cd "$ROOT_DIR"

step "Validating shell scripts"
bash -n script/build_and_run.sh
bash -n script/create_dmg.sh
bash -n script/load_version.sh
bash -n script/ci_verify.sh
bash -n script/release_preflight.sh
bash -n script/notarize_release.sh
bash -n script/validate_hardware_report.sh

step "Building Tico (SwiftPM product Tico)"
swift build ${SWIFT_ARGS[@]+"${SWIFT_ARGS[@]}"} --product "$PRODUCT_NAME"

step "Running complete Swift test suite"
swift test ${SWIFT_ARGS[@]+"${SWIFT_ARGS[@]}"} 2>&1 | /usr/bin/tee "$TEST_LOG"

step "Running security regression suite"
swift test ${SWIFT_ARGS[@]+"${SWIFT_ARGS[@]}"} --filter SecurityRegressionTests

if [[ "$PACKAGE_MODE" -eq 1 ]]; then
  step "Building and verifying local ad hoc package"
  ./script/build_and_run.sh --package
  [[ -f "$ARCHIVE_PATH" ]]
  [[ -f "$DMG_ARCHIVE_PATH" ]]

  VERIFY_DIR="$(/usr/bin/mktemp -d /private/tmp/Tico-ci-package.XXXXXXXX)"
  /usr/bin/ditto -x -k "$ARCHIVE_PATH" "$VERIFY_DIR"
  EXTRACTED_APP="$VERIFY_DIR/$PUBLIC_APP_NAME.app"
  INFO_PLIST="$EXTRACTED_APP/Contents/Info.plist"
  /usr/bin/xattr -cr "$EXTRACTED_APP"
  codesign --verify --deep --strict "$EXTRACTED_APP"
  /usr/bin/plutil -lint "$INFO_PLIST"
  [[ "$(/usr/bin/plutil -extract CFBundleDisplayName raw "$INFO_PLIST")" == "$PUBLIC_APP_NAME" ]]
  [[ "$(/usr/bin/plutil -extract CFBundleExecutable raw "$INFO_PLIST")" == "$PRODUCT_NAME" ]]
  [[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" == "$BUNDLE_ID" ]]
  [[ "$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" == "$MARKETING_VERSION" ]]
  [[ "$(/usr/bin/plutil -extract CFBundleVersion raw "$INFO_PLIST")" == "$BUILD_NUMBER" ]]
  [[ -x "$EXTRACTED_APP/Contents/MacOS/$PRODUCT_NAME" ]]
  [[ -f "$EXTRACTED_APP/Contents/Resources/Tico.icns" ]]

  step "Verifying Tico DMG"
  /usr/bin/hdiutil verify "$DMG_ARCHIVE_PATH" >/dev/null
  DMG_VERIFY_MOUNT="$(/usr/bin/mktemp -d /private/tmp/Tico-ci-dmg.XXXXXXXX)"
  /usr/bin/hdiutil attach \
    -readonly \
    -nobrowse \
    -noautoopen \
    -mountpoint "$DMG_VERIFY_MOUNT" \
    "$DMG_ARCHIVE_PATH" >/dev/null
  DMG_ATTACHED=1
  DMG_EXTRACTED_APP="$DMG_VERIFY_MOUNT/$PUBLIC_APP_NAME.app"
  /usr/bin/codesign --verify --deep --strict "$DMG_EXTRACTED_APP"
  /usr/bin/plutil -lint "$DMG_EXTRACTED_APP/Contents/Info.plist"
  [[ -L "$DMG_VERIFY_MOUNT/Applications" ]]
  /usr/bin/hdiutil detach "$DMG_VERIFY_MOUNT" >/dev/null
  DMG_ATTACHED=0

  step "Running release preflight for ZIP and DMG"
  ./script/release_preflight.sh "$ARCHIVE_PATH"
  ./script/release_preflight.sh "$DMG_ARCHIVE_PATH"
fi

TEST_COUNT="$(/usr/bin/sed -nE 's/.*Executed ([0-9]+) tests?.*/\1/p' "$TEST_LOG" | /usr/bin/tail -n 1)"
if [[ -z "$TEST_COUNT" ]]; then
  echo "Unable to determine the executed test count." >&2
  exit 1
fi

step "Automated verification summary"
echo "Swift tests: $TEST_COUNT"
echo "Local app path: $ROOT_DIR/dist/$PUBLIC_APP_NAME.app"
if [[ "$PACKAGE_MODE" -eq 1 ]]; then
  echo "Verified ad hoc archive: $ARCHIVE_PATH"
  echo "Verified DMG: $DMG_ARCHIVE_PATH"
else
  echo "Package verification: not requested (use --package)"
fi
echo "Physical trackpad coverage: not exercised by this automated gate"
echo "Notarization: not exercised by this automated gate"
