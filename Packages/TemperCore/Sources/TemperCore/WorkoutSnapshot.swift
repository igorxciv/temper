/// The Workout engine's state at its latest event. Everything between events, such as the time left,
/// is worked out from it, so no tick ever passes through the engine.
public nonisolated struct WorkoutSnapshot<Instant: InstantProtocol>: Equatable, Sendable
where Instant.Duration == Duration {
    public enum Progress: Equatable, Sendable {
        case running(phase: Phase, endsAt: Instant)
        case paused(phase: Phase, timeLeft: Duration)
        case finished
        case stopped
    }

    public let progress: Progress
    /// How many Rounds the Workout has.
    public let rounds: Int

    public init(progress: Progress, rounds: Int) {
        self.progress = progress
        self.rounds = rounds
    }

    /// The current Phase, or `nil` once the Workout has ended.
    public var phase: Phase? {
        switch progress {
        case .running(let phase, _), .paused(let phase, _): phase
        case .finished, .stopped: nil
        }
    }

    public var isPaused: Bool {
        if case .paused = progress { true } else { false }
    }

    /// True from Start until the Workout finishes or stops, including during a Pause.
    public var keepsScreenAwake: Bool {
        phase != nil
    }

    /// The time left in the current Phase, held at zero from the Phase's end until the next snapshot.
    public func timeLeft(at now: Instant) -> Duration {
        switch progress {
        case .running(_, let end): max(.zero, now.duration(to: end))
        case .paused(_, let timeLeft): timeLeft
        case .finished, .stopped: .zero
        }
    }

    /// How much of the current Phase is left at `now`, from 1 as it starts to 0 as it ends.
    public func fractionLeft(at now: Instant) -> Double {
        guard let phase, phase.duration > .zero else { return 0 }
        return min(1, timeLeft(at: now) / phase.duration)
    }
}
