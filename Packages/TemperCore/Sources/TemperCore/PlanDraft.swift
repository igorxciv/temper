/// A Workout as a language model writes it from the owner's description, before it's a Plan.
///
/// It's flatter than a Plan, with fewer ways to go wrong for a small on-device model: every Block is Rounds of one
/// Work and one Rest, every length is whole seconds, and zero stands for none. Making the Plan settles what zero
/// means for each Phase, and the activity type comes from the Plan's shape rather than from the model.
public nonisolated struct PlanDraft: Equatable, Sendable {
    /// Rounds of one Work followed by one Rest.
    public struct Block: Equatable, Sendable {
        /// How many Rounds, unless they repeat until Stop.
        public var rounds: Int
        /// Whether the Rounds repeat until the owner Stops, in place of a set number.
        public var untilStop: Bool
        /// Each Work's length in whole seconds, or zero for open Work, which ends when the owner marks it Done, as
        /// for a set with no time given.
        public var workSeconds: Int
        /// Each Rest's length in whole seconds, or zero for no Rest.
        public var restSeconds: Int

        public init(rounds: Int, untilStop: Bool = false, workSeconds: Int, restSeconds: Int) {
            self.rounds = rounds
            self.untilStop = untilStop
            self.workSeconds = workSeconds
            self.restSeconds = restSeconds
        }
    }

    /// The Prepare in whole seconds, or zero for none.
    public var prepareSeconds: Int
    public var blocks: [Block]
    /// The Cooldown in whole seconds, or zero for none.
    public var cooldownSeconds: Int

    public init(prepareSeconds: Int, blocks: [Block], cooldownSeconds: Int) {
        self.prepareSeconds = prepareSeconds
        self.blocks = blocks
        self.cooldownSeconds = cooldownSeconds
    }

    /// The Plan it describes. A Work of zero becomes open, and a zero Prepare, Rest or Cooldown is left out.
    ///
    /// A Plan with open Work is filed as strength training, like Open Rounds, and its Rest says "10 seconds" before it
    /// ends, since the owner isn't watching a clock during the Work. One with only timed Work is filed as interval
    /// training, like Intervals. The Plan still has to make a Workout before it runs.
    public var plan: Plan {
        let prepare =
            prepareSeconds > 0 ? [Plan.Block.phase(PlannedPhase(kind: .prepare, seconds: prepareSeconds))] : []
        let cooldown =
            cooldownSeconds > 0 ? [Plan.Block.phase(PlannedPhase(kind: .cooldown, seconds: cooldownSeconds))] : []
        let rounds = blocks.map { block in
            let work =
                block.workSeconds > 0
                ? PlannedPhase(kind: .work, seconds: block.workSeconds) : PlannedPhase(kind: .work, length: .open)
            let rest = block.restSeconds > 0 ? [PlannedPhase(kind: .rest, seconds: block.restSeconds)] : []
            return Plan.Block.rounds(block.untilStop ? .untilStop : .times(block.rounds), [work] + rest)
        }
        let hasOpenWork = blocks.contains { $0.workSeconds <= 0 }
        return Plan(
            activity: hasOpenWork ? .traditionalStrengthTraining : .highIntensityIntervalTraining,
            blocks: prepare + rounds + cooldown,
            warnsBeforeRestEnds: hasOpenWork
        )
    }
}

extension PlannedPhase {
    fileprivate nonisolated init(kind: Phase.Kind, seconds: Int) {
        self.init(kind: kind, duration: .seconds(seconds))
    }
}
