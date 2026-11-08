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
///
/// A Phase's end becomes known when the Phase before it ends: at its set length, or at the Done that ended an open
/// Phase. So nothing after an open Phase is placed until it is marked Done. Until then the position stays in that
/// Phase, with no time left and no Cue upcoming.
public nonisolated struct Timeline: Sendable {
    /// Where the Workout is at one active time.
    public struct Position: Equatable, Sendable {
        /// The current Phase, or `nil` once the Workout has finished.
        public let phase: Phase?
        /// The time left in the current Phase, or zero in an open Phase and once the Workout has finished.
        public let timeLeft: Duration
        /// The time spent in the current Phase, or zero once the Workout has finished.
        public let elapsed: Duration
        /// The first Cue due at or after this time, so a Workout that opens on Work reports its Cue at zero.
        /// It is `nil` past the finish, and in an open Phase once it has started. Whether a Cue actually plays is
        /// not decided here.
        public let nextCue: UpcomingCue?

        public var isFinished: Bool { phase == nil }
    }

    private struct Span: Sendable {
        let phase: Phase
        let start: Duration
        /// The start of the next Phase, or `nil` for an open Phase.
        let end: Duration?

        func contains(_ activeTime: Duration) -> Bool {
            end.map { activeTime < $0 } ?? true
        }
    }

    private let phases: [Phase]
    /// The active time each open Phase was marked Done, in the order the Phases were reached.
    private let doneTimes: [Duration]
    private let spans: [Span]
    private let cues: [UpcomingCue]

    public init(workout: Workout) {
        self.init(phases: workout.phases, doneTimes: [])
    }

    private init(phases: [Phase], doneTimes: [Duration]) {
        var start = Duration.zero
        var spans: [Span] = []
        var cues: [UpcomingCue] = []
        var dones = doneTimes[...]
        for phase in phases {
            if let cue = Cue(entering: phase.kind) {
                cues.append(UpcomingCue(cue: cue, due: start))
            }
            guard let end = phase.duration.map({ start + $0 }) ?? dones.popFirst() else {
                spans.append(Span(phase: phase, start: start, end: nil))
                break
            }
            spans.append(Span(phase: phase, start: start, end: end))
            start = end
        }
        if spans.last?.end != nil || spans.isEmpty {
            cues.append(UpcomingCue(cue: .workoutComplete, due: start))
        }
        self.phases = phases
        self.doneTimes = doneTimes
        self.spans = spans
        self.cues = cues
    }

    /// Ends the open Phase still waiting for Done at `activeTime`, which places every following Phase and its Cue
    /// up to the next open Phase. It's `nil` if `activeTime` isn't in that Phase, so a Done during a Phase with a
    /// set length, or a second Done that lands in the Phase after, ends nothing.
    func markingDone(at activeTime: Duration) -> Timeline? {
        guard let waiting = spans.last, waiting.end == nil, activeTime >= waiting.start else { return nil }
        return Timeline(phases: phases, doneTimes: doneTimes + [activeTime])
    }

    /// A Phase's end is the start of the next Phase, and the Workout's end is its finish.
    public func position(at activeTime: Duration) -> Position {
        let nextCue = cues.first { $0.due >= activeTime }
        guard let span = spans.first(where: { $0.contains(activeTime) }) else {
            return Position(phase: nil, timeLeft: .zero, elapsed: .zero, nextCue: nextCue)
        }
        return Position(
            phase: span.phase,
            timeLeft: span.end.map { $0 - activeTime } ?? .zero,
            elapsed: activeTime - span.start,
            nextCue: nextCue
        )
    }
}
