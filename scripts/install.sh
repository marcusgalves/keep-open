#!/usr/bin/env bash
# Builds Keep Open, replaces /Applications/Keep Open.app and opens it.
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/build-app.sh

DEST="/Applications/Keep Open.app"
osascript -e 'tell application id "com.marcusgalves.KeepOpen" to quit' >/dev/null 2>&1 || true
sleep 1
rm -rf "$DEST"
cp -R "build/Keep Open.app" "$DEST"
open "$DEST"
echo "Installed $DEST"
