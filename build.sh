#!/usr/bin/env bash
# Builds a universal ClipSnap.app into ./build
# Optional: SIGN_ID="My Local Cert" ./build.sh  (a stable identity keeps the
# Accessibility permission across rebuilds; ad-hoc signing resets it each time)
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP="build/ClipSnap.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/ClipSnap" "$APP/Contents/MacOS/ClipSnap"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP"
echo "Run: open $APP"
