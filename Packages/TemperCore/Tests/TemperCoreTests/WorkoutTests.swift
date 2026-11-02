import Testing

@testable import TemperCore

struct WorkoutTests {
    private func settings(
        prepare: Duration = .seconds(10),
        rounds: Int = 2,
        rest: Duration = .seconds(15),
        cooldown: Duration = .seconds(60)
    ) -> WorkoutSettings {
        WorkoutSettings(prepare: prepare, rounds: rounds, work: .seconds(30), rest: rest, cooldown: cooldown)
    }

    @Test func `Phases run in Workout order with their durations and Rounds`() {
        let expected = [
            Phase(kind: .prepare, duration: .seconds(10)),
            Phase(kind: .work, duration: .seconds(30), round: 1),
            Phase(kind: .rest, duration: .seconds(15), round: 1),
            Phase(kind: .work, duration: .seconds(30), round: 2),
            Phase(kind: .cooldown, duration: .seconds(60)),
        ]

        #expect(settings().makeWorkout() == Workout(phases: expected))
    }

    @Test func `A zero Prepare is dropped, so the Workout opens on Work`() {
        let kinds = settings(prepare: .zero).makeWorkout().phases.map(\.kind)

        #expect(kinds == [.work, .rest, .work, .cooldown])
    }

    @Test func `A zero Rest is dropped, so Works run back to back with their Rounds`() {
        let expected = [
            Phase(kind: .work, duration: .seconds(30), round: 1),
            Phase(kind: .work, duration: .seconds(30), round: 2),
        ]

        #expect(settings(prepare: .zero, rest: .zero, cooldown: .zero).makeWorkout().phases == expected)
    }

    @Test func `A zero Cooldown leaves the last Work as the final Phase`() {
        #expect(settings(cooldown: .zero).makeWorkout().phases.last?.kind == .work)
    }

    @Test func `A single Round has one Work and no Rest`() {
        let kinds = settings(rounds: 1).makeWorkout().phases.map(\.kind)

        #expect(kinds == [.prepare, .work, .cooldown])
    }

    @Test func `A single Round with every optional Phase off is one Work`() {
        let workout = settings(prepare: .zero, rounds: 1, rest: .zero, cooldown: .zero).makeWorkout()

        #expect(workout == Workout(phases: [Phase(kind: .work, duration: .seconds(30), round: 1)]))
    }

    @Test func `The first-launch Workout runs for 08:50 over 8 Rounds`() {
        let workout = WorkoutSettings.firstLaunch.makeWorkout()

        #expect(workout.totalDuration == .seconds(530))
        #expect(workout.rounds == 8)
    }

    @Test func `The total length counts only the Phases that run`() {
        let workout = settings(prepare: .zero, rest: .zero, cooldown: .zero).makeWorkout()

        #expect(workout.totalDuration == .seconds(60))
    }

    @Test func `A Workout with no Rounds reports none`() {
        #expect(Workout(phases: [Phase(kind: .prepare, duration: .seconds(10))]).rounds == 0)
    }

    @Test func `A Workout needs at least one Round`() async {
        await #expect(processExitsWith: .failure) {
            _ = WorkoutSettings(prepare: .zero, rounds: 0, work: .seconds(5), rest: .zero, cooldown: .zero)
                .makeWorkout()
        }
    }

    @Test func `A Round needs a Work`() async {
        await #expect(processExitsWith: .failure) {
            _ = WorkoutSettings(prepare: .zero, rounds: 1, work: .zero, rest: .zero, cooldown: .zero).makeWorkout()
        }
    }
}
