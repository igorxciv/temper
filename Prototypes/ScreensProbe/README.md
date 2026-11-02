# Screens Probe: PROTOTYPE, throw away

Answers one question: what should the setup, running and Settings screens look like? It never ships. Only the verdict moves on.

The timer is a stand-in. It has no audio, no background running and no accuracy claims, and nothing is saved.

## Run it

In the Simulator, from this folder:

```
./run.sh
```

Legibility at a distance can only be judged on a real iPhone. For that, run `cp Config/Local.xcconfig.example Config/Local.xcconfig`, set your Personal Team ID and bundle prefix, then open `ScreensProbe.xcodeproj` and run the Debug configuration on your phone. Git ignores `Local.xcconfig`. Leave Xcode's Team picker alone, because it writes to the tracked project.

## The bar

The black and yellow bar is not part of any design.

- **Arrows:** switch the variant of the screen you are on. Setup and running switch independently, so any pair can be tried.
- **Skip button:** jumps to the next Phase. Skipping is not a v1 feature.
- **Eye:** hides the bar. A small yellow dot in the bottom corner brings it back.

## Variants

| | Setup | Idea |
|---|---|---|
| A | Form and wheels | Standard iOS rows that expand into minute and second wheels |
| B | Big steppers | Every value on one screen with large minus and plus buttons. Holding a button repeats |
| C | Sentence and presets | The Workout reads as a sentence above a strip of its real shape. A value opens a sheet of presets |

| | Running | Idea |
|---|---|---|
| A | Color flood | The screen takes the Phase's color, with large Pause and Stop buttons |
| B | Ring and timeline | Follows light and dark. A ring for the Phase, a strip for the Workout, and the next Phase named |
| C | Whole-screen tap | Largest digits and no visible controls. A tap anywhere is Pause, and Stop is only reachable when paused |

Settings has one design, because it holds one option.

Launch arguments open a state directly, for example `./run.sh -running C -screen running -phase Rest -time 14`. Others are `-setup`, `-paused YES`, `-confirmStop YES`, `-edit work` and `-noBar YES`.

## Screenshots

`screenshots/` has every variant in light appearance on a Simulator iPhone 18 Pro, without the bar.
