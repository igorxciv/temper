/// The values a Workout is built from.
public nonisolated struct WorkoutSettings: Equatable, Sendable {
    /// The values before the owner has changed anything.
    public static let firstLaunch = WorkoutSettings(
        prepare: .seconds(10),
        rounds: 8,
        work: .seconds(40),
        rest: .seconds(20),
        cooldown: .seconds(60)
    )

    public var prepare: Duration
    public var rounds: Int
    public var work: Duration
    public var rest: Duration
    public var cooldown: Duration

    public init(prepare: Duration, rounds: Int, work: Duration, rest: Duration, cooldown: Duration) {
        self.prepare = prepare
        self.rounds = rounds
        self.work = work
        self.rest = rest
        self.cooldown = cooldown
    }

    /// Builds the Phases in order. The last Round has no Rest, and a zero Prepare, Rest or Cooldown is dropped.
    public func makeWorkout() -> Workout {
        precondition(rounds > 0, "A Workout has at least one Round")
        precondition(work > .zero, "A Round always has a Work")

        var phases = [Phase(kind: .prepare, duration: prepare)]
        for round in 1...rounds {
            phases.append(Phase(kind: .work, duration: work, round: round))
            if round < rounds {
                phases.append(Phase(kind: .rest, duration: rest, round: round))
            }
        }
        phases.append(Phase(kind: .cooldown, duration: cooldown))
        return Workout(phases: phases.filter { $0.duration > .zero })
    }
}
