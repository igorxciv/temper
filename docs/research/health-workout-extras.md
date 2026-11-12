# Which of Apple Workout's extras a third-party Health workout can carry

Research for ticket #154 on map #152. Sources were read on 2026-11-12. The question is about a **Training**: one Watch session lasting a whole gym visit, with several Workouts inside and gaps between them, saved as one Health workout. The Watch is a Series 8, so the target is watchOS 26 (see the #73 research). The iPhone runs iOS 27. No new device runs were made for this ticket. The "Tested" lines come from the #108 probe on the owner's Series 8 (watchOS 26.5) and from typechecking against the watchOS 27.2 SDK at a watchOS 26.0 target. The last section lists what only a device run can settle.

## Answer

- **Live energy: yes, and it's one call.** On the Series 8, the live data source for `traditionalStrengthTraining` collects active energy, basal energy and heart rate. It collects no distance, and setting `.indoor` changes nothing (Tested, #108). Apple documents that strength-type workouts without a tuned calorie model are estimated from the Watch's sensors and never fall below a brisk walk while moving (Doc, Support). To show the live total, read `builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()` in `workoutBuilder(_:didCollectDataOf:)`. That's the same pattern `WatchSession` already uses for heart rate (Doc, Tested by typecheck).
- **Gaps count toward energy and duration if the session keeps running.** Workout-level statistics cover every sample added to the builder, whatever activity is current (Doc, SDK). Activities "don't need to cover the entire" workout (Doc). Duration leaves out only the time between `pause` and `resume` events (Doc). Data collection also stops while the session is paused (WWDC). So a gap counts in full if it isn't a pause, and counts for nothing if it is. Between activities, the Watch's sensor algorithms revert to the session's own activity type (SDK).
- **Rings: Move yes. Exercise follows exertion, not clock time.** Workouts "from third-party apps … count toward ring totals" (Support). On watchOS, Move comes from the workout's active energy samples, and Exercise comes from "the amount of time the user spent actually exerting themselves during the workout session, as calculated by the watch's sensors" (Doc). Inside a session, "sustained exertions at a personalized moderate intensity" also earn Exercise minutes (Support). Gap time therefore earns Move from whatever it burns, and earns Exercise only for the minutes the Watch judges hard enough (Inferred). Move and Exercise also accrue all day outside workouts (Support), so a gap's energy reaches the rings either way. What the Training changes is the workout-grade estimate and the workout total. How much Exercise a rest-heavy strength Training earns is **Unconfirmed**.
- **How Fitness shows a multi-activity third-party workout: undocumented.** No Apple source says whether Fitness or Health lists a third-party workout's `HKWorkoutActivity` objects. One 2022 report says Fitness ignores third-party `segment` events (Report). One 2023 report says Apple's own Workout app, after "combine multiple activities", saved separate workouts in Fitness and Health (Report). Expect Fitness to show one workout with its type, duration, energy and heart rate, and treat any per-activity breakdown as a bonus a device run has to confirm (Inferred).
- **Effort rating: an app can write one, but the Watch won't prompt for it.** `relateWorkoutEffortSample(_:with:activity:)` exists on watchOS 11+ and iOS 18+, so it's available on watchOS 26 and iOS 27 (Doc, SDK). An Apple engineer saw a related `workoutEffortScore` sample show as "8 Hard" in Fitness's Effort section (Apple staff). The rating prompt Apple documents belongs to the Workout app's end flow, and no HealthKit API asks the system to show it. Temper would need its own rating screen (Doc by absence, Inferred). The automatic estimate covers "most cardio-focused workouts" (Support). On the Series 8, `highIntensityIntervalTraining` collects `estimatedWorkoutEffortScore` but `traditionalStrengthTraining` doesn't (Tested, #108). So a strength Training gets no estimate. Whether Fitness lets the owner enter effort by hand on a third-party workout is **Unconfirmed**.
- **One Health workout can't mix activity types, except triathlon.** "All workout activities must use the same activity type as the containing workout. You can't mix activities within a single workout." The only exception Apple documents is `swimBikeRun`, with `transition` between legs (Doc, WWDC). So a treadmill walk or a core block inside a strength Training can't be an `indoorWalk` or `coreTraining` activity. It stays `traditionalStrengthTraining`, with metadata to say what it was (Doc, Inferred). What the session does if asked to begin an activity of another type is **Unconfirmed**.

## How to read the labels

| Label | Meaning |
|---|---|
| **Doc** | Current Apple developer documentation, read from the developer site's JSON renderings. |
| **SDK** | Header comments in the watchOS 27.2 SDK (Xcode 27.2, 27B52). |
| **WWDC** | An Apple WWDC session transcript. |
| **Support** | Apple Support or Apple's published white paper on Apple Watch heart rate, calorimetry and activity. These are first-party but written for users, not developers. |
| **Apple staff** | A developer-forum reply with an Apple badge. Informed, but not a contract. |
| **Report** | A developer or user report. Not an Apple source. |
| **Tested** | Measured in the #108 probe on the Series 8 (watchOS 26.5, iOS 27.2), or typechecked locally where marked. |
| **Inferred** | My conclusion. No source states it. |
| **Unconfirmed** | I looked and found no source. |

## 1. Live active energy for Traditional Strength Training

### What gets collected

- **Tested (#108, Series 8, watchOS 26.5):** `typesToCollect` for `traditionalStrengthTraining` and for `other` is active energy, basal energy and heart rate. For `highIntensityIntervalTraining` it's those three plus `estimatedWorkoutEffortScore`. Setting `.indoor` changes nothing, and none of the three collects distance ([#108][i108]).
- **Doc:** the data source "automatically provides live data from an active workout session". `typesToCollect` "can include types like `basalEnergyBurned`, `activeEnergyBurned`, `heartRate`, …" and varies "depending on platform, the person's settings and the workout configuration" ([typesToCollect][ttc]). The initializer populates it "with default types for the workout configuration" (SDK, `HKLiveWorkoutDataSource.h`).
- **Doc:** "Apple Watch optimizes both the sensors and the calorimetry based on the configuration. … HealthKit provides optimized calorie calculations for some activities. These include, but are not limited to, run, walk, cycle, stair-climbing, elliptical, and rowing activities. … For all other activities, the system estimates calories based on the data from Apple Watch's sensors. Depending on the activity, this rate is either never lower than the brisk walk burn rate or never lower than the brisk walk burn rate when moving" ([Running workout sessions][rws]).
- **Support (white paper, Nov 2024):** Apple's table of workout models lists functional strength training and HIIT under "heart rate predominant". It doesn't list traditional strength training. "For all other models, the user will earn at least the credit equivalent of a brisk walk while moving, with the potential for additional credit based on sensor data and activity classification" ([white paper][wp]). So Traditional Strength Training gets the generic sensor-based estimate (Inferred, from its absence in the table).

### Reading the live total

- **Doc:** "Use the workout builder's `statistics(for:)` method to calculate statistics, such as the total, average, minimum, or maximum, for any types that have new data." Apple's example reads it in `workoutBuilder(_:didCollectDataOf:)` "whenever the builder receives a new sample", "for example, by updating the current distance traveled, calories burned, and pace during a run" ([Running workout sessions][rws]).
- **SDK:** the builder's `statisticsForType:` "Returns an HKStatistics object containing the statistics for all the samples of the given type that have been added to the receiver" (`HKWorkoutBuilder.h`). For a cumulative type like active energy, that's `sumQuantity()`.
- **Tested (typecheck):** this compiles at a watchOS 26.0 target for `arm64_32` and `arm64`:

```swift
func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
    let energy = HKQuantityType(.activeEnergyBurned)
    guard collectedTypes.contains(energy),
        let sum = workoutBuilder.statistics(for: energy)?.sumQuantity()
    else { return }
    kilocalories = sum.doubleValue(for: .kilocalorie())
}
```

- **SDK:** `HKLiveWorkoutBuilder.currentWorkoutActivity` (watchOS 9+) returns the activity in progress, and `HKWorkoutActivity.statisticsForType:` covers "all the samples of the given type that have been added to the workout within the date interval of this activity". That gives a per-Workout figure alongside the Training total, if a Workout is an activity (#157).
- **Inferred, for the display:** Apple Workout shows Active and Total calories. Basal energy is collected too, so the Watch can show active energy alone or active plus basal.
- **Tested, caveat (#108):** a 35-second plain session had no active energy in its statistics, only heart rate. Energy samples seem to arrive in batches, so the first reading can take a while. The UI should show a placeholder until the first sum arrives, not "0 kcal" (Inferred).

## 2. Gaps between activities: energy, duration and rings

### Energy and duration

- **Doc:** "Activities can't overlap, but they also don't need to cover the entire `HKWorkout` sample's duration. You can leave the time between the active portions of the workout blank, or you can explicitly create workout activities for these intervals" ([Dividing a workout][div]). WWDC22: "because there may be a transition period between each activity, they are not required to be contiguous" ([WWDC22 10005][wwdc22]).
- **SDK:** workout-level `allStatistics` covers "all of the samples that have been added to the builder". Activity-level statistics cover only samples "within the date interval of this activity" (`HKWorkoutBuilder.h`, `HKWorkoutActivity.h`). So gap energy is in the workout total and in no activity's total (Inferred, from the two scopes).
- **SDK:** `endCurrentActivityOnDate:` "will end the current activity, reverting to the main session activity. … Sensor algorithms to generate data would be updated to match the main session activity." `beginNewActivity` likewise updates "sensor algorithms … to match the new activity" (`HKWorkoutSession.h`). In a gap, the Watch keeps estimating energy with the session's activity type.
- **SDK:** `HKWorkoutSession.currentActivity` "will return a copy of the main workout activity if no new activity has begun". **Tested (#108):** a session that never called an activity API saved one activity covering the whole workout. That automatic activity has to be accounted for when Workouts become activities (#157).
- **Doc:** "The duration of a workout doesn't include intervals between pause and resume events" ([elapsedTime(at:)][elapsed-at]). The live builder's `elapsedTime` is "the elapsed time for the workout based on the builder's current contents, including pauses" ([elapsedTime][elapsed]), and the header says it is "considering paused time" and can rise or fall as events arrive (SDK).
- **WWDC18 707 (demo):** on pausing the session, "My timer has paused. Data collection as well" ([WWDC18 707][wwdc18]).
- **Inferred, for a Training:** a gap that isn't a session pause adds to both duration and energy. If a Workout's Pause inside a Training pauses the HealthKit session, it removes that time and energy from the whole Training. Today `WatchSession` applies the iPhone's Pause to the session (#108). #157 has to decide whether a Workout's Pause still pauses the session inside a Training.

### Rings

- **Doc:** "Workouts can contribute to the Move and Exercise rings in the Activity app. To affect the rings, you must associate one or more active energy burned samples with the workout. … In watchOS … The system updates the Move ring based on the active energy burned samples. It updates the Exercise ring based on the amount of time the user spent actually exerting themselves during the workout session, as calculated by the watch's sensors." On iOS, by contrast, "The Exercise ring increases by the workout's total duration" ([HKWorkout, Fill the Activity rings][hkworkout]).
- **WWDC25 322:** the builder and its generated types are what "ensure that activity rings are appropriately updated" ([WWDC25 322][wwdc25]).
- **Support (white paper):** "Workouts completed in the Workout app, as well as those from third-party apps or user-entered workouts written to the Health app, count toward ring totals." "Every full minute of movement that equals or exceeds the intensity of a brisk walk counts toward daily Exercise goals on Apple Watch, including activity outside of a workout session. … In workout sessions, the user can also earn exercise minutes for sustained exertions at a personalized moderate intensity" ([white paper][wp]). The support article says the same about brisk activity, adding that "any activity below this level counts only toward your daily Move goal" ([accuracy][acc]).
- **Support (iOS 27 guide):** "Any workout you complete in a compatible third-party app appears in your activity summary and contributes to the progress toward closing your Move ring in the Fitness app" ([Sync a third-party workout app][sup-sync]).
- **Inferred, for a Training:** Move counts active calories all day, so gap energy reaches Move whether or not a workout is running. The Training adds a better estimate and puts the energy in one workout total. Exercise on watchOS is earned by exertion, not by the workout's length. Walking between machines and sitting through Rest earn Exercise only where the Watch judges them brisk or moderate. A two-hour strength Training won't add 120 Exercise minutes the way an iPhone-saved workout of the same length would.
- **Unconfirmed:** how many Exercise minutes a rest-heavy Traditional Strength Training earns on a Series 8, against the same visit in Apple Workout. This matters only if the owner compares the two.

## 3. How Fitness shows a multi-activity third-party workout

- **Doc:** activities are stored on the workout (`workoutActivities`) and can be queried with `predicateForWorkoutActivities`. "All `HKWorkout` objects have at least one associated `HKWorkoutActivity`" ([Dividing a workout][div], [HKWorkoutActivity][act]). Nothing in Apple's developer documentation or the WWDC22, WWDC25 and WWDC26 workout sessions says what Fitness or Health displays for a third-party workout's activities ([WWDC22 10005][wwdc22], [WWDC25 322][wwdc25], [WWDC26 207][wwdc26]).
- **Report (2022, unanswered):** segment events added through the builder: "Once the workout is finished, the Apple Fitness app doesn't show these segments" ([forum 707173][f707173]).
- **Support:** Apple's own Workout app can "combine multiple activities into a single workout" by swiping right and tapping New ([Combine multiple workouts][combine]). It doesn't say how that's stored.
- **Report (2023):** a user who combined a run and a walk got a combined summary on the Watch, but "after tapping done, everything has become separate workouts in the fitness app and health app" ([Apple Community][community-combine]). If that still holds, Apple Workout itself saves one workout per activity type, so it has no single mixed workout of its own to match.
- **Unconfirmed:** whether Fitness lists per-activity rows, splits or intervals for a third-party workout with several `traditionalStrengthTraining` activities, with or without metadata. A device run has to look. Until then, assume Fitness shows one workout with its type, duration, energy, heart rate and effort (Inferred).
- **Out of reach on a Series 8:** heart-rate zones on `HKWorkout` and `HKWorkoutActivity` are iOS 27 and watchOS 27 only ([WWDC26 207][wwdc26]).

## 4. Effort rating

### Writing one

- **Doc, SDK:** `HKQuantityTypeIdentifier.workoutEffortScore` and `.estimatedWorkoutEffortScore`, unit `appleEffortScore`, and `HKHealthStore.relateWorkoutEffortSample(_:with:activity:completion:)` / `unrelateWorkoutEffortSample(...)` are available on iOS 18+ and watchOS 11+ ([relate][relate], [workoutEffortScore][wes]). So they work on watchOS 26 and iOS 27. The June 2024 HealthKit update: "Associate perceived and estimated exertion values with workouts. … Use `relateWorkoutEffortSample` to associate exertion data with a workout, and `HKWorkoutEffortRelationshipQuery` to query for associated exertion data" ([HealthKit updates][updates]). The developer pages carry no discussion text beyond the declarations.
- **Apple staff (DTS, 2024):** the score must be 0 to 10. The app needs share and read permission for `workoutEffortScore`. The sample spans the workout's start and end and is related to an already saved `HKWorkout`, with `activity: nil` in the example. Afterwards, "my Fitness.app shows '8 Hard' in the 'Effort' section of the 'workout Details' view" ([forum 763539][f763539]). The same thread reports that adding the sample through the builder or `add(_:to:)` fails, so it has to be related after the save (Report).
- **Tested (typecheck):** relating a `workoutEffortScore` sample to an `HKWorkout` compiles at a watchOS 26.0 target for `arm64_32` and `arm64`. So either the Watch, after `finishWorkout`, or the iPhone can write it.
- **Inferred:** relating it means adding `workoutEffortScore` to the Health permission request. The rating needs the saved `HKWorkout`, so it's a step after the save.

### Prompting and estimates

- **Support (watchOS 26 guide):** at the end of a workout in Apple's Workout app, "Turn the Digital Crown to indicate your effort". "After completing a cardio-focused workout, you can adjust estimated ratings of how hard you exercised", and the rating can later be edited in Fitness on iPhone under Sessions ([End and view a summary][summary]). The page doesn't mention third-party apps.
- **Doc, by absence:** `HKWorkoutSession`, `HKLiveWorkoutBuilder` and `HKHealthStore` have no call that shows the system's effort prompt (SDK headers read for this ticket). **Inferred:** the Watch won't prompt after a Temper session, and Temper would need its own rating screen.
- **Support (white paper):** "Apple Watch supports automatic Effort estimation for most cardio-focused workouts. … Users can manually adjust the Effort estimate or enter a value in sessions where an estimate is not provided" ([white paper][wp]).
- **Apple staff (DTS, 2024):** the system "is supposed to create estimated workout effort scores … for certain workout types. As of today, the types include walking, running, hiking, and cycling", then: "I haven't seen the metric in my Fitness.app or Health.app" for a third-party workout ([forum 764884][f764884]).
- **Tested (#108):** on the Series 8, the default `typesToCollect` includes `estimatedWorkoutEffortScore` for `highIntensityIntervalTraining`, but not for `traditionalStrengthTraining` or `other`. **Inferred:** a strength Training gets no automatic estimate. An HIIT one might, but whether it shows in Fitness for a third-party workout is **Unconfirmed**, given the DTS report.
- **Unconfirmed:** whether Fitness lets the owner tap Effort and enter a value by hand on a third-party workout that has none.

## 5. Mixing activity types in one Health workout

- **Doc:** for interval training, "You can create an interval workout for any `HKWorkoutActivityType`; however, all workout activities must use the same activity type as the containing workout. You can't mix activities within a single workout." Multisport means `swimBikeRun`, whose activities are `swimming`, `cycling`, `running` and `transition` ([Dividing a workout][div]).
- **WWDC22 10005:** "You just need to make sure that all activities of an interval workout have the same activity type as the workout" ([WWDC22 10005][wwdc22]).
- **Doc:** `beginNewActivity` "may also set the data source's `typesToCollect` value based on the new activity", unless the app has called `enableCollection` or `disableCollection` ([beginNewActivity][bna]). For `swimBikeRun`, "HealthKit automatically changes the collected data types based on the current workout activity" ([Dividing a workout][div]).
- **Unconfirmed:** what a non-`swimBikeRun` session does if it's asked to begin an activity of another type (an error, silent acceptance, or a saved workout Health later rejects). Not worth testing, since the documented rule already forbids it.
- **Inferred, for #160:** a treadmill walk or a core block inside a strength Training stays a `traditionalStrengthTraining` activity, perhaps with metadata naming it. Strength collects no distance (Tested, #108). If steps or distance for the walk matter, the data source could be asked to `enableCollection(for:)` `distanceWalkingRunning` or `stepCount` for that stretch, so the Watch's own samples are linked to the workout (Doc for the call, behaviour **Unconfirmed**). The Watch's step and distance samples reach Health either way, outside the workout. The only documented way to keep the walk as an Indoor Walk is a separate Health workout, which breaks "one Training, one Health workout".

## What only a device run can settle

1. **Live energy cadence:** how soon the first active energy sum arrives in a Traditional Strength Training session on the Series 8, and how often it updates.
2. **Gap credit:** for a Training with two Workouts and a long gap, the workout's total energy against the sum of its activities, and its duration against wall-clock time.
3. **Rings:** Move and Exercise before and after a real Training, against the same visit in Apple Workout.
4. **Fitness and Health display:** what each shows for one `traditionalStrengthTraining` workout with several activities (per-Phase or per-Workout, with metadata), and whether any per-activity rows appear.
5. **Effort:** a related `workoutEffortScore` shows in Fitness for a Watch-saved Temper workout. Whether Fitness offers to add effort by hand when there is none. Whether an HIIT session gets an estimate.

## Sources

[i108]: https://github.com/igorxciv/temper/issues/108
[ttc]: https://developer.apple.com/documentation/healthkit/hkliveworkoutdatasource/typestocollect
[ds]: https://developer.apple.com/documentation/healthkit/hkliveworkoutdatasource
[rws]: https://developer.apple.com/documentation/healthkit/running-workout-sessions
[div]: https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities
[act]: https://developer.apple.com/documentation/healthkit/hkworkoutactivity
[bna]: https://developer.apple.com/documentation/healthkit/hkworkoutsession/beginnewactivity(configuration:date:metadata:)
[elapsed]: https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder/elapsedtime
[elapsed-at]: https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/elapsedtime(at:)
[hkworkout]: https://developer.apple.com/documentation/healthkit/hkworkout
[relate]: https://developer.apple.com/documentation/healthkit/hkhealthstore/relateworkouteffortsample(_:with:activity:completion:)
[wes]: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/workouteffortscore
[updates]: https://developer.apple.com/documentation/updates/healthkit
[wwdc18]: https://developer.apple.com/videos/play/wwdc2018/707/
[wwdc22]: https://developer.apple.com/videos/play/wwdc2022/10005/
[wwdc25]: https://developer.apple.com/videos/play/wwdc2025/322/
[wwdc26]: https://developer.apple.com/videos/play/wwdc2026/207/
[f707173]: https://developer.apple.com/forums/thread/707173
[f763539]: https://developer.apple.com/forums/thread/763539
[f764884]: https://developer.apple.com/forums/thread/764884
[wp]: https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf
[acc]: https://support.apple.com/en-us/105002
[sup-sync]: https://support.apple.com/guide/iphone/sync-a-third-party-workout-app-iph392b962da/ios
[summary]: https://support.apple.com/guide/watch/apd95450de2a/watchos
[combine]: https://support.apple.com/guide/watch/apdf42f22a41/watchos
[community-combine]: https://discussions.apple.com/thread/254661405

- HealthKit docs: [HKLiveWorkoutDataSource][ds], [typesToCollect][ttc], [Running workout sessions][rws], [Dividing a HealthKit workout into activities][div], [HKWorkoutActivity][act], [beginNewActivity][bna], [HKLiveWorkoutBuilder.elapsedTime][elapsed], [HKWorkoutBuilder.elapsedTime(at:)][elapsed-at], [HKWorkout][hkworkout], [relateWorkoutEffortSample][relate], [workoutEffortScore][wes], [HealthKit updates][updates].
- SDK headers (watchOS 27.2 SDK): `HKLiveWorkoutDataSource.h`, `HKLiveWorkoutBuilder.h`, `HKWorkoutBuilder.h`, `HKWorkoutActivity.h`, `HKWorkoutSession.h`, `HKHealthStore.h`, `HKTypeIdentifiers.h`.
- WWDC: [18 707 New Ways to Work with Workouts][wwdc18], [22 10005 What's new in HealthKit][wwdc22], [25 322 Track workouts with HealthKit on iOS and iPadOS][wwdc25], [26 207 Deliver workout insights with HealthKit workout zones][wwdc26].
- Apple Support: [Using Apple Watch to measure heart rate, calorimetry, and activity][wp] (white paper, Nov 2024), [Get the most accurate measurements using your Apple Watch][acc], [Sync a third-party workout app to Fitness on iPhone][sup-sync] (iOS 27), [End and view a summary of your workout on Apple Watch][summary] (watchOS 26), [Combine multiple workouts on Apple Watch][combine].
- Apple Developer Forums: [707173][f707173] (Report), [763539][f763539] and [764884][f764884] (Apple staff).
- Apple Community: [thread 254661405][community-combine] (Report).
- This repo: [#108][i108], the Watch Health probe's device results.
