# Workout Types Probe: PROTOTYPE, throw away

This probe answers [How should Workout Types be picked, and how does a Stopwatch look?](https://github.com/igorxciv/temper/issues/44). It never merges. Only the verdict moves on.

Unlike Screens Probe, it runs inside the real app, so each picker is tried against the real setup, running and Settings screens. The code is in `Temper/WorkoutTypesProbe/`, plus small changes to `SetupScreen`, `RunningScreen` and `TemperApp`. A Stopwatch runs on the real engine as `[Prepare, Work]`. Its values live in memory only, and the last-used type lasts until the app quits.

## Run it

From the repo root:

```
Prototypes/WorkoutTypesProbe/run.sh
```

If the Simulator window doesn't open, open `Temper.xcodeproj` in Xcode and press Run.

## The bar

The black and yellow bar at the bottom is not part of any design.

- **‹ and ›:** switch between the pickers, (a) to (e).
- **Line button:** cycles what a running Stopwatch shows under the ring.
- **Eye:** hides the bar. A small yellow dot in the bottom corner brings it back.

## The pickers

| | Picker | Switching | Settings |
|---|---|---|---|
| (a) | Segmented control in the navigation bar | 1 tap, always visible | Gear, top right |
| (b) | Menu on the navigation title, "Intervals ⌄" | 2 taps | Gear, top right |
| (c) | Swipe between pages, dots under the title | 1 swipe | Gear, top right |
| (d) | Tab bar, one tab per type | 1 tap, always visible | Its own tab |
| (e) | List of types that pushes into setup | Back, then a tap | Gear on the list |

Every picker opens straight onto the last-used type. In (e), Back leads to the list.

## The Stopwatch

- **Setup:** two rows, Prepare and Work, each half the screen. Start reads Prepare plus Work, for example `Start · 10:10`.
- **Prepare:** counts down as in Intervals. Under the ring is the length to come, "10:00 Stopwatch".
- **Work:** counts up from 00:00, rounding down, with the ring filling clockwise. Under the ring is one of:
  - **of length:** "of 10:00"
  - **time left:** "09:56 left"
  - **nothing:** the space stays empty, so the ring doesn't move when Paused appears

Launch arguments open a state directly, for example `run.sh -variant d -type stopwatch -line left`. Others are `-autostart YES`, which starts the last-used type, `-atList YES`, which leaves (e) on its list, and `-noBar YES`.

## Screenshots

`screenshots/` has every picker with each type, the list home, and a running Stopwatch with each line, on a Simulator iPhone 18 Pro.
