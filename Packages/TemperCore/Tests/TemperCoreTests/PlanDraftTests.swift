import Testing

@testable import TemperCore

nonisolated struct PlanDraftTests {
    /// "Today I'm training chest: 10 sets at 60% for 1 rep, exactly 1 minute of rest between them, 10 rounds."
    private let chest = PlanDraft(blocks: [
        .init(rounds: 10, phases: [.init(.work, seconds: 0), .init(.rest, seconds: 60)])
    ])

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
        let tabata = PlanDraft(blocks: [
            .init(rounds: 1, phases: [.init(.prepare, seconds: 10)]),
            .init(rounds: 8, phases: [.init(.work, seconds: 20), .init(.rest, seconds: 10)]),
        ])

        #expect(tabata.plan.activity == .highIntensityIntervalTraining)
        #expect(!tabata.plan.warnsBeforeRestEnds)
    }

    @Test func `A Block that runs once with no Work becomes single Phases, and a zero one is left out`() {
        let draft = PlanDraft(blocks: [
            .init(rounds: 1, phases: [.init(.prepare, seconds: 10)]),
            .init(rounds: 8, phases: [.init(.work, seconds: 20), .init(.rest, seconds: 0)]),
            .init(rounds: 1, phases: [.init(.rest, seconds: 0), .init(.cooldown, seconds: 60)]),
        ])

        #expect(
            draft.plan.blocks == [
                .phase(PlannedPhase(kind: .prepare, duration: .seconds(10))),
                .rounds(.times(8), [PlannedPhase(kind: .work, duration: .seconds(20))]),
                .phase(PlannedPhase(kind: .cooldown, duration: .seconds(60))),
            ]
        )
    }

    /// "5 rounds of 30 seconds work and 30 rest, then a 2 minute cooldown, then 5 more rounds, then a 3 minute
    /// cooldown."
    @Test func `A Cooldown can sit between Blocks of Rounds as well as at the end`() throws {
        let round = [PlanDraft.Phase(.work, seconds: 30), .init(.rest, seconds: 30)]
        let draft = PlanDraft(blocks: [
            .init(rounds: 5, phases: round),
            .init(rounds: 1, phases: [.init(.cooldown, seconds: 120)]),
            .init(rounds: 5, phases: round),
            .init(rounds: 1, phases: [.init(.cooldown, seconds: 180)]),
        ])

        let workout = try draft.plan.makeWorkout()

        // Each 5 Rounds is 9 Phases, the last Round skipping its Rest.
        #expect(workout.phases.count == 20)
        #expect(workout.phases[8] == Phase(kind: .work, duration: .seconds(30), round: 5))
        #expect(workout.phases[9] == Phase(kind: .cooldown, duration: .seconds(120)))
        #expect(workout.phases[10] == Phase(kind: .work, duration: .seconds(30), round: 6))
        #expect(workout.phases.last == Phase(kind: .cooldown, duration: .seconds(180)))
        #expect(workout.rounds == 10)
    }

    /// "8 rounds of 20 seconds on and 10 off, rest 1 minute, then rest another 2 minutes, then 8 more."
    @Test func `Rests can follow one another, each its own Phase`() throws {
        let round = [PlanDraft.Phase(.work, seconds: 20), .init(.rest, seconds: 10)]
        let draft = PlanDraft(blocks: [
            .init(rounds: 8, phases: round),
            .init(rounds: 1, phases: [.init(.rest, seconds: 60), .init(.rest, seconds: 120)]),
            .init(rounds: 8, phases: round),
        ])

        #expect(
            draft.plan.blocks[1...2] == [
                .phase(PlannedPhase(kind: .rest, duration: .seconds(60))),
                .phase(PlannedPhase(kind: .rest, duration: .seconds(120))),
            ]
        )
        let workout = try draft.plan.makeWorkout()
        #expect(workout.phases[15...16].map(\.duration) == [.seconds(60), .seconds(120)])
    }

    /// "3 rounds: a set of push-ups, rest 30 seconds, a set of squats, rest 90 seconds."
    @Test func `A Round can hold several Works and Rests`() throws {
        let draft = PlanDraft(blocks: [
            .init(
                rounds: 3,
                phases: [
                    .init(.work, seconds: 0), .init(.rest, seconds: 30), .init(.work, seconds: 0),
                    .init(.rest, seconds: 90),
                ])
        ])

        let workout = try draft.plan.makeWorkout()

        #expect(workout.rounds == 3)
        #expect(workout.phases.filter { $0.round == 1 }.map(\.kind) == [.work, .rest, .work, .rest])
        #expect(workout.phases.filter { $0.round == 3 }.map(\.kind) == [.work, .rest, .work])
    }

    @Test func `A lone Work runs as one Round`() {
        let draft = PlanDraft(blocks: [.init(rounds: 1, phases: [.init(.work, seconds: 300)])])

        #expect(draft.plan.blocks == [.rounds(.times(1), [PlannedPhase(kind: .work, duration: .seconds(300))])])
    }

    @Test func `Rounds until Stop ignore their count`() {
        let draft = PlanDraft(blocks: [
            .init(rounds: 3, untilStop: true, phases: [.init(.work, seconds: 0), .init(.rest, seconds: 90)])
        ])

        #expect(
            draft.plan.blocks == [
                .rounds(
                    .untilStop,
                    [PlannedPhase(kind: .work, length: .open), PlannedPhase(kind: .rest, duration: .seconds(90))])
            ]
        )
    }

    @Test func `A draft that can't run is reported by the Plan, not fixed`() {
        let noRounds = PlanDraft(blocks: [.init(rounds: 0, phases: [.init(.work, seconds: 30)])])
        let restsRepeated = PlanDraft(blocks: [.init(rounds: 3, phases: [.init(.rest, seconds: 30)])])

        #expect(throws: PlanProblem.roundCountOutOfRange(block: 0)) { try noRounds.plan.makeWorkout() }
        #expect(throws: PlanProblem.roundsWithoutWork(block: 0)) { try restsRepeated.plan.makeWorkout() }
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

    @Test func `Exercises named in the description reach the Plan's Works, trimmed`() {
        let circuit = PlanDraft(blocks: [
            .init(
                rounds: 3,
                phases: [
                    .init(.work, seconds: 30, exercise: "  Squats "), .init(.rest, seconds: 15),
                    .init(.work, seconds: 30, exercise: "Push-ups"), .init(.rest, seconds: 15),
                ])
        ])

        #expect(
            circuit.plan.blocks == [
                .rounds(
                    .times(3),
                    [
                        PlannedPhase(kind: .work, duration: .seconds(30), exercise: Exercise("Squats")),
                        PlannedPhase(kind: .rest, duration: .seconds(15)),
                        PlannedPhase(kind: .work, duration: .seconds(30), exercise: Exercise("Push-ups")),
                        PlannedPhase(kind: .rest, duration: .seconds(15)),
                    ]
                )
            ])
    }

    @Test func `A blank Exercise is none, and a long one keeps its first 24 characters`() throws {
        let draft = PlanDraft(blocks: [
            .init(
                rounds: 1,
                phases: [
                    .init(.work, seconds: 30, exercise: "   "),
                    .init(.work, seconds: 30, exercise: "Single-arm kettlebell swings"),
                ])
        ])

        guard case .rounds(_, let phases) = try #require(draft.plan.blocks.first) else {
            Issue.record("Expected Rounds")
            return
        }
        #expect(phases.map(\.exercise?.name) == [nil, "Single-arm kettlebell sw"])
    }
}
