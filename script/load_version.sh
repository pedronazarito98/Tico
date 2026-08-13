#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
  echo "error: load_version.sh requires the repository root" >&2
  return 2
fi

VERSION_FILE="$1/version.env"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "error: version file not found: $VERSION_FILE" >&2
  return 1
fi

# version.env is tracked project configuration and the single package version source.
source "$VERSION_FILE"
if [[ ! "${MARKETING_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: MARKETING_VERSION must use the x.y.z format" >&2
  return 1
fi
if [[ ! "${BUILD_NUMBER:-}" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: BUILD_NUMBER must be a positive integer" >&2
  return 1
fi
