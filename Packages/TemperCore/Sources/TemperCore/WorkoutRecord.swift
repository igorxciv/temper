/// What a Workout ended as, finished or Stopped: when it started and ended, its Pauses, and each Phase that ran.
///
/// The engine builds it from its own instants, never from the snapshots it published, so a Phase the screen never
/// heard of, because a suspended app skipped it, is still in it. It rides on the ended snapshot, whose case says how
/// the Workout ended. Its instants are the engine clock's, so turning them into dates takes one pair of an engine
/// instant and the wall-clock date read at the same moment.
public nonisolated struct WorkoutRecord<Instant: InstantProtocol>: Equatable, Sendable
where Instant.Duration == Duration {
    /// A Phase as it ran, from its start to the start of the next, or to the end for the last one. A Pause in it is
    /// inside its span.
    public struct RecordedPhase: Equatable, Sendable {
        public let kind: Phase.Kind
        /// The Round it belongs to, or `nil` for Prepare, Cooldown and a Stopwatch's Work.
        public let round: Int?
        public let start: Instant
        public let end: Instant

        public init(kind: Phase.Kind, round: Int?, start: Instant, end: Instant) {
            self.kind = kind
            self.round = round
            self.start = start
            self.end = end
        }
    }

    /// The fixed start point the engine set at Start.
    public let start: Instant
    /// The finish, or the Stop. A Workout Stopped before it started ends where it starts.
    public let end: Instant
    /// Each Pause, from its tap to its Resume, in order. A Pause still on at Stop ends at the Stop.
    public let pauses: [Range<Instant>]
    /// Each Phase that ran, in order. A Phase cut short by Stop ends at the Stop, and Phases never reached aren't in
    /// it.
    public let phases: [RecordedPhase]

    public init(start: Instant, end: Instant, pauses: [Range<Instant>], phases: [RecordedPhase]) {
        self.start = start
        self.end = end
        self.pauses = pauses
        self.phases = phases
    }

    /// The time from Start to the end, not counting any Pause.
    public var activeTime: Duration {
        activeTime(from: start, to: end)
    }

    /// The active time of each Work that ran, in order, not counting any Pause. Their number is the number of
    /// Rounds, so in Intervals and Open Rounds the first is Round 1's. The last can be a Work cut short by Stop.
    public var workTimes: [Duration] {
        phases.filter { $0.kind == .work }.map { activeTime(from: $0.start, to: $0.end) }
    }

    /// The time between two instants, leaving out the part of any Pause between them.
    private func activeTime(from start: Instant, to end: Instant) -> Duration {
        pauses.reduce(start.duration(to: end)) { time, pause in
            let overlap = max(pause.lowerBound, start).duration(to: min(pause.upperBound, end))
            return time - max(.zero, overlap)
        }
    }
}

nonisolated extension WorkoutRecord {
    /// The record of a Workout that started at `start`, was held for `pauses`, and ended at `end`, with its Phases
    /// placed by `timeline`.
    ///
    /// A Phase's start is placed in active time by the Timeline, then moved later by every Pause tapped before that
    /// active time. A Pause tapped as a Phase starts belongs to that Phase, as the engine Pauses the Phase a tap
    /// lands in.
    init(timeline: Timeline, start: Instant, pauses: [Range<Instant>], end: Instant) {
        let held = pauses.reduce(Duration.zero) { $0 + $1.lowerBound.duration(to: $1.upperBound) }
        let reached = timeline.phasesReached(by: start.duration(to: end) - held)
        let starts = reached.map { Self.instant(at: $0.start, from: start, pauses: pauses) }
        self.init(
            start: start,
            end: end,
            pauses: pauses,
            phases: reached.indices.map { index in
                RecordedPhase(
                    kind: reached[index].phase.kind,
                    round: reached[index].phase.round,
                    start: starts[index],
                    end: index + 1 < starts.count ? starts[index + 1] : end
                )
            }
        )
    }

    /// The instant an active time was reached: the start, plus that active time, plus every Pause tapped before it.
    private static func instant(at activeTime: Duration, from start: Instant, pauses: [Range<Instant>]) -> Instant {
        var held = Duration.zero
        for pause in pauses {
            guard start.duration(to: pause.lowerBound) - held < activeTime else { break }
            held += pause.lowerBound.duration(to: pause.upperBound)
        }
        return start.advanced(by: activeTime + held)
    }
}
