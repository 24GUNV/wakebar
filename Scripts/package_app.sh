#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-release}"
case "$configuration" in
  debug) xcode_configuration="Debug" ;;
  release) xcode_configuration="Release" ;;
  *)
    echo "Unsupported configuration: $configuration" >&2
    exit 1
    ;;
esac

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if [[ -z "${WAKEBAR_DEVELOPMENT_TEAM:-}" ]]; then
  echo "Set WAKEBAR_DEVELOPMENT_TEAM to your Apple development team identifier." >&2
  echo "Wakebar needs a signed CloudKit entitlement; an ad-hoc package cannot sync the iPhone alarm." >&2
  exit 1
fi

archive_path="$project_root/.build/Wakebar-${xcode_configuration}.xcarchive"
xcodebuild \
  -project Wakebar.xcodeproj \
  -scheme Wakebar \
  -configuration "$xcode_configuration" \
  -destination "generic/platform=macOS" \
  -archivePath "$archive_path" \
  DEVELOPMENT_TEAM="$WAKEBAR_DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  archive

echo "$archive_path"
