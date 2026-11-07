import Testing

@testable import TemperCore

/// How Intervals builds its Workout.
struct WorkoutTests {
    private func intervals(
        prepare: Duration = .seconds(10),
        rounds: Int = 2,
        rest: Duration = .seconds(15),
        cooldown: Duration = .seconds(60)
    ) -> Workout {
        WorkoutType.intervals.makeWorkout(
            from: WorkoutSettings(prepare: prepare, rounds: rounds, work: .seconds(30), rest: rest, cooldown: cooldown)
        )
    }

    @Test func `Phases run in Workout order with their durations and Rounds`() {
        let expected = [
            Phase(kind: .prepare, duration: .seconds(10)),
            Phase(kind: .work, duration: .seconds(30), round: 1),
            Phase(kind: .rest, duration: .seconds(15), round: 1),
            Phase(kind: .work, duration: .seconds(30), round: 2),
            Phase(kind: .cooldown, duration: .seconds(60)),
        ]

        #expect(intervals() == Workout(phases: expected))
    }

    @Test func `A zero Prepare is dropped, so the Workout opens on Work`() {
        let kinds = intervals(prepare: .zero).phases.map(\.kind)

        #expect(kinds == [.work, .rest, .work, .cooldown])
    }

    @Test func `A zero Rest is dropped, so Works run back to back with their Rounds`() {
        let expected = [
            Phase(kind: .work, duration: .seconds(30), round: 1),
            Phase(kind: .work, duration: .seconds(30), round: 2),
        ]

        #expect(intervals(prepare: .zero, rest: .zero, cooldown: .zero).phases == expected)
    }

    @Test func `A zero Cooldown leaves the last Work as the final Phase`() {
        #expect(intervals(cooldown: .zero).phases.last?.kind == .work)
    }

    @Test func `A single Round has one Work and no Rest`() {
        let kinds = intervals(rounds: 1).phases.map(\.kind)

        #expect(kinds == [.prepare, .work, .cooldown])
    }

    @Test func `A single Round with every optional Phase off is one Work`() {
        let workout = intervals(prepare: .zero, rounds: 1, rest: .zero, cooldown: .zero)

        #expect(workout == Workout(phases: [Phase(kind: .work, duration: .seconds(30), round: 1)]))
    }

    @Test func `The first-launch Workout runs for 08:50 over 8 Rounds`() {
        let workout = WorkoutType.intervals.makeWorkout(from: WorkoutType.intervals.firstLaunch)

        #expect(workout.totalDuration == .seconds(530))
        #expect(workout.rounds == 8)
    }

    @Test func `The total length counts only the Phases that run`() {
        let workout = intervals(prepare: .zero, rest: .zero, cooldown: .zero)

        #expect(workout.totalDuration == .seconds(60))
    }

    @Test func `A Workout with no Rounds reports none`() {
        #expect(Workout(phases: [Phase(kind: .prepare, duration: .seconds(10))]).rounds == 0)
    }

    @Test func `An open Phase has no set length`() {
        let phase = Phase(kind: .work, length: .open, round: 1)

        #expect(phase.isOpen)
        #expect(phase.duration == nil)
        #expect(!Phase(kind: .work, duration: .seconds(30), round: 1).isOpen)
    }

    @Test func `A Workout with an open Phase has no total length and no set number of Rounds`() {
        let workout = Workout(phases: [
            Phase(kind: .work, length: .open, round: 1),
            Phase(kind: .rest, duration: .seconds(60), round: 1),
        ])

        #expect(workout.totalDuration == nil)
        #expect(workout.rounds == nil)
    }

    @Test func `A Workout needs at least one Round`() async {
        await #expect(processExitsWith: .failure) {
            _ = WorkoutType.intervals.makeWorkout(
                from: WorkoutSettings(prepare: .zero, rounds: 0, work: .seconds(5), rest: .zero, cooldown: .zero)
            )
        }
    }

    @Test func `A Round needs a Work`() async {
        await #expect(processExitsWith: .failure) {
            _ = WorkoutType.intervals.makeWorkout(
                from: WorkoutSettings(prepare: .zero, rounds: 1, work: .zero, rest: .zero, cooldown: .zero)
            )
        }
    }
}
