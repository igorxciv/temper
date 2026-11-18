# Temper

Temper is an interval timer for iPhone and Apple Watch. It runs a Workout of a chosen Workout Type, moves through its Phases, and announces each change aloud. Every Workout starts on the iPhone. Apple Watch can follow it, showing the Workout and the heart rate, tapping the wrist at each Cue, and serving as a remote to Pause, Resume, mark Done or Stop.

## Language

**Workout**:
A run of Phases, of one Workout Type, from Start until it finishes or is Stopped.
_Avoid_: Session, timer, routine

**Workout Type**:
The kind of Workout picked before Start, which decides its shape and its values: Intervals, Stopwatch or Open Rounds.
_Avoid_: Timer, mode, program

**Intervals**:
The Workout Type made of a Prepare if one is configured, followed by a set number of Rounds, the last with no Rest, followed by a Cooldown if one is configured.
_Avoid_: HIIT, Tabata, rounds timer

**Stopwatch**:
The Workout Type made of a Prepare if one is configured, followed by a single Work that counts up past a set length until the owner marks it Done.
_Avoid_: Timer, count-up

**Open Rounds**:
The Workout Type made of a Prepare if one is configured, followed by Rounds of open Work, each followed by a Rest of a set length if one is configured. The Rounds repeat until the Workout is Stopped or, if a number of Rounds is configured, that many times, the last with no Rest, followed by a Cooldown if one is configured.
_Avoid_: Sets, Strength, Lifting, rest timer

**Plan**:
A Workout set out as Blocks in any order, which builds the Workout that runs. Each Workout Type is a built-in Plan, and a Plan can also take shapes no Workout Type has, as when Describe turns the owner's words into one.
_Avoid_: Program, routine, template, widget

**Block**:
One part of a Plan: a single Phase that runs once, or Rounds of a group of Phases that repeat a set number of times or until Stop.
_Avoid_: Widget, step, segment

**Preset**:
A named, saved set of one Workout Type's values, kept for starting that kind of Workout again.
_Avoid_: Saved Workout, template, favorite, routine

**Phase**:
A single period within a Workout: a Prepare, Work, Rest, or Cooldown. It ends at its set length or, if it is open or is a Stopwatch's Work, when the owner marks it Done.
_Avoid_: Stage, step, interval

**Open**:
Said of a Phase with no set length, which ends only when the owner marks it Done.
_Avoid_: Untimed, manual, unlimited

**Done**:
The owner's mark that ends an open Phase, or a Stopwatch's Work once it has passed its set length.
_Avoid_: Next, Skip, Lap, Split, Finish

**Prepare**:
The optional Phase at the start of a Workout, used to get into position. A Plan can also put one before any later Block.
_Avoid_: Countdown, warm-up

**Round**:
One Work and the Rest that follows it, if there is one. In a Plan, one run through a Block's group of Phases, which holds at least one Work.
_Avoid_: Set, rep, cycle

**Work**:
The Phase in which the exercise is performed: one per Round in Intervals and Open Rounds, and the only one after Prepare in a Stopwatch.
_Avoid_: Work round, active time

**Exercise**:
What the owner calls the activity of a Work in a Plan, such as Squats. A Work may have none. The Phase before a named Work shows it as next and, if that Phase is timed and has room, says it after its own Cue. Otherwise the Work says it over its Round Sound. The Work shows it in place of "Work".
_Avoid_: Name, label, move, title

**Rest**:
The Phase between one Work and the next. A Plan can also put one between Blocks, on its own or one after another.
_Avoid_: Break, pause

**Cooldown**:
The optional final Phase of Intervals, and of Open Rounds with a set number of Rounds, following the last Work. A Plan can put one anywhere, such as between two Blocks of Rounds as well as at the end.
_Avoid_: Final rest, warm-down

**Pause**:
A hold on the current Phase, requested by the owner, that stops its clock until resumed.
_Avoid_: Rest, break

**End**:
On Apple Watch, stopping following a Workout while the iPhone is out of reach, connecting or out of contact. The Watch goes back to idle and the Workout runs on, on the iPhone. Stop ends the Workout itself.
_Avoid_: Leave, disconnect, Stop

**Cue**:
The sound announcing a Phase change, the end of the Workout, that Rest is about to end, that a Phase is about to reach its set length, that a Stopwatch's Work has reached it, or the next Exercise. Work starts and ends on the Round Sound. Cooldown and the end of the Workout add their name, spoken over the Round Sound, and the other Cues are spoken. Apple Watch can also mark it with a tap on the wrist.
_Avoid_: Alert, notification, beep

**Round Sound**:
The sound that starts and ends every Work, and that Cooldown, the end of the Workout and an Exercise are spoken over: a gong, a chime or a beep, as the owner picks in Settings. It's the gong until they pick another.
_Avoid_: Bell, gong, tone

**Countdown**:
The Cue that counts "5, 4, 3, 2, 1" aloud, one number a second, over the last five seconds before a Phase reaches its set length. A Phase too short to fit it after its own Cue has none, and Apple Watch doesn't tap for it.
_Avoid_: Beeps, final seconds, Prepare

**Zone**:
One of five bands of heart rate, from 1 (easiest) to 5 (hardest), that the Watch shows beside the current heart rate.
_Avoid_: Intensity, level, heart-rate band
