#!/bin/sh
# Captures the App Store screenshots the Simulator can stage with launch arguments alone (see Temper/DebugLaunch.swift)
# into a folder of raw captures, for compose.swift to frame.
# Usage: AppStore/Screenshots/capture.sh <raw folder>
set -eu

raw=${1:?usage: capture.sh <raw folder>}
device=${DEVICE:-iPhone 18 Pro Max}
built=$(mktemp -d)
mkdir -p "$raw"

xcodebuild -scheme Temper -destination "platform=iOS Simulator,name=$device" -derivedDataPath "$built" -quiet build
app="$built/Build/Products/Debug-iphonesimulator/Temper.app"
id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 \
	--cellularBars 4 --wifiBars 3 --operatorName ''
xcrun simctl install "$device" "$app"

# Launches Temper with the given arguments, waits, and captures the screen with the display's own shape.
shoot() {
	name=$1 wait=$2
	shift 2
	xcrun simctl launch --terminate-running-process "$device" "$id" "$@" >/dev/null
	sleep "$wait"
	xcrun simctl io "$device" screenshot --mask=black "$raw/$name" >/dev/null 2>&1
	echo "captured $raw/$name"
}

# The model's Plan takes a while; the words fit the outline above Start on a 6.9" iPhone.
shoot 1-describe.png 30 -debugDescribe "4 rounds of 40 seconds of Burpees, 40 seconds of Squats and 20 seconds of rest"
# Partway into the first Work, so the ring shows progress.
shoot 2-work.png 16 -debugStart describe
shoot 5-presets.png 5 -debugTab intervals -debugPresets YES

xcrun simctl status_bar "$device" clear
rm -rf "$built"
