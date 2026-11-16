/// A Workout as a language model writes it from the owner's description, before it's a Plan.
///
/// It has the Plan's freedom, Blocks of any Phases in any order, in a flatter shape that leaves fewer ways to go wrong
/// for a small on-device model. Every Block is Rounds of a list of Phases, and one that runs once with no Work stands
/// for single Phases, such as a Prepare, a Cooldown or a Rest between two Blocks. Every length is whole seconds, and
/// zero stands for none. Making the Plan settles what that means for each, and the activity type comes from the Plan's
/// shape rather than from the model.
public nonisolated struct PlanDraft: Equatable, Sendable {
    /// One Phase of a Block.
    public struct Phase: Equatable, Sendable {
        public var kind: TemperCore.Phase.Kind
        /// Its length in whole seconds. Zero makes a Work open, so it ends when the owner marks it Done, as for a set
        /// with no time given, and leaves out any other Phase.
        public var seconds: Int
        /// The exercise the owner named for a Work, as written. Making the Plan trims it, and drops one that's blank
        /// or on any other kind of Phase.
        public var exercise: String?

        public init(_ kind: TemperCore.Phase.Kind, seconds: Int, exercise: String? = nil) {
            self.kind = kind
            self.seconds = seconds
            self.exercise = exercise
        }
    }

    /// Phases that run, in order, a number of times.
    public struct Block: Equatable, Sendable {
        /// How many Rounds, unless they repeat until Stop. One for Phases that run once.
        public var rounds: Int
        /// Whether the Rounds repeat until the owner Stops, in place of a set number.
        public var untilStop: Bool
        public var phases: [Phase]

        public init(rounds: Int, untilStop: Bool = false, phases: [Phase]) {
            self.rounds = rounds
            self.untilStop = untilStop
            self.phases = phases
        }
    }

    /// Every part of the Workout, in the order it runs.
    public var blocks: [Block]

    public init(blocks: [Block]) {
        self.blocks = blocks
    }

    /// The Plan it describes. A Work of zero becomes open, and any other Phase of zero is left out. A Block that runs
    /// once and holds no Work becomes a single Phase for each of its Phases, so a Prepare, a Cooldown or a Rest
    /// belongs to no Round. Any other Block becomes Rounds, even one with no Work, which the Plan then refuses.
    ///
    /// A Plan with open Work is filed as strength training, like Open Rounds, and its Rest says "10 seconds" before it
    /// ends, since the owner isn't watching a clock during the Work. One with only timed Work is filed as interval
    /// training, like Intervals. The Plan still has to make a Workout before it runs.
    public var plan: Plan {
        let planned = blocks.map { block in
            (block, block.phases.compactMap(PlannedPhase.init(drafted:)))
        }
        let planBlocks = planned.flatMap { block, phases -> [Plan.Block] in
            if !block.untilStop, block.rounds == 1, !phases.contains(where: { $0.kind == .work }) {
                return phases.map(Plan.Block.phase)
            }
            return [.rounds(block.untilStop ? .untilStop : .times(block.rounds), phases)]
        }
        let hasOpenWork = planned.contains { _, phases in
            phases.contains { $0.kind == .work && $0.length == .open }
        }
        return Plan(
            activity: hasOpenWork ? .traditionalStrengthTraining : .highIntensityIntervalTraining,
            blocks: planBlocks,
            warnsBeforeRestEnds: hasOpenWork
        )
    }
}

extension PlannedPhase {
    /// The drafted Phase, or `nil` for a Phase other than Work with no length, which is left out.
    fileprivate nonisolated init?(drafted: PlanDraft.Phase) {
        let exercise = drafted.kind == .work ? drafted.exercise.flatMap(Exercise.init) : nil
        if drafted.seconds > 0 {
            self.init(kind: drafted.kind, duration: .seconds(drafted.seconds), exercise: exercise)
        } else if drafted.kind == .work {
            self.init(kind: .work, length: .open, exercise: exercise)
        } else {
            return nil
        }
    }
}
