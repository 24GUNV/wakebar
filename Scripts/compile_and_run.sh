#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

# Debug builds sign with the fixed "Wakebar Dev Signing" identity (set in
# Configurations/Debug.xcconfig) so keychain "Always Allow" grants survive
# rebuilds. Set WAKEBAR_DEVELOPMENT_TEAM to use an Apple team identity instead.
signing_args=()
if [[ -n "${WAKEBAR_DEVELOPMENT_TEAM:-}" ]]; then
  signing_args=(
    DEVELOPMENT_TEAM="$WAKEBAR_DEVELOPMENT_TEAM"
    CODE_SIGN_STYLE=Automatic
    CODE_SIGN_IDENTITY="Apple Development"
  )
elif ! security find-identity -v -p codesigning 2>/dev/null | grep -Fq "Wakebar Dev Signing"; then
  echo "No \"Wakebar Dev Signing\" identity found." >&2
  echo "Run Scripts/setup_dev_signing.sh once to create it (keeps keychain" >&2
  echo "prompts from returning after every rebuild), or set" >&2
  echo "WAKEBAR_DEVELOPMENT_TEAM to sign with your Apple team." >&2
  exit 1
fi

xcodebuild \
  -project Wakebar.xcodeproj \
  -scheme Wakebar \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$project_root/.build/DerivedData" \
  ${signing_args+"${signing_args[@]}"} \
  build

pkill -x Wakebar 2>/dev/null || true
open -n "$project_root/.build/DerivedData/Build/Products/Debug/Wakebar.app"
