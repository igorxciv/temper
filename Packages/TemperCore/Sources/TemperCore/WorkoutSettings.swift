/// The values a Workout Type builds its Workout from. Each Workout Type keeps its own, and reads only the
/// values its setup shows.
public nonisolated struct WorkoutSettings: Equatable, Sendable {
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
}
