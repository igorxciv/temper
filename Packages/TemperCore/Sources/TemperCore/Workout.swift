/// A single period within a Workout, which ends at its set length or, if it is open or runs past its set length,
/// when the owner marks it Done.
public nonisolated struct Phase: Equatable, Sendable {
    /// The raw value is what a Live Activity stores, so renaming a case breaks one that's showing.
    public enum Kind: String, Codable, Equatable, Sendable {
        case prepare, work, rest, cooldown

        /// The name the running screen and the Live Activity show.
        public var name: String {
            switch self {
            case .prepare: "Prepare"
            case .work: "Work"
            case .rest: "Rest"
            case .cooldown: "Cooldown"
            }
        }
    }

    /// How long a Phase runs.
    ///
    /// Open is a length rather than a fifth `Kind`, so any Phase, a Rest included, can be open, and the kinds a Live
    /// Activity stores stay as they are.
    public enum Length: Equatable, Sendable {
        /// It ends once this much active time has passed.
        case set(Duration)
        /// It has no set length, and ends only when the owner marks it Done. Unlike a set time, which stops at 30:00,
        /// it has no cap, so a forgotten Workout keeps counting until Stop rather than ending by itself. A locked iPhone
        /// has been seen to keep an open Work running past 30 minutes.
        case open
        /// It counts towards this length and says "Finish" once that much active time has passed, then keeps
        /// counting, with no cap, until the owner marks it Done. A Stopwatch's Work runs past its set length, since
        /// an exercise can take longer than planned.
        case runsPast(Duration)
    }

    public let kind: Kind
    public let length: Length
    /// The Round a Work or Rest in Intervals or Open Rounds belongs to. Prepare, Cooldown and a Stopwatch's Work have
    /// none.
    public let round: Int?

    public init(kind: Kind, length: Length, round: Int? = nil) {
        self.kind = kind
        self.length = length
        self.round = round
    }

    /// A Phase with a set length.
    public init(kind: Kind, duration: Duration, round: Int? = nil) {
        self.init(kind: kind, length: .set(duration), round: round)
    }

    /// Its set length, or `nil` if it's open. A Phase that runs past its set length doesn't end there.
    public var duration: Duration? {
        switch length {
        case .set(let duration), .runsPast(let duration): duration
        case .open: nil
        }
    }

    public var isOpen: Bool {
        length == .open
    }

    public var runsPastSetLength: Bool {
        if case .runsPast = length { true } else { false }
    }

    /// Whether it ends only at Done: an open Phase, or one that runs past its set length.
    var endsAtDone: Bool {
        isOpen || runsPastSetLength
    }
}

/// A timed run of Phases, of one Workout Type.
///
/// Its Phases are kept in flat lists rather than as Rounds, so later training with several stages can reuse the
/// timer.
///
/// A Phase can be open, with no set length, so it ends only when the owner marks it Done. Nothing after an open
/// Phase can be placed in time until then, and a Workout with one has no total length.
///
/// A Workout can end in a repeating Round: a group of Phases, holding at least one open Phase, that runs again
/// and again until Stop. Each time it repeats, its Phases are produced as they're reached, never all at once,
/// and numbered as the next Round after any in `phases`. Such a Workout never finishes, so it has no total length and no set number
/// of Rounds. Open Rounds is a repeating Round of an open Work and a Rest, after a Prepare if one is set.
public nonisolated struct Workout: Equatable, Sendable {
    /// The Phases that run once, in order.
    public let phases: [Phase]
    /// The Phases of the Round that repeats after `phases` until Stop, or none. Their own Round is ignored, since
    /// each time they repeat they're numbered as the next Round.
    public let repeatingRound: [Phase]
    /// Whether a Rest long enough says "10 seconds" before it ends, as in Open Rounds.
    public let warnsBeforeRestEnds: Bool

    public init(phases: [Phase], repeatingRound: [Phase] = [], warnsBeforeRestEnds: Bool = false) {
        // Without an open Phase to wait on, a repeating Round would place Phases forever.
        precondition(
            repeatingRound.isEmpty || repeatingRound.contains(where: \.isOpen),
            "A repeating Round has an open Phase"
        )
        self.phases = phases
        self.repeatingRound = repeatingRound
        self.warnsBeforeRestEnds = warnsBeforeRestEnds
    }

    /// The length of all its Phases, not counting any Pause, or `nil` if a Phase is open or Rounds repeat, and so
    /// it has no length. A Phase that runs past its set length counts its set length, so this is the length the
    /// owner set, not the time the Workout will take.
    public var totalDuration: Duration? {
        guard repeatingRound.isEmpty else { return nil }
        return phases.reduce(Duration?.some(.zero)) { total, phase in
            guard let total, let duration = phase.duration else { return nil }
            return total + duration
        }
    }

    /// How many Rounds it has, or `nil` if it has no set number, as when a Phase is open or Rounds repeat. A
    /// Stopwatch has none.
    public var rounds: Int? {
        guard repeatingRound.isEmpty, !phases.contains(where: \.isOpen) else { return nil }
        return lastRound
    }

    /// The highest Round in `phases`, or 0 if none has one.
    private var lastRound: Int {
        phases.compactMap(\.round).max() ?? 0
    }

    /// Every Phase in the order it runs: `phases`, then the repeating Round again and again, numbered as the
    /// next Round each time. With a repeating Round it never ends, so read only as far as needed.
    var phasesInOrder: some Sequence<Phase> {
        let firstRepeatingRound = lastRound + 1
        return sequence(state: 0) { [phases, repeatingRound] index -> Phase? in
            defer { index += 1 }
            if index < phases.count { return phases[index] }
            guard !repeatingRound.isEmpty else { return nil }
            let (roundsBefore, offset) = (index - phases.count).quotientAndRemainder(dividingBy: repeatingRound.count)
            let phase = repeatingRound[offset]
            return Phase(kind: phase.kind, length: phase.length, round: firstRepeatingRound + roundsBefore)
        }
    }
}
