# PROTOTYPE: every Watch screen

Throwaway. It lives only on the `prototype/watch-running-screen` branch and is never merged. It answers
[How should each of the Watch's screens look, and which heart-rate reading goes in the slot?](https://github.com/igorxciv/temper/issues/111)

It started as the prototype for [How should the Watch running screen look: a large tap target or tap-anywhere?](https://github.com/igorxciv/temper/issues/76). Variant A won there, so the running screen here is A only. B, C and the Crown turn are in this branch's history at `ec745ac`.

## Verdict

The owner picked on 2026-11-08, from the snapshot sheets: **H3** bpm with the five-bar zone meter, **D2** the mark replaces the line, **P1** two wide buttons, **S2** tap Stop again, **L1** the message only, and **C2** with average and max heart rate. The wording stays as prototyped. The app opens with these picks.

## What's in it

Every screen from "Start on iPhone" to the complete screen, with a pick wherever the map left a choice:

| Screen | Fixed | Variants |
| --- | --- | --- |
| Idle | "Start on iPhone" | none |
| Waiting, from `handle(_:)` to the iPhone's first message | "Connecting to iPhone" | none |
| Running, per Workout Type and Phase | #76's variant A | **Heart rate:** H1 bpm only, H2 bpm + zone number, H3 bpm + zone meter |
| Dropout | time held at what it last heard, 00:00 at most; controls dimmed in place | **D1** the mark replaces the Phase name, **D2** the mark replaces the line |
| Secondary page, a swipe right | Pause or Resume, and Stop | **P1** two wide buttons, **P2** two round buttons |
| Stop's confirmation | | **S1** "End this Workout?" dialog, **S2** tap again within 3 s |
| Late Watch | "Running on iPhone", no controls, no heart rate | **L1** message only, **L2** message and the time, read-only |
| Complete | the iPhone's complete screen shrunk; Done goes back to idle | **C1** as the iPhone, **C2** plus average and max heart rate |

The zone uses heart-rate reserve at 60, 70, 80 and 90%, with a stand-in maximum of 186 and resting rate of 58. On a real Watch Temper would have to find both itself, because watchOS 27's zone APIs don't run on a Series 8.

## Look at the snapshots

`Snapshots/Output/` has two sheets per Series 8 size:

- `watch-running-*.png`: every Workout Type and Phase against H1, H2 and H3, and H3 in Always On
- `watch-screens-*.png`: every other screen and variant

Regenerate them with:

```sh
swift run --package-path Prototypes/WatchRunningScreen Snapshots Prototypes/WatchRunningScreen/Snapshots/Output
```

macOS draws SF Pro where the Watch uses SF Compact, and the clock and corner radius are approximate, so trust the Watch over the snapshots. The complete screens show only the first screenful, because a snapshot can't scroll.

## Run it on the Series 8

Xcode 27.2 runs a Watch app on the Series 8 directly ([#101](https://github.com/igorxciv/temper/issues/101)).

1. Make sure `Config/Local.xcconfig` exists in this checkout. The prototype reads `DEVELOPMENT_TEAM` and `BUNDLE_ID_PREFIX` from it.
2. Open `Prototypes/WatchRunningScreen/WatchRunningPrototype.xcodeproj`, pick the **WatchRunningPrototype** scheme with the Watch as the destination, and Run. The **PrototypeHost** scheme, which carries the Watch app through the iPhone, still works as a fallback.
3. On the Watch, set Settings → General → Return to Clock → Temper Proto → After 1 hour. The prototype has no workout session, so it would otherwise drop to the watch face after 2 minutes, and Always On updates only once a minute.

On the Watch, the last page (swipe left) holds the prototype's controls:

- **iPhone:** pick the Workout Type, then **Start, in time** (waiting, then the running screen) or **Start, Watch late** (waiting, then "Running on iPhone"). **Connected** off starts a dropout. **Stop** stands in for Stop on the iPhone.
- **Jump into a run:** go straight to Prepare, Work, Rest, Cooldown or Paused.
- **Variants:** every pick in the table above, and Force Always On.

While a Workout runs, swipe right for the secondary page. The clock stands in for the iPhone engine: Intervals is a 0:10 Prepare, eight Rounds of 0:40 Work and 0:20 Rest, and a 1:00 Cooldown. Stopwatch is a 0:10 Prepare and a 5:00 Work. Open Rounds has a 1:00 Rest after each Done. A tap that does nothing gives a failure haptic.

## What to judge

- Which heart-rate slot do you read at arm's length mid-set: the bpm alone, or a zone beside it? If a zone, the number or the meter?
- During a dropout, is "iPhone not connected" obvious without hiding the Phase or the heart rate?
- Secondary page: wide buttons or round ones? Is Stop far enough from Pause?
- Stop: a dialog, or tap again?
- A late Watch: a message, or the time without controls?
- Complete: is heart rate worth a line there, given the iPhone's complete screen leaves it out?
- Idle, waiting and "Running on iPhone": is the wording right?
