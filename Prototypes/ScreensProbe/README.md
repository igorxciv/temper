# Screens Probe: PROTOTYPE, throw away

Answers one question: what should the setup, running and Settings screens look like? It never ships. Only the verdict moves on.

The timer is a stand-in. It has no audio, no background running and no accuracy claims, and nothing is saved.

## Hold-up round

This branch tests the chosen screens where they weren't tested: small screens, large text, Increase Contrast, Reduce Transparency, color blindness and distance.

The probe bar's third line shows what the app sees: Increase Contrast from the system and as shown, Reduce Transparency, text size, and the ring style or word strength.

- **Half circle:** forces the Increase Contrast colors on or off. The system setting also turns them on.
- **Ruler, on the running screen:** cycles the ring style through `current`, `thin` and `edge`. Launch with `-timeStyle thin`.
- **Text icon, on setup:** cycles the word strength through 32%, 45% and 60%. Launch with `-label 0.45`. Increase Contrast always uses 60%.

The owner's choices are now the defaults: the `edge` ring and 45% words. The ring redraws every display frame. The value sheet has a Confirm button, and swiping the sheet away discards the change.

This probe has no audio, so it never speaks Cues. Those are in Timing Probe.

`python3 -I palette.py` prints the contrast, color-blindness and distance figures. `screenshots/holdup/` has the evidence.

This is the final round, with the layouts, the Ink design system and the outlined setup labels chosen. Earlier variants are in this branch's history: the first round at `d6cee05`, the second at `6c6edda`, the third, with the Tide and Plum themes, at `b8542a3`, the fourth, with "Round 3 of 8" as text, at `9fc9369`, the fifth, with the Chalk and Bezel styles, at `31084cb`, the Temper bar at `825ef26`, the Thread, Italic and Edge labels at `11379f3`, and the Stamped and Fade labels at `8617a1c`.

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

## Rounds

The running screen shows the Round number at 64 pt with "of 8" smaller beside it. VoiceOver says "Round 3 of 8".

## Setup labels

Each row's label is a 60 pt bold hollow word on the left, in the Phase's color at 45%, with its value on the right. A long word dissolves just before the digits begin. Rounds has no Phase, so it uses brass.

## Time format

Every time reads `00:00`, for example `01:00`.

## Ranges

Prepare, Rest and Cooldown run from Off to 30:00 in 5-second steps, and Off skips the Phase. Work runs from 00:05 to 30:00. Rounds run from 1 to 99.

Launch arguments open a state directly, for example `./run.sh -screen running -phase Rest -time 14`. Others are `-screen settings`, `-screen complete`, `-paused YES`, `-confirmStop YES`, `-edit work`, `-noBar YES`, `-rounds 99` and `-rest 0`.

## Screenshots

`screenshots/` has every screen on a Simulator iPhone 18 Pro, without the bar, including 3 and 99 Rounds.
