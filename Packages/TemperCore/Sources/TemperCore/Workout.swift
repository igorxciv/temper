/// A single timed period within a Workout.
public nonisolated struct Phase: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case prepare, work, rest, cooldown
    }

    public let kind: Kind
    public let duration: Duration

    public init(kind: Kind, duration: Duration) {
        self.kind = kind
        self.duration = duration
    }
}

/// One Prepare, followed by all its Rounds, followed by a Cooldown if one is configured.
public nonisolated struct Workout: Equatable, Sendable {
    public let phases: [Phase]

    /// Builds the Phases in order. The last Round has no Rest, and a zero `cooldown` means no Cooldown.
    public init(prepare: Duration, rounds: Int, work: Duration, rest: Duration, cooldown: Duration = .zero) {
        precondition(rounds > 0, "A Workout has at least one Round")

        var phases = [Phase(kind: .prepare, duration: prepare)]
        for round in 1...rounds {
            phases.append(Phase(kind: .work, duration: work))
            if round < rounds {
                phases.append(Phase(kind: .rest, duration: rest))
            }
        }
        if cooldown > .zero {
            phases.append(Phase(kind: .cooldown, duration: cooldown))
        }
        self.phases = phases
    }
}
