/// The line under the ring: the Round line in Intervals, and the length in a Stopwatch.
public nonisolated enum RingLine: Equatable, Sendable {
    /// A smaller caption, and which side of the value it sits on.
    public enum Caption: Equatable, Sendable {
        case before(String)
        case after(String)
    }

    /// A large value, such as a Round number or a length, with a caption beside it, and what VoiceOver says for
    /// the two together.
    case value(String, caption: Caption, spoken: String)
    case paused
}

/// What the running screen shows for a Workout Type at one snapshot: the time in the ring, how full the ring is,
/// and the line under it, with what VoiceOver says for each.
///
/// Every Phase counts down except a Stopwatch's Work, which counts up. Counting up is only a display choice, so
/// the engine, the Timeline and the Cue rules are the same for both.
public nonisolated struct RunningDisplay<Instant: InstantProtocol>: Equatable, Sendable
where Instant.Duration == Duration {
    /// The ring at one instant.
    public struct Ring: Equatable, Sendable {
        /// The time in the ring, as `00:00`.
        public let time: String
        /// What VoiceOver says for the time, such as "8 seconds left" or "4 seconds elapsed".
        public let spokenTime: String
        /// How much of the ring is drawn, from 0 to 1, clockwise from the top.
        public let fill: Double
    }

    public let workoutType: WorkoutType
    public let workout: Workout
    public let snapshot: WorkoutSnapshot<Instant>

    public init(workoutType: WorkoutType, workout: Workout, snapshot: WorkoutSnapshot<Instant>) {
        self.workoutType = workoutType
        self.workout = workout
        self.snapshot = snapshot
    }

    /// True during a Stopwatch's Work, including while it's Paused.
    public var countsUp: Bool {
        workoutType == .stopwatch && snapshot.phase?.kind == .work
    }

    /// The ring at `now`. Counting down, the time left rounds up and the ring empties. Counting up, the time
    /// elapsed rounds down and the ring fills. Either way the time holds at the Phase's end until the next snapshot.
    public func ring(at now: Instant) -> Ring {
        let timeLeft = snapshot.timeLeft(at: now)
        let fractionLeft = snapshot.fractionLeft(at: now)
        guard countsUp, let phase = snapshot.phase else {
            return Ring(
                time: timeLeft.clockText,
                spokenTime: "\(timeLeft.spokenText(rounding: .up)) left",
                fill: fractionLeft
            )
        }
        let elapsed = Duration.seconds((phase.duration - timeLeft).wholeSeconds(rounding: .down))
        return Ring(
            time: elapsed.clockText,
            spokenTime: "\(elapsed.spokenText(rounding: .down)) elapsed",
            fill: 1 - fractionLeft
        )
    }

    /// The line under the ring, or `nil` once the Workout has ended.
    public var line: RingLine? {
        guard let phase = snapshot.phase else { return nil }
        if snapshot.isPaused { return .paused }
        switch workoutType {
        case .intervals: return roundLine(in: phase)
        case .stopwatch: return lengthLine(in: phase)
        }
    }

    private func roundLine(in phase: Phase) -> RingLine {
        let rounds = snapshot.rounds
        let total = rounds == 1 ? "1 Round" : "\(rounds) Rounds"
        switch phase.kind {
        case .prepare:
            return .value("\(rounds)", caption: .after(rounds == 1 ? "Round" : "Rounds"), spoken: total)
        case .work, .rest:
            let round = phase.round ?? rounds
            return .value("\(round)", caption: .after("of \(rounds)"), spoken: "Round \(round) of \(rounds)")
        case .cooldown:
            return .value("\(rounds)", caption: .after("of \(rounds)"), spoken: total)
        }
    }

    /// Prepare shows the length to come, and Work shows the length it counts up to.
    private func lengthLine(in phase: Phase) -> RingLine {
        let length = workout.phases.first { $0.kind == .work }?.duration ?? phase.duration
        let spokenLength = length.spokenText(rounding: .up)
        if phase.kind == .prepare {
            return .value(length.clockText, caption: .after("Stopwatch"), spoken: "Stopwatch, \(spokenLength)")
        }
        return .value(length.clockText, caption: .before("of"), spoken: "of \(spokenLength)")
    }
}
