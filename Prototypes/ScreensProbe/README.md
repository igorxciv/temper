# Screens Probe: PROTOTYPE, throw away

Answers one question: what should the setup, running and Settings screens look like? It never ships. Only the verdict moves on.

The timer is a stand-in. It has no audio, no background running and no accuracy claims, and nothing is saved.

This is the second round. The first round's variants (A, B and C) are in this branch's history at `d6cee05`.

## Run it

In the Simulator, from this folder:

```
./run.sh
```

If the Simulator window doesn't open, open `ScreensProbe.xcodeproj` in Xcode and press Run.

Legibility at a distance can only be judged on a real iPhone. For that, run `cp Config/Local.xcconfig.example Config/Local.xcconfig`, set your Personal Team ID and bundle prefix, then open `ScreensProbe.xcodeproj` and run the Debug configuration on your phone. Git ignores `Local.xcconfig`. Leave Xcode's Team picker alone, because it writes to the tracked project.

## The bar

The black and yellow bar is not part of any design.

- **Arrows:** switch the variant of the screen you are on. Setup and running switch independently, so any pair can be tried.
- **Skip button:** jumps to the next Phase. Skipping is not a v1 feature.
- **Eye:** hides the bar. A small yellow dot in the bottom corner brings it back.

## Variants

| | Setup | Idea |
|---|---|---|
| D | Preview and docked wheel | Every value on top, with a custom wheel always open below. Tapping a value points the wheel at it |
| E | Hero and ruler | Small previews, one huge value, and a horizontal ruler dial instead of a wheel |
| F | Big preview and sheet | The big-stepper look without buttons. Tapping a value opens the custom wheel in a sheet |

| | Running | Idea |
|---|---|---|
| D | Neutral ring, Rounded | Dark neutral background with a Phase-colored ring. Follows light and dark |
| E | Tinted ring, Rounded | Deep Phase-tinted background with a lighter tonal ring. Always dark |
| F | Neutral ring, SF Pro | The colors of D in SF Pro instead of SF Rounded, to compare the font alone |

Settings has one design, because it holds one option.

## Ranges

Prepare, Rest and Cooldown run from Off to 30:00 in 5-second steps, and Off skips the Phase. Work runs from 0:05 to 30:00. Rounds run from 1 to 99.

Launch arguments open a state directly, for example `./run.sh -running E -screen running -phase Rest -time 14`. Others are `-setup`, `-paused YES`, `-confirmStop YES`, `-edit work` and `-noBar YES`.

## Colors and type

They come from [the running colors research](https://github.com/igorxciv/temper/blob/research/running-colors/docs/research/running-colors.md).

## Screenshots

`screenshots/` has the variants on a Simulator iPhone 18 Pro, without the bar. Running screens are in dark appearance unless the name says `light`.
