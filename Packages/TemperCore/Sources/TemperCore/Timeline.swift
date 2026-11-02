/// The spoken announcement of a Phase change or of the end of the Workout.
public nonisolated enum Cue: Equatable, Sendable {
    case work, rest, cooldown, workoutComplete

    /// The Cue for entering a Phase. Prepare starts silently.
    init?(entering kind: Phase.Kind) {
        switch kind {
        case .prepare: return nil
        case .work: self = .work
        case .rest: self = .rest
        case .cooldown: self = .cooldown
        }
    }
}

/// A Cue and the active time it is due.
public nonisolated struct UpcomingCue: Equatable, Sendable {
    public let cue: Cue
    public let due: Duration
}

/// Where a Workout is at any active time, the time spent running and not Paused.
public nonisolated struct Timeline: Sendable {
    /// Where the Workout is at one active time.
    public struct Position: Equatable, Sendable {
        /// The current Phase, or `nil` once the Workout has finished.
        public let phase: Phase?
        /// The time left in the current Phase, or zero once the Workout has finished.
        public let timeLeft: Duration
        /// The first Cue due at or after this time, so a Workout that opens on Work reports its Cue at zero.
        /// It is `nil` only past the finish. Whether a Cue actually plays is not decided here.
        public let nextCue: UpcomingCue?

        public var isFinished: Bool { phase == nil }
    }

    private struct Span: Sendable {
        let phase: Phase
        let end: Duration
    }

    private let spans: [Span]
    private let cues: [UpcomingCue]

    public init(workout: Workout) {
        var end = Duration.zero
        var spans: [Span] = []
        var cues: [UpcomingCue] = []
        for phase in workout.phases {
            if let cue = Cue(entering: phase.kind) {
                cues.append(UpcomingCue(cue: cue, due: end))
            }
            end += phase.duration
            spans.append(Span(phase: phase, end: end))
        }
        cues.append(UpcomingCue(cue: .workoutComplete, due: end))
        self.spans = spans
        self.cues = cues
    }

    /// A Phase's end is the start of the next Phase, and the Workout's end is its finish.
    public func position(at activeTime: Duration) -> Position {
        let nextCue = cues.first { $0.due >= activeTime }
        guard let span = spans.first(where: { activeTime < $0.end }) else {
            return Position(phase: nil, timeLeft: .zero, nextCue: nextCue)
        }
        return Position(phase: span.phase, timeLeft: span.end - activeTime, nextCue: nextCue)
    }
}
