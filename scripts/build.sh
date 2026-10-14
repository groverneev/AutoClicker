#!/bin/zsh
# Builds a Release copy of Auto Clicker and installs it to /Applications.
# Usage: scripts/build.sh [--no-install]
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate --quiet
mkdir -p build
if ! xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/DerivedData build > build/xcodebuild.log 2>&1; then
    grep -E "error:" build/xcodebuild.log >&2 || tail -30 build/xcodebuild.log >&2
    echo "Build failed (full log: build/xcodebuild.log)" >&2
    exit 1
fi
grep -E "^/.*warning:" build/xcodebuild.log || true

APP="build/DerivedData/Build/Products/Release/Auto Clicker.app"

if [[ "${1:-}" != "--no-install" ]]; then
    pkill -x "Auto Clicker" 2>/dev/null || true
    rm -rf "/Applications/Auto Clicker.app"
    cp -R "$APP" /Applications/
    echo "Installed /Applications/Auto Clicker.app"
else
    echo "Built $APP"
fi
