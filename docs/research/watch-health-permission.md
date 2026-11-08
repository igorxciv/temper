# Health permission for the Watch app

Research for ticket #113 on map #100. Sources were read on 2026-11-07. Nothing here has been run on a device. The last section lists what only a device test can settle.

The iPhone asks for one thing today: permission to share workouts, with no reads (`Temper/HealthKitWorkouts.swift`, `Config/Temper-Info.plist`). Settings' Apple Health section shows that status and is the only place Temper asks (`Temper/AppleHealthSection.swift`). Ticket #102 decided that the Watch app ships only as a companion and that the iPhone calls `startWatchApp` at every Start. Ticket #75 decided that the Watch owns the Health session with heart rate when it joins within 10 s, and the iPhone saves alone otherwise. This file builds on [`watch-health-session.md`](https://github.com/igorxciv/temper/blob/research/watch-health-session/docs/research/watch-health-session.md) (ticket #103) and [`iphone-health-save.md`](https://github.com/igorxciv/temper/blob/research/iphone-health-save/docs/research/iphone-health-save.md) (ticket #84) and doesn't repeat them.

The Watch runs watchOS 26.5 and the Watch target deploys to watchOS 26. The iPhone runs iOS 27.

## Answer

- **Types: share workouts, read heart rate. Nothing else is required.** Apple's guide and both Apple samples ask to share only `workoutType()`, yet their live builders save heart-rate and energy samples (Doc, Sample, WWDC). Reads are what lets the app see data it didn't write. Apple asks to read heart rate, active energy and distance "automatically recorded by Apple Watch as part of the session" (Doc). Temper shows live heart rate on the Watch (#102), so it should read heart rate and, optionally, active energy. Whether the builder's live statistics reach the app without read permission is undocumented (Unconfirmed). The Watch target needs the HealthKit capability and both usage strings, `NSHealthUpdateUsageDescription` and `NSHealthShareUsageDescription`, because it reads as well as writes (Doc, WWDC).
- **One grant or two: undocumented for today's single-target Watch apps, and the reports disagree.** Apple said in 2016 that "authorizations are shared between your iOS app and its companion watchOS app" (WWDC16). That was the WatchKit-extension era. In 2022, developers moving to Xcode 14's single-target Watch app saw a separate dialog and a separate entry in Settings for each app (Report). A 2026 developer log shows a decision made on the Watch syncing to the phone (Report). The bundle IDs differ (`<iOS ID>.watchkitapp`), and no Apple document says the grant crosses devices (Unconfirmed). A device test settles it. Until then, design for two grants. That design also works if the grant is shared.
- **Where the prompt appears: on the Watch.** "In watchOS 6 and later, this method displays the permission form on Apple Watch" (Doc). The iPhone has no API to ask on the Watch app's behalf. `handleAuthorizationForExtension` is for app extensions and is unavailable on watchOS (SDK). If the grant turns out to be shared, an iPhone request that includes the Watch's types would cover the Watch ahead of time. If it isn't, nothing the iPhone asks helps the Watch (Inferred). So the Watch app should ask in its own foreground UI, before the first Watch Workout.
- **`startWatchApp` with no permission: no rule is published, so the Watch app must check first.** `startWatchApp` launches the Watch app "in the background" and calls `handle(_:)` (Doc). Creating `HKWorkoutSession` fails only for an invalid configuration (SDK). Whether the session then starts, records, or fails without permission is undocumented (Unconfirmed). Saving can't succeed: "any attempts to save fail with an `errorAuthorizationNotDetermined` error" (Doc). A background launch is no place for a permission sheet. A developer reports an unanswered sheet turning into a denial during exactly this relaunch (Report). So in `handle(_:)` the Watch app should check `authorizationStatus(for: .workoutType())`. If it isn't `.sharingAuthorized`, the Watch starts no session and doesn't ask. It tells the iPhone at once, so the iPhone records the Workout itself without waiting out the 10 s (Inferred).
- **The iPhone can't query the Watch app's status. The Watch has to report it.** `authorizationStatus(for:)` answers for "the application" calling it, on the device it runs on (SDK). Write status is visible on the Watch. Read status (heart rate) is hidden on every device (Doc). So the Watch app sends its own workout write status to the iPhone whenever it runs: on foreground, after a prompt, and in `handle(_:)`. The iPhone keeps the last value for Settings (Inferred). If the device test shows one shared grant, the iPhone's own status already is the Watch's, and the report changes nothing.

## How to read the labels

| Label | Meaning |
|---|---|
| **Doc** | Apple developer documentation, read from the site's JSON data. |
| **SDK** | Headers and Swift interfaces in Xcode 27.2 (watchOS 27.2 and iOS 27.2 SDKs). |
| **Sample** | Apple's sample code project *Building a multidevice workout app*, downloaded from its documentation page. |
| **WWDC** | An Apple WWDC session transcript. |
| **Apple staff** | A forum reply with an Apple badge. Informed, but not a contract. |
| **Report** | A developer report on the forums or GitHub, not an Apple source. |
| **Tested** | Typechecked on this Mac with `xcrun --sdk watchos swiftc -typecheck -target arm64_32-apple-watchos26.0 -swift-version 6 -warnings-as-errors`. Nothing was run. |
| **Inferred** | My conclusion. No source states it. |
| **Unconfirmed** | I looked and found no source. |

## 1. Which types the Watch session needs

### What Apple asks for

- **Doc:** "For workout sessions, you must request permission to share workout types. You may also want to read any data types automatically recorded by Apple Watch as part of the session." The listed code shares `workoutType()` and reads `heartRate`, `activeEnergyBurned`, `distanceWalkingRunning`, `activitySummaryType()` and `activityMoveMode` ([Running workout sessions][running]).
- **Doc:** in the same guide, "while the session runs, Apple Watch automatically collects data about the workout, and saves samples to the HealthKit store. For example, an outdoor running session collects and saves `activeEnergyBurned`, `basalEnergyBurned`, `heartRate`, and `distanceWalkingRunning` samples" ([running]). It asks for no share permission on any of those types.
- **Sample:** the multidevice sample uses one set of types for both apps. It shares `workoutType()` and `dietaryWater` (water is the sample's own manual entry), and reads heart rate, active energy, walking and cycling distance, cycling speed, power and cadence, water, workouts, the activity summary and the move mode (`Shared/WorkoutManager.swift`). The Watch's live builder uses `HKLiveWorkoutDataSource` with no share permission for heart rate or energy (`Shared/WorkoutManager+watchOS.swift`).
- **WWDC21 10009:** "For workout sessions, we must request permission to share workout types. We also want to read any data types automatically recorded by Apple Watch as part of the session." The code shares `workoutType()` only ([WWDC21][wwdc21]).
- **WWDC18 707:** "my typesToShare here is workout because I want to be able to save a workout at the end. Next, I would like to read heartRate, activeEnergyBurned, as well as distanceWalkingRunning" ([WWDC18][wwdc18]).
- **Inferred:** the samples the live data source saves don't need share permission per type, since every Apple example saves them without it. Apple doesn't say whose source they carry.

### What reading does

- **Doc:** "your app cannot determine whether or not a user has granted permission to read data. If you are not given permission, it simply appears as if there is no data of the requested type in the HealthKit store. If your app is given share permission but not read permission, you see only the data that your app has written to the store" ([authorizationStatus][auth-status]).
- **Unconfirmed:** whether `HKLiveWorkoutBuilder.statistics(for:)` and `workoutBuilder(_:didCollectDataOf:)` deliver heart rate to an app with no heart-rate read permission. No Apple source says, and every Apple example asks to read it. A 2019 forum answer says to request "the permissions required for the sample types you want", without a source ([forum 110498][f110498], Report).
- **Inferred for Temper:** the Watch asks to share `workoutType()` and to read `heartRate`. Add `activeEnergyBurned` to the reads only if the Watch shows energy, which #102 doesn't ask for. Basal energy and distance aren't shown, so don't ask to read them. WWDC25: "only request for authorization for data types you need" ([WWDC25 322][wwdc25], quoted in the iPhone research).

### Capability and strings

- **Doc:** "In watchOS 6 and later, users can authorize reading and sharing data on Apple Watch. As a result, you must add usage descriptions to your WatchKit App Extension. Use the `NSHealthShareUsageDescription` key to describe why your app needs to read the requested data. Use `NSHealthUpdateUsageDescription` for the data your app intends to write" ([running]). For a single-target Watch app, that's the Watch app target's Info.plist or `INFOPLIST_KEY_` settings (Inferred).
- **Doc:** "You must set the usage keys, or your app will crash when you request authorization" ([requestAuthorization][request-auth]).
- **WWDC18 707:** turn on the HealthKit capability, "and you should also do the same for your WatchKit app extension" ([WWDC18][wwdc18]). The Watch target needs its own HealthKit entitlement (Inferred, single target).
- **Doc:** the `healthkit` entry in required device capabilities "isn't used by watchOS apps" ([Setting up HealthKit][setup]).
- **Workout processing background mode:** "Workout sessions require the Workout processing background mode" ([running]). This is not a permission, but it's the other Watch target setting the session needs.

## 2. One grant or two

### What Apple has said

- **WWDC16 209 (watchOS 3):** "Authorizations are shared between your iOS app and its companion watchOS app", and "you can request authorization at any time from your iOS code or your watchOS code". In that era "the system authorization UI can only be presented to the user on the phone" ([WWDC16 transcript][wwdc16]). Those Watch apps ran their code in a WatchKit extension.
- **WWDC18 707 (watchOS 5):** "because the watch screen is small, the user will be presented with an authorization sheet on the phone. So you need to make sure to also handle authorization on your iPhone app" ([WWDC18][wwdc18]).
- **WWDC19 208 (watchOS 6):** "with watchOS 6, we now support giving health authorization directly on Apple Watch" ([WWDC19][wwdc19]). The session doesn't say whether the grant still crosses to the iPhone app.
- **Doc:** an independent Watch app should "request permission for any system services the app requires so that the user doesn't need to authorize an app on their iPhone. Frameworks that support independent watchOS apps display their authorization form directly on Apple Watch" ([Creating independent watchOS apps][independent]). Temper's Watch app is not independent (#102), and the page doesn't cover companions.
- **Doc:** `HKSource.bundleIdentifier` "holds the app's bundle identifier" ([HKSource.bundleIdentifier][source-bundle]). `HKSource.default()` is "a source object for the current app" ([hksource]). Neither says which app a companion Watch app's source is.
- **Doc (Platform Security):** "apps are granted separate access for reading and writing data", and "access permissions for apps" are stored as management data ([Protecting access to health data][platform-security]). The page says nothing about how they move between paired devices.

### What developers report

- **Report, 2022, separate:** after moving to Xcode 14's single-target Watch app, "both the iPhone app and watch app now display a dialog to allow access", and Settings shows "permission settings for both the iPhone app and watch app … independently", so one can be allowed and the other denied. With the old extension project, a grant in either app was "synchronized". Another developer in the thread blamed a watchOS 9.1 beta, saying pairs on watchOS 9.0 synced fine. A 2023 post reports the same split after a move to a single target. No Apple reply ([forum 715238][f715238]).
- **Report, 2021, one source:** workouts a watchOS app read back carried "the bundle identifier from the iPhone App", not the Watch app's own. An Apple engineer asked for a feedback report and gave no ruling ([forum 683224][f683224], already in the #103 research).
- **Report, 2026, shared:** a developer's logs on a current iPhone and Watch pair show a decision made on the Watch being stored for every type and then received by the phone's health daemon. After that, the phone's own sessions failed with "Not authorized" (code 4). The author states that "the phone app and its watch app share one grant, which Health syncs between the two devices", but couldn't say whether a real dismissed sheet causes the revocation ([a-better-me PR 38][abm38]).

### Where that leaves Temper

- **Unconfirmed:** whether Temper's single-target Watch app and the iPhone app share one HealthKit grant on iOS 27 with watchOS 26.5.
- **Inferred:** design for two grants. Have the Watch app check and ask for itself, and report its status to the iPhone (section 5). If the grant is shared, the Watch's check simply finds the iPhone's earlier answer. It then asks only for what's new (heart-rate read), and the report matches the iPhone's own status. Nothing breaks either way.
- **Inferred, a hazard if the grant is shared:** a "Don't Allow" on the Watch would turn off the iPhone's own workout saves too, and Settings would show that right away. That is the 2026 report's failure. It is one more reason not to raise a sheet that can go unanswered (section 4).

## 3. Where the prompt appears, and asking ahead

- **Doc:** "In watchOS 6 and later, this method displays the permission form on Apple Watch, enabling independent HealthKit apps. In watchOS 5 and earlier, this method prompts the user to authorize the app on their paired iPhone" ([requestAuthorization][request-auth]). So on watchOS 26 the Watch app's request shows its sheet on the Watch.
- **Doc:** the sheet shows only for types not decided yet. "If the user has already chosen to grant or prohibit access to all of the types specified, HealthKit calls the completion without prompting the user" ([request-auth]). `statusForAuthorizationRequest(toShare:read:)` tells whether a request would prompt (`HKHealthStore.h`, SDK).
- **SDK:** `handleAuthorizationForExtension(completion:)` and `UIApplicationDelegate.applicationShouldRequestHealthAuthorization(_:)` let a host app prompt "the app and its extensions". It is `API_UNAVAILABLE(watchos)` and `NS_EXTENSION_UNAVAILABLE` (`HKHealthStore.h`, `UIApplication.h`). A single-target Watch app is an app, not an extension of the iPhone app (Inferred). No API asks for the Watch app from the iPhone.
- **SDK, Tested:** `healthDataAccessRequest(store:shareTypes:readTypes:trigger:completion:)` is available on watchOS 10.2 and later (HealthKitUI Swift interface). It typechecks at a watchOS 26.0 target, as do `requestAuthorization(toShare:read:)` and `statusForAuthorizationRequest(toShare:read:)`. Apple's sample, older than 10.2, calls `requestAuthorization` on the Watch when its root view appears, with the comment "when healthDataAccessRequest isn't available yet".
- **Sample:** each app asks for itself. The iPhone asks when its start screen appears. The Watch asks when its root view appears, which happens when the owner opens the app or when `startWatchApp` brings it up. Neither waits for the other.
- **Doc (HIG via the iPhone research):** ask "only when you need it", in context. WWDC16 warns that during a workout "they can't really easily approve an authorization request" ([wwdc16]).

**Can the iPhone ask ahead of the first Watch Workout?** Only if the grant is shared. Then a single iPhone request covering share `workoutType()` and read `heartRate` covers the Watch too. That would add a heart-rate read request and `NSHealthShareUsageDescription` to an iPhone app that never reads anything, for a Watch it may not know exists. If the grant isn't shared, the iPhone's request does nothing for the Watch (Inferred). The reliable path is for the Watch app to ask on the Watch, in the foreground, before the first Watch Workout: on its first open, or from a button on its idle screen.

## 4. When `startWatchApp` launches a Watch app without permission

### What the APIs say

- **Doc:** `startWatchApp` "launches or wakes the companion watchOS app to create a new workout session" ([start-watch]). The Watch's `handle(_:)`: "the system launches or wakes the corresponding Watch app in the background and calls this method" ([wk-handle]).
- **Apple staff (2025):** an iOS app can launch its Watch app with `startWatchApp`, "and if your watchOS app has the `Workout processing` background mode, it will run in the background, until the workout session ends" ([forum 787130][f787130]).
- **SDK:** `HKWorkoutSession(healthStore:configuration:)` sets an error "if the configuration does not specify valid configuration properties" (`HKWorkoutSession.h`). Authorization isn't mentioned. `HKLiveWorkoutDataSource.h`, `HKLiveWorkoutBuilder.h` and `HKWorkoutSession.h` say nothing about authorization either.
- **Doc:** "If you haven't yet requested permission, any attempts to save fail with an `errorAuthorizationNotDetermined` error. If they've denied permission, attempts to save fail with an `errorAuthorizationDenied` error" ([Authorizing access][authorizing]). So `finishWorkout()` can't save a workout the Watch app lacks permission for.
- **SDK:** `HKErrorBackgroundWorkoutSessionNotAllowed` (watchOS 10): "A workout session is not allowed to start or prepare when this app is in the background" (`HKDefines.h`). Apple's sample starts the session from `handle(_:)`, so that launch must count as allowed (Inferred).
- **Unconfirmed:** whether a session started without workout share permission reaches `.running` and collects heart rate, or fails through `workoutSession(_:didFailWithError:)`, or whether `beginCollection` fails. No Apple source covers it.
- **Unconfirmed:** whether a sheet requested by an app launched in the background shows on the Watch, waits until the app comes forward, or fails. A 2026 report saw an unanswered sheet stored as a denial when `startWatchApp` relaunched the app ([abm38], Report). The same report found that once the decision existed, the Watch logged "NOT prompting for authorization".
- **Inferred:** the `startWatchApp` completion says nothing about authorization. Its `success` is about the launch (#103 found it undocumented).

### What the Watch app should do

1. **In `handle(_:)`, check before anything else.** If `authorizationStatus(for: .workoutType()) != .sharingAuthorized`, don't create a session and don't request authorization (Tested: the check typechecks in `handle(_:)` at watchOS 26.0).
2. **Tell the iPhone straight away** that the Watch won't record, so the iPhone saves the Workout itself without waiting out #75's 10 s window. The mirrored session doesn't exist yet, so this needs Watch Connectivity (Inferred). If no message is sent, the existing 10 s fallback still covers it, only later.
3. **Without a session, the Watch app gets no workout runtime.** It runs in the background only "until the workout session ends" (Apple staff), and with no session it is soon suspended. A Watch without permission can't be the display and remote for that Workout. It shows the idle screen's permission prompt the next time it's in front (Inferred).
4. **Heart-rate read denied but workout share allowed:** the session runs and saves as normal. Live heart rate on the Watch may show nothing, and the app can't tell that from "no reading yet" (Doc, read status hidden). Show the heart-rate slot empty, not an error (Inferred).

## 5. How the iPhone learns the Watch app's write status

- **SDK:** `authorizationStatus(for:)` "returns the application's authorization status for the given object type". The values say whether "this application" may save (`HKHealthStore.h`, `HKDefines.h`). Nothing in the API names another device or app.
- **Doc:** `authorizationStatus(for:)` "checks the authorization status for saving data". Write status is visible, read status is not ([auth-status]). So the Watch app can know its workout write status, and nobody can know its heart-rate read status.
- **Doc:** a person "can change the permissions for your app at any time using either the Settings or Health app" ([authorizing]). The status can change while Temper isn't running, on either device.

**Inferred, a design for Settings' Health section:**

- The Watch app reads its own `authorizationStatus(for: .workoutType())` when it comes to the front, after its prompt completes, and in `handle(_:)`. It sends the value to the iPhone. `updateApplicationContext` in Watch Connectivity keeps only the latest value and arrives when the iPhone app next runs. The mirrored session's `sendToRemoteWorkoutSession` works only during a Workout.
- The iPhone stores the last value with no timestamp logic. Settings shows a second row, "Apple Watch", with "Saving to Health", "Not allowed — allow in Temper on Apple Watch", or "Open Temper on Apple Watch to allow". Show nothing when no paired Watch has the app installed (`WCSession.isWatchAppInstalled`).
- The value can be stale if the owner changes it in the Watch's settings and doesn't open the Watch app. The next `handle(_:)` corrects it, and the status check there guards the save anyway.
- **If the device test shows one shared grant:** the iPhone's own status is the Watch's. Settings needs one row, the Watch report is redundant, and the iPhone's existing "Save Workouts to Health" button covers workouts on both. The Watch still asks for heart-rate read itself, unless the iPhone takes on that read request too.

## New questions for the map

1. **Where does the Watch app ask?** On its first open, or from an "Allow Health" button on its idle screen, or both. And what does its idle screen say when workouts aren't allowed?
2. **Does the iPhone ask for the Watch's types ahead?** That only works if the grant is shared. It would add a heart-rate read and `NSHealthShareUsageDescription` to an iPhone app that reads nothing today. Decide after the device test.
3. **A Watch-to-iPhone status message outside a Workout** (Watch Connectivity application context), and an "Apple Watch" row in Settings' Health section. Neither exists in the map's decisions yet.
4. **An early "won't record" message from `handle(_:)`**, so the iPhone doesn't wait the full 10 s when the Watch lacks permission. It could also tell the iPhone to show "Running on iPhone".

## What only a device test can settle

1. **One grant or two:** with the iPhone app allowed to share workouts, install the Watch app and check `authorizationStatus(for: .workoutType())` on the Watch before it ever asks. Then deny on the Watch and check the iPhone's status, and the reverse. Note what Settings › Health on the iPhone, and the Watch's Health settings, list for Temper.
2. **The source of the Watch's saves:** the `sourceRevision.source.bundleIdentifier` of a workout saved by the Watch app, and of its heart-rate samples (the iPhone app's ID, the Watch app's ID, or the Watch device).
3. **Session with no workout permission:** from `handle(_:)`, create and start a session with the status `.notDetermined`, then `.sharingDenied`. Record the session states, any `didFailWithError`, whether heart rate arrives, and what `finishWorkout()` returns.
4. **Live heart rate with no read permission:** share allowed, heart-rate read denied. Does `didCollectDataOf` fire for heart rate, and does `statistics(for:)` return values?
5. **A sheet requested from a background launch:** call `requestAuthorization` inside `handle(_:)` with the status `.notDetermined`. Does a sheet show on the Watch, wait, or fail? Leave it unanswered until the session ends, then read the status. That is the 2026 report's case.

## Sources

[running]: https://developer.apple.com/documentation/healthkit/running-workout-sessions
[setup]: https://developer.apple.com/documentation/healthkit/setting-up-healthkit
[authorizing]: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
[request-auth]: https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:)
[auth-status]: https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:)
[hksource]: https://developer.apple.com/documentation/healthkit/hksource/default()
[source-bundle]: https://developer.apple.com/documentation/healthkit/hksource/bundleidentifier
[start-watch]: https://developer.apple.com/documentation/healthkit/hkhealthstore/startwatchapp(with:completion:)
[wk-handle]: https://developer.apple.com/documentation/watchkit/wkapplicationdelegate/handle(_:)-1pfoc
[independent]: https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps
[sample]: https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app
[platform-security]: https://support.apple.com/guide/security/protecting-access-to-users-health-data-sec88be9900f/web
[wwdc16]: https://nonstrict.eu/wwdcindex/wwdc2016/209/
[wwdc18]: https://developer.apple.com/videos/play/wwdc2018/707/
[wwdc19]: https://developer.apple.com/videos/play/wwdc2019/208/
[wwdc21]: https://developer.apple.com/videos/play/wwdc2021/10009/
[wwdc25]: https://developer.apple.com/videos/play/wwdc2025/322/
[f715238]: https://developer.apple.com/forums/thread/715238
[f683224]: https://developer.apple.com/forums/thread/683224
[f787130]: https://developer.apple.com/forums/thread/787130
[f110498]: https://developer.apple.com/forums/thread/110498
[abm38]: https://github.com/smirea/a-better-me/pull/38

- HealthKit docs: [Running workout sessions][running], [Setting up HealthKit][setup], [Authorizing access to health data][authorizing], [requestAuthorization][request-auth], [authorizationStatus(for:)][auth-status], [HKSource.default()][hksource], [HKSource.bundleIdentifier][source-bundle], [startWatchApp][start-watch], [Building a multidevice workout app][sample] (sample code, files `Shared/WorkoutManager.swift`, `Shared/WorkoutManager+watchOS.swift`, `MirroringWorkoutsSample/StartView.swift`, `MirroringWorkoutsSample Watch App/PagingView.swift`, `MirroringWorkoutsSample Watch App/AppDelegate.swift`).
- WatchKit and watchOS docs: [WKApplicationDelegate.handle(_:)][wk-handle], [Creating independent watchOS apps][independent].
- Apple Platform Security: [Protecting access to user's health data][platform-security].
- SDK (Xcode 27.2): watchOS `HKHealthStore.h`, `HKDefines.h`, `HKWorkoutSession.h`, `HKLiveWorkoutDataSource.h`, `HKLiveWorkoutBuilder.h`, `HKSource.h`, WatchKit `WKApplication.h`, HealthKitUI `arm64_32-apple-watchos.swiftinterface`. iOS `HKHealthStore.h` (`startWatchAppWithWorkoutConfiguration:completion:`), UIKit `UIApplication.h`.
- WWDC: [WWDC16 209 Getting the Most Out of HealthKit][wwdc16] (transcript index), [WWDC18 707 New Ways to Work with Workouts][wwdc18], [WWDC19 208 Creating Independent watchOS Apps][wwdc19], [WWDC21 10009 Build a workout app for Apple Watch][wwdc21], [WWDC25 322][wwdc25].
- Forums: [715238][f715238] (separate grants after single target, Report), [683224][f683224] (source bundle ID, Report), [787130][f787130] (Apple staff, `startWatchApp` runtime), [110498][f110498] (Report).
- GitHub: [a-better-me PR 38][abm38] (shared grant and background sheet, Report).
