#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/mFanCtl.app"
BIN="$ROOT/.build/debug/mfanctl-menubar"
HELPER_BIN="$ROOT/.build/debug/mfanctl-helper"
HELPER_ID="io.github.jinnyday0719.mfanctl.helper"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

cd "$ROOT"
swift build --product mfanctl-menubar
swift build --product mfanctl-helper
"$ROOT/scripts/generate-app-icon.sh" >/dev/null

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Library/PrivilegedHelperTools"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/mFanCtl"
chmod +x "$APP/Contents/MacOS/mFanCtl"
cp "$HELPER_BIN" "$APP/Contents/Library/PrivilegedHelperTools/$HELPER_ID"
chmod +x "$APP/Contents/Library/PrivilegedHelperTools/$HELPER_ID"
cp "$ROOT/scripts/install-helper.sh" "$APP/Contents/Resources/install-helper.sh"
chmod +x "$APP/Contents/Resources/install-helper.sh"
cp "$ROOT/Resources/AppIcon.png" "$APP/Contents/Resources/AppIcon.png"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Clear dict" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string mFanCtl" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string io.github.jinnyday0719.mfanctl" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string mFanCtl" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string mFanCtl" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $APP_VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist"

echo "$APP"
