/// The line under the ring: the Round line in Intervals and Open Rounds, and the length in a Stopwatch.
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
/// Every Phase counts down except a Stopwatch's Work and an open Phase, which count up. Counting up is only a display
/// choice, so the engine, the Timeline and the Cue rules are the same for both.
///
/// In Open Rounds, an open Work counts up over the empty track with "Round 3" under it, and the Rest after it counts
/// down with "Round 3 · Work 1:42", the Work time just ended.
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

    /// The running screen's Done button, which only Open Rounds has.
    public enum DoneButton: Equatable, Sendable {
        case enabled
        /// Kept in place but dimmed, so nothing moves under the owner's thumb as Work turns to Rest or is Paused.
        case disabled
    }

    public let workoutType: WorkoutType
    public let workout: Workout
    public let snapshot: WorkoutSnapshot<Instant>

    public init(workoutType: WorkoutType, workout: Workout, snapshot: WorkoutSnapshot<Instant>) {
        self.workoutType = workoutType
        self.workout = workout
        self.snapshot = snapshot
    }

    /// True during a Stopwatch's Work and an open Phase, including while it's Paused.
    public var countsUp: Bool {
        guard let phase = snapshot.phase else { return false }
        return phase.isOpen || (workoutType == .stopwatch && phase.kind == .work)
    }

    /// Done, enabled only in a running open Work, the only time the engine takes it, or `nil` in Intervals and
    /// Stopwatch, which have no open Phase.
    public var doneButton: DoneButton? {
        guard workoutType == .openRounds else { return nil }
        if case .runningOpen = snapshot.progress { return .enabled }
        return .disabled
    }

    /// The ring at `now`. Counting down, the time left rounds up and the ring empties. Counting up, the time
    /// elapsed rounds down and the ring fills, except in an open Phase, which has no length to fill towards and so
    /// draws only the empty track. Either way the time holds at the Phase's end until the next snapshot. Past an
    /// hour the time keeps counting in minutes, as `72:15`.
    public func ring(at now: Instant) -> Ring {
        let timeLeft = snapshot.timeLeft(at: now)
        let fractionLeft = snapshot.fractionLeft(at: now)
        guard countsUp else {
            return Ring(
                time: timeLeft.clockText,
                spokenTime: "\(timeLeft.spokenText(rounding: .up)) left",
                fill: fractionLeft
            )
        }
        let elapsed = Duration.seconds(snapshot.elapsed(at: now).wholeSeconds(rounding: .down))
        return Ring(
            time: elapsed.clockText,
            spokenTime: "\(elapsed.spokenText(rounding: .down)) elapsed",
            fill: snapshot.phase?.isOpen == true ? 0 : 1 - fractionLeft
        )
    }

    /// The line under the ring, or `nil` once the Workout has ended or when there's nothing to say.
    public var line: RingLine? {
        guard let phase = snapshot.phase else { return nil }
        if snapshot.isPaused { return .paused }
        switch workoutType {
        case .intervals, .openRounds: return roundLine(in: phase)
        case .stopwatch: return lengthLine(in: phase)
        }
    }

    private func roundLine(in phase: Phase) -> RingLine? {
        guard let rounds = snapshot.rounds else {
            guard let round = phase.round else { return nil }
            if phase.kind == .rest, let workTime = snapshot.previousOpenPhaseTime {
                return .value(
                    workTime.shortClockText(rounding: .down),
                    caption: .before("Round \(round) · Work"),
                    spoken: "Round \(round), Work \(workTime.spokenText(rounding: .down))"
                )
            }
            return .value("\(round)", caption: .before("Round"), spoken: "Round \(round)")
        }
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
    private func lengthLine(in phase: Phase) -> RingLine? {
        guard let length = workout.phases.first(where: { $0.kind == .work })?.duration ?? phase.duration else {
            return nil
        }
        let spokenLength = length.spokenText(rounding: .up)
        if phase.kind == .prepare {
            return .value(length.clockText, caption: .after("Stopwatch"), spoken: "Stopwatch, \(spokenLength)")
        }
        return .value(length.clockText, caption: .before("of"), spoken: "of \(spokenLength)")
    }
}
