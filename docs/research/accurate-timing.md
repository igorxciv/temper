# How should Temper keep accurate time on iOS?

Research for ticket #2. Sources checked 2026-11-01 against the iOS 27.2 SDK in Xcode 27.2 and Swift 6.4.2.

## Answer

Compute the time, never count it. At the start of a Workout, turn the Phases into fixed offsets from one starting instant. Read `ContinuousClock.now` whenever the answer is needed, and derive the Phase and the time left from it. Wake for each Phase change with `clock.sleep(until: boundary, tolerance: .milliseconds(10))`, off the main actor. The display only reads the same derived value.

The trap that matters most: **`Task.sleep` with no tolerance is not safe for this job.** A 90 s sleep with the default tolerance woke 5 to 6 s late on a Mac, and the code path permits up to 9 s. See [Sleep tolerance](#sleep-tolerance-the-least-obvious-trap).

## How to read the evidence

Each claim carries one of these labels:

- **[Source]** Stated by a primary source, linked in [Sources](#sources).
- **[Mac]** Measured on an Apple silicon MacBook Pro on AC power with `caffeinate -i`, macOS 27, Swift 6.4.2, in optimized builds. Several experiments ran at once, so timers in separate processes could interact. **None of these are iPhone results.** iOS uses the same clock and Dispatch interfaces, but its power policy can differ.
- **[Inferred]** My conclusion from the above, not stated by a source.
- **[Unverified]** Could not be confirmed here. See [What is not verified](#what-is-not-verified).

The Swift and libdispatch sources are open-source `main` at the commits pinned below. The binaries that ship in iOS 27 may differ, and no source says they match. The [Mac] results fit the source, which is supporting evidence and not proof.

## Which API does what

| API | Role in Temper | Reason |
|---|---|---|
| `ContinuousClock` | **The only source of truth for elapsed time** | Keeps counting while the system sleeps [S1]. On Apple platforms it reads `CLOCK_MONOTONIC_RAW` [S3], which is unaffected by frequency or time adjustments [S10]. |
| `SuspendingClock` | Do not use | Stops while the system sleeps [S2], because it reads `CLOCK_UPTIME_RAW` [S3][S10]. Phases would silently stretch by the sleep time. |
| `Clock.sleep(until:tolerance:)` | **Schedules the wake for each Phase change** | The deadline is absolute. Tolerance is the maximum delay allowed after it [S7]. |
| `Timer` | Do not use for timing | "Not a real-time mechanism". It runs on a run loop and can fire "significantly later" [S11]. |
| `DispatchSourceTimer` | Fallback only (see [Accuracy target](#is-the-accuracy-target-achievable)) | A `DispatchTime` deadline uses up time and does not count sleep. A `DispatchWallTime` deadline uses `gettimeofday` and follows clock changes [S12][S13]. The public headers offer no continuous-time deadline [Inferred from S12]. |
| `CADisplayLink` | Do not use | Synchronizes drawing to the display [S14]. It has no role in logic. Apple's page does not say what it does when the screen is off, but a callback tied to screen updates should not be relied on when locked [Inferred]. |
| `TimelineView` | **Trigger for repainting the visible number only** | Redraws "at scheduled points in time", and the system may use a slower cadence than the schedule [S15]. Its schedules and `context.date` are `Date` based [S16]. |
| `Date` | Do not use for elapsed time | The wall clock can be changed [S17]. Fine for "when did this Workout happen", which v1 does not need. |
| `Text(timerInterval:)`, `Text(_, style: .timer)` | Do not use | Both take `Date` values [S16], so they run on a second clock that could disagree with the engine. Their rounding is not documented on the pages I read. |

Other uptime clocks fail the same way as `SuspendingClock`: `DispatchTime`, `CACurrentMediaTime()`, `mach_absolute_time()` and `ProcessInfo.systemUptime` [S12][S18][S19][S20].

**[Mac] Clock census.** I read every clock once on a Mac that had slept since boot, without putting it to sleep:

| Clocks | Reading |
|---|---|
| `ContinuousClock.now`, `CLOCK_MONOTONIC_RAW`, `mach_continuous_time` | 1,898,653.560 s |
| `CLOCK_MONOTONIC`, wall time since `kern.boottime` | 1,898,643.706 s |
| `SuspendingClock.now`, `CLOCK_UPTIME_RAW`, `mach_absolute_time`, `DispatchTime.now`, `systemUptime`, `CACurrentMediaTime` | 768,615.113 s |

The gap of 1,130,038 s between the first and third rows is sleep that the uptime family never counted. That confirms the grouping above, but it is a reading of the clocks. I did not run a timer across a real sleep. The 9.85 s between rows one and two is about 5 parts per million over those 22 days. Over a 90 s Phase that is about 0.5 ms, so oscillator error is negligible for Temper [Inferred]. Apple publishes no oscillator accuracy figure that I could find.

## Sleep tolerance: the least obvious trap

**[Source]** When tolerance is `nil`, the Swift runtime calls `dispatch_after_f`. With an explicit tolerance, it creates a one-shot dispatch timer using that value as leeway [S4]. libdispatch's `dispatch_after` sets leeway to one tenth of the delay, between 1 ms and 60 s, and makes `target + leeway` the deadline [S5]. So a 90 s nil-tolerance sleep may fire up to 9 s late. SE-0329 and Apple's `Clock` page only say a nil tolerance leaves the choice to the clock [S7][S8], so this behaviour is not a documented guarantee in either direction.

`Task.sleep(for:)` and `Task.sleep(until:)` default to `tolerance: nil` and forward to the clock [S6].

**[Mac]** How late `ContinuousClock.sleep(until:tolerance:)` woke, off the main actor:

| Delay | Tolerance | Samples | Min | Median | Max |
|---|---|---:|---:|---:|---:|
| 1 s | nil | 60 | 0.8 ms | 10 ms | 67 ms |
| 1 s | 0 | 60 | 0.3 ms | 8 ms | 10 ms |
| 10 s | nil | 12 | 229 ms | 502 ms | 644 ms |
| 10 s | 0 | 12 | 0.4 ms | 6 ms | 12 ms |
| 10 s | 10 ms | 12 | 0.3 ms | 6 ms | 11 ms |
| 10 s | 50 ms | 12 | 1.9 ms | 44 ms | 50 ms |
| 30 s | nil | 6 | 383 ms | 1,812 ms | 1,974 ms |
| 30 s | 50 ms | 6 | 8 ms | 25 ms | 50 ms |
| 90 s | nil | 3 | 5,905 ms | 5,906 ms | 5,963 ms |
| 90 s | nil (second run) | 2 | 4,993 ms | n/a | 5,869 ms |
| 90 s | 50 ms | 3 | 10 ms | 35 ms | 49 ms |
| 90 s | 10 ms | 2 | 8 ms | n/a | 9 ms |

No sleep woke early. The late wakes used most of whatever tolerance was allowed, and lateness grew with the delay when tolerance was nil. Sample counts at 30 s and 90 s are small.

**[Mac] Why this bug hides.** In a 90 s run with nine timers in one process, a nil-tolerance sleep landed only 10 ms late. So I ran 60 s nil-tolerance sleeps both ways:

| Setup | Late by (two runs) |
|---|---|
| Alone in the process | 3,083 ms, 3,976 ms |
| With a 10 ms tolerance sleep to the same deadline | 11 ms, 9 ms |

The likely cause is that the sleep fires when another timer wakes the process inside its window [Inferred, consistent with S9 and S21]. A nil-tolerance implementation can therefore pass while UI or logging timers are active and fail in a quiet locked app. That is exactly the state Temper cares about [Inferred].

## Common wrong implementations

"Late" is the error when each implementation believed a 90 s countdown had ended.

| Wrong implementation | Why it fails | Evidence, 90 s |
|---|---|---|
| Repeating `Timer`, counting ticks | Firings during a stall are dropped, not caught up [S11]. Each dropped tick adds a full tick of error. | [Mac] 8 ms late when idle, **2.0 s late** with three 1.5 s main-thread stalls |
| 10 Hz `Timer`, counting tenths | Same, and more ticks to lose | [Mac] 10 ms late when idle, **4.2 s late** with stalls |
| Repeating `DispatchSourceTimer`, counting ticks | Same failure when its queue is blocked. A `deadline:` schedule also does not count sleep [S13]. | [Mac] 10 ms late when idle, **2.0 s late** with stalls |
| `Task.sleep(for: .seconds(1))` loop, counting | Each sleep starts from the moment the last one woke [S22], so lateness adds up | [Mac] **2.8 s late** off main, **7.6 s late** on the main actor with stalls |
| One `Task.sleep(for: phaseLength)` | Nil tolerance, as above. Also starts from a new "now". | [Mac] 5 to 6 s late when alone |
| Wall clock: `Date()` start and subtraction | The system clock can be changed by the user or by `settimeofday` [S17], and a Phase would jump by that amount. A time zone change is harmless, because `Date` is independent of time zone [S23]. | Not run: changing the clock needs root and would disturb this machine |
| `SuspendingClock`, `DispatchTime`, `CACurrentMediaTime`, `systemUptime` | Do not count device sleep [S2][S12][S18][S20] | [Mac] Census above. No real sleep run. |
| Engine on the main actor | Any main-thread stall delays the Phase change | [Mac] A 1.5 s stall across the deadline made a `@MainActor` sleep **1,481 ms late** and a main `Timer` **1,480 ms late**, while an off-main sleep in the same process was 10 ms late |
| `remaining -= 0.1` with `Double` | Floating-point error | [Mac] 0.1 added 900 times gives 89.999999999999. `Duration` gives exactly 90.0. |
| Deriving logic from `TimelineView` or `CADisplayLink` | Callbacks serve drawing and may slow down [S14][S15]. No screen means no reason to call them [Inferred]. | Not run |
| Assuming any of these run in the background | Apps are typically suspended in the background unless a background mode applies [S24]. No clock can run code in a suspended process [Inferred]. | Ticket #3 owns this |
| Restarting a Phase with its full length, or the rounded on-screen value, after Pause | Loses or adds up to a second, against the map's "exact time left" | Logic error |

A fair point for `Timer`: without stalls, a repeating `Timer` does not drift, because it schedules from the original fire date [S11]. A 20 Hz `Timer` comparing the clock to a fixed deadline stayed within 10 ms in my no-stall and away-from-deadline runs. Its failure is that it depends on the main run loop, not that it drifts.

## The correct design

1. **One fixed schedule.** Pure data: Phases and their cumulative end offsets as `Duration`. `Duration` is integral, not floating point [S25].
2. **Active time, derived.** `active = anchor.duration(to: now)`, or a frozen value while paused.
3. **Position, derived.** A pure function of active time gives the Phase and the time left.
4. **Wake off the main actor** for the next boundary, with a 10 ms tolerance. On each wake, re-read the clock and re-derive the position. Never advance by "one Phase" because a sleep returned, as a late wake may have crossed several boundaries.
5. **Never anchor to a wake time.** The next boundary comes from the schedule, so a late wake delays one event and cannot accumulate. [Mac] A prototype on a manual clock, made to wake 37 ms late at every boundary, ended each Phase at its exact offset plus 37 ms, with no growth over five Phases. This checks the logic, not real wake times.

```swift
struct Timeline {
    let boundaries: [Duration]              // cumulative Phase ends
    func position(at active: Duration) -> (index: Int, remaining: Duration)? {
        for (index, end) in boundaries.enumerated() where active < end {
            return (index, end - active)
        }
        return nil                          // Workout complete
    }
}

struct ActiveTime<I: InstantProtocol> where I.Duration == Duration {
    private(set) var anchor: I              // instant at which active time was zero
    private(set) var frozen: Duration?      // set only while paused

    func value(at now: I) -> Duration { frozen ?? anchor.duration(to: now) }
    mutating func pause(at now: I) { if frozen == nil { frozen = anchor.duration(to: now) } }
    mutating func resume(at now: I) {
        guard let frozen else { return }
        anchor = now.advanced(by: .zero - frozen)
        self.frozen = nil
    }
}
```

This is design guidance, not a final API. Ticket #10 owns the engine design. The `Timeline` and `ActiveTime` logic above ran in the Mac prototype, with `ActiveTime` under a slightly different name.

### Pause

Pause freezes active time and Resume moves the anchor, as above. That excludes exactly the paused span, keeps the time left to the clock's resolution, and leaves later boundaries correct with no separate "paused total" to maintain. The Mac prototype checked this: pausing at 25 s for 1,000 s and resuming left exactly 75 s of a 90 s Work.

These rules are my judgement [Inferred]:

- Read `now` once per event, and use that same value for both settling due boundaries and applying the Pause.
- If Pause arrives after a boundary has passed but before the wake ran, apply the Phase change first, then pause.
- Pause cancels the pending sleep and any scheduled Cue. Resume arms new ones. The prototype's driver polled while paused, so **cancellation was not tested**.

### Rounding on screen

Show `ceil(remaining)` in whole seconds, using integer components rather than `Double`:

```swift
let (seconds, attoseconds) = remaining.components
let shown = seconds + (attoseconds > 0 ? 1 : 0)
```

Choosing ceiling is a design judgement, since no Apple source prescribes one [Inferred]. Each number is then on screen for one full second. A 90 s Phase opens on 90, the number changes on exact seconds, the last second shows 1, and the next Phase takes over where 0 would have appeared.

Do not use the default format for this. [Mac] `Duration.formatted(.time(pattern: .minuteSecond))` rounds to nearest, even on ties, so 0.5 s and 0.4 s show `0:00` while time remains, and 89.5 s shows `1:30`. Passing `roundFractionalSeconds: .up` gives ceiling results for formatted strings: 89.4 s shows `01:30` and 0.001 s shows `00:01`.

While paused, show the same ceiling value. The stored time left keeps its full precision, so the display never feeds back into timing.

For the display trigger, use `TimelineView(.animation(minimumInterval: 0.05, paused: isPaused))` and read `ContinuousClock.now` inside it, ignoring `context.date`. The schedule updates "no more quickly than the provided interval" [S26]. The interval is my judgement, and this view was not run on a device. A `.periodic` schedule would need a `Date` anchor aligned to the engine's clock, which brings back the two-clocks problem [Inferred].

### Testing without waiting

Three layers, none needing a third-party dependency:

1. **Pure logic with no clock.** `Timeline.position(at:)`, `ActiveTime` and the rounding function take plain values. Test boundaries directly, including one nanosecond either side.
2. **The driver, generic over `Clock`,** with a test-only manual clock. `Clock` needs only `now`, `minimumResolution` and `sleep(until:tolerance:)` [S7]. [Mac] A prototype ran a simulated 280 s Workout in **0.015 s**, including late wakes.
3. **A short real-clock smoke test,** plus device measurement in ticket #9. This is the only layer that can test the actual accuracy.

Details that matter:

- Use `<C: Clock> where C.Duration == Duration`, not `any Clock<Duration>`. [Mac, Swift 6 mode] `sleep(for:)` compiles on the existential, as SE-0374 intended [S27], but `sleep(until:tolerance:)` does not: "member 'sleep' cannot be used on value of type 'any Clock<Duration>'". And `sleep(for:)` is implemented as `now + duration` [S22], which is the relative scheduling this design avoids.
- A manual clock's advance must wait until the code under test has registered its sleep, or the test races. My prototype polled for this, and real tests should wait on a signal instead.
- The default executor calls `fatalError` for unknown clock types [S28], so a manual clock must implement `sleep` itself with continuations, not by enqueueing on a deadline.

## Is the accuracy target achievable?

The map says each Phase ends within 0.1 s, each Cue starts within 0.25 s, and both hold when locked or backgrounded.

**Phase, 0.1 s: plausible, keep it, and verify it on an iPhone.** With a 10 ms tolerance off the main actor, the worst wake measured on the Mac was 12 ms, and error cannot accumulate by construction. Two limits apply:

- It cannot be a hard guarantee. Apple says the system "cannot guarantee exact firing times" and may add a small tolerance by itself [S21]. App code here has no documented real-time bound [Inferred].
- Locked behaviour is the real risk. The Dispatch header says the system's lower limit on timer delay "may vary with process state such as visibility of application UI" [S9]. So a locked iPhone could wake later than the Mac did, and these Mac results cannot rule that out.

If ticket #9 shows late wakes when locked, try these in order:

1. Schedule the Cue ahead of time on the audio timeline (below), which removes thread wake time from the Cue path [Inferred].
2. Use `DispatchSourceTimer` with `.strict`, which asks the system to honour small leeway at a stated power cost [S9]. Its deadlines use up time, so compute each one from the `ContinuousClock` time left and re-arm it often [Inferred].

**Cue, 0.25 s: not achievable as written on every audio route.** Apple says AirPlay output "can result in a 2-second delay" [S29]. Bluetooth latency is route dependent and I found no Apple figure for it. `AVAudioSession.outputLatency` reports latency [S29], but I could not check how accurately it does so for Bluetooth. Calling `AVSpeechSynthesizer.speak` also has no documented start latency [S30], so ticket #4 should measure it.

A better path to investigate in tickets #4 and #10: render each Cue ahead of time with `write(_:toBufferCallback:)` [S31], and schedule it on an `AVAudioPlayerNode` with an `AVAudioTime` [S32]. Host time there is `mach_absolute_time()` [S33], which does not count sleep. So compute the host time from the time left just before scheduling, keep the lead short, and cancel on Pause [Inferred]. This is untested here.

**"Both hold when locked": conditional.** It depends on ticket #3 keeping the process running. Apps are typically suspended in the background [S24]. If Temper is ever suspended, no Phase change or Cue fires on time. On resume, the design still computes the right position, because `ContinuousClock` counts through the gap [Inferred], and overdue Cues should be skipped, matching the map's rule for interruptions.

### Suggested revision to the map's target

> Each Phase change happens within 0.1 s of its scheduled instant, measured with `ContinuousClock` from the fixed start, excluding only Pause time. A late Phase change never moves later Phases. Each Cue reaches the audio system within 0.25 s of the Phase change, and is audible within 0.25 s on the built-in speaker and wired output. On wireless routes the Cue starts earlier by the reported `outputLatency` where possible, best effort. AirPlay is excluded. Both hold when locked or backgrounded as long as the process is running. These are targets verified by measurement on a device in ticket #9, not guarantees from iOS.

## What is not verified

- **Nothing here ran on an iPhone.** Locked and backgrounded wake lateness, the main question, is for ticket #9.
- **Timers across real device sleep.** I did not sleep this Mac. The source says a `ContinuousClock` sleep uses a continuous-time deadline [S4][S34], and the census shows the clocks diverge, but nothing shows that a sleeping iPhone wakes for such a deadline. No source I found says so. Do not assume it. An active audio session may keep the device from sleeping fully, but that too is unconfirmed [Inferred].
- **Wall-clock jumps** were not run. That claim rests on documentation [S17].
- **Shipping binaries.** libdispatch and Swift source are open-source `main`, not the code in iOS 27. In particular, the 10 percent leeway is confirmed in source, and the lateness measured fits it, but only on a Mac.
- **`TimelineView`, `CADisplayLink` and `Text` timers** were not run. Apple's pages do not state their behaviour when the screen is off, or the rounding of `Text` timers.
- **Why nil tolerance used about 5 to 7 percent** of the delay at 60 s and 90 s rather than the full 10 percent. I did not investigate this, and samples are small.
- **Power cost** of a 10 ms tolerance was not measured. Temper only wakes at Phase boundaries plus display updates while the screen is on, so I expect it to be small [Inferred].
- **WWDC.** I found no session that addresses these questions directly. The TimelineView passages in WWDC21 "What's new in SwiftUI" do not cover timing guarantees, and I read only the first part of that transcript.
- **Privacy manifest.** `systemUptime` and `mach_absolute_time` are required-reason APIs [S19][S20]. Whether that applies to `ContinuousClock` or to this personal install path was not checked. If the audio path computes host times directly, ticket #12 should look at it.

## Recommendation

1. **`ContinuousClock` is the only time source.** No other clock feeds any logic.
2. **Fix all Phase boundaries as offsets from one start instant**, and derive the Phase and time left from `now`. Never count ticks, and never decrement.
3. **Always pass an explicit tolerance:** `clock.sleep(until: boundary, tolerance: .milliseconds(10))`. Treat a nil-tolerance sleep in the engine as a bug. Re-derive the position after every wake.
4. **Run the engine off the main actor.** The UI observes it.
5. **Pause freezes active time, and Resume moves the anchor.**
6. **Display `ceil(remaining)` in whole seconds**, repainted by `TimelineView(.animation(minimumInterval: 0.05, paused:))` reading the engine's value. The display drives nothing.
7. **Keep the core pure and the driver generic over `Clock`**, tested with a manual clock in the test target.
8. **Have ticket #9 measure, on a locked iPhone,** the wake lateness of this exact design, including a run with no other timers active, since those can hide lateness. Have ticket #4 measure Cue start latency per route.
9. **Revise the accuracy target** as suggested above.

## Sources

Apple documentation pages were read through their DocC JSON. Header references are to the iPhoneOS27.2 SDK, under `usr/include/`.

Pinned source commits: Swift `2b0c27d`, libdispatch `2078b9d`, Swift Evolution `0bc0e34`.

- [S1] [ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock), Apple
- [S2] [SuspendingClock](https://developer.apple.com/documentation/swift/suspendingclock), Apple
- [S3] [Clock.cpp, Apple clock IDs](https://github.com/swiftlang/swift/blob/2b0c27dbdd76ed8b7b5b82bc52980f13bcb8a85d/stdlib/public/Concurrency/Clock.cpp#L56-L57), lines 56-57 and 89-90
- [S4] [DispatchGlobalExecutor.cpp, `swift_dispatchEnqueueWithDeadline`](https://github.com/swiftlang/swift/blob/2b0c27dbdd76ed8b7b5b82bc52980f13bcb8a85d/stdlib/public/Concurrency/DispatchGlobalExecutor.cpp#L288-L343), and clock mapping at lines 259-285
- [S5] [libdispatch source.c, `_dispatch_after`](https://github.com/swiftlang/swift-corelibs-libdispatch/blob/2078b9d4a2853b8b07a61e3d460e9dfd9d3c3454/src/source.c#L1345-L1374), lines 1345-1348 and 1374
- [S6] [TaskSleepDuration.swift](https://github.com/swiftlang/swift/blob/2b0c27dbdd76ed8b7b5b82bc52980f13bcb8a85d/stdlib/public/Concurrency/TaskSleepDuration.swift#L221-L246), lines 221-246
- [S7] [SE-0329: Clock, Instant, and Duration](https://github.com/swiftlang/swift-evolution/blob/0bc0e34e392763bc93fd224ee67859a58e9805cd/proposals/0329-clock-instant-duration.md)
- [S8] [Clock](https://developer.apple.com/documentation/swift/clock), Apple
- [S9] `dispatch/source.h`, `DISPATCH_TIMER_STRICT` (line 343 and the comment above it) and `dispatch_source_set_timer` (from line 699), iOS SDK; [`strict`](https://developer.apple.com/documentation/dispatch/dispatchsource/timerflags/strict), Apple
- [S10] `clock_gettime(3)` man page, macOS 27
- [S11] [Timer](https://developer.apple.com/documentation/foundation/timer), Apple
- [S12] `dispatch/time.h`, iOS SDK; [DispatchTime](https://developer.apple.com/documentation/dispatch/dispatchtime), Apple
- [S13] `dispatch/source.h`, `dispatch_source_set_timer` (from line 716), iOS SDK; [DispatchWallTime](https://developer.apple.com/documentation/dispatch/dispatchwalltime), Apple
- [S14] [CADisplayLink](https://developer.apple.com/documentation/quartzcore/cadisplaylink), Apple
- [S15] [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview), Apple
- [S16] SwiftUI and SwiftUICore `.swiftinterface`, iOS SDK: `TimelineView.Context.date`, `Text.init(timerInterval:pauseTime:countsDown:showsHours:)`; [Text.DateStyle.timer](https://developer.apple.com/documentation/swiftui/text/datestyle/timer), Apple
- [S17] [NSSystemClockDidChange](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nssystemclockdidchange), Apple; `clock_gettime(3)`: `CLOCK_REALTIME` is the wall clock and can be set
- [S18] [CACurrentMediaTime()](https://developer.apple.com/documentation/quartzcore/cacurrentmediatime()), Apple
- [S19] [mach_absolute_time](https://developer.apple.com/documentation/kernel/1462446-mach_absolute_time), Apple
- [S20] [systemUptime](https://developer.apple.com/documentation/foundation/processinfo/systemuptime), Apple
- [S21] [Energy Efficiency Guide for iOS Apps: Minimize Timer Use](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/MinimizeTimerUse.html), Apple (archived, older guidance)
- [S22] [Clock.swift, `sleep(for:tolerance:)`](https://github.com/swiftlang/swift/blob/2b0c27dbdd76ed8b7b5b82bc52980f13bcb8a85d/stdlib/public/Concurrency/Clock.swift#L120-L125), lines 120-125
- [S23] [Date](https://developer.apple.com/documentation/foundation/date), Apple
- [S24] [Configuring background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes), Apple
- [S25] [Duration](https://developer.apple.com/documentation/swift/duration), Apple
- [S26] [animation(minimumInterval:paused:)](https://developer.apple.com/documentation/swiftui/timelineschedule/animation(minimuminterval:paused:)), Apple
- [S27] [SE-0374: Add sleep(for:) to Clock](https://github.com/swiftlang/swift-evolution/blob/0bc0e34e392763bc93fd224ee67859a58e9805cd/proposals/0374-clock-sleep-for.md)
- [S28] [DispatchExecutor.swift](https://github.com/swiftlang/swift/blob/2b0c27dbdd76ed8b7b5b82bc52980f13bcb8a85d/stdlib/public/Concurrency/DispatchExecutor.swift), `_dispatchEnqueue`
- [S29] [outputLatency](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputlatency), Apple
- [S30] [speak(_:)](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/speak(_:)), Apple
- [S31] [write(_:toBufferCallback:)](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write(_:tobuffercallback:)), Apple
- [S32] [AVAudioPlayerNode](https://developer.apple.com/documentation/avfaudio/avaudioplayernode), Apple
- [S33] [AVAudioTime](https://developer.apple.com/documentation/avfaudio/avaudiotime), Apple
- [S34] [libdispatch shims/time.h, `_dispatch_time_to_clock_and_value`](https://github.com/swiftlang/swift-corelibs-libdispatch/blob/2078b9d4a2853b8b07a61e3d460e9dfd9d3c3454/src/shims/time.h#L257-L269), lines 257-269
