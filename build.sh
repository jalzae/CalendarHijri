#!/bin/bash
# Build, sign, install and register the CalendarHijri app + widget.
# Usage: ./build.sh
#   CODE_SIGN_IDENTITY="Apple Development" ./build.sh   # once you have a cert
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CalendarHijri"
INSTALLED="/Applications/$APP_NAME.app"
BUILT="build/Release/$APP_NAME.app"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
SIGN_ID="${CODE_SIGN_IDENTITY:--}"   # default: ad-hoc

echo "▸ xcodegen"
xcodegen generate

echo "▸ xcodebuild (Release, sign: $SIGN_ID)"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
  -configuration Release SYMROOT=build -quiet \
  CODE_SIGN_IDENTITY="$SIGN_ID" CODE_SIGNING_ALLOWED=YES

echo "▸ Install to /Applications"
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
rm -rf "$INSTALLED"
cp -R "$BUILT" "$INSTALLED"
xattr -dr com.apple.quarantine "$INSTALLED" 2>/dev/null || true
"$LSREG" -f -R "$INSTALLED"

echo "▸ Launch + refresh widget stack"
open "$INSTALLED"
sleep 2
killall Dock NotificationCenter 2>/dev/null || true

echo "✓ Done. Open Notification Center → Edit Widgets → search “Hijri”."
