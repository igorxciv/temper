#!/bin/zsh
# PROTOTYPE: builds Screens Probe and opens it in the Simulator.
# Arguments are passed to the app, for example: ./run.sh -setup B -running C
set -euo pipefail
cd "${0:A:h}"
udid=$(xcrun simctl list devices available | grep -E '^ +iPhone 18 Pro \(' | head -1 | grep -oE '[0-9A-F-]{36}')
xcodebuild -quiet -project ScreensProbe.xcodeproj -scheme ScreensProbe -configuration Debug \
  -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$udid" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$udid" build/Build/Products/Debug-iphonesimulator/ScreensProbe.app
xcrun simctl terminate "$udid" org.example.screensprobe 2>/dev/null || true
xcrun simctl launch "$udid" org.example.screensprobe "$@"
