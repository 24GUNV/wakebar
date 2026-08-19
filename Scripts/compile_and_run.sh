#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
"$project_root/Scripts/package_app.sh" debug

pkill -x Wakebar 2>/dev/null || true
open -n "$project_root/.build/Wakebar.app"
