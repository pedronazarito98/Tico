#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Tico.xcodeproj"
SCHEME_NAME="Tico"
HOST_ARCH="$(/usr/bin/uname -m)"

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
RESULT_BUNDLE_PATH="$DERIVED_DATA_PATH/TicoUITests.xcresult"

cleanup() {
  if [[ "$OWNS_DERIVED_DATA" -eq 1 ]]; then
    /bin/rm -rf -- "$DERIVED_DATA_PATH"
  fi
}
trap cleanup EXIT HUP INT TERM

# O Xcode recusa sobrescrever um result bundle existente. A remoção é segura
# porque o caminho permanece dentro do DerivedData temporário ou explicitamente
# fornecido para esta execução do teste.
/bin/rm -rf -- "$RESULT_BUNDLE_PATH"

set +e
/usr/bin/xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -configuration Debug \
  -destination "platform=macOS,arch=$HOST_ARCH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -parallel-testing-enabled NO \
  -only-testing:TicoUITests \
  test
TEST_STATUS=$?
set -e

if [[ "$TEST_STATUS" -ne 0 ]]; then
  echo
  echo "XCUITest diagnostics"
  /usr/bin/xcrun xcresulttool get test-results tests \
    --path "$RESULT_BUNDLE_PATH" \
    --compact 2>/dev/null || true
  exit "$TEST_STATUS"
fi

echo "XCUITest end-to-end flow: PASS"
