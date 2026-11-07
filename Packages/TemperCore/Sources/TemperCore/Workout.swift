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
public nonisolated struct Workout: Equatable, Sendable {
    public let phases: [Phase]

    public init(phases: [Phase]) {
        self.phases = phases
    }

    /// The length of all its Phases, not counting any Pause, or `nil` if a Phase is open and so has no length.
    public var totalDuration: Duration? {
        phases.reduce(Duration?.some(.zero)) { total, phase in
            guard let total, let duration = phase.duration else { return nil }
            return total + duration
        }
    }

    /// How many Rounds it has, or `nil` if it has no set number, as when a Phase is open. A Stopwatch has none.
    public var rounds: Int? {
        guard !phases.contains(where: \.isOpen) else { return nil }
        return phases.compactMap(\.round).max() ?? 0
    }
}
