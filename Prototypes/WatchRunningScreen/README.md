# PROTOTYPE: Watch running screen

Throwaway. It lives only on the `prototype/watch-running-screen` branch and is never merged. It answers
[How should the Watch running screen look: a large tap target or tap-anywhere?](https://github.com/igorxciv/temper/issues/76)

Three variants, from the smallest target to the whole screen:

- **A · Large button:** the iPhone layout shrunk, with one full-width capsule about 56 pt tall at the bottom. Taps above it do nothing.
- **B · Half-screen band:** information in the top half and the bottom half of the glass, edge to edge, as the button.
- **C · Tap anywhere:** no button. The time is about 40% bigger, progress runs around the screen's edge, and a hint at the bottom says what a tap does.

Each one covers an Open Rounds Work, an Open Rounds Rest (Done dimmed in place), and an Intervals Work (Pause and Resume), awake and Always On, with a slot kept for heart rate.

## Look at the snapshots

`Snapshots/Output/watch-running-45mm.png` and `watch-running-41mm.png` put all three side by side at Series 8 sizes. Regenerate them with:

```sh
swift run --package-path Prototypes/WatchRunningScreen Snapshots Prototypes/WatchRunningScreen/Snapshots/Output
```

macOS draws SF Pro where the Watch uses SF Compact, and the clock and corner radius are approximate, so trust the Watch over the snapshots.

## Run it on the Series 8

No watchOS Simulator runtime is installed, and only the wrist answers "can I hit it mid-set without looking".

1. Make sure `Config/Local.xcconfig` exists in this checkout. The prototype reads `DEVELOPMENT_TEAM` and `BUNDLE_ID_PREFIX` from it.
2. Open `Prototypes/WatchRunningScreen/WatchRunningPrototype.xcodeproj`, pick the Watch as the destination, and Run. The app is watch-only and appears as "Temper Proto".
3. On the Watch, set Settings → General → Return to Clock → Temper Proto → After 1 hour. The prototype has no workout session, so it would otherwise drop to the watch face after 2 minutes, and Always On updates only once a minute.

On the Watch:

- **Middle page:** the running screen. The quick action works by tap, or by a firm Crown turn with a meter beside the Crown. One turn fires once, and the Crown has to rest before it can fire again.
- **Swipe right:** Stop, with its "End this Workout?" confirmation.
- **Swipe left:** the prototype's controls: variant, scenario, restart, Force Always On, the heart-rate slot, and the Crown turn's firmness (Light, Firm, Very firm).

The clock is a stand-in for the iPhone engine. Done starts a 1:00 Rest, and the next Work starts by itself. Intervals runs 0:40 Work and 0:20 Rest. A Done that does nothing gives a failure haptic.

## What to judge

- Can you hit the quick action mid-set without looking, with a sweaty hand, in a sleeve?
- Did anything fire that you didn't mean? A sleeve or a brush in C, a wrist bend on the Crown.
- Can you still read the time, Phase, Round and the last Work time at arm's length, and is there room for heart rate?
- Does Always On stay readable, and is a dimmed tap still easy?
- Which Crown firmness is a deliberate turn and not an accident?
