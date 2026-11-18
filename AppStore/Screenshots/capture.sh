#!/bin/sh
# Stages and captures every App Store screenshot in the Simulator, into a folder of raw captures for compose.swift.
# Needs AXe (brew install cameroncooke/axe/axe) for the taps and the lock button.
# Usage: AppStore/Screenshots/capture.sh <raw folder>
#   IPHONE and WATCH name the Simulators, by default "iPhone 18 Pro Max" and "Apple Watch Series 11 (46mm)": the 6.9"
#   iPhone size App Store Connect requires, and a Watch size it accepts. The script pairs them if they aren't.
set -eu

raw=${1:?usage: capture.sh <raw folder>}
iphone_name=${IPHONE:-iPhone 18 Pro Max}
watch_name=${WATCH:-Apple Watch Series 11 (46mm)}
command -v axe >/dev/null || {
	echo "capture.sh needs AXe: brew install cameroncooke/axe/axe" >&2
	exit 1
}

# The first available Simulator of a name, by its UDID, which AXe needs.
udid() {
	xcrun simctl list devices available | grep -F "$1 (" | head -1 | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}'
}
iphone=$(udid "$iphone_name")
watch=$(udid "$watch_name")
built=$(mktemp -d)
mkdir -p "$raw"
swiftc -O "$(dirname "$0")/clock.swift" -o "$built/time"

xcodebuild -scheme Temper -destination "id=$iphone" -derivedDataPath "$built" -quiet build
xcodebuild -scheme TemperWatch -destination "id=$watch" -derivedDataPath "$built" -quiet build
app="$built/Build/Products/Debug-iphonesimulator/Temper.app"
watch_app="$built/Build/Products/Debug-watchsimulator/TemperWatch.app"
id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
watch_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$watch_app/Info.plist")

xcrun simctl pair "$watch" "$iphone" >/dev/null 2>&1 || true
for device in "$iphone" "$watch"; do
	xcrun simctl boot "$device" 2>/dev/null || true
	xcrun simctl bootstatus "$device" -b >/dev/null
done
xcrun simctl install "$iphone" "$app"
xcrun simctl install "$watch" "$watch_app"

pause() { perl -e "select(undef, undef, undef, $1)"; }
clock() { xcrun simctl status_bar "$iphone" override --time "$1" --batteryState charged --batteryLevel 100 \
	--cellularBars 4 --wifiBars 3 --operatorName ''; }
# Captures a screen with the display's own shape, its corners black.
snap() { xcrun simctl io "$1" screenshot --mask=black "$2" >/dev/null 2>&1; }
launch() { xcrun simctl launch --terminate-running-process "$iphone" "$id" "$@" >/dev/null; }
# The seconds a running Workout has left, as VoiceOver reads them.
left() { axe describe-ui --udid "$1" 2>/dev/null | grep -oE '[0-9]+ seconds left' | grep -oE '^[0-9]+' | head -1; }

clock 9:41

# 1. Describe, with the Plan the model makes of the words, which fit the outline above Start.
launch -debugDescribe "4 rounds of 40 seconds of Burpees, 40 seconds of Squats and 20 seconds of rest"
pause 30
snap "$iphone" "$raw/1-describe.png"

# 2. That Plan's first Work, partway, so the ring shows progress.
launch -debugStart describe
pause 16
snap "$iphone" "$raw/2-work.png"

# 5. Setup with sample Presets and its Preset menu open.
launch -debugTab intervals -debugPresets YES
pause 5
axe tap --label Presets --udid "$iphone" >/dev/null
pause 2
snap "$iphone" "$raw/5-presets.png"

# 3. The Live Activity on the Lock Screen: lock, then wake. The first time, iOS asks to allow Live Activities, and
# later asks again whether to keep allowing them.
launch -debugStart describe
pause 10
axe button lock --udid "$iphone" >/dev/null
pause 2
axe button lock --udid "$iphone" >/dev/null
pause 3
for answer in "Always Allow" Allow; do
	axe tap --label "$answer" --udid "$iphone" >/dev/null 2>&1 && pause 3 && break
done
snap "$iphone" "$raw/3-live-activity.png"
axe button home --udid "$iphone" >/dev/null
pause 2

# 4. The iPhone and the Watch on the same Work. The Watch shows a sample (see TemperWatch/WatchDebugLaunch.swift),
# set to end when the iPhone's Work does. The clocks show the real time, since a Watch Simulator's can't be set.
launch -debugStart describe
pause 10
xcrun simctl spawn "$watch" defaults write "$watch_id" debugRunning -bool YES
# The iPhone's count is whole seconds rounded up, so the Work ends up to a second before it says: half a second less
# splits the difference.
end=$(perl -MTime::HiRes=time -e "printf '%.3f', time + $(left "$iphone") - 0.5")
xcrun simctl spawn "$watch" defaults write "$watch_id" debugRunningEnd -string "$end"
# The iPhone opens the Watch app at Start when Heart Rate is allowed, and that one read the defaults before they
# were written, so it's replaced.
xcrun simctl terminate "$watch" "$watch_id" 2>/dev/null || true
pause 1
xcrun simctl launch "$watch" "$watch_id" >/dev/null
pause 4
# Until the two captures show the same time, as clock.swift reads it off them. VoiceOver's counts can't tell: the
# Watch's rounds differently from its digits.
for attempt in 1 2 3 4 5 6 7 8; do
	clock "$(date +%-I:%M)"
	snap "$watch" "$raw/4-watch.png"
	snap "$iphone" "$raw/4-iphone.png"
	[ "$("$built/time" "$raw/4-iphone.png")" = "$("$built/time" "$raw/4-watch.png")" ] && break
	[ "$attempt" = 8 ] && echo "4-watch.png and 4-iphone.png show different times" >&2
	pause 0.3
done
xcrun simctl spawn "$watch" defaults delete "$watch_id" debugRunning
xcrun simctl spawn "$watch" defaults delete "$watch_id" debugRunningEnd
xcrun simctl terminate "$watch" "$watch_id" 2>/dev/null || true
xcrun simctl terminate "$iphone" "$id" 2>/dev/null || true

xcrun simctl status_bar "$iphone" clear
rm -rf "$built"
echo "captured into $raw"
