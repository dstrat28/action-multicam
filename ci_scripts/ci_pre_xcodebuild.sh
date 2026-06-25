#!/bin/sh
set -eu

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "CI_BUILD_NUMBER is not set; leaving CURRENT_PROJECT_VERSION unchanged."
  exit 0
fi

case "$CI_BUILD_NUMBER" in
  ''|*[!0-9]*)
    echo "CI_BUILD_NUMBER must be an integer, got: $CI_BUILD_NUMBER"
    exit 1
    ;;
esac

cd "${CI_PRIMARY_REPOSITORY_PATH:-.}"
echo "Setting CURRENT_PROJECT_VERSION to Xcode Cloud build number: $CI_BUILD_NUMBER"
xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
