# Temper

Temper is a personal training app. It runs a timed Workout of a chosen Workout Type, moves through its Phases automatically, and announces each change aloud.

## Language

**Workout**:
A timed run of Phases, of one Workout Type.
_Avoid_: Session, timer, routine

**Workout Type**:
The kind of Workout picked before Start, which decides its shape and its values: Intervals or Stopwatch.
_Avoid_: Timer, mode, program

**Intervals**:
The Workout Type made of a Prepare if one is configured, followed by all its Rounds, followed by a Cooldown if one is configured.
_Avoid_: HIIT, Tabata, rounds timer

**Stopwatch**:
The Workout Type made of a Prepare if one is configured, followed by a single Work that counts up to a set length.
_Avoid_: Timer, count-up

**Phase**:
A single timed period within a Workout: a Prepare, Work, Rest, or Cooldown.
_Avoid_: Stage, step, interval

**Prepare**:
The optional Phase at the start of a Workout, used to get into position.
_Avoid_: Countdown, warm-up

**Round**:
One Work, followed by a Rest if one is configured, unless it is the last Round of the Workout.
_Avoid_: Set, rep, cycle

**Work**:
The Phase in which the exercise is performed: one per Round in Intervals, and the only one after Prepare in a Stopwatch.
_Avoid_: Work round, active time

**Rest**:
The optional Phase between one Work and the next. The last Round has none.
_Avoid_: Break, pause

**Cooldown**:
The optional final Phase of Intervals, following the last Work.
_Avoid_: Final rest, warm-down

**Pause**:
A hold on the current Phase, requested by the user, that keeps its remaining time until resumed.
_Avoid_: Rest, break

**Cue**:
The spoken announcement of a Phase change or of the end of the Workout.
_Avoid_: Alert, notification, beep

**Dip**:
A brief lowering of other audio while a Cue speaks.
_Avoid_: Interrupt, mute
