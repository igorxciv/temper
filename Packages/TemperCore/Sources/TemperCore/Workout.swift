/// A single period within a Workout, which ends at its set length or, if it is open, when the owner marks it Done.
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
    public enum Length: Equatable, Sendable {
        /// It ends once this much active time has passed.
        case set(Duration)
        /// It has no set length, and ends only when the owner marks it Done.
        case open
    }

    public let kind: Kind
    public let length: Length
    /// The Round a Work or Rest in Intervals belongs to. Prepare, Cooldown and a Stopwatch's Work have none.
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

    /// Its set length, or `nil` if it's open.
    public var duration: Duration? {
        if case .set(let duration) = length { duration } else { nil }
    }

    public var isOpen: Bool {
        length == .open
    }
}

/// A timed run of Phases, of one Workout Type.
///
/// The Phases are a flat list rather than Rounds, so later training with several stages can reuse the timer.
///
/// A Phase can be open, with no set length, so it ends only when the owner marks it Done. Nothing after an open
/// Phase can be placed in time until then, and a Workout with one has no total length.
///
/// A Workout can end in a repeating Round: a group of Phases, holding at least one open Phase, that runs again
/// and again until Stop. Each repetition is produced as it's reached, never all at once, and numbered as the
/// next Round after any in `phases`. Such a Workout never finishes, so it has no total length and no set number
/// of Rounds. Open Rounds is a repeating Round of an open Work and a Rest, with nothing before it.
public nonisolated struct Workout: Equatable, Sendable {
    /// The Phases that run once, in order.
    public let phases: [Phase]
    /// The Phases of the Round that repeats after `phases` until Stop, or none. Their own Round is ignored, since
    /// each repetition is numbered as it's reached.
    public let repeatingRound: [Phase]

    public init(phases: [Phase], repeatingRound: [Phase] = []) {
        // Without an open Phase to wait on, a repeating Round would place Phases forever.
        precondition(
            repeatingRound.isEmpty || repeatingRound.contains(where: \.isOpen),
            "A repeating Round has an open Phase"
        )
        self.phases = phases
        self.repeatingRound = repeatingRound
    }

    /// The length of all its Phases, not counting any Pause, or `nil` if a Phase is open or Rounds repeat, and so
    /// it has no length.
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
        return phases.compactMap(\.round).max() ?? 0
    }

    /// Every Phase in the order it runs: `phases`, then the repeating Round again and again, each repetition
    /// numbered as the next Round. With a repeating Round it never ends, so read only as far as needed.
    var phasesInOrder: some Sequence<Phase> {
        let firstRepeat = (phases.compactMap(\.round).max() ?? 0) + 1
        return sequence(state: 0) { [phases, repeatingRound] index -> Phase? in
            defer { index += 1 }
            if index < phases.count { return phases[index] }
            guard !repeatingRound.isEmpty else { return nil }
            let (repetition, offset) = (index - phases.count).quotientAndRemainder(dividingBy: repeatingRound.count)
            let phase = repeatingRound[offset]
            return Phase(kind: phase.kind, length: phase.length, round: firstRepeat + repetition)
        }
    }
}
