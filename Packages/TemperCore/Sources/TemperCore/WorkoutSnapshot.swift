/// What the Round line under the ring shows.
public nonisolated enum RoundLine: Equatable, Sendable {
    /// A large number with a caption beside it, and what VoiceOver says for the two together.
    case count(number: Int, caption: String, spoken: String)
    case paused
}

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

    /// How full the ring is at `now`, from 1 as a Phase starts to 0 as it ends.
    public func fractionLeft(at now: Instant) -> Double {
        guard let phase, phase.duration > .zero else { return 0 }
        return min(1, timeLeft(at: now) / phase.duration)
    }

    /// The Round line, or `nil` once the Workout has ended.
    public var roundLine: RoundLine? {
        guard let phase else { return nil }
        if isPaused { return .paused }
        let total = rounds == 1 ? "1 Round" : "\(rounds) Rounds"
        switch phase.kind {
        case .prepare:
            return .count(number: rounds, caption: rounds == 1 ? "Round" : "Rounds", spoken: total)
        case .work, .rest:
            let round = phase.round ?? rounds
            return .count(number: round, caption: "of \(rounds)", spoken: "Round \(round) of \(rounds)")
        case .cooldown:
            return .count(number: rounds, caption: "of \(rounds)", spoken: total)
        }
    }
}
