import Testing

@testable import TemperCore

struct WorkoutTests {
    private func workout(rounds: Int, cooldown: Duration = .zero) -> Workout {
        Workout(prepare: .seconds(10), rounds: rounds, work: .seconds(30), rest: .seconds(15), cooldown: cooldown)
    }

    @Test(arguments: [1, 2, 8])
    func `N Rounds give N Works and one fewer Rests`(rounds: Int) {
        let kinds = workout(rounds: rounds).phases.map(\.kind)

        #expect(kinds.count(where: { $0 == .work }) == rounds)
        #expect(kinds.count(where: { $0 == .rest }) == rounds - 1)
    }

    @Test func `Phases run in Workout order with their durations`() {
        let expected = [
            Phase(kind: .prepare, duration: .seconds(10)),
            Phase(kind: .work, duration: .seconds(30)),
            Phase(kind: .rest, duration: .seconds(15)),
            Phase(kind: .work, duration: .seconds(30)),
            Phase(kind: .cooldown, duration: .seconds(60)),
        ]

        #expect(workout(rounds: 2, cooldown: .seconds(60)).phases == expected)
    }

    @Test func `A zero Cooldown leaves the last Work as the final Phase`() {
        #expect(workout(rounds: 2).phases.last?.kind == .work)
    }
}
