#!/bin/zsh
# PROTOTYPE: builds Temper with Workout Types Probe and opens it in the Simulator.
# Arguments go to the app, for example: ./run.sh -variant d -type stopwatch -line left
set -euo pipefail
cd "${0:A:h}/../.."
udid=$(xcrun simctl list devices available | grep -E '^ +iPhone 18 Pro \(' | head -1 | grep -oE '[0-9A-F-]{36}')
derived="Prototypes/WorkoutTypesProbe/build"
xcodebuild -quiet -project Temper.xcodeproj -scheme Temper -configuration Debug \
  -destination "id=$udid" -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$udid" 2>/dev/null || true
open -b com.apple.iphonesimulator 2>/dev/null || echo "Simulator app not found. Open Temper.xcodeproj in Xcode and press Run to see the window."
app="$derived/Build/Products/Debug-iphonesimulator/Temper.app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
xcrun simctl install "$udid" "$app"
xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
xcrun simctl launch "$udid" "$bundle" "$@"
