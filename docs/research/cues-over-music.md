# How should Cues play over music from other apps?

Research for ticket #4. Sources were read on 2026-11-01. API facts were checked against Apple's documentation and the iOS 27.2 SDK headers in Xcode 27.2.

Nothing here has been run on an iPhone. The measurements Temper needs are listed in [What must be measured](#what-must-be-measured-on-a-real-iphone).

**How claims are marked**

- **No mark, with a citation:** stated by Apple's documentation, an SDK header, a WWDC session or a technical note.
- **[Forum]:** an Apple Developer Forums post. It is a report rather than a specification. Apple staff replies are called out.
- **[Inferred]:** my reasoning from the cited facts. Apple does not state it.
- **[Unconfirmed]:** I looked and found no primary source.

## Summary

- Use the `.playback` category. Use `.mixWithOthers` when Dip is off and `.duckOthers` when Dip is on.
- Play pre-rendered PCM buffers through `AVAudioEngine`, scheduled ahead of the Phase change. Do not call `AVSpeechSynthesizer.speak(_:)` at Cue time.
- Dip conflicts with staying alive while locked. Un-ducking requires deactivating the session, and the `audio` background mode only keeps the app awake while its session is active. Dip therefore needs a session cycle around each Cue, and whether that holds on a locked phone is the main thing the prototype must establish.

## Session configuration

| Need | Setting | Source |
|---|---|---|
| Ignore Silent mode, keep playing on lock | `.playback`. Audio continues with the Silent switch set to silent or when the screen locks. | [playback][playback] |
| Keep playing in the background | Add `audio` to `UIBackgroundModes`. | [playback][playback] |
| Not `.ambient` | Screen locking and the Silent switch both silence it. | [ambient][ambient] |
| Dip off | `.mixWithOthers`. Without it, activating a `.playback` session interrupts other non-mixable audio. | [mixWithOthers][mix], [playback][playback] |
| Dip on | `.duckOthers`, which implicitly sets `mixWithOthers`. | [duckOthers][duck] |

**Mode: stay on `.default`.** `.voicePrompt` is described as being for text-to-speech prompts, and its only documented benefit is different routing on devices such as CarPlay ([voicePrompt][voiceprompt]). That has no value in a gym [Inferred]. The header also says `DuckOthers` is valid with listed categories "with `AVAudioSessionModeDefault`" (`AVAudioSessionTypes.h`). That wording may apply only to `MultiRoute`, but it is ambiguous. A forum post shows `.playback` and `.voicePrompt` with `.duckOthers` ducking successfully [Forum: [759553][f759553]].

**Do not set `.interruptSpokenAudioAndMixWithOthers` in v1.** This departs from Apple's advice, which recommends this option for exercise apps ([duckOthers][duck], [guidelines][guidelines]). Temper skips it for two reasons:

- It pauses audio from sessions in `spokenAudio` mode for as long as Temper's session is active ([option][spoken]). That conflicts with the map's "Music never pauses" and would last the whole Workout if the session stays active.
- Whether Spotify uses `spokenAudio` for any content is [Unconfirmed]. The cost of leaving it out is that a podcast mixes under a Cue instead of pausing. Dip mode lowers the podcast as well.

**Dip depth.** I found no API for setting how far other audio is lowered or how fast it fades [Unconfirmed]. Treat it as system-controlled.

## When to activate and deactivate

What Apple documents:

- Ducking begins when the session activates and ends when it deactivates. Do not use it to duck other apps for more than a few seconds ([duckOthers][duck]). The header says the same: "You will need to deactivate your audio session when you want to restore full volume" (`AVAudioSessionTypes.h`).
- For navigation and workout apps: do not activate until a prompt is needed, always deactivate after it plays, and do not try to resume an interrupted prompt ([guidelines][guidelines], updated 2017).
- `AVAudioPlayer.prepareToPlay()` activates the session, and with `duckOthers` this lowers other audio at that moment ([prepareToPlay][prepare]).
- Stop running I/O before deactivating. The [Swift documentation][setactive] says deactivating with running audio objects returns `isBusy`. The iOS 27.2 header says that since iOS 26.0 it no longer returns that error (`AVAudioSession.h`). The two disagree, so stop I/O first either way.
- `.notifyOthersOnDeactivation` lets sessions that yours *interrupted* return ([option][notify]). Avoid it when going inactive only to change preferences ([QA1631][qa1631]). Temper interrupts no one under this configuration, so the option should have no effect [Inferred]. Pass it on the final deactivation at the end of the Workout, and test whether un-ducking needs it.
- Activation is blocking and "relatively time consuming", so do not do it on a thread where that matters (`AVAudioSession.h`). iOS 27 adds asynchronous activate and deactivate calls (same header).

### The conflict: Dip against locked-phone runtime

Apple's prompt pattern leaves the session inactive between Cues. These sources suggest that takes away the only background runtime Temper has:

- Apps are normally suspended in the background, and the `audio` mode is described as "the app plays audible content in the background" ([background modes][bgmodes]).
- An Apple DTS engineer says the mode "allows your app to remain awake while your audio session is active, which isn't quite the same as guaranteeing it will not be suspended". The same engineer lists going silent for "to long" as a likely cause of suspension [Forum, Apple staff: [764096][f764096]].
- When an app is suspended, its session is deactivated, and it only learns this once it runs again ([interruptionNotification][interruption]).
- A background task is short and not a substitute: the time is finite, and exceeding it gets the app terminated ([beginBackgroundTask][bgtask]).

Navigation apps can follow Apple's pattern because location updates give them another reason to run [Inferred]. Temper has no such reason yet. Ticket #3 owns the question of background runtime, but its answer decides which Dip design works:

| Variant | How it works | Evidence | Risk |
|---|---|---|---|
| **A. Session cycle** (recommended first) | Between Cues the session is active, mixable and running. Ahead of the Cue: stop the engine, deactivate, set `.duckOthers`, activate, start the engine, schedule the Cue. After the Cue: reverse it. Hold a background task across each gap. | Every step is documented. The sequence on a locked phone is untested. | The app may suspend in a gap. Cycling happens twice per Cue. The running base state may be a silent keep-alive (see below). |
| **B. Change options while active** | Call `setCategory` with or without `.duckOthers` without deactivating. | [Unconfirmed]. Documentation ties ducking to activation, so this may do nothing. | Undocumented, but it would avoid the gap if it works. |
| **C. Separate synthesizer session** | Keep the app session mixable and never deactivate it. With Dip on, speak through `AVSpeechSynthesizer` with `usesApplicationAudioSession = false`, whose separate session mixes, ducks and manages its own active state (`AVSpeechSynthesis.h`, [WWDC20][wwdc20]). | An Apple engineer found deactivation succeeded this way [Forum, Apple staff: [759553][f759553]]. | Live synthesis latency. May use a different route (header). Whether it ignores Silent mode is [Unconfirmed]. Ducking of *other apps'* audio is stated by the header, but the WWDC talk describes only the app's own audio. |
| **D. Non-audio runtime** | If #3 finds another way to stay running, follow Apple's pattern exactly: activate per Cue. | `HKWorkoutSession` exists on iOS ([docs][hk], [WWDC25][wwdc25]), and HealthKit is available to free accounts ([capabilities][caps]). But `workout-processing` is listed for watchOS only ([background modes][bgmodes]). Whether it keeps an iPhone app running while locked is [Unconfirmed]. | Adds a HealthKit permission to an app with no health features. |

Keeping the session ducked for the whole Workout is not an option. Music would stay lowered throughout, against Apple's "few seconds" rule and the glossary's "brief lowering".

**Silent keep-alive.** Variants A and C need something holding the session up between Cues, for example a running engine with nothing scheduled.

- Apple's guidance says "use a background task instead of streaming silence" ([guidelines][guidelines], under user-controlled playback apps).
- App Review restricts background services to their intended purposes ([2.5.4][review]). Temper is not distributed through the App Store, so that rule does not block it [Inferred], but it would matter to anyone who submits a fork.
- Whether iOS tolerates a running engine that outputs silence for a long Workout is [Unconfirmed]. Ticket #3 decides this; the prototype measures it.

## AVSpeechSynthesizer against pre-rendered audio

Apple publishes no start-latency figure for any of these paths [Unconfirmed].

| | `speak(_:)` at Cue time | Rendered on device with `write`, then cached | Audio file bundled in the repo |
|---|---|---|---|
| **Start latency** | Unknown and outside Temper's control. Starts "immediately or after pausing for its `preUtteranceDelay`", and speaks through a queue ([docs][speech]). Synthesis cannot be scheduled against an audio timeline. | Best. `AVAudioPlayerNode` schedules buffers at a specific sample or host time ([docs][playernode]). `prepare()` helps the engine start responsively ([docs][engineprepare]). | Same as cached. |
| **Background reliability** | Worst. Reports of utterances stalling mid-utterance when the phone locks, despite an active session [Forum, unanswered, iOS version not stated, via a React Native wrapper: [849627][f849627]]. Reports that it activates the session but does not deactivate it, leaving others ducked, with an error on manual deactivation; an Apple engineer reproduced it [Forum: [759553][f759553]]. | Same as any buffer: no synthesis at Cue time. Renders in the foreground during setup. | Same as cached. |
| **Dip off** | With an app session: possible. With a separate session: it always ducks (header), so it cannot do Dip off. | Works. | Works. |
| **Offline** | Probably on-device for installed voices [Inferred]. `speechVoices()` returns voices "available on the device" ([docs][voices]), but a voice may not be downloaded (header). I found no statement that synthesis never uses the network [Unconfirmed]. | Fully offline after the first render. | Fully offline. |
| **Public repo** | Nothing committed. | Nothing committed. | Do not commit Apple-voice audio. The [macOS licence][slamac] limits output from System Voices to personal, non-commercial use and excludes "recording, publishing or redistribution" in a "public sharing" context. The English part of the [iOS licence][slaios] has no equivalent clause on system voices. This is my reading, not legal advice. Files generated with `say` on a Mac would be covered. |

**Choice: render on device, then cache.**

1. Render the four Cues with [`write(_:toBufferCallback:)`][write] in the foreground, for example at first launch.
2. Save them with the voice's `audioFileSettings` (`AVSpeechSynthesis.h`) and load them into `AVAudioPCMBuffer`s at Workout start.
3. Render again if the chosen voice disappears ([availableVoicesDidChange][voicechange]).

Older forum posts (2021) report format quirks with `write` output, such as 22,050 Hz mono and an unreliable reported format [Forum: [684419][f684419]]. Check this again on iOS 27. Buffers must match the node's sample rate and channels ([docs][playernode]), so connect the player through a mixer.

If rendering turns out unreliable, the fallback is a bundled recording under a clear licence, such as a CC0 voice. Avoid the owner's own voice, since this repo is public.

`AVAudioEngine` is preferred over `AVAudioPlayer`. It gives one graph, and it schedules to the sample rather than to a device clock that resets to 0 when no player is active ([deviceCurrentTime][devicetime]). Two engine hazards:

- The engine stops itself when the hardware's channel count or sample rate changes ([configuration change][engineconfig]). Restart it and schedule again.
- Do not stop a player inside its completion handler, because it can deadlock ([docs][playernode]). Hand off to another queue first.

**Meeting 0.25s.** Phase changes are known in advance, so the session work can start before the Phase change and the Cue can be scheduled for the exact moment [Inferred]. The lead time comes from measurement. A Pause during the lead window must cancel the pending Cue and end the cycle.

## How interruptions and route changes are reported

iOS 27 is the minimum, so use the new lifecycle notifications. `interruptionNotification` and its keys are deprecated as of iOS 27 (`AVAudioSessionTypes.h`). Apple says the new ones "don't get out of sync when the system can't deliver an end event" ([Handling interruptions][handling]).

| Event | Notification | Detail |
|---|---|---|
| Session inactive | `didBecomeInactiveNotification` | `DeactivationContext.source` is `.app` or `.system`. `interruptionContext.reason` is present when interrupted by another app ([docs][handling], `AVAudioSession.h`). |
| Session active | `didBecomeActiveNotification` | No payload. |
| Interruption over | `resumptionRecommendationNotification` | `.shouldResume` or `.shouldNotResume` ([docs][handling]). |
| Route change | `routeChangeNotification` | Posted on a secondary thread, with reason and previous route ([docs][route]). Lifecycle notifications arrive on the main queue. |
| Media server restart | `mediaServicesWereResetNotification` | Rebuild audio objects and session configuration ([docs][reset]). Developer settings has a menu item to trigger it. |

### Implementing the map's rules

- **A Cue comes due during a call or Siri:** skip it, and never queue it. If the session is system-inactive or activation fails at Cue time, drop that Cue and carry on. The timer does not depend on audio.
- **Do not rely on session state alone for calls.** A `.playback` session may activate while another app hosts a call ([setActive][setactive]). A Cue could therefore play during a call once activation succeeds [Inferred]. Check [`CXCallObserver`][callobserver], which any app may create, before each Cue.
- **Siri:** a forum report shows a recording session being deactivated by Siri on iOS 27.0.1 [Forum, unanswered: [852971][f852971]]. Whether Siri interrupts a *mixable playback* session is [Unconfirmed]. I found no API that reports Siri directly.
- **A Cue cut off partway:** do not resume it ([guidelines][guidelines]).
- **The next Cue speaks normally:** try activation fresh for every Cue rather than waiting for `.shouldResume`, which may never arrive or may advise against resuming [Inferred].
- **Calls and suspension:** the system deactivates sessions for calls and alarms ([guide][configuring]). If that removes the reason to run, a locked app may suspend during a long call [Inferred]. The timer will still be correct on waking, because it measures from a fixed start. But the next Cue may be missed unless the app is running by then. Apple does not say whether a suspended app is woken for `resumptionRecommendationNotification` [Unconfirmed].
- **Leave `setPrefersNoInterruptionsFromSystemAlerts` off.** It stops banner-style incoming calls interrupting the session until accepted ([docs][noalerts]), so a Cue could speak over a ringing call.
- **Media reset:** Apple says not to restart playback until the user acts ([docs][reset]). Temper should rebuild and speak the next Cue anyway, because a Workout in progress is already user-initiated [Inferred].

### Route changes

The map leaves this open, so this is a proposal:

- **Headphones disconnect:** the reason is `.oldDeviceUnavailable`. Apple's guidance to pause on disconnect is about media playback and privacy ([docs][routeguide]). Temper should keep the timer running with Cues on the new route, matching "no automatic Pause" [Inferred]. Cues may then come from the phone's speaker in a gym, so the owner should confirm this.
- **Session interruption on disconnect:** since iOS 17, only Now Playing sessions are interrupted by default (`AVAudioSession.h`). A mixable Temper session with no Now Playing info should get a route change only [Inferred].
- **Every route change:** restart the engine if it stopped, then read `outputLatency` again.

## What must be measured on a real iPhone

For ticket #9. Test with the phone in front, locked, and with another app in front, with both Spotify and Apple Music, and on the speaker and Bluetooth headphones.

Software timestamps do not include output latency, so check start time at least once acoustically, for example by recording the speaker alongside a visible Phase-change marker.

1. **Runtime with an idle session:** does the app keep running, locked, with an active mixable session and a running engine outputting silence, across a Workout of 30 minutes or more? Does it matter if samples are digital zero? This also serves #3.
2. **Variant A on a locked phone:** does the cycle complete every time? Does the app survive the gaps? How long does the cycle take (mean and worst case)? This sets the lead time.
3. **Variant B:** does changing `.duckOthers` on an active session duck and un-duck at all?
4. **Variant C:** `speak(_:)` latency from a warm and a cold synthesizer, on a locked phone. Does it duck Spotify and Apple Music? Does it ignore Silent mode? Does its output stall on lock, as reported?
5. **Variant D:** does an `HKWorkoutSession` with no active audio session keep the app running while locked? Can it then activate audio for a Cue?
6. **Cue start error:** Phase change to first audible sound, against 0.25s, with Dip on and off, across a long Workout. Report worst case as well as mean.
7. **Route latency:** does `outputLatency` match what is heard on Bluetooth? Does compensating for it bring Cues within target? Is AirPlay usable at all?
8. **Dip quality:** how deep and how fast, and does music recover fully every time without staying lowered? Does Spotify or Apple Music pause, skip or glitch? Are repeated short Workouts stable?
9. **Silent mode:** does a Cue sound with the Action button or switch set to Silent, and does it follow media volume? The map assumes it follows media volume; I found no direct statement [Unconfirmed].
10. **Interruptions while locked:** incoming call declined, call accepted, FaceTime or VoIP call, Siri, alarm. Which notifications arrive? Do they arrive while locked? Is the next Cue spoken? Is a Cue ever spoken during a call?
11. **Route changes:** Bluetooth disconnect and reconnect, mid-Workout and mid-Cue. Does the engine restart in time for the next Cue? Does a Cue play on the expected route?
12. **Media reset:** use the developer setting mid-Workout.
13. **Voice rendering:** does `write` work in airplane mode with no voices downloaded? Is its output format stable?
14. **Battery:** cost of a running engine across a one-hour Workout.

## Risks to the map's decisions

1. **"Dip on by default" with "Cues hold when locked" (highest).** They pull in opposite directions, as shown above. If no variant holds, the likely change is Dip off by default, or Dip guaranteed only while unlocked.
2. **"Each Cue starts within 0.25s".** No Apple source guarantees this. It is plausible for speaker output with scheduling ahead [Inferred]. Apple warns AirPlay can add 2 seconds ([outputLatency][latency]), and Bluetooth delay is not documented. The map should say whether 0.25s means when audio leaves Temper or when it is heard, and on which routes.
3. **"Timer and Cues keep working with the phone locked."** The supported route may be a silent keep-alive, which Apple advises against. A DTS engineer also names silence as a possible cause of suspension. This belongs to #3.
4. **"The next Cue speaks normally" after a call.** It may not hold on a locked phone if the app suspends during the call.
5. **"Music never pauses."** Temper can keep this by leaving out the spoken-audio option, against Apple's recommendation. What the other app does when ducked cannot be confirmed from Apple's documentation.

No risk found to Silent mode, the no-network rule or the no-dependency rule, subject to measurements 9 and 13.

## Recommendation

**Build the audio as follows, and let #9 confirm or eliminate the Dip variant.**

1. **Session:** `.playback`, mode `.default`, with `audio` in `UIBackgroundModes`. Dip off uses `.mixWithOthers`. Dip on uses `.duckOthers`. Leave out `.interruptSpokenAudioAndMixWithOthers`.
2. **Cue audio:** render the four Cues on device with `AVSpeechSynthesizer.write`, cache them, and play them as buffers through `AVAudioEngine` and `AVAudioPlayerNode`, scheduled for the Phase change. Do not commit Apple-voice audio. Do not use `speak(_:)` at Cue time, except as variant C.
3. **Dip:** try variant A first (session cycle ahead of each Cue, with a background task over the gaps), because every step is documented and start time stays under Temper's control. If it fails on a locked phone, try C, then B. If #3 finds non-audio runtime, D replaces them all.
4. **Interruptions:** use the iOS 27 lifecycle notifications and `routeChangeNotification`, gate each Cue on session state and `CXCallObserver`, skip rather than queue, and retry activation fresh for every Cue.
5. **If no Dip variant holds when locked:** keep Cues and drop or reduce Dip, because the map's Cue and locked-phone requirements matter more than Dip. Default it to off, or limit it to when the phone is unlocked. That decision is the owner's.

[playback]: https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback
[ambient]: https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient
[mix]: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers
[duck]: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/duckothers
[spoken]: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/interruptspokenaudioandmixwithothers
[voiceprompt]: https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voiceprompt
[guidelines]: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioGuidelinesByAppType/AudioGuidelinesByAppType.html
[configuring]: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/ConfiguringanAudioSession/ConfiguringanAudioSession.html
[prepare]: https://developer.apple.com/documentation/avfaudio/avaudioplayer/preparetoplay()
[setactive]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)
[notify]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setactiveoptions/notifyothersondeactivation
[qa1631]: https://developer.apple.com/library/archive/qa/qa1631/_index.html
[bgmodes]: https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
[interruption]: https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification
[bgtask]: https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:)
[hk]: https://developer.apple.com/documentation/healthkit/hkworkoutsession
[wwdc25]: https://developer.apple.com/videos/play/wwdc2025/322/
[wwdc20]: https://developer.apple.com/videos/play/wwdc2020/10022/
[caps]: https://developer.apple.com/help/account/reference/supported-capabilities-ios
[review]: https://developer.apple.com/app-store/review/guidelines/
[speech]: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer
[write]: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write(_:tobuffercallback:)
[voices]: https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/speechvoices()
[voicechange]: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/availablevoicesdidchangenotification
[playernode]: https://developer.apple.com/documentation/avfaudio/avaudioplayernode
[engineprepare]: https://developer.apple.com/documentation/avfaudio/avaudioengine/prepare()
[engineconfig]: https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
[devicetime]: https://developer.apple.com/documentation/avfaudio/avaudioplayer/devicecurrenttime
[handling]: https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
[route]: https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification
[routeguide]: https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes
[reset]: https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification
[callobserver]: https://developer.apple.com/documentation/callkit/cxcallobserver
[noalerts]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts(_:)
[latency]: https://developer.apple.com/documentation/avfaudio/avaudiosession/outputlatency
[slamac]: https://www.apple.com/legal/sla/docs/macOS27.pdf
[slaios]: https://www.apple.com/legal/sla/docs/iOS27_iPadOS27.pdf
[f759553]: https://developer.apple.com/forums/thread/759553
[f764096]: https://developer.apple.com/forums/thread/764096
[f849627]: https://developer.apple.com/forums/thread/849627
[f852971]: https://developer.apple.com/forums/thread/852971
[f684419]: https://developer.apple.com/forums/thread/684419
