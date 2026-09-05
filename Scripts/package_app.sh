#!/usr/bin/env bash
set -euo pipefail

dry_run=false
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=true
  shift
fi

if [[ $# -ne 0 ]]; then
  echo "Usage: Scripts/package_app.sh [--dry-run]" >&2
  exit 2
fi

project_root="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="$project_root/.build/release-package"
derived_data="$work_dir/DerivedData"
staging_dir="$work_dir/staging"
app_path="$staging_dir/Wakebar.app"
dmg_path="$project_root/.build/Wakebar.dmg"
checksum_path="$dmg_path.sha256"
entitlements_path="$project_root/Resources/WakebarMac/WakebarRelease.entitlements"

development_team="${WAKEBAR_DEVELOPMENT_TEAM:-}"
signing_identity="${WAKEBAR_DEVELOPER_ID_APPLICATION:-}"
notary_profile="${WAKEBAR_NOTARY_PROFILE:-}"

if [[ "$dry_run" == false ]]; then
  if [[ -z "$development_team" ]]; then
    echo "Set WAKEBAR_DEVELOPMENT_TEAM to the Apple Developer team identifier." >&2
    exit 1
  fi
  if [[ -z "$signing_identity" ]]; then
    echo "Set WAKEBAR_DEVELOPER_ID_APPLICATION to the Developer ID Application signing identity." >&2
    exit 1
  fi
  if [[ -z "$notary_profile" ]]; then
    echo "Set WAKEBAR_NOTARY_PROFILE to the notarytool Keychain profile name." >&2
    exit 1
  fi
else
  development_team="${development_team:-DRYRUNTEAM}"
  signing_identity="${signing_identity:-Developer ID Application: Dry Run ($development_team)}"
  notary_profile="${notary_profile:-wakebar-dry-run}"
fi

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  if [[ "$dry_run" == false ]]; then
    "$@"
  fi
}

verify_signing_identity() {
  printf '+ security find-identity -v -p codesigning\n'
  if [[ "$dry_run" == true ]]; then
    return
  fi

  local identities
  identities="$(security find-identity -v -p codesigning)"
  printf '%s\n' "$identities"
  if [[ "$identities" != *"\"$signing_identity\""* ]]; then
    echo "The configured Developer ID Application identity is not installed or valid: $signing_identity" >&2
    exit 1
  fi
}

if [[ ! -f "$entitlements_path" ]]; then
  echo "Missing release entitlements: $entitlements_path" >&2
  exit 1
fi

if [[ "$signing_identity" != *"($development_team)"* ]]; then
  echo "WAKEBAR_DEVELOPER_ID_APPLICATION must end with the configured team identifier: ($development_team)" >&2
  exit 1
fi

verify_signing_identity
run xcrun notarytool history --keychain-profile "$notary_profile"

cd "$project_root"

run rm -rf "$work_dir"
run mkdir -p "$staging_dir"
run xcodegen generate
run xcodebuild \
  -project Wakebar.xcodeproj \
  -scheme Wakebar \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$derived_data" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  DEVELOPMENT_TEAM="$development_team" \
  CODE_SIGNING_ALLOWED=NO \
  build

built_app="$derived_data/Build/Products/Release/Wakebar.app"
if [[ "$dry_run" == false && ! -d "$built_app" ]]; then
  echo "Release build did not produce $built_app" >&2
  exit 1
fi

run ditto "$built_app" "$app_path"

framework_path="$app_path/Contents/Frameworks/WakebarCore.framework"
if [[ "$dry_run" == true || -d "$framework_path" ]]; then
  run codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$signing_identity" \
    "$framework_path"
fi

run codesign \
  --force \
  --timestamp \
  --options runtime \
  --entitlements "$entitlements_path" \
  --sign "$signing_identity" \
  "$app_path"
run codesign --verify --deep --strict --verbose=2 "$app_path"

run ln -s /Applications "$staging_dir/Applications"
run rm -f "$dmg_path" "$checksum_path"
run hdiutil create \
  -volname Wakebar \
  -srcfolder "$staging_dir" \
  -ov \
  -format UDZO \
  "$dmg_path"

run xcrun notarytool submit \
  "$dmg_path" \
  --keychain-profile "$notary_profile" \
  --wait
run xcrun stapler staple "$dmg_path"
run xcrun stapler validate "$dmg_path"

checksum_dir="$(dirname "$dmg_path")"
dmg_name="$(basename "$dmg_path")"
checksum_name="$(basename "$checksum_path")"
printf '+ cd %q\n' "$checksum_dir"
printf '+ shasum -a 256 %q > %q\n' "$dmg_name" "$checksum_name"
printf '+ shasum -a 256 -c %q\n' "$checksum_name"
if [[ "$dry_run" == false ]]; then
  (
    cd "$checksum_dir"
    shasum -a 256 "$dmg_name" > "$checksum_name"
    shasum -a 256 -c "$checksum_name"
  )
fi

if [[ "$dry_run" == false ]]; then
  echo "Created notarized disk image: $dmg_path"
  echo "Created SHA-256 checksum: $checksum_path"
else
  echo "Dry run complete. No build, signing, notarization, or file changes were performed."
fi
