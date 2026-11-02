# Temper

Temper is a personal training app. Its first feature runs a timed Workout that moves through its Phases automatically and announces each change aloud.

## Language

**Workout**:
A Prepare if one is configured, followed by all its Rounds, followed by a Cooldown if one is configured.
_Avoid_: Session, timer, routine

**Phase**:
A single timed period within a Workout: a Prepare, Work, Rest, or Cooldown.
_Avoid_: Stage, step, interval

**Prepare**:
The optional Phase before the first Round, used to get into position.
_Avoid_: Countdown, warm-up

**Round**:
One Work, followed by a Rest if one is configured, unless it is the last Round of the Workout.
_Avoid_: Set, rep, cycle

**Work**:
The Phase of a Round in which the exercise is performed.
_Avoid_: Work round, active time

**Rest**:
The optional Phase between one Work and the next. The last Round has none.
_Avoid_: Break, pause

**Cooldown**:
The optional final Phase, following the last Work.
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
