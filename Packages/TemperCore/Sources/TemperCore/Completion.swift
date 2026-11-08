/// The complete screen a Workout ends on.
public nonisolated enum Completion: Equatable, Sendable {
    /// The complete screen of a finished Intervals or Stopwatch, with the Workout's length, or `nil` if it has none
    /// to show.
    case total(Duration?)
    /// The Rounds complete screen of a Stopped Open Rounds.
    case rounds(RoundsSummary)
}

extension RunningDisplay {
    /// The complete screen once the Workout has ended, or `nil` while it runs and after a Stop that returns to setup.
    ///
    /// Open Rounds ends only at Stop, so its Stop opens the Rounds complete screen, and the Live Activity shows its
    /// complete state. In Intervals and Stopwatch, Stop returns to setup and ends the Live Activity, and a finish
    /// opens the complete screen.
    public nonisolated var completion: Completion? {
        switch (workoutType, snapshot.progress) {
        case (.openRounds, .stopped(let record)), (.openRounds, .finished(let record)):
            .rounds(RoundsSummary(record: record))
        case (_, .finished):
            .total(workout.totalDuration)
        case (_, .stopped), (_, .running), (_, .runningOpen), (_, .paused), (_, .pausedOpen):
            nil
        }
    }
}
