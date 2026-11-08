@testable import TemperCore

/// For tests that check only how a Workout ended, not what its record holds.
nonisolated extension WorkoutSnapshot {
    var hasFinished: Bool {
        if case .finished = progress { true } else { false }
    }

    var wasStopped: Bool {
        if case .stopped = progress { true } else { false }
    }
}

nonisolated extension WorkoutRecord where Instant == ManualClock.Instant {
    /// A record of `seconds` of active time from zero, with no Pause and no Phase, for display tests that read only
    /// its active time.
    static func lasting(_ seconds: Double) -> Self {
        Self(start: Instant(offset: .zero), end: Instant(offset: .seconds(seconds)), pauses: [], phases: [])
    }
}
