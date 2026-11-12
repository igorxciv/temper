/// The line under the ring: the Round line in a Workout with Rounds, as in Intervals and Open Rounds, and the length
/// in one without, as in a Stopwatch.
public nonisolated enum RingLine: Codable, Hashable, Sendable {
    /// A smaller caption, and which side of the value it sits on.
    public enum Caption: Codable, Hashable, Sendable {
        case before(String)
        case after(String)
    }

    /// A large value, such as a Round number or a length, with a caption beside it, and what VoiceOver says for
    /// the two together.
    case value(String, caption: Caption, spoken: String)
    case paused
}

/// What the running screen shows for a Workout at one snapshot: the time in the ring, how full the ring is, and the
/// line under it, with what VoiceOver says for each. It reads only the Workout, never its Workout Type, so a Plan of
/// any shape shows the same way.
///
/// Every Phase counts down except one that ends at Done, an open Phase or a Stopwatch's Work, which counts up. Counting up is only a display
/// choice, so the engine, the Timeline and the Cue rules are the same for both.
///
/// In Open Rounds, an open Work counts up over the empty track with "Round 3" under it, and the Rest after it counts
/// down with "Round 3 · Work 1:42", the Work time just ended.
///
/// A Stopwatch's Work fills the ring as it counts up to its set length, then keeps counting over the full ring, with
/// "of 10:00" under it, until Done.
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

        /// The time with no leading zero on the minutes, as `0:08`, `12:30` or `72:15`, the way the Plan board writes
        /// times.
        public var shortTime: String {
            time.hasPrefix("0") ? String(time.dropFirst()) : time
        }
    }

    /// The running screen's Done button, which a Workout with a Phase that ends at Done has, as Open Rounds and
    /// Stopwatch do.
    public enum DoneButton: Equatable, Sendable {
        case enabled
        /// Kept in place but dimmed, so nothing moves under the owner's thumb as Work turns to Rest or is Paused, or
        /// as a Stopwatch reaches its set length.
        case disabled
    }

    public let workout: Workout
    public let snapshot: WorkoutSnapshot<Instant>

    public init(workout: Workout, snapshot: WorkoutSnapshot<Instant>) {
        self.workout = workout
        self.snapshot = snapshot
    }

    /// True during a Phase that ends at Done, an open Phase or a Stopwatch's Work, including while it's Paused.
    public var countsUp: Bool {
        snapshot.phase?.endsAtDone ?? false
    }

    /// Done, enabled only in a running open Phase or a running Phase past the set length it runs past, the only times
    /// the engine takes it, or `nil` in a Workout that never waits for Done, as in Intervals.
    public var doneButton: DoneButton? {
        let phases = workout.phases + workout.repeatingRound
        guard phases.contains(where: \.endsAtDone) else { return nil }
        if case .runningOpen = snapshot.progress { return .enabled }
        return .disabled
    }

    /// The ring at `now`. Counting down, the time left rounds up and the ring empties. Counting up, the time
    /// elapsed rounds down and the ring fills, except in an open Phase, which has no length to fill towards and so
    /// draws only the empty track. A Stopwatch's Work past its set length keeps counting over the full ring. Counting
    /// down, the time holds at the Phase's end until the next snapshot. Past an hour the time keeps counting in
    /// minutes, as `72:15`.
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
        let elapsed = snapshot.elapsed(at: now)
        return Ring(
            time: elapsed.clockText(rounding: .down),
            spokenTime: "\(elapsed.spokenText(rounding: .down)) elapsed",
            fill: snapshot.phase?.isOpen == true ? 0 : 1 - fractionLeft
        )
    }

    /// The line under the ring, or `nil` once the Workout has ended or when there's nothing to say.
    public var line: RingLine? {
        guard let phase = snapshot.phase else { return nil }
        if snapshot.isPaused { return .paused }
        // A Workout has no Rounds only when it reports a set number of none.
        return workout.rounds == 0 ? lengthLine(in: phase) : roundLine(in: phase)
    }

    /// A Rest after an open Work shows the Work time just ended, whether or not the Rounds have a set number.
    private func roundLine(in phase: Phase) -> RingLine? {
        if phase.kind == .rest, let round = phase.round, let workTime = snapshot.previousOpenPhaseTime {
            return .value(
                workTime.shortClockText(rounding: .down),
                caption: .before("Round \(round) · Work"),
                spoken: "Round \(round), Work \(workTime.spokenText(rounding: .down))"
            )
        }
        guard let rounds = snapshot.rounds else {
            guard let round = phase.round else { return nil }
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

    /// Prepare shows the length to come, and Work shows the length it counts up to, and keeps showing it past it.
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
