/// A single timed period within a Workout.
public nonisolated struct Phase: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case prepare, work, rest, cooldown
    }

    public let kind: Kind
    public let duration: Duration
    /// The Round a Work or Rest belongs to. Prepare and Cooldown have none.
    public let round: Int?

    public init(kind: Kind, duration: Duration, round: Int? = nil) {
        self.kind = kind
        self.duration = duration
        self.round = round
    }
}

/// A Prepare if one is configured, followed by all its Rounds, followed by a Cooldown if one is configured.
public nonisolated struct Workout: Equatable, Sendable {
    public let phases: [Phase]

    public init(phases: [Phase]) {
        self.phases = phases
    }
}
