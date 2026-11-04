# Temper

Temper is a personal training app. It runs a Workout of a chosen Workout Type, moves through its Phases, and announces each change aloud.

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
The Workout Type made of a Prepare if one is configured, followed by a single Work that counts up to a set length.
_Avoid_: Timer, count-up

**Open Rounds**:
The Workout Type made of Rounds of open Work, each followed by a Rest of a set length if one is configured, repeated until the Workout is Stopped.
_Avoid_: Sets, Strength, Lifting, rest timer

**Preset**:
A named, saved set of one Workout Type's values, kept for starting that kind of Workout again.
_Avoid_: Saved Workout, template, favorite, routine

**Phase**:
A single period within a Workout: a Prepare, Work, Rest, or Cooldown. It ends at its set length or, if it is open, when the owner marks it Done.
_Avoid_: Stage, step, interval

**Open**:
Said of a Phase with no set length, which ends only when the owner marks it Done.
_Avoid_: Untimed, manual, unlimited

**Done**:
The owner's mark that ends an open Phase.
_Avoid_: Next, Skip, Lap, Split, Finish

**Prepare**:
The optional Phase at the start of a Workout, used to get into position.
_Avoid_: Countdown, warm-up

**Round**:
One Work and the Rest that follows it, if there is one.
_Avoid_: Set, rep, cycle

**Work**:
The Phase in which the exercise is performed: one per Round in Intervals and Open Rounds, and the only one after Prepare in a Stopwatch.
_Avoid_: Work round, active time

**Rest**:
The Phase between one Work and the next.
_Avoid_: Break, pause

**Cooldown**:
The optional final Phase of Intervals, following the last Work.
_Avoid_: Final rest, warm-down

**Pause**:
A hold on the current Phase, requested by the owner, that stops its clock until resumed.
_Avoid_: Rest, break

**Cue**:
The spoken announcement of a Phase change or of the end of the Workout.
_Avoid_: Alert, notification, beep

**Dip**:
A brief lowering of other audio while a Cue speaks.
_Avoid_: Interrupt, mute

**Health workout**:
The record of one Workout that Temper saves to Apple Health. One Workout makes at most one.
_Avoid_: Activity, Session, Fitness workout
