# Saving a Health workout from the iPhone after Stop

Research for ticket #84 on map #70. Sources were read on 2026-11-06. Nothing here has been run on a device. The last section lists what only a device test can settle.

This covers the iPhone-only path: no Watch, no heart rate, and a Health workout built after Stop or finish from the engine's own times (start, end, each Pause, each Phase), saved only when the active time is 1 minute or more. The Watch-owned path, activities versus segment events, and entitlements were covered by [`docs/research/health-workout-recording.md`](https://github.com/igorxciv/temper/blob/research/health-workout-recording/docs/research/health-workout-recording.md) (ticket #73). This file builds on that one and doesn't repeat it.

## Answer

- **Apple documents that writing works while the device is locked, but a current bug makes a locked save untrustworthy.** HealthKit "can still write to the store, even when the phone is locked", by caching the data and merging it on unlock ([Doc][privacy], [Doc][db-inaccessible]). `finishWorkout` returns a nil workout and a nil error to mean "succeeded, but the sample is not available because the device is locked" ([Doc][finish]). Since iOS 26.4, and still on iOS 27, developers report the same nil/nil result when the workout was **not** saved. Apple DTS couldn't reproduce it ([forum 825838][f825838], Report and Apple staff). So a nil/nil result can mean either outcome.
- **Recommended pattern:** persist a pending-save record at Stop, try the save at once inside a background task, and treat nil/nil as "unverified". The next time Temper runs with protected data available, query by sync identifier, and save again only if the Health workout is missing (Inferred, section 1).
- **Saving once:** put `HKMetadataKeySyncIdentifier` (the Workout's UUID as a `String`) and `HKMetadataKeySyncVersion` on the workout. A save with a greater version replaces the older object. A same-identifier object that isn't newer is ignored ([Doc][sync-id], [WWDC20 10184][wwdc20]). Raise the version on every attempt, so the attempts end as one Health workout in whatever order they land (Inferred, section 2).
- **`HKWorkoutBuilder.init(healthStore:configuration:device:)` is still current on iOS 27.** It isn't deprecated, and its header says it can "create a workout that occurred in the past" (Doc, SDK header). It compiles with no warnings against the iOS 27.2 SDK (Tested). The iOS 26 iPhone `HKWorkoutSession` is a live API that has to start in the foreground. It doesn't replace the builder for after-the-fact saves (section 3).
- **Pauses:** add `pause`/`resume` event pairs. The builder leaves paused intervals out of the duration, and an activity's duration does the same, so an activity can span a Pause (Doc). **Phases:** one `HKWorkoutActivity` per Work (and per Rest if wanted), each with custom metadata, all using the workout's activity type (Doc). What Fitness shows for these is undocumented. One report says it ignores third-party `segment` events (section 4).
- **Activity types:** Intervals → `highIntensityIntervalTraining`. Open Rounds → `traditionalStrengthTraining`. Stopwatch has no natural fit: use `other`, or let the owner choose (Inferred from Apple's descriptions). Apple Support says a compatible third-party workout "contributes to the progress toward closing your Move ring". Without a Watch, iPhone shows only the Move ring ([Support][sup-summary]). What a workout with **no energy samples** adds is **Unconfirmed** (section 5).
- **Permission:** the HealthKit capability, plus `NSHealthUpdateUsageDescription` only (read-only string not needed for write-only, per framework strings, Tested). `authorizationStatus(for: .workoutType())` **does** reveal write permission. Only read permission is hidden (Doc). Ask in the foreground, in context, before the first Workout that would be saved, never at Stop (section 6).

## How to read the labels

| Label | Meaning |
|---|---|
| **Doc** | Current Apple documentation, read from the developer site's Markdown renderings, or the iOS 27.2 SDK headers where marked. |
| **Support** | An Apple Support or Apple Platform Security page. |
| **WWDC** | An Apple WWDC session transcript. |
| **Apple staff** | A forum reply with an Apple badge. Informed, but not a contract. |
| **Report** | A developer report on the forums or GitHub, not an Apple source. |
| **Tested** | Checked on this Mac with Xcode 27.2 (27B52) and the iOS 27.2 SDK, by compiling or by inspecting framework strings. Nothing was run. |
| **Inferred** | My conclusion. No source states it. |
| **Unconfirmed** | I looked and found no source. |

## 1. Saving while locked or in the background

### What Apple documents

- **Doc:** "the device encrypts the HealthKit store when the user locks the device. As a result, your app may not be able to read data from the store when it runs in the background. However, your app can still write to the store, even when the phone is locked. HealthKit temporarily caches the data and saves it to the encrypted store as soon as the user unlocks the phone" ([Protecting user privacy][privacy]).
- **Doc:** `errorDatabaseInaccessible` "occurs when your app queries for HealthKit data while the device is locked. You can, however, still save data. This data is saved into a temporary file, which is merged with HealthKit's data when the user unlocks their device" ([errorDatabaseInaccessible][db-inaccessible]). The SDK header gives the code as "Protected health data is inaccessible because the device is locked" (Doc, `HKDefines.h`).
- **Doc:** `finishWorkout(completion:)`: "If both this and the `error` parameter are `nil` then finishing the workout succeeded but the workout sample is not available because the device is locked" ([finishWorkout][finish]). The header says the same (Doc, `HKWorkoutBuilder.h`).
- **Apple staff (2021):** "If the device is locked, finishing a workout will succeed but will not be able to return the HKWorkout object. You'll be able to query for that object once the device unlocks again" ([forum 695853][f695853]).
- **Support:** HealthKit's main data is in the Protected Unless Open class. "Access to the data is relinquished 10 minutes after the device locks." "Temporary journal files store health records that are generated when the device is locked, such as when the user is exercising", and they are merged on unlock. "When an app is using the HKWorkoutSession API, HealthKit data is accessible for the duration of the workout session while the device is locked" ([Platform Security][security]).
- **Doc:** the builder's `beginCollection`, `addWorkoutEvents`, `addWorkoutActivity` and `endCollection` pages and headers say nothing about the lock state (Doc, by absence). No source says they fail while locked. A 2021 report did run `beginCollection` through `finishWorkout` on a locked iPhone, and the workout appeared in Health. Only its route link was lost, because that step needs the returned `HKWorkout` ([forum 695845][f695845], Report).

### What developers report on iOS 26.4 and later

- **Report:** "HKWorkoutBuilder.finishWorkout() fails silently (nil workout, nil error) when device is locked (iOS 26.4+)". The developer locks the phone during a 5-second delay inside a `UIBackgroundTask`, `finishWorkout` returns nil/nil, and after unlocking "the workout does not exist". They say it's still present on iOS 26.5 and the 26.6 beta, and they filed FB22396180 ([forum 825838][f825838]).
- **Apple staff (June 2026):** "it doesn't seem that we can reproduce the issue with our own code" ([forum 825838][f825838]). No fix or workaround has been posted.
- **Report:** two other developers see it in production. One says saving while locked used to work and "is now broken". The other sees nil/nil while **unlocked and in the foreground**, on iOS 26.4 through iOS 27, for "a small percentage of users": the samples are saved but no `HKWorkout` is ([forum 825838][f825838], [forum 838067][f838067]).

**Reading these together (Inferred):** the documented meaning of nil/nil is "saved, can't show you yet", and some devices return nil/nil when nothing was saved. The app can't tell the two apart at the moment of the call. It can tell them apart later, once protected data is available, by querying for the workout. Temper's design has to treat nil/nil as unverified, not as success and not as failure.

### Staying alive long enough to save

- **Doc:** `beginBackgroundTask(withName:expirationHandler:)`: "call this method before writing data to a file to prevent the system from suspending your app while the operation is in progress". "Call this method as early as possible before starting your task, preferably before your app actually enters the background" ([beginBackgroundTask][bg-task]). Temper already uses one for the Dip (`Temper/AudioAdapter.swift`).
- **Inferred:** take the background task **before** releasing the audio session at Stop or finish. While audio is active the app is running, so the assertion is granted, and it keeps the app alive through the few builder calls. Apple doesn't publish the time allowed.
- **Doc:** `isProtectedDataAvailable` is false "if data protection is enabled and the device is currently locked", and `protectedDataDidBecomeAvailableNotification` posts when protected files become available ([isProtectedDataAvailable][protected], [notification][protected-note]). These track file protection, not HealthKit's own 10-minute window. A suspended app doesn't receive the notification. It gets the current value when it next runs (Inferred).
- **Doc:** a file with no explicit protection gets "Complete until first user authentication", which stays readable and writable while locked once the device has been unlocked after boot ([Encrypting your app's files][encrypting]). The pending-save record should use that class, not `complete` (Inferred).

### Recommended deferral pattern (Inferred)

1. **At Stop or finish,** before audio is released: work out the Health workout from the engine's times in `TemperCore` (start, end, Pauses, Phases, active time). If active time is under 60 s, stop here. Otherwise write a pending-save record (Workout UUID, attempt number, the times) to a file of the default protection class, then begin a background task.
2. **Attempt 1, straight away, locked or not.** Increment the attempt number and build a fresh `HKWorkoutBuilder` with the sync identifier and version (section 2). Then `beginCollection`, add events, activities and metadata, `endCollection`, `finishWorkout`, and end the background task.
   - A workout comes back: saved and verified. Delete the record.
   - An error comes back (including `errorDatabaseInaccessible` from any step): keep the record. Call `discardWorkout()` on that builder.
   - nil/nil: mark the record "unverified" and keep it.
3. **Whenever Temper next runs with protected data available** (launch, foreground, or `protectedDataDidBecomeAvailableNotification` while still running): for each pending record, query for a workout with that sync identifier. If one is found, delete the record. If not, repeat step 2 with the next version.
4. **Give up rule:** after N failed foreground attempts, or on `errorAuthorizationDenied`, drop the record. Ticket #77's decision.

Why not skip the locked attempt and always wait for unlock? Temper is suspended soon after it releases audio, and nothing documented wakes a suspended app at unlock. So the save would wait until the owner next opens Temper. That can be acceptable, because the saved times are historical either way. The locked attempt costs nothing when the record and the sync identifier guard it. When it works, as documented, the Health workout is there without the owner opening the app (Inferred).

A local notification telling the owner to open Temper to finish saving is possible, but optional. One developer used a spoken prompt for the same problem ([forum 695845][f695845], Report).

## 2. Saving once

- **Doc:** `HKMetadataKeySyncIdentifier`: "When you save an HKObject with a sync identifier, the system looks for any existing objects with the same sync identifier. If it finds a match, the system compares the objects' HKMetadataKeySyncVersion values. If the new object has a greater sync version, the system replaces the old object with the new one." If you add it, "you must also add" `HKMetadataKeySyncVersion` ([sync identifier][sync-id]). The version takes an `NSNumber` ([sync version][sync-version]). The header adds "The expected value type is NSString" (Doc, `HKMetadata.h`).
- **WWDC20 10184:** "When you set a sync identifier on a sample, HealthKit ensures that duplicate copies of the sample are not saved." "If you try to save the sample again, HealthKit would see that the sample already exists and ignore it." "All operations done using sync identifiers are transaction safe" ([WWDC20 10184][wwdc20]).
- **Report:** a developer verified on the iOS 26.5 Simulator that two `HKWorkoutBuilder` saves with the same sync identifier and a higher version "leave exactly one workout carrying the second version" ([GitHub PR][pr-sync]). Another passed the identifier as a raw `UUID`, got an error, and fixed it with a string ([forum 658843][f658843]).
- **Doc:** `HKMetadataKeyExternalUUID` is only a label for the app's own lookups. It has no replace semantics ([external UUID][external-uuid]).
- **Doc, querying:** `HKQuery.predicateForObjects(withMetadataKey:allowedValues:)` finds the workout by its sync identifier. An app with share permission but no read permission sees "only the data that your app has written" ([authorizationStatus][auth-status]). The query compiles in the throwaway check below (Tested).

**Design (Inferred):**

- Sync identifier: the Workout's UUID, created at Start and stored as `uuidString`. Version: the attempt number, starting at 1 and persisted before each attempt.
- Raising the version on every attempt makes the order of landing irrelevant: a later attempt replaces an earlier one, and an earlier one that lands later is not newer, so it is ignored. That covers the worst case, where a journaled locked save merges after a foreground retry. Whether the sync-identifier check is applied when a journal merges at unlock is **Unconfirmed**. A device test has to check it.
- Keeping version 1 for every attempt also relies only on "already exists, ignored" (WWDC20). What `finishWorkout` returns when its workout is ignored as a duplicate is **Unconfirmed**. Raising the version avoids that question.
- The workout's activities and events belong to the workout object, so a replacement brings its own set (Inferred). Temper adds no samples, so no orphan samples are left behind.

## 3. Builder or iPhone session on iOS 27

| | `HKWorkoutBuilder` (iOS 12+) | iPhone `HKWorkoutSession` + `HKLiveWorkoutBuilder` (iOS 26+) |
|---|---|---|
| Purpose | "create a workout that occurred in the past" or during a session (Doc, header) | Live tracking while the Workout runs (WWDC25) |
| Start from the background | Not restricted in the docs (Doc, by absence) | `errorBackgroundWorkoutSessionNotAllowed`: "not allowed to start or prepare when this app is in the background" (Doc, header) |
| Locked access to Health data | None. The 10-minute window, then write-only (Support) | Accessible "for the duration of the workout session" (Support). First run shows a prompt (WWDC25) |
| System metrics on iPhone | None (Doc, "unconnected to … any sources of data") | Calories and distance generated by the system. "May" differ from what was asked (WWDC25, Doc) |
| Crash recovery | None. Temper re-creates it from its own record (Inferred) | System relaunch and `recoverActiveWorkoutSession` (WWDC25) |
| Keeps state with the engine | Once, at Stop | Live: pause, resume and each Phase must be mirrored as they happen (Inferred) |

- **Doc (SDK header):** `HKWorkoutBuilder` is `API_AVAILABLE(ios(12.0), watchos(5.0))` with no deprecation. Its class comment says: "Samples, events, and metadata may be added to a builder either during a live workout session or to create a workout that occurred in the past." The initializer "Creates a new HKWorkoutBuilder unconnected to any HKWorkoutSession or any sources of data." The developer page tells watchOS apps to use the session instead, and says nothing like that for iOS ([HKWorkoutBuilder][builder]).
- **Doc:** the old `HKWorkout(activityType:start:end:workoutEvents:…)` initializers are deprecated as of iOS 17 ([doc][hkworkout-init]). The builder is the remaining way to make a workout.
- **WWDC25 322:** "always use the workout builder API to create and save a workout. This will ensure that activity rings are appropriately updated" ([WWDC25 322][wwdc25]). `HKWorkoutBuilder` is the base class of `HKLiveWorkoutBuilder` (Doc), so the advice covers both (Inferred).
- **Tested:** a throwaway file built the whole builder path with `swiftc -typecheck -target arm64-apple-ios27.0 -swift-version 6 -warnings-as-errors` against the iOS 27.2 SDK, with no errors and no warnings. The path was: builder init, `beginCollection(at:)`, `addMetadata` with sync keys, `addWorkoutEvents` (pause, resume, segment), `addWorkoutActivity`, `endCollection(at:)`, `elapsedTime(at:)`, `finishWorkout()`, a sync-identifier query, `authorizationStatus(for:)`, `statusForAuthorizationRequest(toShare:read:)` and `isProtectedDataAvailable`. At an iOS 18 target, only `HKWorkoutSession(healthStore:configuration:)`, `associatedWorkoutBuilder()` and `HKLiveWorkoutBuilder` failed, as "only available in iOS 26.0 or newer".

**Conclusion (Inferred):** for the settled design (#75: save after the fact from the engine's times, no heart rate), `HKWorkoutBuilder` is the current, intended API. An iPhone session is worth weighing only if live locked access, crash recovery or system calorie estimates become goals. It would have to start at Start in the foreground and follow every Pause and Phase live. The silent nil/nil reports concern `HKWorkoutBuilder.finishWorkout`. Whether a session's live builder has the same problem is **Unconfirmed**.

## 4. Pauses and Phases

### Pauses

- **Doc:** "Workouts start in an active state. A pause event switches it to an inactive state; a resume event switches it back to an active state." Repeated pauses or resumes "are ignored" ([HKWorkoutEvent][event]).
- **Doc:** `elapsedTime(at:)`: "The duration of a workout doesn't include intervals between pause and resume events" ([elapsedTime][elapsed]). So the saved duration is the active time when each Pause is a `pause` event at its start and a `resume` event at its end.
- **Doc (SDK header), activities:** `HKWorkoutActivity.duration` "takes into account periods that the activity was paused", based on "the workoutEvents property of the parent workout object". An activity's `workoutEvents` includes "any event that overlaps the activity, even partially". So **an activity can span a Pause**, and its duration leaves the Pause out.
- **Inferred:** a Workout Stopped while Paused can end at the Pause's start, which avoids a trailing `pause` with no `resume`. The 1-minute rule should use the same active time, computed in `TemperCore` before any HealthKit call. `elapsedTime(at:)` can confirm it.

### Phases

- **Doc:** "All workout activities must use the same activity type as the containing workout. You can't mix activities within a single workout." Activities "can't overlap" and "don't need to cover the entire" workout. For rest periods "you may want to add custom metadata to indicate whether the activity is an active or resting interval", or, for exercise and rest, "leave the rest intervals blank" ([Dividing a workout into activities][dividing]).
- **Doc:** a workout with no explicit activity gets one added by HealthKit, matching its type ([dividing][dividing]).
- **Doc:** `addWorkoutActivity(_:)` takes `HKWorkoutActivity(workoutConfiguration:start:end:metadata:)`. Activity metadata values are `NSString`, `NSNumber`, `NSDate` or `HKQuantity` ([addWorkoutActivity][add-activity], `HKWorkoutActivity.h`).
- **Doc:** `segment` events "mark important periods during the workout". "Unlike laps, segments can freely overlap" ([segment][segment]).

**Mapping onto Temper (Inferred):**

| Workout Type | Health workout span | Activities |
|---|---|---|
| Intervals | First Work start to the end of the last Phase (Cooldown if any) or Stop | One per Work, metadata `Phase = work`, `Round = n`. Rest as `Phase = rest` activities or left blank. Cooldown as a `Phase = cooldown` activity of the same type |
| Stopwatch | Work start to Work end or Stop | One Work activity, or none (HealthKit adds one) |
| Open Rounds | First Work start to Stop | One per Work (ended by Done), plus Rest activities if Rest is recorded |

- Prepare is "used to get into position" (GLOSSARY), so starting the Health workout at the first Work keeps it out of the active time. Including it is #77's call.
- Give custom metadata keys an app prefix (for example `Temper.Phase`) so they can't collide with Apple's `HK…` keys.
- Segment events on top of activities add nothing Temper needs, and Fitness reportedly doesn't show them (below).

### What Fitness and Health show

- **Report (2022, unanswered):** a developer added `segment` events through the builder. "Once the workout is finished, the Apple Fitness app doesn't show these segments" ([forum 707173][f707173]).
- **Report (2025, unanswered):** a developer couldn't find the Watch's own custom-workout intervals in HealthKit's events or segments ([forum 798752][f798752]).
- **Unconfirmed:** whether Fitness or Health lists third-party `HKWorkoutActivity` objects, and how a workout with no heart rate or energy appears (duration only, presumably). Apple documents neither. A device test has to look.

## 5. Activity types and rings

From [HKWorkoutActivityType][activity-type] (Doc):

| Workout Type | Case | Apple's description |
|---|---|---|
| Intervals | `highIntensityIntervalTraining` | "high intensity interval training" |
| Open Rounds | `traditionalStrengthTraining` | "strength training exercises primarily using machines or free weights" |
| Open Rounds, body weight | `functionalStrengthTraining` | "strength training, primarily with free weights and body weight" |
| Stopwatch | `other` | "a workout that does not match any of the other workout activity types" |

- **Inferred:** Stopwatch is a count-up Work of any exercise, so no single case fits. `other` is honest. A per-Preset or Settings choice of type would be better, and that choice could also override the Intervals and Open Rounds defaults. One type per Health workout, since types can't be mixed ([dividing][dividing]).
- **Doc:** `HKMetadataKeyIndoorWorkout` (`NSNumber` BOOL) records whether the workout was indoors (`HKMetadata.h`).

**Rings:**

- **Support (iOS 27):** "Any workout you complete in a compatible third-party app appears in your activity summary and contributes to the progress toward closing your Move ring in the Fitness app" ([Sync a third-party workout app][sup-sync]). "The red Move ring shows how many active calories you've burned. And if you have an Apple Watch, you'll also see a green Exercise ring … and a blue Stand ring" ([Activity summary][sup-summary]).
- **WWDC25 322:** the builder API "will ensure that activity rings are appropriately updated" ([WWDC25 322][wwdc25]).
- **Unconfirmed:** what a workout with no `activeEnergyBurned` samples adds to Move. Move counts active calories, and this workout carries none, so it probably adds nothing beyond what iPhone motion, or a worn Watch, measured anyway (Inferred). Whether it adds Exercise minutes for a Watch owner is also **Unconfirmed**. A device test, or adding an estimated energy sample, would settle it. Estimating calories is outside the settled design.

## 6. Permission

- **Entitlement (Doc):** enable the HealthKit capability, which writes `com.apple.developer.healthkit` ([Setting up HealthKit][setup], [entitlement][entitlement]). Xcode also adds `healthkit` to the required device capabilities. Remove it if Health saving is optional ([setup][setup]). The free-signing and public-repo notes from the #73 file still apply.
- **Info.plist strings (Doc):** `NSHealthUpdateUsageDescription` "explains why the app requested permission to save samples". `NSHealthShareUsageDescription` is for reading ([update key][update-key], [privacy][privacy]). "You must set the usage keys, or your app will crash when you request authorization" ([requestAuthorization][request-auth]).
- **Tested (framework strings):** the iOS 27.2 Simulator runtime's shared cache holds two separate messages. One reads "NSHealthUpdateUsageDescription must be set in the app's Info.plist in order to request write authorization". The other reads "NSHealthShareUsageDescription must be set … in order to request read authorization". There are also "is an invalid value" checks for both. So a write-only request (`toShare: [workoutType], read: []`) needs only the update string. Placeholder text may be rejected (Inferred from the strings). Temper's `Config/Temper-Info.plist` or an `INFOPLIST_KEY_` build setting can hold it.
- **Does status reveal write permission? Yes (Doc).** `authorizationStatus(for:)` "checks the authorization status for saving data", returning `notDetermined`, `sharingDenied` or `sharingAuthorized`. Only **read** permission is hidden: "your app cannot determine whether or not a user has granted permission to read data" ([authorizationStatus][auth-status], [HKAuthorizationStatus][auth-enum]). Saving without asking fails with `errorAuthorizationNotDetermined`, and after a denial with `errorAuthorizationDenied` ([Authorizing access][authorizing]).
- **Doc:** `statusForAuthorizationRequest(toShare:read:)` tells whether a request would show the sheet ([getRequestStatus][request-status]). The sheet shows only for types not yet decided. Otherwise the completion runs "without prompting the user" ([requestAuthorization][request-auth]).
- **Sheet from the background or while locked: Unconfirmed.** Apple doesn't say. The sheet is system UI over the app, so assume it needs Temper active in the foreground (Inferred).
- **When to ask (Doc):** "Request access to health data only when you need it … not immediately after your app launches. When your request is clearly related to the current context, you help people understand your app's intentions" ([HIG HealthKit][hig]). "It might make more sense to wait until you need to access the data before asking for permission" ([Authorizing access][authorizing]). WWDC25: "only request for authorization for data types you need" ([WWDC25 322][wwdc25]).
- **Inferred for Temper:** ask when the owner turns on "Save to Health" in Settings, or at the first foreground Start that would be saved. Never at Stop, which often happens while locked. At Stop, check `authorizationStatus`: if it isn't `sharingAuthorized`, don't write a pending record. Request only `HKObjectType.workoutType()` to share, with no reads. The verification query in section 1 relies on seeing the app's own data with share-only permission, which the docs describe ([authorizationStatus][auth-status]). Whether a query on a never-requested read type returns that data or an error is **Unconfirmed**. If it errors, Temper would add a read request for `workoutType` and the share string.

## What only a device test can settle

1. **The locked save on iOS 27:** Stop an Intervals Workout on a phone locked for more than 10 minutes. Record what `finishWorkout` returns, and whether the Health workout exists after unlock. Repeat with the phone locked under 10 minutes and with it unlocked. This is the regression in [forum 825838][f825838].
2. **Builder steps while locked:** whether `beginCollection`, `addWorkoutActivity` or `addWorkoutEvents` ever fail with `errorDatabaseInaccessible`.
3. **The background-task window after Stop:** that Temper finishes the builder calls after releasing audio, before suspension.
4. **Idempotency:** two saves with the same sync identifier and version, then with version 1 and 2 in both orders, and with a locked (journaled) save followed by an unlocked retry. Each should end with one Health workout. What `finishWorkout` returns for an ignored duplicate. The Simulator can cover the unlocked cases.
5. **Share-only verification query:** whether a workout query by sync identifier works with share permission only and no read request.
6. **What Fitness and Health show** for a workout with per-Work activities, Rest recorded or blank, Pauses, and no heart rate or energy.
7. **Rings:** whether a no-sample `highIntensityIntervalTraining` or `traditionalStrengthTraining` workout adds anything to Move, or to Exercise when a Watch is paired.
8. **The authorization sheet:** what `requestAuthorization` does when called while Temper is in the background or the phone is locked.

## Sources

[privacy]: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
[db-inaccessible]: https://developer.apple.com/documentation/healthkit/hkerror/code/errordatabaseinaccessible
[finish]: https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/finishworkout(completion:)
[builder]: https://developer.apple.com/documentation/healthkit/hkworkoutbuilder
[elapsed]: https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/elapsedtime(at:)
[add-activity]: https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/addworkoutactivity(_:completion:)
[event]: https://developer.apple.com/documentation/healthkit/hkworkoutevent
[segment]: https://developer.apple.com/documentation/healthkit/hkworkouteventtype/segment
[dividing]: https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities
[activity-type]: https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype
[hkworkout-init]: https://developer.apple.com/documentation/healthkit/hkworkout/init(activitytype:start:end:workoutevents:totalenergyburned:totaldistance:metadata:)
[sync-id]: https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier
[sync-version]: https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion
[external-uuid]: https://developer.apple.com/documentation/healthkit/hkmetadatakeyexternaluuid
[auth-status]: https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:)
[auth-enum]: https://developer.apple.com/documentation/healthkit/hkauthorizationstatus
[authorizing]: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
[request-auth]: https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:)
[request-status]: https://developer.apple.com/documentation/healthkit/hkhealthstore/getrequeststatusforauthorization(toshare:read:completion:)
[setup]: https://developer.apple.com/documentation/healthkit/setting-up-healthkit
[entitlement]: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit
[update-key]: https://developer.apple.com/documentation/bundleresources/information-property-list/nshealthupdateusagedescription
[hig]: https://developer.apple.com/design/human-interface-guidelines/healthkit
[bg-task]: https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:)
[protected]: https://developer.apple.com/documentation/uikit/uiapplication/isprotecteddataavailable
[protected-note]: https://developer.apple.com/documentation/uikit/uiapplication/protecteddatadidbecomeavailablenotification
[encrypting]: https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files
[security]: https://support.apple.com/guide/security/protecting-access-to-users-health-data-sec88be9900f/web
[sup-sync]: https://support.apple.com/guide/iphone/sync-a-third-party-workout-app-iph392b962da/ios
[sup-summary]: https://support.apple.com/guide/iphone/see-your-activity-summary-iph4c34a8a95/ios
[wwdc20]: https://developer.apple.com/videos/play/wwdc2020/10184/
[wwdc25]: https://developer.apple.com/videos/play/wwdc2025/322/
[f695853]: https://developer.apple.com/forums/thread/695853
[f695845]: https://developer.apple.com/forums/thread/695845
[f825838]: https://developer.apple.com/forums/thread/825838
[f838067]: https://developer.apple.com/forums/thread/838067
[f658843]: https://developer.apple.com/forums/thread/658843
[f707173]: https://developer.apple.com/forums/thread/707173
[f798752]: https://developer.apple.com/forums/thread/798752
[pr-sync]: https://github.com/korjavin/medicationtrackerbot/pull/1568

- HealthKit docs: [Protecting user privacy][privacy], [errorDatabaseInaccessible][db-inaccessible], [HKWorkoutBuilder][builder], [finishWorkout][finish], [elapsedTime(at:)][elapsed], [addWorkoutActivity][add-activity], [HKWorkoutEvent][event], [segment][segment], [Dividing a HealthKit workout into activities][dividing], [HKWorkoutActivityType][activity-type], [deprecated HKWorkout initializer][hkworkout-init], [HKMetadataKeySyncIdentifier][sync-id], [HKMetadataKeySyncVersion][sync-version], [HKMetadataKeyExternalUUID][external-uuid], [authorizationStatus(for:)][auth-status], [HKAuthorizationStatus][auth-enum], [Authorizing access to health data][authorizing], [requestAuthorization][request-auth], [getRequestStatusForAuthorization][request-status], [Setting up HealthKit][setup].
- iOS 27.2 SDK headers: `HKWorkoutBuilder.h`, `HKWorkoutActivity.h`, `HKWorkoutSession.h`, `HKLiveWorkoutBuilder.h`, `HKMetadata.h`, `HKDefines.h`, `HKHealthStore.h`.
- Bundle resources: [HealthKit entitlement][entitlement], [NSHealthUpdateUsageDescription][update-key]. Design: [HIG HealthKit][hig].
- UIKit: [beginBackgroundTask][bg-task], [isProtectedDataAvailable][protected], [protectedDataDidBecomeAvailableNotification][protected-note], [Encrypting your app's files][encrypting].
- Apple Support: [Protecting access to user's health data][security] (Platform Security), [Sync a third-party workout app][sup-sync], [See your activity summary][sup-summary].
- WWDC: [20 10184 Synchronize health data with HealthKit][wwdc20], [25 322 Track workouts with HealthKit on iOS and iPadOS][wwdc25].
- Apple Developer Forums: [695853][f695853] (Apple staff), [825838][f825838] (Apple staff and reports), [695845][f695845], [838067][f838067], [658843][f658843], [707173][f707173], [798752][f798752] (reports).
- GitHub: [korjavin/medicationtrackerbot#1568][pr-sync] (report, Simulator test of sync-identifier replacement).
