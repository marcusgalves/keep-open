#!/usr/bin/env bash
# Builds a universal, ad-hoc signed "Keep Open.app" into ./build.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/build/Keep Open.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/KeepOpen"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchAgents"
cp "$BIN" "$APP/Contents/MacOS/KeepOpen"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/com.marcusgalves.KeepOpen.agent.plist "$APP/Contents/Library/LaunchAgents/"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"
