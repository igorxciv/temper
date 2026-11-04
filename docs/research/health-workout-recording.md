# Recording a Health workout when the iPhone runs the Workout and the Watch controls it

Research for ticket #73 on map #70. Sources were read on 2026-11-03. Nothing here has been run on a device. The last section lists what only a device test can settle. Which device owns the session is ticket #75's decision, so this file sets out the options and doesn't pick one.

## Answer

- **Read this first: a Series 8 can't run watchOS 27.** Apple's watchOS page lists SE 3, Series 9 and later, and Ultra 2 and later ([watchOS][watchos]). Series 6, 7 and 8, SE 2 and the first Ultra stop at watchOS 26 ([MacRumors][macrumors-drop], Report). Xcode 27.2 also warns that `arm64_32`, the Series 8's architecture, "is deprecated for your deployment target (watchOS 27.0)" (Tested). So the Temper Watch app has to target **watchOS 26 and include `arm64_32`**, or it won't install on the owner's Watch. watchOS 27-only APIs, such as workout zones, are out of reach on that Watch.
- **Only the Watch can host a mirrored session.** `startMirroringToCompanionDevice` exists only on watchOS. The Watch is always the primary and the iPhone the mirror ([doc][start-mirroring], [Apple staff][forum-740630]). iOS 26 added `HKWorkoutSession` on iPhone ([doc][init], [updates][updates]), but no API mirrors an iPhone session to the Watch, and the 2025 and 2026 HealthKit updates add none ([updates][updates]).
- **Heart rate comes from the Watch's own session.** iPhone has no heart-rate sensor. An iPhone session gets heart rate only from a paired Bluetooth heart-rate-profile device ([doc][session], [WWDC25 322][wwdc25-322]). Apple's advice for an app that has a Watch app: "be sure to start the workout there to get all available metrics" and mirror it to the iPhone ([WWDC25 322][wwdc25-322]).
- **A Watch-primary session fits "iPhone in charge" better than it sounds.** The iPhone can start it with `startWatchApp(toHandle:)` ([doc][start-watch-app]). Both sides can send arbitrary `Data` over the session ([doc][send-remote]). The Watch app stays running in the background for the whole session, which a remote needs ([doc][running-sessions]). The Watch saves the workout ([WWDC23 10023][wwdc23-10023]).
- **One activity type per workout.** Interval activities must use the workout's own activity type. "You can't mix activities within a single workout." The only exception is `swimBikeRun` ([doc][dividing]). Each Round's Work and Rest can be an `HKWorkoutActivity` of that type with custom metadata, or a `segment` event ([doc][dividing], [doc][event]).
- **`Packages/TemperCore` builds for watchOS as it stands.** It builds for the Simulator and device with no source changes and no warnings. It also builds at a watchOS 26.0 deployment target for `arm64_32` and `arm64` (Tested, details below). `Package.swift` doesn't list watchOS, so it should gain `.watchOS(.v26)`.

## How to read the labels

| Label | Meaning |
|---|---|
| **Doc** | Current Apple documentation, read from the developer site's Markdown renderings. |
| **WWDC** | An Apple WWDC session transcript. |
| **Apple staff** | A forum reply with an Apple badge. Informed, but not a contract. |
| **Report** | Press or developer report, not an Apple source. |
| **Tested** | Run locally on this Mac with Xcode 27.2 (27B52). |
| **Inferred** | My conclusion. No source states it. |
| **Unconfirmed** | I looked and found no source. |

## 1. Which device can own the session

### What each device can do

| | Watch primary, mirrored to iPhone | iPhone primary (iOS 26+) | iPhone, no session, `HKWorkoutBuilder` |
|---|---|---|---|
| Create it | Watch app, or the iPhone via `startWatchApp(toHandle:)` | iPhone app | iPhone app |
| Heart rate | Watch sensors, high-frequency for the whole session (Doc) | Only from a Bluetooth heart-rate strap (Doc). Watch heart rate isn't streamed in (Inferred) | Only samples the app adds itself (Doc) |
| Calories | Watch calorimetry tuned to the activity type (Doc) | System-generated iPhone metrics, which "may" differ from what was requested (Doc) | None unless the app adds them (Inferred) |
| Activity rings | The workout builder updates rings (WWDC25). Watch sensors supply Move and Exercise (Inferred) | Builder updates rings (WWDC25). How much Exercise credit an iPhone-only workout earns: **Unconfirmed** | **Unconfirmed** |
| Mirror to the other device | Yes, Watch to iPhone only (Doc) | No API (Doc, by absence) | No |
| Keeps the Watch app alive | Yes, `workout-processing` (Doc) | No, so the Watch app suspends on wrist-down (Inferred from `isReachable`) | No |
| Saved by | Watch, which syncs to iPhone (WWDC23) | iPhone | iPhone |

**Sources for the table:**

- **Doc:** `startMirroringToCompanionDevice(completion:)` is available on watchOS 10 and later only: "Call this method in your watchOS app to start a mirrored workout session on the companion iOS app. If your iOS app isn't running, the system launches it in the background" ([doc][start-mirroring]).
- **Apple staff (2023, before iOS 26):** "Live workout sessions are only available on watchOS and not on iOS. … iOS can mirror watch workout sessions now. But the watch continues to remain the main device for workouts" ([forum][forum-740630]). iOS 26 changed the first half, since `HKWorkoutSession.init(healthStore:configuration:)` is iOS 26.0 and later ([doc][init]). Nothing changed the second half. The iOS mirroring entry points are still the receive-side `workoutSessionMirroringStartHandler` and `sendToRemoteWorkoutSession` ([doc][mirror-handler], [doc][send-remote]).
- **Doc:** "Collecting heart rate data on iPhone or iPad requires pairing with an external heart rate sensor because these devices don't have one. iPhone and iPad can collect various workout metrics, but the system may generate different samples than those specifically requested by an app" ([HKWorkoutSession][session]).
- **WWDC25 322:** iPhone and iPad "don't contain a heart rate sensor. But you can pair them with any device … that supports the heart rate GATT profile." Also: "If you have a Watch app, be sure to start the workout there to get all available metrics. Just call Start Watch App from the Health Store. And once you have, be sure to mirror the workout to the iPhone." And: "always use the workout builder API to create and save a workout. This will ensure that activity rings are appropriately updated" ([WWDC25 322][wwdc25-322]).
- **Doc:** On the Watch, "all workout sessions generate high-frequency heart rate samples". Apple Watch "optimizes both the sensors and the calorimetry based on the configuration". Activities without a tuned model get calories estimated from the Watch's sensors ([Running workout sessions][running-sessions]).
- **Doc:** "Apple Watch runs one workout session at a time. If a second workout starts while your workout is running, your … delegate … receives an `errorAnotherWorkoutSessionStarted` error, and your session ends" ([HKWorkoutSession][session]).
- **Doc:** `HKWorkoutBuilder` (iOS 12+) is "not connected to a workout session or other data source" when created with `init(healthStore:configuration:device:)`. It can add samples, events, activities and metadata, then save ([HKWorkoutBuilder][builder]).
- **Doc:** "If the user doesn't start and stop a workout session in your watchOS app, don't try to retroactively create a workout session on Apple Watch" ([Running workout sessions][running-sessions]).

### Options for ticket #75

**A. The Watch owns the session and mirrors it to the iPhone.** The iPhone engine still runs the Workout and speaks the Cues. The Watch session only records it.

- For: Watch heart rate and calories, rings updated by the Watch, and a Watch app that stays alive and reachable all Workout. It's the path Apple documents and ships sample code for ([sample][sample]). One channel carries both control and state.
- Against: the Watch's HealthKit session runs alongside the iPhone engine, and their states must stay in step: start, pause, Stop, and which Phase it is. The Watch builder writes the activities and events, so the iPhone must send every Phase change to it (Inferred). A run with no Watch, or with the Watch off the wrist, needs a separate path, B or C. If the Watch app crashes, the workout is recovered on the Watch ([doc][running-sessions]), but the iPhone gets a new mirrored session instance (Doc, see section 2).
- Starting: from the iPhone, `startWatchApp(toHandle:)` "launches or wakes the companion watchOS app". The Watch app's `WKApplicationDelegate.handle(_:)` then creates and mirrors the session ([doc][start-watch-app]). From the Watch, starting the session and mirroring it launches the iPhone app in the background, which gets "10 seconds to start a live activity and call a handler to start mirroring" ([WWDC23 10023][wwdc23-10023]). Whether a background-launched Temper can start its audio engine from that state is **Unconfirmed**.

**B. The iPhone owns an iOS 26+ session, and the Watch is a plain WatchConnectivity remote.**

- For: one owner, the device that already runs the engine. The Workout is recorded even when no Watch is present. It needs no Watch HealthKit code.
- Against: no heart rate unless the owner wears a Bluetooth strap. The Watch app has no workout session, so it isn't kept running in the background, and `WCSession` live messaging from the iPhone "does not wake up the corresponding WatchKit extension" ([sendMessage][wc-send]). The Watch can't run its own session alongside to fill the gap without risking two saved workouts (Inferred). The iPhone's "health data usually isn't accessible while the device is locked", which shows up as a first-run prompt ([doc][session], [WWDC25 322][wwdc25-322]). Whether an iPhone `HKWorkoutSession` keeps a backgrounded app running is still **Unconfirmed**. `workout-processing` is documented for watchOS only ([background modes][bg-modes]). The earlier background-execution research left this open too.

**C. A hybrid: A when the Watch app is reachable at Start, B or a plain `HKWorkoutBuilder` save when it isn't.**

- For: every Workout is recorded, and Watch metrics are used whenever the Watch is there.
- Against: two recording paths to build and test. The rule for picking one is decided at Start and must not flip mid-Workout (Inferred).

Option C covers the map's open question, "whether a phone-only run is still recorded". A phone-only run can be recorded through B or a builder save, without heart rate.

## 2. How control and state cross between the devices

### The mirrored session's data channel

- **Doc:** `sendToRemoteWorkoutSession(data:)` takes any `Data` and works "from either the mirrored or primary session". It is available on iOS 17 and watchOS 10 and later ([doc][send-remote]). The receiver gets `workoutSession(_:didReceiveDataFromRemoteWorkoutSession: [Data])` ([delegate][delegate]).
- **WWDC23:** the iPhone can pause and resume the mirrored session, and "the primary session delegate on my Apple Watch gets notified about the state change" ([WWDC23 10023][wwdc23-10023]). Whether the mirrored side can **end** the session, or add activities and events through its own builder, is **Unconfirmed**. Apple's guide says that if a Watch-started workout is ended from the iPhone, the iPhone app "should instruct the user to end the workout in your watchOS app" ([doc][running-sessions]), which suggests not (Inferred). Sending a Temper command such as "Stop" over the data channel and letting the Watch end its own session avoids the question.
- **Doc:** the docs and the WWDC23 session give no size limit, latency or delivery guarantee for the channel. **Unconfirmed.**
- **Doc, disconnects:** when the mirrored session disconnects, "the provided workout session is no longer valid". "If the primary workout session is still running, it automatically tries to reconnect. If successful, the companion iOS device calls the `workoutSessionMirroringStartHandler` block again, passing in a new, valid `HKWorkoutSession` instance" ([didDisconnect][did-disconnect], [mirroring handler][mirror-handler]). The handler should be set "as soon as your app launches", and it is called "from an arbitrary background queue" ([mirroring handler][mirror-handler]).
- **Inferred:** while they're apart, the Watch keeps recording heart rate and the iPhone keeps running the Workout. Commands sent in that window fail, since the send completion reports `success == false`. On reconnect, the iPhone should send a full state snapshot rather than replay the events it missed. A Stop on the iPhone during a disconnect leaves the Watch session running until they reconnect. The spec needs a rule for that, such as the Watch ending its session when it hears nothing for N seconds.

### WatchConnectivity

- **Doc:** `sendMessage` "sends a message immediately". Messages "are queued serially and delivered in the order in which you sent them". Sending from an active Watch app "wakes up the corresponding iOS app in the background". Sending from iOS "does not wake up the corresponding WatchKit extension". An unreachable counterpart triggers the error handler ([sendMessage][wc-send]).
- **Doc:** the Watch side is reachable when the iPhone is in range and the Watch app is in the foreground "or is running with a high priority in the background (for example, during a workout session…)". The iOS side is reachable only when the Watch app is running and reachable ([isReachable][wc-reachable]).
- **Inferred:** without a Watch workout session (option B), the Watch app suspends on wrist-down. Each raise starts with a stale screen until a fresh state arrives. With a session (option A), WatchConnectivity and the mirrored channel are both available. WatchConnectivity is still the tool for things outside a Workout, such as syncing Presets, Settings and remembered values with `updateApplicationContext` or `transferUserInfo`.
- **Unconfirmed:** Apple publishes no latency numbers for either channel. A tap-to-Cue round trip has to be measured.

## 3. Recording structure inside a workout

- **Doc, activities:** `HKWorkoutActivity` can "represent the active and rest periods during interval training". "All workout activities must use the same activity type as the containing workout. You can't mix activities within a single workout." Activities "can't overlap", and they "don't need to cover the entire `HKWorkout`". "For interval training, you can use the same activity type as the workout for the rest periods; however, you may want to add custom metadata to indicate whether the activity is an active or resting interval." For work-and-rest HIIT, "you may want to leave the rest intervals blank" ([Dividing a workout into activities][dividing]).
- **Doc, live:** `beginNewActivity(configuration:date:metadata:)` is on the session (watchOS 9+, iOS 17+). It ends the current activity first. "For interval training, the activity's configuration must use the same activity type as the containing workout" ([doc][begin-activity]). The data source switches the collected types automatically unless the app set them explicitly (same page).
- **Doc, after the fact:** `HKWorkoutBuilder.addWorkoutActivity(_:)` and `updateActivity(uuid:end:)` add activities from saved timestamps ([HKWorkoutBuilder][builder]). That fits options B and C, where the engine already knows each Phase's boundaries.
- **Doc, events:** `HKWorkoutEventType` has `pause`, `resume`, `motionPaused`, `motionResumed`, `pauseOrResumeRequest`, `lap`, `segment` and `marker` ([doc][event-type]). "Segment events mark important periods during the workout, while markers identify important points in time." Laps are for equal distances ([HKWorkoutEvent][event]). Events take a `DateInterval` and metadata, and a builder adds them with `addWorkoutEvents(_:)` ([builder][builder]). Pause and resume events toggle the workout's active state. Duplicates are ignored ([HKWorkoutEvent][event]).
- **Doc:** activities expose per-activity `allStatistics`, such as average heart rate, plus the events inside them, and they can be queried by predicate ([HKWorkoutActivity][activity], [dividing][dividing]).

**Mapping onto Temper (Inferred):**

- Each Work is one activity with metadata such as `Phase = work` and `Round = n`. Each Rest is either a separate activity with `Phase = rest`, or left blank.
- Prepare and Cooldown are activities with their own Phase metadata, or they sit outside the workout's start and end. Recording a Cooldown under HealthKit's `cooldown` activity type isn't possible inside the same workout, because types can't be mixed.
- Open Rounds has no fixed Round count, which suits `beginNewActivity` at each hand-ended Work. Stopwatch is a single activity.
- A `segment` event per Phase is the lighter alternative. It gives no per-segment statistics object, though statistics can be computed over its interval.

**What Fitness shows** for third-party activities, segments or markers isn't documented anywhere I found. **Unconfirmed**, so a device test has to look.

## 4. Activity types

From [HKWorkoutActivityType][activity-type] (Doc):

| Case | Apple's description | Fits |
|---|---|---|
| `traditionalStrengthTraining` | "strength training exercises primarily using machines or free weights" | Open Rounds at the gym |
| `functionalStrengthTraining` | "strength training, primarily with free weights and body weight" | Body-weight or free-weight circuits |
| `highIntensityIntervalTraining` | "high intensity interval training" | Intervals |
| `crossTraining` | "any mixture of cardio, strength, and/or flexibility training" | Mixed sessions |
| `mixedCardio` | "a variety of cardio exercise machines or modalities" | Cardio-only mixes |
| `coreTraining` | "core training" | |
| `cooldown`, `preparationAndRecovery`, `flexibility` | warm-up, stretching, mobility | Separate workouts only |
| `other` | "does not match any of the other workout activity types" | Fallback |

- **Doc:** one workout can't mix types, except that `swimBikeRun` takes swimming, cycling, running and `transition` activities ([dividing][dividing], [begin-activity][begin-activity]).
- **Inferred:** the activity type is chosen per Workout at Start, from the Workout Type, a Preset or a setting. A training that mixes strength and cardio becomes `crossTraining`, or one workout per block, which loses the single-workout view.
- **Doc:** calories for activities without a tuned model are estimated from the Watch's sensors, with a brisk-walk floor ([running sessions][running-sessions]). Strength and HIIT calories are therefore estimates.

## 5. Entitlements, privacy strings, prompts and the public repo

**What each target needs (Doc unless marked):**

- **iOS app and Watch app:** the HealthKit capability, which writes the `com.apple.developer.healthkit` entitlement ([Setting up HealthKit][setup]). Xcode also adds `healthkit` to the iOS app's required device capabilities. watchOS doesn't use that entry (same page).
- **Both:** `NSHealthShareUsageDescription` for reads and `NSHealthUpdateUsageDescription` for writes. On watchOS 6 and later, people can authorize on the Watch itself, so the Watch target needs both strings too ([running sessions][running-sessions]).
- **Authorization:** request share for `HKWorkoutType.workoutType()`, plus reads such as `heartRate`, `activeEnergyBurned` and the activity summary ([running sessions][running-sessions]). Request only the types the app uses ([WWDC25 322][wwdc25-322]).
- **Watch app:** the Background Modes capability with **Workout processing** (`workout-processing`), which is watchOS-only. Add **Audio** if the Watch plays sound or haptics during the session ([running sessions][running-sessions], [background modes][bg-modes]).
- **Watch app:** `WKCompanionAppBundleIdentifier` set to the iOS app's bundle ID ([sample][sample]).
- **iPhone session, option B:** the first iPhone session shows a system prompt that makes workout data available while the device is locked ([WWDC25 322][wwdc25-322]).

**Free account:** Apple's watchOS capability table gives HealthKit and Background modes checkmarks in the free "Apple Developer" column. I parsed this from the page's HTML, because text extraction drops the checkmarks. HealthKit Estimate Recalibration has no free checkmark ([watchOS capabilities][caps-watchos]). The free-signing research found the same for iOS. A Watch app adds an App ID and a registered device, within the free limits of 10 App IDs and 3 devices.

**What stays out of tracked files in this public repo:**

- The `.entitlements` file holds only `com.apple.developer.healthkit` (and `.access` if used), with no personal values. It can be tracked (Inferred).
- `WKCompanionAppBundleIdentifier` and any App Group must be built from `$(BUNDLE_ID_PREFIX)` in the xcconfig, never a literal ID (Inferred, from `AGENTS.md` and `make identifiers`).
- The Watch target's signing goes in `Config/Local.xcconfig`, like the others. Using the Team picker on the new target would write the team into `project.pbxproj` (Inferred, from `AGENTS.md`).
- No Health data, exported workouts, heart-rate logs or Watch identifiers go in timing logs or fixtures that might be committed (Inferred).

## 6. Live heart rate for a future widget

- **Doc:** on the Watch, `HKLiveWorkoutBuilderDelegate.workoutBuilder(_:didCollectDataOf:)` fires as samples arrive. `statistics(for: heartRate)` gives the latest and average values ([running sessions][running-sessions]).
- **Doc:** the multi-device sample sends the Watch's live statistics to the iPhone over `sendToRemoteWorkoutSession`. Apple's snippet error string reads "sending the health data to the companion iPhone" ([send-remote][send-remote], [WWDC23 10023][wwdc23-10023]). That's the documented way to show live Watch heart rate on the iPhone, so a Live Activity or iPhone widget depends on option A.
- **Inferred:** data that arrives over the data channel belongs to the app, not the locked HealthKit store. The iPhone can therefore put it in the Live Activity while locked. Under option B, Apple's locked-device guidance applies: omit the metric if access is denied ([WWDC25 322][wwdc25-322]).
- **Doc:** watchOS 27 and iOS 27 add live heart-rate **zones** through `HKLiveWorkoutBuilderDelegate` ([updates][updates], [WWDC26 207][wwdc26-207]). These need watchOS 27, so the owner's Series 8 won't get them (Inferred from the compatibility list).
- **Inferred:** without a Watch session, the iPhone only sees the Watch's background heart-rate samples after they sync, which is too slow and too sparse for a live widget.

## 7. Does `Packages/TemperCore` build for watchOS?

**Yes, with no source changes.** `Package.swift` declares `platforms: [.iOS(.v27), .macOS(.v27)]`, and the sources import only `Foundation`. A plain `swift build` builds only for the host Mac, so I used `xcodebuild` on the package. Xcode 27.2 (27B52) with the watchOS 27.2 SDK gave these results (Tested):

| Command (run in `Packages/TemperCore`) | Result |
|---|---|
| `xcodebuild -scheme TemperCore -destination 'generic/platform=watchOS Simulator' build` | Succeeded, 0 warnings. Built `arm64` and `x86_64` simulator, watchOS 27.0 |
| `xcodebuild -scheme TemperCore -destination 'generic/platform=watchOS' build` | Succeeded, 0 warnings. Built **`arm64` only**, watchOS 27.0 |
| same, `ARCHS=arm64_32` | Succeeded, with "The arm64_32 architecture is deprecated for your deployment target (watchOS 27.0)" |
| same, `ARCHS="arm64_32 arm64" WATCHOS_DEPLOYMENT_TARGET=26.0` | Succeeded, 0 warnings, both architectures |

What this means for the build:

- **Inferred:** an unlisted platform falls back to a default deployment target, which here was watchOS 27.0. Add `.watchOS(.v26)` to `platforms` so the package matches a Watch app that has to run on a Series 8.
- **Inferred:** the Watch app target needs a watchOS 26 deployment target. Its standard architectures at that target should then include `arm64_32`. Check the built binary with `lipo -archs` before calling it done.
- `make test` still runs on macOS and is unaffected. A Watch app could share the engine, but the settled design keeps the engine on the iPhone. On the Watch, the package would at most format display state such as `ClockText` (Inferred).

## What only a device test can settle

1. **The Watch app installs and debugs on the Series 8 (watchOS 26) from Xcode 27.2,** with a watchOS 26 target and `arm64_32` in the binary.
2. **Tap-to-effect latency** for the quick action over the mirrored data channel versus `WCSession.sendMessage`, measured from the Watch tap to the iPhone Cue, at the gym distance (Bluetooth) and over Wi-Fi.
3. **Disconnect behaviour:** walk out of range mid-Rest and come back. Check the reconnect time, that `workoutSessionMirroringStartHandler` fires again, and what the Watch shows meanwhile.
4. **Whether the mirrored iPhone session can end the session or add activities and events,** or only pause and resume.
5. **What Fitness shows** on iPhone and Watch for a third-party workout with per-Round activities, with Rest left blank or recorded, and with `segment` events.
6. **Rings:** Exercise and Move credit for a Watch-primary strength or HIIT workout versus an iPhone-primary one.
7. **Starting from the Watch:** whether a background-launched iPhone Temper can start its audio engine and speak the first Cue in time.
8. **An iPhone-primary session (option B), if chosen:** whether it keeps a locked, backgrounded Temper running without the `audio` mode, and how the locked-data prompt behaves.

## Sources

[watchos]: https://www.apple.com/os/watchos/
[macrumors-drop]: https://www.macrumors.com/2026/06/19/apple-explains-why-watchos-27-drops-support/
[session]: https://developer.apple.com/documentation/healthkit/hkworkoutsession
[init]: https://developer.apple.com/documentation/healthkit/hkworkoutsession/init(healthstore:configuration:)
[start-mirroring]: https://developer.apple.com/documentation/healthkit/hkworkoutsession/startmirroringtocompaniondevice(completion:)
[send-remote]: https://developer.apple.com/documentation/healthkit/hkworkoutsession/sendtoremoteworkoutsession(data:completion:)
[begin-activity]: https://developer.apple.com/documentation/healthkit/hkworkoutsession/beginnewactivity(configuration:date:metadata:)
[mirror-handler]: https://developer.apple.com/documentation/healthkit/hkhealthstore/workoutsessionmirroringstarthandler
[start-watch-app]: https://developer.apple.com/documentation/healthkit/hkhealthstore/startwatchapp(with:completion:)
[delegate]: https://developer.apple.com/documentation/healthkit/hkworkoutsessiondelegate
[did-disconnect]: https://developer.apple.com/documentation/healthkit/hkworkoutsessiondelegate/workoutsession(_:diddisconnectfromremotedevicewitherror:)
[builder]: https://developer.apple.com/documentation/healthkit/hkworkoutbuilder
[activity]: https://developer.apple.com/documentation/healthkit/hkworkoutactivity
[dividing]: https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities
[event]: https://developer.apple.com/documentation/healthkit/hkworkoutevent
[event-type]: https://developer.apple.com/documentation/healthkit/hkworkouteventtype
[activity-type]: https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype
[running-sessions]: https://developer.apple.com/documentation/healthkit/running-workout-sessions
[setup]: https://developer.apple.com/documentation/healthkit/setting-up-healthkit
[updates]: https://developer.apple.com/documentation/updates/healthkit
[sample]: https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app
[bg-modes]: https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
[wc-send]: https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage(_:replyhandler:errorhandler:)
[wc-reachable]: https://developer.apple.com/documentation/watchconnectivity/wcsession/isreachable
[caps-watchos]: https://developer.apple.com/help/account/reference/supported-capabilities-watchos/
[forum-740630]: https://developer.apple.com/forums/thread/740630
[wwdc23-10023]: https://developer.apple.com/videos/play/wwdc2023/10023/
[wwdc25-322]: https://developer.apple.com/videos/play/wwdc2025/322/
[wwdc26-207]: https://developer.apple.com/videos/play/wwdc2026/207/

- Apple, [watchOS][watchos]: the watchOS 27 compatibility list.
- MacRumors, [Apple explains why watchOS 27 drops support][macrumors-drop] (Report).
- HealthKit docs: [HKWorkoutSession][session], [init(healthStore:configuration:)][init], [startMirroringToCompanionDevice][start-mirroring], [sendToRemoteWorkoutSession][send-remote], [beginNewActivity][begin-activity], [workoutSessionMirroringStartHandler][mirror-handler], [startWatchApp][start-watch-app], [HKWorkoutSessionDelegate][delegate], [didDisconnectFromRemoteDevice][did-disconnect], [HKWorkoutBuilder][builder], [HKWorkoutActivity][activity], [Dividing a HealthKit workout into activities][dividing], [HKWorkoutEvent][event], [HKWorkoutEventType][event-type], [HKWorkoutActivityType][activity-type], [Running workout sessions][running-sessions], [Setting up HealthKit][setup], [HealthKit updates][updates], [Building a multidevice workout app][sample].
- Xcode: [Configuring background execution modes][bg-modes]. Account help: [Supported capabilities (watchOS)][caps-watchos].
- WatchConnectivity: [sendMessage][wc-send], [isReachable][wc-reachable].
- Apple Developer Forums: [thread 740630][forum-740630] (Apple staff).
- WWDC: [23 10023 Build a multi-device workout app][wwdc23-10023], [25 322 Track workouts with HealthKit on iOS and iPadOS][wwdc25-322], [26 207 Deliver workout insights with HealthKit workout zones][wwdc26-207].
