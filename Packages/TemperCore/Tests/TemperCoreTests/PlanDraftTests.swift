import Testing

@testable import TemperCore

nonisolated struct PlanDraftTests {
    /// "Today I'm training chest: 10 sets at 60% for 1 rep, exactly 1 minute of rest between them, 10 rounds."
    private let chest = PlanDraft(
        prepareSeconds: 0,
        blocks: [PlanDraft.Block(rounds: 10, workSeconds: 0, restSeconds: 60)],
        cooldownSeconds: 0
    )

    @Test func `Sets with no time given become open Work, with the Rest exactly as said`() throws {
        let plan = chest.plan

        #expect(
            plan.blocks == [
                .rounds(
                    .times(10),
                    [PlannedPhase(kind: .work, length: .open), PlannedPhase(kind: .rest, duration: .seconds(60))]
                )
            ]
        )
        let workout = try plan.makeWorkout()
        #expect(workout.rounds == 10)
        #expect(Array(workout.phasesInOrder).last == Phase(kind: .work, length: .open, round: 10))
    }

    @Test func `Open Work is filed as strength and warns before a Rest ends, as Open Rounds does`() {
        #expect(chest.plan.activity == .traditionalStrengthTraining)
        #expect(chest.plan.warnsBeforeRestEnds)
    }

    @Test func `Only timed Work is filed as interval training, with no warning, as Intervals is`() {
        let tabata = PlanDraft(
            prepareSeconds: 10, blocks: [.init(rounds: 8, workSeconds: 20, restSeconds: 10)], cooldownSeconds: 0)

        #expect(tabata.plan.activity == .highIntensityIntervalTraining)
        #expect(!tabata.plan.warnsBeforeRestEnds)
    }

    @Test func `A zero Prepare, Rest or Cooldown is left out, and the others become single Phases`() {
        let draft = PlanDraft(
            prepareSeconds: 10, blocks: [.init(rounds: 8, workSeconds: 20, restSeconds: 0)], cooldownSeconds: 60)

        #expect(
            draft.plan.blocks == [
                .phase(PlannedPhase(kind: .prepare, duration: .seconds(10))),
                .rounds(.times(8), [PlannedPhase(kind: .work, duration: .seconds(20))]),
                .phase(PlannedPhase(kind: .cooldown, duration: .seconds(60))),
            ]
        )
    }

    @Test func `Rounds until Stop ignore their count`() {
        let draft = PlanDraft(
            prepareSeconds: 0, blocks: [.init(rounds: 3, untilStop: true, workSeconds: 0, restSeconds: 90)],
            cooldownSeconds: 0)

        #expect(
            draft.plan.blocks == [
                .rounds(
                    .untilStop,
                    [PlannedPhase(kind: .work, length: .open), PlannedPhase(kind: .rest, duration: .seconds(90))])
            ]
        )
    }

    @Test func `A draft that can't run is reported by the Plan, not fixed`() {
        let noRounds = PlanDraft(
            prepareSeconds: 0, blocks: [.init(rounds: 0, workSeconds: 30, restSeconds: 0)], cooldownSeconds: 0)

        #expect(throws: PlanProblem.roundCountOutOfRange(block: 0)) { try noRounds.plan.makeWorkout() }
    }

    // MARK: Outline

    @Test func `The outline gives each Block on a line`() {
        let plan = Plan(
            activity: .other,
            blocks: [
                .phase(PlannedPhase(kind: .prepare, duration: .seconds(10))),
                .rounds(
                    .times(10),
                    [PlannedPhase(kind: .work, length: .open), PlannedPhase(kind: .rest, duration: .seconds(60))]
                ),
                .rounds(.times(1), [PlannedPhase(kind: .work, length: .runsPast(.seconds(600)))]),
                .rounds(.untilStop, [PlannedPhase(kind: .work, length: .open)]),
            ]
        )

        #expect(
            plan.outline == [
                "Prepare 0:10",
                "10 Rounds · Work until Done · Rest 1:00",
                "1 Round · Work 10:00, then until Done",
                "Rounds until Stop · Work until Done",
            ]
        )
    }
}
