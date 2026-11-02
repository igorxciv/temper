# Screens Probe: PROTOTYPE, throw away

Answers one question: what should the setup, running and Settings screens look like? It never ships. Only the verdict moves on.

The timer is a stand-in. It has no audio, no background running and no accuracy claims, and nothing is saved.

This is the third round. The layouts are chosen, and the open question is the app's dark design system. Earlier variants are in this branch's history: the first round at `d6cee05` and the second at `6c6edda`.

## Run it

In the Simulator, from this folder:

```
./run.sh
```

If the Simulator window doesn't open, open `ScreensProbe.xcodeproj` in Xcode and press Run.

Colors are best judged on a real iPhone. For that, run `cp Config/Local.xcconfig.example Config/Local.xcconfig`, set your Personal Team ID and bundle prefix, then open `ScreensProbe.xcodeproj` and run the Debug configuration on your phone. Git ignores `Local.xcconfig`. Leave Xcode's Team picker alone, because it writes to the tracked project.

## The bar

The black and yellow bar is not part of any design.

- **Arrows:** switch the theme for the whole app, on any screen.
- **Skip button:** jumps to the next Phase. Skipping is not a v1 feature.
- **Eye:** hides the bar. A small yellow dot in the bottom corner brings it back.

## Themes

The app is dark only. Each theme colors every screen, and each Phase has its own background and ring.

| Theme | Home background | Accent | Idea |
|---|---|---|---|
| Tide | Deep teal `#0F2A28` | Sea-glass `#8FE3D4` | Not being in a Workout is resting, so home is the Rest color and Work warms away from it |
| Plum | Aubergine `#1C1424` | Apricot `#FFB38A` | A warm, unusual base with no green outside Rest |
| Ink | Blue-black `#11151D` | Brass `#E6B566` | The quietest base, with a metallic accent |

## Ranges

Prepare, Rest and Cooldown run from Off to 30:00 in 5-second steps, and Off skips the Phase. Work runs from 0:05 to 30:00. Rounds run from 1 to 99.

Launch arguments open a state directly, for example `./run.sh -theme Plum -screen running -phase Rest -time 14`. Others are `-screen settings`, `-paused YES`, `-confirmStop YES`, `-edit work` and `-noBar YES`.

## Screenshots

`screenshots/` has every theme on a Simulator iPhone 18 Pro, without the bar.
