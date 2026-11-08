# A Watch-owned Health session alongside the iPhone's own Health save

Research for ticket #103 on map #100. Sources were read on 2026-11-07. Nothing here has been run on a device. The last section lists what only a device test can settle.

The iPhone save is built and shipped (spec #86, `Temper/HealthSaves.swift`, `Temper/HealthKitWorkouts.swift`). Ticket #75 decided that the Watch owns a mirrored session when a Watch is there, and the iPhone saves by itself when no Watch answers within 10 s of Start. This file asks how those two paths fit together. It builds on [`health-workout-recording.md`](https://github.com/igorxciv/temper/blob/research/health-workout-recording/docs/research/health-workout-recording.md) (ticket #73) and [`iphone-health-save.md`](https://github.com/igorxciv/temper/blob/research/iphone-health-save/docs/research/iphone-health-save.md) (ticket #84) and doesn't repeat them.

The owner's Series 8 stops at watchOS 26 (#73), so watchOS 26 is the version that matters for the build. The iPhone runs iOS 27.

## Answer

- **Same sync identifier on a Watch save: yes, it can be set. That it makes Health keep one workout: undocumented, so don't rely on it.** `HKLiveWorkoutBuilder` is a subclass of `HKWorkoutBuilder` and inherits `addMetadata(_:)`. The sync keys are available on watchOS 4 and later, and the call typechecks at a watchOS 26 target (Doc, Tested). Apple never says whether replacement by sync identifier works across sources. The Watch app and the iPhone app may also be separate sources. "An application may only delete objects that it previously saved" (Doc), and replacing an object removes it. If replacement does cross sources, the higher version wins outright. An iPhone attempt with a higher version would then swap the Watch's heart-rate workout for one without heart rate. The real guard stays #75's rule that one device is chosen to record and that choice never changes. As a backstop, give both saves the same identifier, and give the Watch a version above any iPhone attempt (section 1).
- **Watch app start time: no figure published.** `startWatchApp(toHandle:)` "launches or wakes" the Watch app in the background and calls its `handle(_:)` (Doc). Apple gives no time for that, and no WWDC session or Apple staff answer does either. With the Watch powered off, the completion has been reported to never fire (Report). For the reverse direction, Apple gives the iPhone app 10 seconds when the Watch launches it (WWDC23). So 10 s is a reasonable starting value, but it's our own number. Start the clock at the call, and stop it when the mirrored session arrives, not when the completion fires. A wait that's too short costs heart rate, and a longer one costs nothing the owner sees, because the iPhone saves only after Stop (section 2).
- **iPhone locked: the mirrored session doesn't depend on it.** The primary session runs on the Watch, and the Watch app keeps running for the whole session (Doc). Apple doesn't say whether a mirrored session keeps a locked iPhone app running. Temper's iPhone app should stay running anyway, because it keeps its audio session active for Cues during a Workout (Inferred, from the shipped design). **What ends it:** on the Watch, `end()` (mirroring stops with it), `stopMirroringToCompanionDevice`, another workout session starting (`errorAnotherWorkoutSessionStarted`), the person leaving the session (`errorUserExitedWorkoutSession`), or a crash, after which the session is recovered. On the iPhone, Apple's sample ends the workout by calling `stopActivity(with:)` on the mirrored session. Losing the link invalidates the iPhone's session instance, and HealthKit hands over a new instance when the link comes back (Doc). A known iOS 26 bug drops mirroring of iPhone-started sessions. Apple DTS's workaround is to mirror only once the session is prepared or running. No fix has been confirmed for iOS 26 or 27 (Apple staff) (section 3).
- **The Watch builder records heart rate and energy by itself, and it can take one activity per Phase.** The live data source collects high-frequency heart rate, active energy and basal energy, plus distance for activities that have it, and saves the samples to Health as they arrive (Doc). Activities work two ways, both on watchOS 9 and later and both typechecked at watchOS 26. The live way is `session.beginNewActivity(configuration:date:metadata:)` at each Phase change. The other is `builder.addWorkoutActivity(_:)` after the fact, which is what the iPhone save does. Every activity has to use the workout's activity type (Doc). Whether either call accepts a past date on a live builder is undocumented (section 4).
- **watchOS 26 to 27: the only workout API change is heart-rate and power zones.** In the watchOS 27.2 SDK, the only watchOS 27 workout APIs are the zone types and calls. Nothing Temper needs is newer than watchOS 10, and nothing it needs is deprecated in 26 or 27 (Doc, SDK, Tested). The difference that matters is behaviour: the iOS 26 mirroring bug, whose status on iOS 27 with a watchOS 26 Watch is unknown (section 5).

## How to read the labels

| Label | Meaning |
|---|---|
| **Doc** | Apple developer documentation, read from the site's JSON data, or the watchOS 27.2 / iOS 27.2 SDK headers and Swift interfaces where marked "SDK". |
| **Sample** | Apple's sample code project *Building a multidevice workout app*, downloaded from the documentation page. |
| **WWDC** | An Apple WWDC session transcript. |
| **Apple staff** | A forum reply with an Apple badge. Informed, but not a contract. |
| **Report** | A developer report on the forums or a blog, not an Apple source. |
| **Tested** | Typechecked on this Mac with `xcrun --sdk watchos swiftc -typecheck -target arm64_32-apple-watchos26.0 -swift-version 6 -warnings-as-errors` against the watchOS 27.2 SDK. Nothing was run. |
| **Inferred** | My conclusion. No source states it. |
| **Unconfirmed** | I looked and found no source. |

## 1. One Health workout if both devices save

### What the APIs allow

- **Doc (SDK):** `HKLiveWorkoutBuilder : HKWorkoutBuilder` (watchOS 5+). `addMetadata(_:)` merges keys into the workout's metadata "in the same manner as `-[NSMutableDictionary addEntriesFromDictionary:]`" (`HKWorkoutBuilder.h`). `HKMetadataKeySyncIdentifier` and `HKMetadataKeySyncVersion` are watchOS 4.0 and later (`HKMetadata.h`).
- **Tested:** `builder.addMetadata([HKMetadataKeySyncIdentifier: uuid.uuidString as NSString, HKMetadataKeySyncVersion: NSNumber(value: version)])` on the session's associated builder typechecks at a watchOS 26.0 target for `arm64_32`.
- **Report (2020):** a developer adding the sync keys to an `HKLiveWorkoutBuilder` hit a cryptic connection error, and fixed it by passing the identifier as an `NSString` rather than a Swift `String` built from a `UUID` ([forum 658843][f658843]). The iPhone save already passes a string (#84).
- **Doc:** "If you save the workout in the watchOS app, you can incorporate data from the iOS workout. For example, you should set the workout's `startDate` to the iOS workout's start" ([Running workout sessions][running]). That backs #75's rule that the Watch begins collection at the Workout's Start date.

### What Apple doesn't say

- **Doc:** "When you save an HKObject with a sync identifier, the system looks for any existing objects with the same sync identifier. If it finds a match … if the new object has a greater sync version, the system replaces the old object with the new one" ([sync identifier][sync-id]). The header calls it "an identifier for an HKObject that is set by its source" (`HKMetadata.h`). Neither says whether the match is limited to one source.
- **WWDC20 10184:** the identifier "allows us to recognize a sample anywhere in the health ecosystem across any of the user's devices". The examples are all one app syncing its own samples between iPhone and Watch ([WWDC20][wwdc20]). Not covered: two different sources writing the same identifier.
- **Doc (SDK):** "An application may only delete objects that it previously saved" (`HKHealthStore.h`, `deleteObjects:`). Replacing a workout removes the old one, so a source rule for replacement would be consistent with this (Inferred). Developers state that replacement is limited to one source, without citing a source or a test ([Maui.Health #47][maui], Report).
- **Unconfirmed: whether a Watch app and its iOS companion count as one HealthKit source.** `HKSource.default()` is "a source object for the current app" ([HKSource][hksource]). In 2021 a developer said workouts their watchOS app read back carried "the bundle identifier from the iPhone App", unlike the Watch's own `HKSource.default()`. An Apple engineer asked for a feedback report and gave no ruling ([forum 683224][f683224]). The bundle IDs differ: the Watch app's is the iOS app's plus `.watchkitapp`.
- **Unconfirmed: what happens to the Watch workout's heart-rate samples if an iPhone save replaces it.** The doc covers a replaced sample inside a workout ("the system also replaces the old object in the workout"), not a replaced workout. The samples stay in Health either way. The live data source saves them as they're collected, and even `discardWorkout()` leaves them: "Samples that were added to the workout will not be deleted" (Doc, `HKWorkoutBuilder.h`, [running][running]).

### What that means for Temper (Inferred)

1. **Keep #75's decision as the only real guard.** One device is chosen to record, and the choice never changes. When the Watch owns the session, `HealthSaves.save` must not write a pending save for that Workout. A pending save left over would be retried, possibly days later, by `retryPending()`.
2. **Backstop with the same sync identifier.** Today the iPhone's identifier is the Workout's UUID, made at Start (`WorkoutRunner.healthWorkoutID`). Send that UUID to the Watch in the first update, and have the Watch put it on its workout.
3. **Make the Watch's version outrank every iPhone attempt.** The iPhone's version starts at 1 and rises with each attempt. Locked attempts aren't counted toward the limit of 3, so the version has no fixed ceiling (`HealthSaves.attempt`). A large constant on the Watch, such as 1,000,000, means that if replacement does cross sources, the heart-rate workout wins.
4. **Test cross-source replacement on devices** before treating it as more than a backstop (last section).

## 2. How long an iPhone-started session takes to reach the Watch

- **Doc:** `startWatchApp(toHandle:)` (iOS 10+, not deprecated in the iOS 27.2 SDK) "Launches or wakes the companion watchOS app to create a new workout session". The system then "calls the handle method on the watchOS app's delegate" ([startWatchApp][start-watch], `HKHealthStore.h`). The Watch side: "the system launches or wakes the corresponding Watch app in the background and calls this method. Use this method to configure an `HKWorkoutSession`" ([handle(_:)][wk-handle]).
- **Not documented anywhere I found:** how long the launch takes, what `success == true` in the completion means (request delivered, app launched, or session started), or a timeout. WWDC23 10023 and WWDC25 322 give none.
- **Report (2021):** with the Watch powered off but paired, "The startWatchApp method's completion never fires". The only reply, not from Apple, suggests checking `WCSession.default.isReachable` first ([forum 688922][f688922]). #75 already relies on this report for its timeout.
- **WWDC23 10023, the other direction:** when the Watch mirrors, "HealthKit launches my companion iPhone app in the background, gives my app 10 seconds to start a live activity and call a handler to start mirroring" ([WWDC23][wwdc23]). This is the only 10-second figure Apple gives for this path. It covers the iPhone being launched, not the Watch.
- **Doc (SDK):** `errorBackgroundWorkoutSessionNotAllowed`: "A workout session is not allowed to start or prepare when this app is in the background" (`HKDefines.h`). The `handle(_:)` launch is the documented way to start a session from the background. A Watch app woken any other way, such as by WatchConnectivity, may get this error (Inferred).

**Is 10 s fair? (Inferred)**

- Steps between Start and "the Watch owns it": the wake travels over Bluetooth or Wi-Fi, the app launches in the background, `handle(_:)` runs, the session is created and prepared, mirroring starts (after `.prepared`, per DTS, section 3), and the iPhone's `workoutSessionMirroringStartHandler` fires. Apple publishes a time for none of these. The device check has to measure the whole chain on the Series 8: Watch on the wrist and unlocked, wrist down, and app not yet launched since the Watch restarted.
- **What a wrong timeout costs:** too short, and a Watch that was going to answer is told to end without saving, so heart rate is lost. Too long costs nothing the owner sees. Start never waits, the iPhone saves only after Stop, and a late Watch session collects from the Workout's Start date anyway (section 1). So it's cheap to err long.
- **Measure from the call to the mirrored session's arrival,** not to the completion. The completion may never fire, and what it means isn't documented. Arrival of the mirrored session, or the Watch's first message over it, is the event that says the Watch owns the recording.
- A sharper option for the map: the iPhone doesn't have to decide at 10 s at all. It could decide at the first of "a mirrored session arrives" or "Stop". Section "New questions" below.

## 3. The mirrored session with the iPhone locked, and what ends it

### Locked iPhone

- **Doc:** "When your app has an active workout session, it continues to run in the background … throughout the entire workout session, even when the user lowers their wrist" ([running][running]). This is the Watch. The primary session doesn't depend on the iPhone's state.
- **Doc (SDK):** if the iOS app "is not active when a mirrored session starts, it will be launched in the background and given a one-time permission to start a Live Activity from the background" (`HKHealthStore.h`, `workoutSessionMirroringStartHandler`). The handler should be set "promptly after your app is launched" and may be called more than once. "Each call has its own `HKWorkoutSession` instance" ([mirroring handler][mirror-handler]).
- **Unconfirmed: whether a mirrored session keeps a backgrounded, locked iOS app running.** Nothing says so. Background modes list `workout-processing` for watchOS only (#73). The delegate header says a suspended app gets state changes "once the application resumes, which may be much later" (`HKWorkoutSession.h`).
- **Inferred for Temper:** this doesn't matter during a Workout. The iPhone engine holds an active audio session for Cues, which keeps the app running while locked (the shipped design). So mirrored callbacks and `sendToRemoteWorkoutSession` work while the iPhone is locked. The iPhone needs nothing from the locked Health store, because it reads no Health data.
- **Doc (SDK), new since #73:** the data channel is limited to "100 KB in any given 10-second time window". Over the limit, or "if the session is not mirroring", the send returns an error (`HKWorkoutSession.h`, `sendDataToRemoteWorkoutSession:`). #75's event-only full updates are far below that.

### What ends it, from each side

| Cause | Side | What happens | Source |
|---|---|---|---|
| The Watch app calls `stopActivity(with:)`, then `endCollection`, `finishWorkout`, `end()` | Watch | Saved. "When a workout session is ended, mirroring is automatically stopped" | Doc, SDK `HKWorkoutSession.h` |
| `stopMirroringToCompanionDevice` | Watch | The Watch session keeps running. The iPhone's delegate gets `didDisconnectFromRemoteDeviceWithError` | Doc, SDK, WWDC23 |
| Another workout session starts, in Temper or any other app | Watch | Session fails with `errorAnotherWorkoutSessionStarted`. "Apple Watch runs one workout session at a time" | Doc, SDK `HKDefines.h`, #73 |
| The person leaves the session | Watch | `errorUserExitedWorkoutSession`: "User exited the application while a workout session was running". Which system gesture causes this isn't documented | SDK `HKDefines.h`, Unconfirmed |
| Excessive background CPU | Watch | "watchOS may suspend it" | Doc, [running][running] |
| Watch app crash | Watch | The system relaunches it, calls `handleActiveWorkoutRecovery()`, and `recoverActiveWorkoutSession` returns the session. The data source has to be set up again | Doc, WWDC25 322 |
| Out of range or link lost | Either | The iPhone's instance "is no longer valid". "If the primary workout session is still running, it automatically tries to reconnect", and the handler gets a new instance | Doc, [didDisconnect][did-disconnect] |
| The iPhone app calls `stopActivity(with:)` on the mirrored session | iPhone | Apple's sample does exactly this for its End button. The Watch's delegate sees `.stopped`, and the Watch finishes the builder and calls `end()` | Sample (`MirroringWorkoutView.swift`, `WorkoutManager.swift`) |
| The iPhone app calls `pause()` / `resume()` on the mirrored session | iPhone | "the primary session delegate on my Apple Watch gets notified about the state change" | WWDC23, Sample |
| The iPhone app calls `end()` on the mirrored session | iPhone | Not documented. Apple's sample doesn't do it | Unconfirmed |
| The iPhone app is killed or crashes | iPhone | Not documented. Nothing says it ends the Watch session. Whether a relaunched iOS app gets the running session through its handler again is also undocumented | Unconfirmed |

- **WWDC23 10023:** HealthKit gives the mirrored side "the ability to begin and end activities as well as generate events" ([WWDC23][wwdc23]). This updates #73, which marked iPhone-side control as unconfirmed. #75 still sends Stop over the data channel, because Stop has to carry the iPhone's end time. Letting the Watch end its own session keeps that one path (Inferred).
- **Doc:** "If the user starts the workout in your watchOS app, and then tries to end it in the iOS companion, the iOS app should instruct the user to end the workout in your watchOS app" ([running][running]). This guidance predates mirroring and covers unmirrored companions. The sample's iPhone End button shows that a mirrored session can be ended from the iPhone (Inferred).

### The iOS 26 mirroring bug

- **Report and Apple staff (Oct to Nov 2025, iOS 26.0.1 / watchOS 26.0.2, still there in the 26.1 RC):** "A workout session is started from the phone app and starts mirroring to the watch companion device. The watch starts the workout session and then the mirroring session is disconnected / lost. Sending data to the companion device fails and ending the session on the phone doesn't end the session on the watch". The phone logs "Primary session is unreachable" (HealthKit error 554). That is exactly Temper's path. Apple DTS: the report is "a duplicate, which the HealthKit folks are actively working on". Later: "making sure `startMirroringToCompanionDevice` is called after the workout session gets prepared or running may be able to work around the issue" ([forum 804276][f804276]). No fixed version is named.
- **Report (2024):** "Remote session delegate is not set up" errors on sends went away after calling `prepare()` before mirroring. Sends still failed sometimes, and a retry usually worked ([nonstrict][nonstrict]).
- **Inferred:** Apple's own documentation snippets call `startMirroringToCompanionDevice()` before `startActivity(with:)`, which is the order the workaround avoids ([startWatchApp][start-watch]). Temper's Watch app should call `prepare()`, wait for `.prepared` in the delegate, then mirror, then `startActivity(with: workoutStart)`. The iPhone should also be ready for sends to fail and retry them, since a full update is idempotent.
- **Unconfirmed:** whether iOS 27 fixes it, and how an iOS 27 iPhone behaves with a watchOS 26 Watch. No iOS 27 reports turned up either way.

## 4. What the Watch's live builder records, and one activity per Phase

### Recorded without Temper doing anything

- **Doc:** "all workout sessions generate high-frequency heart rate samples". "Apple Watch automatically collects data about the workout, and saves samples to the HealthKit store. For example, an outdoor running session collects and saves `activeEnergyBurned`, `basalEnergyBurned`, `heartRate`, and `distanceWalkingRunning` samples." Calories for activities without a tuned model are estimated from the sensors, never lower than a brisk walk ([running][running]).
- **Doc (SDK):** `HKLiveWorkoutDataSource(healthStore:workoutConfiguration:)`: "typesToCollect will be populated with default types for the workout configuration". Types can be added or removed with `enableCollection(for:predicate:)` and `disableCollection(for:)` (`HKLiveWorkoutDataSource.h`).
- **Unconfirmed:** the exact default set for `highIntensityIntervalTraining`, `traditionalStrengthTraining` and `other`. Apple lists types only for the running example. Expect heart rate, active energy and basal energy, and no distance, for indoor types (Inferred). The Watch app can log `typesToCollect` on the device.
- **Doc:** the session forwards its events to the builder by default, so `pause()` and `resume()` become `pause` and `resume` events. `shouldCollectWorkoutEvents = false` turns that off, and then "the client is expected to add relevant events directly to the builder" (`HKLiveWorkoutBuilder.h`, [running][running]).
- **Rings:** WWDC25 says the builder API keeps activity rings updated, and Apple Support says compatible third-party workouts count toward Move (#73, #84). Watch energy samples are what Move counts, so a Watch-owned workout should give real Move credit where the iPhone save gives none (Inferred). Exercise-minute credit for a third-party strength workout is still **Unconfirmed**.

### Activities, one per Phase

- **Doc:** interval training "can use the same activity type as the workout for the rest periods; however, you may want to add custom metadata to indicate whether the activity is an active or resting interval". Activities "can't overlap" ([Dividing a workout][dividing]). #73 already covered the "same type" rule.
- **Live, at each Phase change:** `session.beginNewActivity(configuration:date:metadata:)` (watchOS 9+) "also ends that activity" if one is running. `endCurrentActivity(on:)` ends one without starting another. The builder delegate gets `didBeginActivity` / `didEndActivity`, and `HKLiveWorkoutBuilder.currentWorkoutActivity` tracks it ([beginNewActivity][begin-activity], `HKWorkoutSession.h`, `HKLiveWorkoutBuilder.h`). The metadata dictionary takes `TemperPhase` and `TemperRound`, the same keys the iPhone save uses.
- **After the fact, from the record:** `HKWorkoutBuilder.addWorkoutActivity(_:)`, `updateActivity(uuid:end:)` and `updateActivity(uuid:adding:)` are watchOS 9+ and inherited by the live builder (`HKWorkoutBuilder.h`). The iPhone already builds its activities this way, from the Workout record.
- **Tested:** both paths typecheck at a watchOS 26.0 target: `beginNewActivity` with a stored Phase start date, `endCurrentActivity(on:)`, and `addWorkoutActivity` on the session's associated builder.
- **Unconfirmed:** whether `beginNewActivity` honours a `date` in the past, such as a Phase start that reaches the Watch a second later. Also whether `addWorkoutActivity` on a live builder clashes with the activity the session manages. The headers state neither limit.

**Fitting the iPhone save (Inferred):**

- The iPhone already turns a Workout record into a `HealthRecord`: span, Pauses, and Phases with `TemperPhase`/`TemperRound` (`HealthRecord.swift`). If the iPhone sends that record over the data channel at Stop, the Watch can add the same activities after the fact and the same `pause`/`resume` events. It would set `shouldCollectWorkoutEvents = false`, so the times are the iPhone's tap times rather than the moment each command reached the Watch. The Watch then saves a workout whose structure matches the iPhone save exactly, plus heart rate and energy. A record of a long Open Rounds session is a few KB, inside the 100 KB per 10 s limit.
- The live path (`beginNewActivity` at each Phase update) gives the Watch per-activity statistics during the Workout, which a live heart-rate-per-Round display would want. But it depends on the Watch hearing every Phase change, and Phase changes during a dropout would be lost or late. The record path doesn't have that problem.
- `session.pause()` / `resume()` should still be called live, so the sensors know the state, even when the builder's events come from the record.

## 5. What differs between watchOS 26 and 27, and iOS 27

**Doc (SDK), watchOS 27.2 headers and Swift interface, every `watchOS 26`/`27` availability that touches workouts:**

| API | Availability | Temper needs it? |
|---|---|---|
| `HKLiveWorkoutZoneUpdate`, `HKLiveWorkoutBuilderDelegate.workoutBuilder(_:didUpdateWorkoutZone:)` | watchOS 27, iOS 27 | No |
| `HKWorkoutZone`, `HKWorkoutZoneConfiguration`, `HKWorkoutZoneDuration`, `HKWorkoutZoneGroup` | watchOS 27 (`anyAppleOS 27`) | No |
| `HKWorkoutBuilder.setCustomZoneConfiguration`, `zoneConfiguration(for:)`, `zoneGroup(for:)`; `HKWorkout`/`HKWorkoutActivity.zoneGroupsByType`; `HKHealthStore.preferredWorkoutZoneConfiguration(for:)` | watchOS 27 | No |
| Everything else in the Watch session path: `HKWorkoutSession(healthStore:configuration:)` and `associatedWorkoutBuilder()` (watchOS 5), `prepare`/`startActivity`/`stopActivity`/`end` (watchOS 5), `beginNewActivity`/`endCurrentActivity` (watchOS 9), `addWorkoutActivity` (watchOS 9), `startMirroringToCompanionDevice`/`sendToRemoteWorkoutSession` (watchOS 10), sync metadata (watchOS 4), `recoverActiveWorkoutSession` (watchOS 5), `WKApplicationDelegate.handle(_:)` (watchOS 7) | Unchanged in 26 and 27 | Yes |

- No workout API is deprecated in watchOS 26 or 27. A search of the headers for `API_DEPRECATED` ending at 26 or 27 finds nothing (SDK).
- The HealthKit updates page lists only workout zones and the menopause types for June 2026. For June 2025 it lists iPhone workout sessions and medications, and no watchOS workout change ([updates][updates]).
- **Tested:** the whole Watch path in section 4 typechecks at watchOS 26.0 with warnings as errors. `zoneGroup(for:)` fails there with "only available in watchOS 27.0 or newer". So zones are out of reach on the Series 8, as #73 said.
- **iOS 27 side:** the mirrored-session APIs are all iOS 17 (`workoutSessionMirroringStartHandler`, `sendToRemoteWorkoutSession`, `pause`/`resume`/`stopActivity` on the mirrored instance), and `startWatchApp` is iOS 10. iOS 26 added iPhone-primary sessions (`HKWorkoutSession(healthStore:configuration:)`, `HKLiveWorkoutBuilder`, `recoverActiveWorkoutSession` on iOS), which the Watch design doesn't use. iOS 27 also adds `earliestAuthorizedSampleDate(for:)`, about limited read access, which doesn't matter for a write-only app (SDK).
- **The behaviour difference that matters** is the iOS 26.x mirroring bug in section 3. Its state on iOS 27, especially with a watchOS 26 Watch, is unknown.

## New questions for the map

1. **Decide the recorder at the first of "mirrored session arrives" or Stop, instead of at 10 s?** The iPhone saves only after Stop, so it doesn't need to choose at 10 s. If it chose at the first of the two, a Watch that wakes late would still record, from the Workout's Start date, and there would still be one Health workout. The 10-minute Watch dropout rule and "a session that arrives late is told to end without saving" would need rereading against this.
2. **Where do the Watch workout's activities and Pause events come from:** the iPhone's record sent at Stop (exact times, survives dropouts), or live `beginNewActivity` and session-generated events (live per-Round statistics, but receive-time timestamps)?
3. **Cross-source sync identifiers:** a device test, below, decides whether the shared identifier is a real backstop or a no-op.

## What only a device test can settle

1. **Cross-source replacement:** the iPhone app saves a workout with identifier X, version 1. The Watch app saves one with identifier X, version 1,000,000. Then the reverse order. Count the Health workouts, check which survives, and check whether heart-rate samples stay linked to it. Also record which source Health shows for the Watch app's workout.
2. **`startWatchApp` to mirrored session arrival on the Series 8,** timed from the call to `workoutSessionMirroringStartHandler`. Cases: Watch on the wrist and unlocked, wrist down, Watch app not launched since the Watch restarted, over Bluetooth and over Wi-Fi. Also what the completion reports, and when.
3. **The iOS 26/27 mirroring bug on iOS 27 with watchOS 26:** an iPhone-started session that mirrors after `.prepared` stays connected for a 30-minute Workout, and sends work both ways.
4. **Locked iPhone:** with the iPhone locked for over 10 minutes, Watch commands and iPhone updates still cross within #75's 1 s bar, and a disconnect and reconnect delivers a new mirrored instance.
5. **Ending from each side:** `stopActivity(with:)` on the mirrored session ends and saves on the Watch. What `end()` on the mirrored session does. What happens to the Watch session if the iPhone app is force-quit mid-Workout.
6. **`typesToCollect`** for `highIntensityIntervalTraining`, `traditionalStrengthTraining` and `other` on the Series 8.
7. **Activities on a live builder:** `beginNewActivity` with a date 1 to 2 s in the past, and `addWorkoutActivity` after the fact with `shouldCollectWorkoutEvents = false`. Check what Health and Fitness show for each.
8. **Rings:** Move and Exercise credit for a Watch-owned Open Rounds workout, against #86's iPhone-only save.

## Sources

[running]: https://developer.apple.com/documentation/healthkit/running-workout-sessions
[sync-id]: https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier
[hksource]: https://developer.apple.com/documentation/healthkit/hksource/default()
[start-watch]: https://developer.apple.com/documentation/healthkit/hkhealthstore/startwatchapp(with:completion:)
[wk-handle]: https://developer.apple.com/documentation/watchkit/wkapplicationdelegate/handle(_:)-1pfoc
[mirror-handler]: https://developer.apple.com/documentation/healthkit/hkhealthstore/workoutsessionmirroringstarthandler
[did-disconnect]: https://developer.apple.com/documentation/healthkit/hkworkoutsessiondelegate/workoutsession(_:diddisconnectfromremotedevicewitherror:)
[begin-activity]: https://developer.apple.com/documentation/healthkit/hkworkoutsession/beginnewactivity(configuration:date:metadata:)
[dividing]: https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities
[updates]: https://developer.apple.com/documentation/updates/healthkit
[sample]: https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app
[wwdc20]: https://developer.apple.com/videos/play/wwdc2020/10184/
[wwdc23]: https://developer.apple.com/videos/play/wwdc2023/10023/
[wwdc25]: https://developer.apple.com/videos/play/wwdc2025/322/
[f658843]: https://developer.apple.com/forums/thread/658843
[f683224]: https://developer.apple.com/forums/thread/683224
[f688922]: https://developer.apple.com/forums/thread/688922
[f804276]: https://developer.apple.com/forums/thread/804276
[nonstrict]: https://nonstrict.eu/blog/2024/hkworkoutsession-remote-delegate-not-setup-error/
[maui]: https://github.com/Kebechet/Maui.Health/issues/47

- HealthKit docs: [Running workout sessions][running], [HKMetadataKeySyncIdentifier][sync-id], [HKSource.default()][hksource], [startWatchApp][start-watch], [workoutSessionMirroringStartHandler][mirror-handler], [didDisconnectFromRemoteDevice][did-disconnect], [beginNewActivity][begin-activity], [Dividing a HealthKit workout into activities][dividing], [HealthKit updates][updates], [Building a multidevice workout app][sample] (sample code).
- WatchKit docs: [WKApplicationDelegate.handle(_:)][wk-handle].
- SDK headers (watchOS 27.2, iOS 27.2): `HKWorkoutSession.h`, `HKWorkoutBuilder.h`, `HKLiveWorkoutBuilder.h`, `HKLiveWorkoutDataSource.h`, `HKLiveWorkoutZoneUpdate.h`, `HKHealthStore.h`, `HKMetadata.h`, `HKDefines.h`, WatchKit `WKApplication.h`. Swift interface `HealthKit.swiftmodule/arm64_32-apple-watchos.swiftinterface`.
- WWDC: [20 10184 Synchronize health data with HealthKit][wwdc20], [23 10023 Build a multi-device workout app][wwdc23], [25 322 Track workouts with HealthKit on iOS and iPadOS][wwdc25].
- Apple Developer Forums: [804276][f804276] (Apple staff and reports), [683224][f683224] (Apple staff), [658843][f658843], [688922][f688922] (reports).
- Other reports: [nonstrict.eu, 2024][nonstrict], [Maui.Health #47][maui].
