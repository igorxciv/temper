import Testing

@testable import TemperCore

struct PlanTests {
    private let openWork = PlannedPhase(kind: .work, length: .open)
    private let rest = PlannedPhase(kind: .rest, duration: .seconds(60))

    private func workout(_ blocks: [Plan.Block], warns: Bool = false) throws(PlanProblem) -> Workout {
        try Plan(activity: .traditionalStrengthTraining, blocks: blocks, warnsBeforeRestEnds: warns).makeWorkout()
    }

    private func problem(_ blocks: [Plan.Block]) -> PlanProblem? {
        do {
            _ = try workout(blocks)
            return nil
        } catch {
            return error
        }
    }

    @Test func `10 Rounds of open Work and a 1:00 Rest end on the last Work, with no Rest after it`() throws {
        let workout = try workout([.rounds(.times(10), [openWork, rest])])

        let phases = Array(workout.phasesInOrder)
        #expect(phases.count == 19)
        #expect(
            phases.prefix(2) == [
                Phase(kind: .work, length: .open, round: 1),
                Phase(kind: .rest, duration: .seconds(60), round: 1),
            ])
        #expect(phases.last == Phase(kind: .work, length: .open, round: 10))
        #expect(workout.repeatingRound.isEmpty)
    }

    @Test func `Only the Rest that ends the last Round is left out`() throws {
        let work = PlannedPhase(kind: .work, duration: .seconds(30))
        let workout = try workout([.rounds(.times(2), [rest, work, rest])])

        #expect(
            workout.phases == [
                Phase(kind: .rest, duration: .seconds(60), round: 1),
                Phase(kind: .work, duration: .seconds(30), round: 1),
                Phase(kind: .rest, duration: .seconds(60), round: 1),
                Phase(kind: .rest, duration: .seconds(60), round: 2),
                Phase(kind: .work, duration: .seconds(30), round: 2),
            ])
    }

    @Test func `Rounds Blocks one after another keep counting Rounds`() throws {
        let work = PlannedPhase(kind: .work, duration: .seconds(30))
        let workout = try workout([
            .rounds(.times(2), [work]),
            .phase(rest),
            .rounds(.times(1), [work]),
        ])

        #expect(workout.phases.map(\.round) == [1, 2, nil, 3])
    }

    @Test func `A later Rounds Block also leaves out the Rest that ends its last Round`() throws {
        let workout = try workout([.rounds(.times(2), [openWork, rest]), .rounds(.times(2), [openWork, rest])])

        #expect(workout.phases.map(\.kind) == [.work, .rest, .work, .work, .rest, .work])
        #expect(workout.phases.map(\.round) == [1, 1, 2, 3, 3, 4])
    }

    @Test func `Rounds until Stop repeat after the set Rounds, numbered on from them`() throws {
        let work = PlannedPhase(kind: .work, duration: .seconds(30))
        let workout = try workout([.rounds(.times(2), [work]), .rounds(.untilStop, [openWork, rest])], warns: true)

        #expect(workout.warnsBeforeRestEnds)
        #expect(Array(workout.phasesInOrder.prefix(4).map(\.round)) == [1, 2, 3, 3])
    }

    @Test func `A Plan with no Blocks makes no Workout`() {
        #expect(problem([]) == .noPhases)
    }

    @Test(arguments: [Phase.Length.set(.zero), .set(.seconds(1805)), .runsPast(.zero), .runsPast(.seconds(1805))])
    func `A length of zero or past 30:00 makes no Workout`(length: Phase.Length) {
        let work = PlannedPhase(kind: .work, length: length)

        #expect(problem([.phase(rest), .phase(work)]) == .lengthOutOfRange(block: 1))
        #expect(problem([.rounds(.times(3), [work])]) == .lengthOutOfRange(block: 0))
    }

    @Test func `A length of exactly 30:00 is allowed`() {
        #expect(problem([.phase(PlannedPhase(kind: .work, duration: .seconds(1800)))]) == nil)
    }

    @Test(arguments: [0, 100])
    func `Rounds outside 1 to 99 make no Workout`(times: Int) {
        #expect(problem([.rounds(.times(times), [openWork])]) == .roundCountOutOfRange(block: 0))
    }

    @Test func `Rounds with no Work make no Workout`() {
        #expect(problem([.rounds(.times(3), [rest])]) == .roundsWithoutWork(block: 0))
        #expect(problem([.rounds(.untilStop, [])]) == .roundsWithoutWork(block: 0))
    }

    @Test func `Rounds until Stop need an open Phase, so they wait on Done`() {
        let work = PlannedPhase(kind: .work, length: .runsPast(.seconds(30)))

        #expect(problem([.rounds(.untilStop, [work, rest])]) == .untilStopWithoutOpenPhase(block: 0))
    }

    @Test func `Nothing can follow Rounds until Stop`() {
        #expect(problem([.rounds(.untilStop, [openWork]), .phase(rest)]) == .blockAfterUntilStop(block: 1))
    }

    @Test func `Each Workout Type's Plan files its Health workout as that type does`() {
        for type in WorkoutType.allCases {
            #expect(type.plan(from: type.firstLaunch).activity == HealthRecord.ActivityType(type))
        }
    }

    @Test func `Intervals is a Prepare, Rounds of Work and Rest, and a Cooldown`() {
        let plan = WorkoutType.intervals.plan(from: WorkoutType.intervals.firstLaunch)

        #expect(
            plan.blocks == [
                .phase(PlannedPhase(kind: .prepare, duration: .seconds(10))),
                .rounds(
                    .times(8),
                    [
                        PlannedPhase(kind: .work, duration: .seconds(40)),
                        PlannedPhase(kind: .rest, duration: .seconds(20)),
                    ]
                ),
                .phase(PlannedPhase(kind: .cooldown, duration: .seconds(60))),
            ])
    }
}
