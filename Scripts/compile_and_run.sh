#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if [[ -z "${WAKEBAR_DEVELOPMENT_TEAM:-}" ]]; then
  echo "Set WAKEBAR_DEVELOPMENT_TEAM to your Apple development team identifier." >&2
  exit 1
fi

xcodebuild \
  -project Wakebar.xcodeproj \
  -scheme Wakebar \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$project_root/.build/DerivedData" \
  DEVELOPMENT_TEAM="$WAKEBAR_DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  build

pkill -x Wakebar 2>/dev/null || true
open -n "$project_root/.build/DerivedData/Build/Products/Debug/Wakebar.app"
