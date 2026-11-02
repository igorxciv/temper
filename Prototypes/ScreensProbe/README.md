# Screens Probe: PROTOTYPE, throw away

Answers one question: what should the setup, running and Settings screens look like? It never ships. Only the verdict moves on.

The timer is a stand-in. It has no audio, no background running and no accuracy claims, and nothing is saved.

This is the fourth round, with the layouts and the Ink design system chosen. Earlier variants are in this branch's history: the first round at `d6cee05`, the second at `6c6edda` and the third, with the Tide and Plum themes, at `b8542a3`.

## Run it

In the Simulator, from this folder:

```
./run.sh
```

If the Simulator window doesn't open, open `ScreensProbe.xcodeproj` in Xcode and press Run.

Colors are best judged on a real iPhone. For that, run `cp Config/Local.xcconfig.example Config/Local.xcconfig`, set your Personal Team ID and bundle prefix, then open `ScreensProbe.xcodeproj` and run the Debug configuration on your phone. Git ignores `Local.xcconfig`. Leave Xcode's Team picker alone, because it writes to the tracked project.

## The bar

The black and yellow bar is not part of any design.

- **Skip button:** jumps to the next Phase. Skipping is not a v1 feature.
- **Eye:** hides the bar. A small yellow dot in the bottom corner brings it back.

## Ink

The app is dark only, on a blue-black home background `#11151D` with a brass accent `#E6B566`.

| Phase | Background | Ring and name | Track | Text |
|---|---|---|---|---|
| Prepare | `#0F2433` | `#8FCBEF` | `#274A60` | `#EFF8FD` |
| Work | `#351C17` | `#FFAE8A` | `#59332A` | `#FFF5F0` |
| Rest | `#0F2A2B` | `#86DCCB` | `#254A48` | `#F0FBF8` |
| Cooldown | `#18223F` | `#AFC4FF` | `#2F3D66` | `#F3F6FF` |

## Time format

Every time reads `00:00`, for example `01:00`.

## Ranges

Prepare, Rest and Cooldown run from Off to 30:00 in 5-second steps, and Off skips the Phase. Work runs from 00:05 to 30:00. Rounds run from 1 to 99.

Launch arguments open a state directly, for example `./run.sh -screen running -phase Rest -time 14`. Others are `-screen settings`, `-paused YES`, `-confirmStop YES`, `-edit work` and `-noBar YES`.

## Screenshots

`screenshots/` has every screen on a Simulator iPhone 18 Pro, without the bar.
