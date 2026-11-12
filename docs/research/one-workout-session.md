# One workout session per Watch: who wins, and what the loser keeps

Research for ticket #153 on map #152. Sources were read on 2026-11-12. Nothing here has been run on a device. The last section lists what only a device run can settle, and #155 is that run.

The owner's Series 8 stops at watchOS 26, so watchOS 26 is the version that matters. Apple's rule hasn't changed since watchOS 2, and no watchOS 26 or 27 release note touches it (section 5). Every developer report below is older than watchOS 26.

## Answer

- **The rule: one workout session per Watch, across all apps (Doc).** "Apple Watch runs one workout session at a time." Apple DTS repeated this in March 2026 when a developer asked for two apps' sessions at once: "there is no way to do that" (Apple staff).
- **Who wins: the session that starts second (Doc).** "If the user begins a second workout session in a different app, the original session receives this error message and then ends. The second session then starts." Apple names no exception for its own Workout app, and its pages don't mention that app at all. Developers and users report the takeover in both directions, with Apple's Workout app as the loser and as the winner (Report, watchOS 3 to 9). One 2017 report had a third-party workout started *from the iPhone* end the Watch's Apple Workout session. That's the path Temper's Start uses (Report).
- **How the loser learns: `didFailWithError`, then `.ended` (Doc).** HealthKit calls `workoutSession(_:didFailWithError:)` with `HKError.Code.errorAnotherWorkoutSessionStarted`, changes the state to `.ended`, then calls `workoutSession(_:didChangeTo:from:date:)`. After `.ended`, "The watch can no longer run in the background", the sensors go back to normal and the session can't be reused. Mirroring stops with the session, so the iPhone's mirrored instance gets `didDisconnectFromRemoteDeviceWithError` and is no longer valid (Doc, SDK).
- **Can the loser's builder still save? Apple's own sample code does, but no page covers this case (Inferred).** The heart-rate and energy samples the live data source collected are already in Health, because it saves them as they arrive. Even a discarded builder leaves them (Doc). Whether `endCollection` and `finishWorkout` work after another app ended the session is undocumented. Apple's WWDC21 workout-app code ends its builder *after* the session reaches `.ended` and saves that way, and WWDC18 gives the same order (WWDC). How long the loser keeps running to do that is undocumented (Unconfirmed).
- **Workarounds: none for collecting or staying in front while another app's session runs.** No API gives a second app live heart rate or energy credit, or background runtime, under someone else's session. A Watch app *can read* the samples the other session saves, but only while it's running: on the screen, or as the frontmost app after the wrist drops. Background delivery on watchOS is at most hourly for heart rate and energy (Doc). Extended runtime sessions are tied to self care, mindfulness, physical therapy and smart alarms. Nothing says whether one can run alongside another app's workout (Unconfirmed). Apple staff also warn against workout sessions used for anything but workouts. The map's choice holds: Temper's own session replaces Apple Workout, and Temper doesn't try to share the Watch.

## How to read the labels

| Label | Meaning |
|---|---|
| **Doc** | Apple developer documentation, read from the site's JSON data. |
| **SDK** | Header comments in the watchOS 27.2 / iOS 27.2 SDKs shipped with Xcode on this Mac. |
| **WWDC** | An Apple WWDC session transcript or its on-page code. |
| **Apple staff** | A forum reply with an Apple badge. Informed, but not a contract. |
| **Report** | A developer or user report on a forum, Q&A site or app help page. Not an Apple source. |
| **Inferred** | My conclusion. No source states it. |
| **Unconfirmed** | I looked and found no source. |

## 1. The one-session rule

- **Doc ([HKWorkoutSession][hkws]):** "Apple Watch runs one workout session at a time. If a second workout starts while your workout is running, your `HKWorkoutSessionDelegate` object receives an `errorAnotherWorkoutSessionStarted` error, and your session ends."
- **Doc ([errorAnotherWorkoutSessionStarted][another], watchOS 2.0+):** abstract "Another app started a workout session." Discussion: "This error occurs whenever a second workout session is started. Apple Watch only runs one workout session at a time. If the user begins a second workout session in a different app, the original session receives this error message and then ends. The second session then starts."
- **SDK (`HKDefines.h`):** "`HKErrorAnotherWorkoutSessionStarted` Another primary workout session has started or is already ongoing by this or another application." Two details matter here. The rule covers *primary* sessions. A mirrored session on the iPhone is a different type (`HKWorkoutSessionTypeMirrored`) and isn't one of the competitors. And "or is already ongoing" suggests that, in some cases, a *starting* session can get this error instead of the running one. No page says when (Unconfirmed). Every Apple page and report I found has the second session winning.
- **Apple staff ([forum 819307][f819307], March 2026):** a developer wanted a metronome app's `HKWorkoutSession` alongside Runna's. Apple DTS: "If you are looking for a way to have multiple apps running their own active `HKWorkoutSession` on watchOS simultaneously, there is no way to do that." The reply quotes the HKWorkoutSession page above. The developer had already seen their session "conflicts with Runna and other workout apps".
- **WWDC16 Building Great Workout Apps ([235][wwdc16]):** the watch-face glyph "indicates that one of the apps on this watch has an active workout session". It's singular, but the session doesn't state the rule outright.

## 2. Who wins, and whether Apple's Workout app is different

### What Apple says

- The second session wins and the first ends (section 1). Apple's documentation, WWDC sessions and release notes never mention its own Workout app in this context, and they give no priority rule. I found no Apple statement either way about whether the Workout app is treated differently (Unconfirmed).
- **Doc ([Running workout sessions][running]):** a session the iOS companion asks for still starts on the Watch through `handle(_:)`. So a Temper Workout started on the iPhone is a second session like any other (Inferred).

### What developers and users report

All of these are older than watchOS 26. None was tested on watchOS 26.

- **Report ([Stack Overflow 42513431][so42513431], watchOS 3, 2017):** an interval-notification app with an `HKWorkoutSession`. Starting Apple's Workout, then this app, then going back to Workout made Workout "crash". Starting this app first and Workout second made the app stop running in the background. The answer: "starting a new HKWorkout session (such as on your app) ends another pre-existing HKWorkout session (such as on the native Workout app)". Both directions match the documented rule.
- **Report ([Apple Community 7819214][ac7819214], watchOS 3.1, 2017):** "the session stops in the Workout app and goes to a summary screen" when another app starts. The same user found that "simply starting a workout using Runtastic Results on my iPhone ends the Workout app's workout session on the Apple Watch". The thread doesn't say whether Apple's app saved the interrupted workout.
- **Report ([Apple Community 254567630][ac254567630], watchOS 9, 2023):** rest timers in Fitbod and 5K Runner "occasionally will prematurely end my workout in the Apple Watch Workout app".
- **Report ([Slopes help][slopes], app developer):** "Only one app at a time is allowed access to Workouts on the Apple Watch … Slopes's workout will be ended to start a workout for the other app."
- **Report ([MacRumors 2228676][mr2228676], 2020):** one user ran three workout apps "at the same time with no problems". Another said the second "will kill off the workout session in the first app", and the original poster found only one app's record afterwards. This is the only report that seems to contradict the rule. It's likely only one of the three held a session (Inferred).

### What that means (Inferred)

Apple's Workout app loses to Temper exactly as Temper loses to it. If the owner has Apple Workout running and taps Start in Temper, the documented rule says Temper's Watch session ends Apple's workout. What Apple's app keeps when that happens is undocumented. The 2017 report of it going to a summary screen suggests it closes its workout normally. #155 should check whether Health has Apple's partial workout.

## 3. How the losing app learns

- **Doc ([didFailWithError][didfail]):** "When the state of the workout session changes due to an error, HealthKit always calls this method before calling the `workoutSession(_:didChangeTo:from:date:)` method. For example, if a second app starts a workout session, HealthKit calls the current session's `workoutSession(_:didFailWithError:)` method. Next, it changes current session's state to the `ended` value. Finally, HealthKit calls the current session's `workoutSession(_:didChangeTo:from:date:)` method." The SDK header says the same and calls it "an error that stops a workout session".
- **SDK (`HKWorkoutSession.h`, `didChangeToState`):** "If your application is suspended then the delegate will receive this call once the application resumes, which may be much later than when the original state change ocurred." The `date` argument is when the change actually happened. A losing app that was suspended when the other app started hears about it only when it next runs (Inferred). Under its own running session it wouldn't have been suspended, so that should be rare.
- **Doc ([HKWorkoutSessionState.ended][ended]):** "The watch can no longer run in the background. Its sensors return to normal, and it no longer generates workout data. You can't restart or reuse the workout session."
- **SDK (`HKWorkoutSession.h`):** `end()` stops sensor algorithms, "no new data will be generated for this session, and the system will exit session mode". `stopMirroringToCompanionDevice`: "When a workout session is ended, mirroring is automatically stopped." `didDisconnectFromRemoteDeviceWithError`: "After this method is called for a mirrored workout session, it is no longer considered valid." `sendDataToRemoteWorkoutSession` returns an error "if the session is not mirroring".
- **What the iPhone can tell (Inferred):** on the iPhone, a takeover looks like any other disconnect. The mirrored session reports a disconnect, and any error it carries is undocumented. To tell the iPhone "another app took over", the Watch would have to send it. The only window over the workout channel is between `didFailWithError` and the change to `.ended`. Whether mirroring still carries a message at that point is undocumented (Unconfirmed). WatchConnectivity is the other path, and the Watch app may be suspended soon after `.ended`.

## 4. Whether the loser's live builder can still save

### What's documented

- **Doc ([Running workout sessions][running]):** "While the session runs, Apple Watch automatically collects data about the workout, and saves samples to the HealthKit store. For example, an outdoor running session collects and saves `activeEnergyBurned`, `basalEnergyBurned`, `heartRate`, and `distanceWalkingRunning` samples."
- **SDK (`HKWorkoutBuilder.h`, `discardWorkout`):** "Samples that were added to the workout will not be deleted." So the heart rate and energy a losing session collected stay in Health whatever its builder does next. Whether they still count toward the rings without a workout around them isn't stated (Unconfirmed).
- **Doc ([finishWorkout][finish]):** "You must call `endCollection(withEnd:completion:)` before calling this method." Neither page puts a condition on the session's state.
- **Today's documented order** (Running workout sessions, WWDC25 322) is `stopActivity`, wait for `.stopped`, `endCollection`, `finishWorkout`, and then `end()`. A session ended by another app skips `.stopped` and goes straight to `.ended`, so this order can't be followed (Inferred).

### What Apple's own code shows

- **WWDC21 10009 ([Build a workout app for Apple Watch][wwdc21]):** "When the session transitions to ended, call endCollection on the builder with the end date provided to stop collecting workout samples. Once endCollection finishes, call finishWorkout to save the HKWorkout to the Health database." The code calls `session.end()` and then, in `didChangeTo` with `toState == .ended`, calls `endCollection(withEnd: date)` and `finishWorkout`. Its `didFailWithError` is empty.
- **WWDC18 707 ([New ways to work with workouts][wwdc18]):** "to end the workout, you first call session.end, and then you also call builder.endCollection and pass the workout's end date … if you want to save the workout in HealthKit, you just call builder.finishWorkout".
- So Apple has shown a live builder finishing and saving after its session reached `.ended`. Code built that way saves a session another app ended without any extra handling (Inferred). No Apple source covers that case directly, and I found no developer report of it working or failing (Unconfirmed).

### What Temper does today

`TemperWatch/WatchSession.swift` already relies on this. On `.ended` it tells the flow and, if a save is pending, calls `save(_:)`, which runs `endCollection(at:)` and `finishWorkout()` and discards on failure. The comment says "A session another workout app took over has ended already, and its builder can still save." The `.stopped` path saved on the devices. The `.ended` path after a takeover has never been run, as far as the repo shows. `didFailWithError` is empty, which is fine, because the state change follows it (Doc).

### Open points (Unconfirmed)

- How long a losing Watch app keeps running after `.ended` to finish its save. No figure is published. "The watch can no longer run in the background" suggests it's short if the app isn't on screen, and the winner usually is.
- Whether `finishWorkout` fails if the end date passed to `endCollection` is later than the takeover. Passing the `date` from the `.ended` change is the safe choice (Inferred).

## 5. watchOS 26 specifics

- The rule's pages (HKWorkoutSession, the error, the delegate) list watchOS 2.0 and later and aren't marked deprecated (Doc).
- watchOS 26, 26.1, 26.2, 26.3, 26.4 and 26.5 release notes: no item about workout sessions across apps. The HealthKit and Workout items are a read-authorization fix, blood-pressure fixes, an auto-paused-workout known issue and Workout Buddy fixes ([26][rn26], [26.4][rn264]).
- watchOS 27 release notes: heart-rate and power zones, a Mirrored Playback fix, and background heart rate pausing while a third-party heart-rate monitor is active. Nothing about concurrent sessions ([27][rn27]).
- iOS 26 made `HKWorkoutSession` and `HKLiveWorkoutBuilder` available on iPhone (Doc). The rule's wording is about Apple Watch, and none of this changes the Watch.
- **Unconfirmed on watchOS 26:** Apple Workout's behaviour in both directions, and the loser's builder save. Every report is from watchOS 3 to 9.

## 6. Collecting or staying in front under another app's session

- **Reading another app's samples (Doc, Inferred):** any app with read permission can query the heart-rate and energy samples the running session saves. On the Watch that works only while the app runs. [Background delivery][bgdelivery] on watchOS is "most data types have an hourly maximum frequency". Heart rate and active energy aren't on the list of immediate types, and the updates share a budget of four an hour with background refresh. A third-party app can't follow another app's session live from the background.
- **Staying in front (Doc):** the frontmost app stays in the foreground after the wrist drops for the Return to Clock time, two minutes by default. People can set it per app in Settings > General > Wake Screen ([frontmost state][frontmost]). That's a person's setting, not an app's. Since watchOS 7, `isFrontmostTimeoutExtended` no longer extends it. Apps with a workout session "continue to run in the background throughout the entire workout", and tapping the glyph brings them back. Which app shows when the wrist goes up, with Temper frontmost and Apple Workout holding a session, is undocumented (Unconfirmed).
- **Extended runtime sessions (Doc):** an app supports one type: self care, mindfulness, physical therapy or smart alarm. "Select a session type based on the app's intended use—not based on the features that the session provides" ([Using extended runtime sessions][ers]). They don't collect workout data or give ring credit. Whether one can run beside another app's workout session is undocumented. The only related invalidation reason is `suppressedBySystem`, "Apple Watch is in a state that doesn't currently allow this session type to run" (SDK). An interval timer isn't any of those four uses (Inferred).
- **Apple staff ([forum 743253][f743253], 2023):** "HKWorkout is intended for recording workouts, not for getting unlimited background runtime for other purposes."

## What this means for map #152 (Inferred)

- The map's Out of scope line holds: the Watch can't run Temper beside Apple Workout, and Temper can't win the Watch back without ending Apple's workout.
- Starting a Training or a Workout in Temper while Apple Workout runs ends Apple's workout. Expect that, and maybe say so where the owner starts a Training. #156 should decide.
- When another app takes over, the Watch's partial save goes through ADR 0001's version 1,000,000 like any Watch save. Outside a Training, it replaces the iPhone's complete copy, as the ADR already notes. #157 should decide what a Training's workout does here.
- For "telling the owner that another app took over" (Not yet specified): the Watch knows for certain from `errorAnotherWorkoutSessionStarted`. The iPhone sees only a disconnect unless the Watch gets a message across, and the workout channel closes with the session (section 3).

## What only a device run can settle

On the Series 8 with watchOS 26.5 (see #155):

1. Apple Workout running, then Start in Temper on the iPhone: does Apple's session end, and does Health get Apple's partial workout?
2. Temper running, then Apple Workout started on the Watch: does Temper's delegate get `errorAnotherWorkoutSessionStarted`, then `.ended`, and does its `endCollection` and `finishWorkout` save a workout? Log the gap between the error and the end of the save.
3. Whether a `sendToRemoteWorkoutSession` call made from `didFailWithError` reaches the iPhone before mirroring stops.
4. Whether any start is refused with the same error while another session runs (the header's "or is already ongoing").

[hkws]: https://developer.apple.com/documentation/healthkit/hkworkoutsession
[another]: https://developer.apple.com/documentation/healthkit/hkerror/code/erroranotherworkoutsessionstarted
[didfail]: https://developer.apple.com/documentation/healthkit/hkworkoutsessiondelegate/workoutsession(_:didfailwitherror:)
[ended]: https://developer.apple.com/documentation/healthkit/hkworkoutsessionstate/ended
[running]: https://developer.apple.com/documentation/healthkit/running-workout-sessions
[finish]: https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/finishworkout(completion:)
[bgdelivery]: https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)
[frontmost]: https://developer.apple.com/documentation/watchkit/taking-advantage-of-frontmost-app-state
[ers]: https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions
[wwdc16]: https://nonstrict.eu/wwdcindex/wwdc2016/235/
[wwdc18]: https://developer.apple.com/videos/play/wwdc2018/707/
[wwdc21]: https://developer.apple.com/videos/play/wwdc2021/10009/
[rn26]: https://developer.apple.com/documentation/watchos-release-notes/watchos-26-release-notes
[rn264]: https://developer.apple.com/documentation/watchos-release-notes/watchos-26_4-release-notes
[rn27]: https://developer.apple.com/documentation/watchos-release-notes/watchos-27-release-notes
[f819307]: https://developer.apple.com/forums/thread/819307
[f743253]: https://developer.apple.com/forums/thread/743253
[so42513431]: https://stackoverflow.com/questions/42513431
[ac7819214]: https://discussions.apple.com/thread/7819214
[ac254567630]: https://discussions.apple.com/thread/254567630
[slopes]: https://slopes.helpscoutdocs.com/article/370-stopped-recording-on-apple-watch
[mr2228676]: https://forums.macrumors.com/threads/record-workout-with-multiple-fitness-tracking-apps-at-a-time.2228676/
