#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -d "dist/Pilcrow.app" ]]; then
  ./Scripts/build-app.sh release
fi
open "dist/Pilcrow.app"
