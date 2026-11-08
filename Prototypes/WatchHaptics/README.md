# PROTOTYPE: a wrist haptic per Cue kind

Throwaway. It lives only on the `prototype/watch-haptics` branch and is never merged. It answers
[Which wrist haptic marks each Cue kind?](https://github.com/igorxciv/temper/issues/112)

## The Cue kinds

The ticket lists a Phase change, the end of the Workout, and Rest about to end. `TemperCore` narrows that to five Cues, and the prototype fires only these:

| Cue | When the iPhone speaks it |
| --- | --- |
| Work | entering Work |
| Rest | entering Rest, including right after your own Done in Open Rounds |
| Cooldown | entering Cooldown |
| Workout complete | when Intervals or a Stopwatch finishes on its own. Stop plays nothing, so Open Rounds never gets it |
| 10 seconds | 10 s before an Open Rounds Rest ends, if that Rest is 0:20 or longer |

Prepare starts silently, so it has no haptic.

## The schemes

Each scheme gives every Cue a pattern, played a **gap** apart (0.4, 0.7 or 1.0 s, from the start of one haptic to the start of the next, default 0.7).

| | Work | Rest | Cooldown | Workout complete | 10 seconds |
| --- | --- | --- | --- | --- | --- |
| **A** Apple's names | start | stop | directionDown | success | retry |
| **B** Counted | notification ×2 | notification | notification ×3 | success ×2 | click ×3 |
| **C** Up and down | directionUp | directionDown | directionDown ×2 | success | click ×2 |
| **D** Strongest | depthCritical | notification ×2 | depth | success, notification | retry |
| **E** Turns | rightTurn | leftTurn | maneuver | success | click ×3 |
| **Custom** Your own | any haptic ×1 to 3 per Cue, edited on the Watch, starting from A | | | | |

`depth` and `depthCritical` are `underwaterDepthPrompt` and `underwaterDepthCriticalPrompt`. `rightTurn`, `leftTurn` and `maneuver` are the `navigation…` haptics. They're in the table because they're longer and stronger than the rest, not for what they mean.

## Run it on the Series 8

It's already installed as **Haptics Proto**. To reinstall:

1. Make sure `Config/Local.xcconfig` exists in this checkout. The prototype reads `DEVELOPMENT_TEAM` and `BUNDLE_ID_PREFIX` from it.
2. Open `Prototypes/WatchHaptics/WatchHapticsPrototype.xcodeproj`, pick the **WatchHapticsPrototype** scheme with the Watch as the destination, and Run. **HapticsHost** carries the Watch app through the iPhone if that fails.

The first launch asks for Health permission to save workouts. The prototype needs it only to run a workout session, which keeps it running with the wrist down so the haptics still play, as they will in Temper. It has no workout builder, so nothing reaches Health. Without permission, the running screen shows in red that haptics stop with the wrist down.

## On the Watch

The home list, top to bottom:

- **Scheme:** pick A to E or Custom. Each Cue row below plays that Cue's pattern when tapped, with its pattern under the name. **Edit your own** sets the Custom scheme.
- **Intervals:** Work / Rest of 0:20/0:10, 0:40/0:20, 1:00/0:30 or 3:00/1:00, 4, 8 or 12 Rounds, and a 1:00 Cooldown. It fires Work, Rest, Cooldown and Workout complete.
- **Open Rounds:** a Rest of 0:30 to 3:00. Work is open and ends at the Done capsule. It fires Work, Rest and 10 seconds, and runs until Stop. **Rest haptic after Done** turns off the Rest haptic that follows your own Done.
- **More:** the gap, **Every haptic** (all 14 of watchOS's haptics, ×1 to 3), the **Log** of every Cue fired with its scheme and time, and the workout session's state.

Both runs open with a silent 0:10 Prepare. The running screen shows the Phase, the time, the Round and the last Cue with its pattern. The scheme letter, top left, cycles to the next scheme mid-run, so two schemes can be compared across sets in one workout. **Stop**, top right, ends on a second tap within 3 s.

## What to judge

- **Felt:** which patterns do you notice mid-rep, with the arm moving, gripping, or the wrist bent under load? `click` and `directionUp`/`directionDown` are the likeliest to be missed.
- **Told apart:** without looking, can you tell Work from Rest, and both from 10 seconds? Cooldown and Workout complete come once per Workout, so they matter less.
- **Too much:** what gets tiresome when it comes every Round, in 0:20/0:10 Intervals especially? `depthCritical` and the turns are long.
- **Gap:** does a sequence such as notification ×2 read as two at 0.4 s, or blur into one?
- **After Done:** when you tap Done yourself, is the Rest haptic welcome confirmation, or noise?
- **With the voice:** the iPhone still speaks every Cue, so the haptic may only need to be felt, not told apart. Is a single pattern for every Phase change enough?
