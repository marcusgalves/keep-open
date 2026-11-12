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

# A stable identity keeps the login agent valid across rebuilds; ad-hoc
# signatures change every build and launchd rejects the new binary until
# the app registers again. Override with SIGN_IDENTITY=- to force ad-hoc.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}"
IDENTITY="${IDENTITY:--}"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
echo "Signed with: $([[ "$IDENTITY" == "-" ]] && echo ad-hoc || echo "$IDENTITY")"
codesign --verify --strict "$APP"
echo "Built $APP"
