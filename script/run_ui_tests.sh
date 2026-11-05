#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Tico.xcodeproj"
SCHEME_NAME="Tico"
HOST_ARCH="$(/usr/bin/uname -m)"
SIGNING_ARGS=()
if [[ "${TICO_CI_ADHOC_SIGNING:-0}" == "1" ]]; then
  # A cópia isolada de UI testing não precisa da identidade de distribuição.
  SIGNING_ARGS+=("CODE_SIGN_IDENTITY=-" "DEVELOPMENT_TEAM=")
fi

case "$HOST_ARCH" in
  arm64|x86_64) ;;
  *)
    echo "error: unsupported host architecture: $HOST_ARCH" >&2
    exit 2
    ;;
esac

OWNS_DERIVED_DATA=0
if [[ -n "${TICO_UI_TEST_DERIVED_DATA_PATH:-}" ]]; then
  DERIVED_DATA_PATH="$TICO_UI_TEST_DERIVED_DATA_PATH"
else
  DERIVED_DATA_PATH="$(/usr/bin/mktemp -d /private/tmp/TicoUITestsDerivedData.XXXXXXXX)"
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
  -configuration Debug \
  -destination "platform=macOS,arch=$HOST_ARCH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallel-testing-enabled NO \
  -only-testing:TicoUITests \
  ${SIGNING_ARGS[@]+"${SIGNING_ARGS[@]}"} \
  test

echo "XCUITest end-to-end flow: PASS"
