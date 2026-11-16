---
status: accepted
---

# No Health workouts, but a Watch workout session for heart rate

Temper saves no workouts to Apple Health, from the iPhone or the Watch, because the owner doesn't want Temper to be a workout app ([#176](https://github.com/igorxciv/temper/issues/176), after the dropped [Training map](https://github.com/igorxciv/temper/issues/152)). The Watch still runs an `HKWorkoutSession` with a live builder for every Workout, and discards the builder at the end. Only a workout session gives a third-party Watch app live heart rate, keeps it in front and able to tap the wrist with the wrist down, and carries the mirrored link to the iPhone, so dropping the session would drop all four. This supersedes [ADR 0001](0001-health-replacement-keeps-one-health-workout.md).

## Consequences

- While the session runs, Apple Watch still writes its own heart-rate, active-energy and exercise-minute samples to Health and moves the rings. No API holds them back. Only the workout entry is gone.
- Temper still asks to share workouts, because Apple's guide asks it of any app that runs a session. Whether a session runs without that grant is undocumented and waits on a device run. If it does, the share type can go.
- Apple's guide asks a session app to save the workout or offer to. Never saving goes against that, which matters if Temper goes to the App Store.
- Don't bring back a save "for completeness". Saving again is a product decision that reopens this ADR.
