/// The Workout engine's state at its latest event. Everything between events, such as the time left,
/// is worked out from it, so no tick ever passes through the engine.
public nonisolated struct WorkoutSnapshot<Instant: InstantProtocol>: Equatable, Sendable
where Instant.Duration == Duration {
    public enum Progress: Equatable, Sendable {
        /// A Phase with a set length, running until `endsAt`, or until it reaches the set length it runs past.
        case running(phase: Phase, endsAt: Instant)
        /// An open Phase, or one past the set length it runs past, running since `startedAt`, which any Pause has
        /// moved later by its length.
        case runningOpen(phase: Phase, startedAt: Instant)
        /// A Phase with a set length, held with `timeLeft` to go.
        case paused(phase: Phase, timeLeft: Duration)
        /// An open Phase, or one past the set length it runs past, held with `elapsed` spent in it.
        case pausedOpen(phase: Phase, elapsed: Duration)
        /// The Workout ran to its end.
        case finished(WorkoutRecord<Instant>)
        /// The owner Stopped the Workout.
        case stopped(WorkoutRecord<Instant>)
    }

    public let progress: Progress
    /// How many Rounds the Workout has, or `nil` if it has no set number.
    public let rounds: Int?
    /// The active time of the open Phase just before the current one, which ended at Done, or `nil` if the Phase
    /// before wasn't open. In Open Rounds it's the Work time a Rest follows.
    public let previousOpenPhaseTime: Duration?

    public init(progress: Progress, rounds: Int?, previousOpenPhaseTime: Duration? = nil) {
        self.progress = progress
        self.rounds = rounds
        self.previousOpenPhaseTime = previousOpenPhaseTime
    }

    /// What the Workout ended as, once it has finished or been Stopped, or `nil` before then.
    public var record: WorkoutRecord<Instant>? {
        switch progress {
        case .finished(let record), .stopped(let record): record
        case .running, .runningOpen, .paused, .pausedOpen: nil
        }
    }

    /// The current Phase, or `nil` once the Workout has ended.
    public var phase: Phase? {
        switch progress {
        case .running(let phase, _), .runningOpen(let phase, _), .paused(let phase, _), .pausedOpen(let phase, _):
            phase
        case .finished, .stopped: nil
        }
    }

    public var isPaused: Bool {
        switch progress {
        case .paused, .pausedOpen: true
        case .running, .runningOpen, .finished, .stopped: false
        }
    }

    /// True from Start until the Workout finishes or stops, including during a Pause.
    public var keepsScreenAwake: Bool {
        phase != nil
    }

    /// The time left in the current Phase, held at zero from the Phase's end until the next snapshot. An open
    /// Phase has none.
    public func timeLeft(at now: Instant) -> Duration {
        switch progress {
        case .running(_, let end): max(.zero, now.duration(to: end))
        case .paused(_, let timeLeft): timeLeft
        case .runningOpen, .pausedOpen, .finished, .stopped: .zero
        }
    }

    /// The time spent in the current Phase, not counting any Pause. In a Phase with a set length it holds at that
    /// length from the Phase's end until the next snapshot.
    public func elapsed(at now: Instant) -> Duration {
        switch progress {
        case .running(let phase, _), .paused(let phase, _):
            phase.duration.map { $0 - timeLeft(at: now) } ?? .zero
        case .runningOpen(_, let start): max(.zero, start.duration(to: now))
        case .pausedOpen(_, let elapsed): elapsed
        case .finished, .stopped: .zero
        }
    }

    /// How much of the current Phase is left at `now`, from 1 as it starts to 0 as it ends. An open Phase has
    /// no length to measure against, so it reads 0.
    public func fractionLeft(at now: Instant) -> Double {
        guard let length = phase?.duration, length > .zero else { return 0 }
        return min(1, timeLeft(at: now) / length)
    }
}
