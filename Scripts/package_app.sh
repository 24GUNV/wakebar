#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-debug}"
case "$configuration" in
  debug|release) ;;
  *)
    echo "Unsupported configuration: $configuration" >&2
    exit 1
    ;;
esac

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

swift build -c "$configuration"
binary_directory="$(swift build -c "$configuration" --show-bin-path)"
app_directory="$project_root/.build/Wakebar.app"

mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp "$binary_directory/Wakebar" "$app_directory/Contents/MacOS/Wakebar"
cp "$project_root/Resources/Info.plist" "$app_directory/Contents/Info.plist"

codesign --force --deep --sign - "$app_directory"
echo "$app_directory"
