/// A Workout described as Blocks, free to combine in any order, which builds the Workout the engine runs.
///
/// Each Workout Type is a built-in Plan. A Plan can also take shapes no Workout Type has, such as a set number of
/// Rounds of open Work, so it's what a Workout described in words is turned into.
///
/// A Plan has no Off: a Phase that doesn't run is left out, rather than given a length of zero.
public nonisolated struct Plan: Equatable, Sendable {
    /// One part of a Plan.
    public enum Block: Equatable, Sendable {
        /// How many times a Rounds Block runs its Phases.
        public enum Count: Equatable, Sendable {
            /// A set number of Rounds, from 1 to 99.
            case times(Int)
            /// Again and again until Stop. It must be the last Block and hold an open Phase, or it would never wait
            /// for anything.
            case untilStop
        }

        /// A single Phase, which runs once and belongs to no Round.
        case phase(PlannedPhase)
        /// A group of Phases, holding at least one Work, that runs as one Round after another, each numbered as the
        /// next Round of the Workout. The last of a set number of Rounds leaves out any Rest that ends it, so the
        /// Workout doesn't end on a Rest.
        case rounds(Count, [PlannedPhase])
    }

    /// The kind of exercise its Health workout is filed under.
    public var activity: HealthRecord.ActivityType
    public var blocks: [Block]
    /// Whether a Rest long enough says "10 seconds" before it ends.
    public var warnsBeforeRestEnds: Bool

    public init(activity: HealthRecord.ActivityType, blocks: [Block], warnsBeforeRestEnds: Bool = false) {
        self.activity = activity
        self.blocks = blocks
        self.warnsBeforeRestEnds = warnsBeforeRestEnds
    }

    /// The most Rounds a Rounds Block can set, as setup's wheel allows.
    public static let maximumRounds = 99
    /// The longest set length a Phase can have. A locked iPhone has been seen to stay alive through 30 minutes of
    /// silence between Cues, and no longer.
    public static let longestPhase = Duration.seconds(1800)

    /// The Workout this Plan describes, or the first problem that stops it from running.
    public func makeWorkout() throws(PlanProblem) -> Workout {
        guard !blocks.isEmpty else { throw .noPhases }
        var phases: [Phase] = []
        var repeatingRound: [Phase] = []
        var round = 0
        for (index, block) in blocks.enumerated() {
            guard repeatingRound.isEmpty else { throw .blockAfterUntilStop(block: index) }
            switch block {
            case .phase(let planned):
                try planned.check(inBlock: index)
                phases.append(planned.phase(round: nil))
            case .rounds(let count, let group):
                for planned in group {
                    try planned.check(inBlock: index)
                }
                guard group.contains(where: { $0.kind == .work }) else { throw .roundsWithoutWork(block: index) }
                switch count {
                case .times(let times):
                    guard (1...Self.maximumRounds).contains(times) else { throw .roundCountOutOfRange(block: index) }
                    let lastRound = group.reversed().drop { $0.kind == .rest }.reversed()
                    for repetition in 1...times {
                        round += 1
                        let thisRound = round
                        phases += (repetition == times ? Array(lastRound) : group).map { $0.phase(round: thisRound) }
                    }
                case .untilStop:
                    guard group.contains(where: { $0.length == .open }) else {
                        throw .untilStopWithoutOpenPhase(block: index)
                    }
                    // The Workout numbers each repeat as the next Round itself.
                    repeatingRound = group.map { $0.phase(round: nil) }
                }
            }
        }
        return Workout(phases: phases, repeatingRound: repeatingRound, warnsBeforeRestEnds: warnsBeforeRestEnds)
    }
}

/// A Phase as a Plan sets it out, before it's placed in a Round.
public nonisolated struct PlannedPhase: Equatable, Sendable {
    public var kind: Phase.Kind
    public var length: Phase.Length

    public init(kind: Phase.Kind, length: Phase.Length) {
        self.kind = kind
        self.length = length
    }

    /// A Phase with a set length.
    public init(kind: Phase.Kind, duration: Duration) {
        self.init(kind: kind, length: .set(duration))
    }

    fileprivate func check(inBlock block: Int) throws(PlanProblem) {
        guard let duration = Phase(kind: kind, length: length).duration else { return }
        guard duration > .zero, duration <= Plan.longestPhase else { throw .lengthOutOfRange(block: block) }
    }

    fileprivate func phase(round: Int?) -> Phase {
        Phase(kind: kind, length: length, round: round)
    }
}

/// What stops a Plan from making a Workout. Each names the Block it's in, counted from 0.
public nonisolated enum PlanProblem: Error, Equatable, Sendable {
    /// The Plan has no Blocks.
    case noPhases
    /// A set length, or a length a Phase runs past, is zero or longer than 30:00.
    case lengthOutOfRange(block: Int)
    /// A Rounds Block has no Work.
    case roundsWithoutWork(block: Int)
    /// A Rounds Block sets fewer than 1 or more than 99 Rounds.
    case roundCountOutOfRange(block: Int)
    /// A Rounds Block that runs until Stop has no open Phase, so it would never wait for Done.
    case untilStopWithoutOpenPhase(block: Int)
    /// A Block comes after Rounds that run until Stop, so it would never be reached.
    case blockAfterUntilStop(block: Int)

    /// What Describe says when a Plan made from the owner's words can't run.
    public var explanation: String {
        switch self {
        case .noPhases: "It has nothing to run."
        case .lengthOutOfRange: "A time is zero or longer than 30 minutes."
        case .roundsWithoutWork: "Some Rounds have no Work."
        case .roundCountOutOfRange: "It asks for fewer than 1 or more than 99 Rounds."
        case .untilStopWithoutOpenPhase: "Rounds that repeat until Stop need a Work that ends at Done."
        case .blockAfterUntilStop: "Something comes after Rounds that repeat until Stop."
        }
    }
}
