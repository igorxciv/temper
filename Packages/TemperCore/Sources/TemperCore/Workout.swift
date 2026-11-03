/// A single timed period within a Workout.
public nonisolated struct Phase: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case prepare, work, rest, cooldown
    }

    public let kind: Kind
    public let duration: Duration
    /// The Round a Work or Rest in Intervals belongs to. Prepare, Cooldown and a Stopwatch's Work have none.
    public let round: Int?

    public init(kind: Kind, duration: Duration, round: Int? = nil) {
        self.kind = kind
        self.duration = duration
        self.round = round
    }
}

/// A timed run of Phases, of one Workout Type.
///
/// The Phases are a flat list rather than Rounds, so later training with several stages can reuse the timer.
public nonisolated struct Workout: Equatable, Sendable {
    public let phases: [Phase]

    public init(phases: [Phase]) {
        self.phases = phases
    }

    /// The length of all its Phases, not counting any Pause.
    public var totalDuration: Duration {
        phases.reduce(.zero) { $0 + $1.duration }
    }

    /// How many Rounds it has. A Stopwatch has none.
    public var rounds: Int {
        phases.compactMap(\.round).max() ?? 0
    }
}
