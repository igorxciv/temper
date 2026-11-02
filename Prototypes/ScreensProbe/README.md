# Screens Probe: PROTOTYPE, throw away

Answers one question: what should the setup, running and Settings screens look like? It never ships. Only the verdict moves on.

The timer is a stand-in. It has no audio, no background running and no accuracy claims, and nothing is saved.

This is the fifth round, with the layouts and the Ink design system chosen, comparing three ways to show Rounds. Earlier variants are in this branch's history: the first round at `d6cee05`, the second at `6c6edda`, the third, with the Tide and Plum themes, at `b8542a3` and the fourth, with "Round 3 of 8" as text, at `9fc9369`.

## Run it

In the Simulator, from this folder:

```
./run.sh
```

If the Simulator window doesn't open, open `ScreensProbe.xcodeproj` in Xcode and press Run.

Colors are best judged on a real iPhone. For that, run `cp Config/Local.xcconfig.example Config/Local.xcconfig`, set your Personal Team ID and bundle prefix, then open `ScreensProbe.xcodeproj` and run the Debug configuration on your phone. Git ignores `Local.xcconfig`. Leave Xcode's Team picker alone, because it writes to the tracked project.

## The bar

The black and yellow bar is not part of any design.

- **Dotted circle:** switches between the three Round styles. The bar names the current one.
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

## Rounds

Each style appears on the running screen, the Rounds row on setup, the Rounds sheet and the complete screen. A mark fills across its Round's Work and Rest.

- **Temper bar:** a steel bar takes on the oxide colors of tempering steel, from straw to blue, with a cut at each Round. The Round number wears its Round's color. Stops: `#F7E8AE`, `#E6B566`, `#DD9A63`, `#C48BD0`, `#8F9CF5`, `#6FBDF5`.
- **Chalk:** five-bar tally gates in chalk, with each stroke drawing itself upward as its Round runs.
- **Bezel:** brass pips around the ring, like the markers on a watch bezel, with the Round number inside the ring.

## Time format

Every time reads `00:00`, for example `01:00`.

## Ranges

Prepare, Rest and Cooldown run from Off to 30:00 in 5-second steps, and Off skips the Phase. Work runs from 00:05 to 30:00. Rounds run from 1 to 99.

Launch arguments open a state directly, for example `./run.sh -screen running -phase Rest -time 14`. Others are `-screen settings`, `-screen complete`, `-paused YES`, `-confirmStop YES`, `-edit work`, `-noBar YES`, `-roundStyle chalk` and `-rounds 99`.

## Screenshots

`screenshots/` has every screen on a Simulator iPhone 18 Pro, without the bar, using the Temper bar. `screenshots/rounds/` has each Round style in every state, including 3 and 99 Rounds.
