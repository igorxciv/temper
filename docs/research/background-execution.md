# Keeping Temper running and speaking while the phone is locked

Research for ticket #3. Sources were read on 2026-11-01. Nothing here has been run on a device. Ticket #9 measures it.

## Answer

iOS offers no supported way to run a timer in the background. Apple's own statement is that there is "no general-purpose mechanism" for running code continuously or at a specific time in the background ([DTS, iOS Background Execution Limits][dts-limits]).

The only API that can both stay alive and start a Cue on time is the `audio` background mode with an active `.playback` audio session and a running `AVAudioEngine`. Apple documents that mode for apps that play audible content. A Workout is mostly quiet between Cues, so Temper would be relying on behaviour Apple does not promise for those gaps. It will probably work on a personal install, but that has to be measured.

## How to read the labels

| Label | Meaning |
|---|---|
| **Doc** | Current Apple documentation or a WWDC session. |
| **DTS** | Forum post with an Apple staff badge. Informed, but not a contract. |
| **Archive** | Apple's archived guides, last updated around 2017. May be out of date. |
| **Report** | Developer report, not confirmed by Apple. |
| **Inferred** | My conclusion. No source states it. |
| **Unconfirmed** | I looked and could not find a source. |

## What iOS does by default

- **Doc:** An app in the background is typically suspended. A limited set of modes lets it run ([background modes][bg-modes]).
- **Doc:** Shortly after `applicationDidEnterBackground(_:)` returns, the app is suspended ([extending background time][bg-time]).
- **DTS:** Suspension "prevents the process from running any code". There is no mechanism for running code continuously, at a specific time, or at a guaranteed interval. Each mechanism has a specific purpose and must not be used for another ([DTS][dts-limits]).
- **Inferred:** Timers, Tasks and clock callbacks do not fire while suspended. The elapsed time is still correct on resume if it is derived from a fixed start point (ticket #2). The Phase is right when Temper wakes, but nothing was spoken while it slept.

## The options

| Option | Keeps the app running? | Starts a Cue on time? | Verdict |
|---|---|---|---|
| Audio mode, Cues only, session idle between them | No (Inferred) | No | Rejected |
| Audio mode, engine running for the whole Workout | Tends to, not guaranteed | Yes, while the engine runs | **Recommended** |
| Scheduling audio ahead | No, it depends on the above | Yes, it is the precision part | **Use inside the above** |
| Live Activity | No | No, it has no audio | Not needed for v1 |
| Local notification | No | System sound with undocumented timing | Safety net at most |
| AlarmKit | No | An alarm, not a Cue | Rejected |
| Background tasks | Briefly | No | Rejected |
| `HKWorkoutSession` on iPhone | Unconfirmed | Not on its own | Measure as a fallback |

### Background audio mode

**Apple guarantees:**

- **Doc:** `audio` is the declared value for an app that "plays audible content in the background" ([background modes][bg-modes]).
- **Doc:** With `.playback`, audio continues with the Silent switch on and when the screen locks. Continuing in the background needs the `audio` key ([`.playback`][playback]). This supports the map's "ignore Silent mode".
- **Doc:** `.playback` is nonmixable by default, and `mixWithOthers` makes it mix ([`.playback`][playback], [`mixWithOthers`][mix]). This is what stops Temper pausing music.
- **Doc:** Occasional spoken audio in "an exercise app" is a named use of `duckOthers` ([`duckOthers`][duck]). Temper's audio is a recognised case. The doc says nothing about staying alive between utterances.

**Apple does not guarantee:**

- **DTS:** Asked whether the audio mode guarantees no suspension: "Strictly speaking, no. The 'audio' background category allows your app to remain awake while your audio session is active" ([DTS, 2024][dts-audio]).
- **DTS:** The same reply lists likely causes of audio stopping: an interruption not resumed, the app going silent for "too long" so that the system triggered an interruption, system maintenance termination, and reboot. It gives no duration for "too long". It also says being Now Playing with under about 100 MB in the background is "generally safe" from memory termination, and Temper would be mixable, so that protection may not apply (Inferred).

**Does it hold when no sound is playing?** Apple's sources point in two directions and neither gives a number:

- The DTS phrasing above ties staying awake to an active session.
- The mode's description and the archived guides tie it to audible content (see the silent keep-alive section below).
- **Report:** A developer says a silent `AVAudioEngine` loop "keeps the app alive, works in testing" ([2026 thread][silent-report]). Apple's reply in that thread did not address it.

### What a silent keep-alive means

Between Cues, a running engine outputs silence. Whatever we call it, that is a silent keep-alive for most of a Workout, and this design should say so plainly.

- **Archive:** "Use a background task instead of streaming silence to keep the app from being suspended" ([audio guidelines][guidelines]).
- **Report (quoting an Apple guide):** "Apps that play audio content in the background must play audible content and not silence" ([thread][audible-quote]). I could not open the original guide, so this is a second-hand quotation.
- **App Review (not a blocker):** Guideline 2.5.4 limits background services to "their intended purposes" ([guidelines][review]). This matters only if Temper is ever submitted. Temper has a better case than an app with no audio, because it does speak. I would still expect a reviewer to question it (Inferred).
- **What the free install leaves open:** no reviewer applies 2.5.4 to a build that is never submitted. The real risk is technical. iOS may end the behaviour after some silence, or an iOS update may change it (Inferred). Re-run the measurement after major iOS updates.
- **Unconfirmed:** Whether iOS distinguishes digital silence from a very quiet signal, or an engine rendering silence from a stopped engine with an active session.

### Scheduling audio ahead of time

- **Doc:** `AVAudioPlayerNode` can schedule buffers "to play at specific points in time" ([player node][player-node]). `AVAudioPlayer.play(atTime:)` starts at a point on the output device's timeline ([`play(atTime:)`][play-at-time]).
- **Doc:** A host time is ignored unless the sample time is invalid while the engine renders to a device ([player node][player-node]), so sample time is the one to use.
- **Doc:** `stop()` removes all scheduled buffers ([player node][player-node]). A hardware change to channel count or sample rate stops the engine and it must be restarted ([configuration change][engine-change]).
- **Doc:** When the system suspends an app, it deactivates the app's audio session ([`interruptionNotification`][interruption-note]).
- **Inferred:** Scheduling gives precise starts and independence from main-thread timing. It does not wake a suspended app, and the schedule is lost when the engine stops. Schedule only the next Cue, computed from the fixed start point. This also limits any drift between the audio clock and the Workout clock.
- **Report:** `AVSpeechSynthesizer.speak` has failed or stalled when called while locked, in reports going back years with no Apple resolution ([2015][speech-2015], [2023 listing][speech-2023]). Rendering Cues to buffers up front ([`write(_:toBufferCallback:)`][speech-write]) or bundling files avoids running the synthesizer in the background. Ticket #4 chooses between them.

### Live Activities

- **Doc:** Up to eight hours, then the system ends it. It runs in its own sandbox. Dynamic data is updated by the app or by push ([Live Activities][live-activities]).
- **Doc:** Normally started from the foreground. People can turn them off in Settings ([Live Activities][live-activities]).
- **Doc:** Views render state. Buttons run App Intents ([WWDC26][wwdc-live]).
- **Unconfirmed:** No source says a Live Activity extends app runtime, and I would assume it does not (Inferred).
- **Report:** Updates stalling while locked on iOS 27 ([thread 837360, listing only][live-report]).
- **Verdict:** It displays and does not speak. A Lock Screen timer is already out of scope on the map, and nothing here needs that to change.

### Local notifications

- **Doc:** The system delivers them when the app is in the background or not running. A time-interval trigger is intended for timers ([scheduling][notif-schedule], [time-interval trigger][notif-trigger]).
- **Doc:** Custom sounds are bundled `aiff`, `wav` or `caf` files under 30 seconds ([sound][notif-sound]). A spoken word is possible.
- **Doc:** Critical alerts ignore the mute switch, and they need an entitlement issued by Apple ([critical sound][notif-critical]).
- **Doc:** Time Sensitive is not available to the free tier ([capabilities][capabilities]).
- **Inferred:** Ordinary notification sounds respect Silent mode, and do not follow the rule the map sets for Cues. Focus can also affect them.
- **Unconfirmed:** Delivery precision, whether a notification sound ducks music, and a current figure for the pending notification limit. No document I read promises sub-second delivery.
- **Verdict:** Not a Cue mechanism. It could be a safety net, described in the recommendation.

### AlarmKit

- **Doc:** An alarm "overrides both a device's focus and silent mode". It needs authorization and `NSAlarmKitUsageDescription`, and presents an alert with a stop button ([sample][alarm-sample], [WWDC25][wwdc-alarm]).
- **Doc:** Good for "a cooking timer" or a wake-up alarm ([WWDC25][wwdc-alarm]). `maximumLimitReached` exists, and I found no published figure ([error][alarm-limit]).
- **Report:** Alarms "intermittently fire late, or not fire at all until the iPhone is woken up", iOS 26.0 through the 27.0 RC, reproduced with Apple's sample. An Apple engineer asked for logs and knew no workaround ([Sep 2026][alarm-report]).
- **Unconfirmed:** Whether an alarm firing pauses other audio. Apple's archived guide says Clock alarms deactivate audio sessions ([activating][activating]). Whether that also covers AlarmKit is unknown.
- **Verdict:** Rejected. It is a prominent alert that needs a response, which is the opposite of a short spoken word over music, and it would fire many times per Workout.

### Other background APIs

- **Doc:** `beginBackgroundTask` is finite ([API][bg-task]). `BGAppRefreshTask` runs when the system chooses, for up to 30 seconds ([strategies][bg-strategies]).
- **Doc:** `BGContinuedProcessingTask` is for user-started jobs that report progress, and the system can end it abruptly ([API][bg-continued]). None of these fits a timer.
- **Rejected without measurement:** the `location` mode, because Temper has no location purpose, and DTS says not to use a mechanism outside its purpose ([DTS][dts-limits]).

### `HKWorkoutSession` on iPhone (not on the ticket's list)

- **Doc:** A WWDC25 session covers running workouts on iPhone, with system crash recovery and Lock Screen Siri control ([WWDC25][wwdc-health], [`HKWorkoutSession`][hk-session]). HealthKit is available to the free tier ([capabilities][capabilities]).
- **Unconfirmed:** Whether a session keeps an iPhone app running. The explicit "continues to run in the background" text is in the Apple Watch article ([running sessions][hk-running]), and the mode table lists `workout-processing` for watchOS only ([background modes][bg-modes]). The WWDC25 session does not say.
- **Verdict:** Worth one prototype test as a fallback. It would add a Health permission and possibly Health records, which is more than v1 needs.

## Interruptions

- **Doc:** On iOS 27, `AVAudioSession` posts `didBecomeInactiveNotification` and `resumptionRecommendationNotification`. The legacy notification is deprecated for later releases ([handling interruptions][interruptions]). Temper's iOS 27 minimum means it should adopt the new ones.
- **Archive:** The system deactivates the session for a Clock or Calendar alarm or an incoming call, and allows it back when the alarm is dismissed or the call ignored ([activating][activating]).
- **Archive:** If the user **accepts** a call, "your app is suspended". There is "no guarantee" that a begin interruption has a matching end ([responding to interruptions][arch-interruptions]).
- **Archive:** Apps without a playback interface can ignore the resume hint and reactivate when the interruption ends ([responding to interruptions][arch-interruptions]).
- **DTS:** A mixable app can start playing from the background, and a nonmixable one cannot interrupt the foreground app's audio ([2020][dts-mixable]).
- **Report:** Reactivation after a call failed about half the time on one CarPlay setup, with a mixable session ([2025][carplay-report]).
- **Doc:** With banner-style calls, `setPrefersNoInterruptionsFromSystemAlerts(true)` means the session is only interrupted if the call is accepted. It has no effect with full-screen calls ([API][no-interrupt]).
- **Doc:** The media services daemon can restart, and all audio objects must be rebuilt. Apple's text says not to restart playback until the user acts ([reset][media-reset]), which is aimed at media apps. How that applies to a Cue is a judgement for ticket #10.
- **Unconfirmed:** Whether a suspended app gets woken when a call ends. The iOS 27 docs do not say. Assume it is not until measured. The app does not know the Workout was left silent until it runs again.

## Dip and the keep-alive pull against each other

- **Doc:** "Ducking begins when you activate your app's audio session and ends when you deactivate the session", and it must not last "more than a few seconds" ([`duckOthers`][duck]).
- **Doc:** Deactivating with running audio objects stops them and returns an error ([`setActive`][set-active]).
- **Consequence (Inferred):** Dip wants the session cycled around each Cue. The keep-alive wants it held for the whole Workout. Leaving `duckOthers` on would lower music for the entire Workout, which breaks Apple's rule and the map's idea of Dip.
- **Doc:** Changing the category while active "results in an immediate change" ([`setCategory`][set-category]).
- **Unconfirmed:** Whether adding and removing `duckOthers` on an active session starts and ends ducking. If it does, the conflict goes away. If not, every Dip needs a deactivate and reactivate while backgrounded, and that gap is a suspension risk. Dip also needs code running before the Cue, so unlike the Cue itself it cannot be scheduled.

Ticket #4 owns the Dip design, and this result feeds it.

## Keeping the screen awake

- **Doc:** Set `UIApplication.shared.isIdleTimerDisabled = true`. It is off by default. Apple says to set it only when needed and reset it when the need ends, and it allows it for "programs where the app needs to continue displaying content when user interaction is minimal" ([API][idle]). A running Workout fits that.
- **Inferred:** The property only disables the idle timer, so the side button still locks the phone.
- **Ends it:** The app setting it back to `false`. This should happen at Workout end and Stop.
- **Inferred:** It has no effect while Temper is not in front. Re-assert it when the scene becomes active. Forum search summaries mention this, but I could not open a reply that says so.
- **Report:** The flag read `false` hours later with no explanation ([2020][idle-report]). This is why it should be re-asserted.
- **Unconfirmed:** Low Power Mode, low battery, and thermal behaviour. The docs are silent, so measure them.

## Accuracy

- **Doc:** `outputLatency` reports output latency, and AirPlay "can result in a 2-second delay" ([API][output-latency]).
- **Inferred:** A scheduled start is the start at the engine, and what the user hears is later by the route's latency. Compensating with `outputLatency` should help on Bluetooth. The 0.25s target cannot hold on AirPlay unless compensation is accurate over that delay.
- **Inferred:** Phase arithmetic is unaffected by background state. Only Cue timing and on-screen updates depend on the app being awake.

## To measure on a real iPhone (ticket #9)

Log from inside the app and also capture audio on a second device, because app logs cannot prove what was heard. Use a sysdiagnose to confirm suspension or termination, as [DTS advises][dts-audio].

| # | Test | Conditions | Records |
|---|---|---|---|
| 1 | Survive silent gaps | Locked, no other audio, battery. Gaps of 1, 5, 15, 30 and 60 minutes | Time alive, next Cue on time |
| 2 | Same with music | Spotify, Apple Music, started before and after the Workout | Same, plus music unaffected |
| 3 | What keeps it alive | Engine rendering zeros, a very quiet signal, engine stopped with session active | Which survive, and how long |
| 4 | Full Workout accuracy | Locked, another app in front, in front itself | Phase and Cue error against the map's targets |
| 5 | Audio route latency | Speaker, wired, AirPods, other Bluetooth, AirPlay | Heard error, with and without `outputLatency` correction |
| 6 | Clock drift | Longest realistic Workout | Audio clock against `ContinuousClock` |
| 7 | Calls | Declined, ignored, accepted (short and long), FaceTime. Locked and in other apps. Banner and full-screen | Process state, notifications and when, reactivation result, next Cue |
| 8 | Other interruptions | Siri, Clock alarm, AlarmKit alarm from another app | Same |
| 9 | Competing audio | Nonmixable game or video, camera recording, Voice Memos | Whether the mixable session is interrupted |
| 10 | Dip mechanics | Toggle `duckOthers` on an active session, then deactivate and reactivate while locked | Ducking starts and ends, ramp time, failures, survival |
| 11 | Route changes | Bluetooth disconnect and reconnect mid-Workout, locked | Engine restart from background, Cue lost or not |
| 12 | Media services reset | Developer setting, locked | Recovery from background |
| 13 | Pause while backgrounded | Pause, lock, wait, return, Resume | Exact time left, restart in front |
| 14 | Screen awake | 30-second Auto-Lock, Low Power Mode, low battery, warm phone, after a call, after returning from another app | Stays lit or not |
| 15 | System stress | Low Power Mode, heavy foreground app, memory footprint | Termination, footprint |
| 16 | Power | One hour, screen on and locked | Battery used, heat |
| 17 | Fallbacks | `HKWorkoutSession` with audio stopped, notification delivery timing | Alive or not, delivery error |

Test 1 decides the design. If the app does not survive the longest gap a Workout can have, this recommendation fails, including with no music playing.

## Effect on the map's decisions

1. **Interruptions: "the next one speaks normally" is not guaranteed.** Declined or ignored calls and Siri should recover if Temper is told it can. After an accepted call, Apple's archived guide says the app is suspended, so with the phone locked Cues may stay silent until the user opens Temper. Elapsed time stays correct. Suggested wording if test 7 confirms it: the next Cue speaks if iOS allows it, otherwise when Temper is next opened.
2. **Running state: this is best effort, not a guarantee.** "The timer and Cues keep working with the phone locked" rests on unpromised behaviour between Cues. Test 1 decides whether it stands.
3. **Accuracy: "each Cue within 0.25s" may need limiting to routes.** AirPlay is the clear risk, and Bluetooth is unknown.
4. **System termination is not covered.** The map covers force-quit only. iOS can also terminate the app. Decide whether a system-ended Workout also has no recovery, and whether that holds for a paused one, as a paused Temper would be allowed to suspend.
5. **Dip on by default depends on an unconfirmed mechanism.** See the Dip section above. If the toggle fails, Dip adds suspension risk in the background.

These hold: Silent mode behaviour, music never pausing (with a mixable session), Pause and Resume in front, force-quit, the free account (Background Modes is available to the free tier, [capabilities][capabilities], with ticket #5 to confirm in practice), and keeping the Lock Screen timer out of scope.

## Could not verify

- How long silence is tolerated, or whether iOS measures silence at all. Apple gives no number.
- Whether a suspended app is resumed when a call ends.
- Whether toggling `duckOthers` on an active session works.
- Whether any of the iOS 27 changes affect this. The iOS 27 release notes have no AVFAudio, AVFoundation, AlarmKit or ActivityKit section that I could find. The archived guides predate iOS 27, and the audio DTS replies are from 2020 and 2024.
- Whether `HKWorkoutSession` keeps an iPhone app running.
- Notification delivery precision and limits, and the AlarmKit alarm limit.

## Recommendation

**Use the audio background mode with a running engine for the whole Workout, and make the prototype prove it before the spec depends on it.**

1. Declare `audio` in `UIBackgroundModes`. Use `.playback` with `mixWithOthers`.
2. Activate the session and start `AVAudioEngine` on Start, in the foreground, and hold both until the Workout ends or is stopped.
3. Render Cues to buffers before the Workout, or bundle them. Schedule only the next Cue by sample time, computed from the fixed start point.
4. On Pause, stop the engine and deactivate the session. Resume is a foreground action, so restarting is safe. This avoids holding a silent session with no Cue due, at the cost of possible suspension during Pause.
5. Handle the iOS 27 lifecycle notifications, engine configuration changes and media services resets. Recompute the Phase from the clock on every wake or return to the front, and skip any Cue already due.
6. Set `isIdleTimerDisabled` while a Workout runs, re-assert it when the scene becomes active, and clear it at the end.
7. Keep memory low and do not adopt Now Playing, so that music apps keep that role.

**Do not use** AlarmKit, Live Activities, or `AVSpeechSynthesizer` running live in the background.

**Decide after ticket #9:** a single pending local notification, moved forward at each Phase change and cancelled when its Cue plays, would fire only if Temper has stopped running. It would tell the user Temper has gone quiet. Add it only if the prototype shows silent failures occur in normal use.

**If test 1 fails:** try the quiet signal, then `HKWorkoutSession`. If neither holds, the honest fallback is to run Temper in the foreground with the screen awake, and to revise the map's running-state decision.

[bg-modes]: https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
[playback]: https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback
[mix]: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers
[duck]: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/duckothers
[set-active]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)
[set-category]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:mode:options:)
[player-node]: https://developer.apple.com/documentation/avfaudio/avaudioplayernode
[play-at-time]: https://developer.apple.com/documentation/avfaudio/avaudioplayer/play(attime:)
[engine-change]: https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
[interruption-note]: https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification
[interruptions]: https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
[no-interrupt]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts(_:)
[media-reset]: https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification
[output-latency]: https://developer.apple.com/documentation/avfaudio/avaudiosession/outputlatency
[speech-write]: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write(_:tobuffercallback:)
[idle]: https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled
[bg-time]: https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time
[bg-task]: https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:)
[bg-strategies]: https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app
[bg-continued]: https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask
[live-activities]: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
[notif-schedule]: https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app
[notif-trigger]: https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger
[notif-sound]: https://developer.apple.com/documentation/usernotifications/unnotificationsound
[notif-critical]: https://developer.apple.com/documentation/usernotifications/unnotificationsound/criticalsoundnamed(_:)
[alarm-sample]: https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit
[alarm-limit]: https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmerror/maximumlimitreached
[hk-session]: https://developer.apple.com/documentation/healthkit/hkworkoutsession
[hk-running]: https://developer.apple.com/documentation/healthkit/running-workout-sessions
[capabilities]: https://developer.apple.com/help/account/reference/supported-capabilities-ios
[review]: https://developer.apple.com/app-store/review/guidelines/

[wwdc-alarm]: https://developer.apple.com/videos/play/wwdc2025/230/
[wwdc-health]: https://developer.apple.com/videos/play/wwdc2025/322/
[wwdc-live]: https://developer.apple.com/videos/play/wwdc2026/223/

[guidelines]: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioGuidelinesByAppType/AudioGuidelinesByAppType.html
[activating]: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/ConfiguringanAudioSession/ConfiguringanAudioSession.html
[arch-interruptions]: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html

[dts-limits]: https://developer.apple.com/forums/thread/685525
[dts-audio]: https://developer.apple.com/forums/thread/764096
[dts-mixable]: https://developer.apple.com/forums/thread/652395

[silent-report]: https://developer.apple.com/forums/thread/822012
[audible-quote]: https://developer.apple.com/forums/thread/106415
[speech-2015]: https://developer.apple.com/forums/thread/27097
[speech-2023]: https://developer.apple.com/forums/thread/115812
[live-report]: https://developer.apple.com/forums/thread/837360
[alarm-report]: https://developer.apple.com/forums/thread/846063
[carplay-report]: https://developer.apple.com/forums/thread/810282
[idle-report]: https://developer.apple.com/forums/thread/133512
