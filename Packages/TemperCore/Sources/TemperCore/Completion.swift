/// The complete screen a Workout ends on.
public nonisolated enum Completion: Codable, Hashable, Sendable {
    /// The complete screen of a finished Workout with no open Phase, such as Intervals or Stopwatch, with the Workout
    /// record's active time: the total length of an Intervals, and a Stopwatch's time up to Done.
    case total(Duration)
    /// The Rounds complete screen of a Workout with an open Phase, such as Open Rounds, once Stopped or finished.
    case rounds(RoundsSummary)
}

extension RunningDisplay {
    /// The complete screen once the Workout has ended, or `nil` while it runs and after a Stop that returns to setup.
    ///
    /// A Workout with an open Phase, as Open Rounds, records each Work time the owner ends with Done, so its Stop opens
    /// the Rounds complete screen however soon after Start, and the Live Activity shows its complete state. Without
    /// one, as in Intervals and Stopwatch, Stop returns to setup and ends the Live Activity, and a finish, which in a
    /// Stopwatch is Done, opens the complete screen.
    public nonisolated var completion: Completion? {
        switch (workout.hasOpenPhase, snapshot.progress) {
        case (true, .stopped(let record)), (true, .finished(let record)):
            .rounds(RoundsSummary(record: record))
        case (false, .finished(let record)):
            .total(record.activeTime)
        case (false, .stopped), (_, .running), (_, .runningOpen), (_, .paused), (_, .pausedOpen):
            nil
        }
    }
}
