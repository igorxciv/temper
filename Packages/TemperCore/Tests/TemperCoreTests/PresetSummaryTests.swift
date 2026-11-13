import Testing

@testable import TemperCore

struct PresetSummaryTests {
    @Test func `An Intervals summary reads Rounds × Work / Rest`() {
        let list = PresetList(workoutType: .intervals)
        let preset = Preset(
            name: "Tabata",
            settings: WorkoutSettings(
                prepare: .seconds(5),
                rounds: 8,
                work: .seconds(20),
                rest: .seconds(30),
                cooldown: .seconds(10)
            )
        )

        #expect(list.summary(of: preset) == "8 × 0:20 / 0:30")
    }

    @Test func `An Intervals summary with no Rest reads Off`() {
        let list = PresetList(workoutType: .intervals)
        let preset = Preset(
            name: "Long",
            settings: WorkoutSettings(
                prepare: .zero,
                rounds: 12,
                work: .seconds(1800),
                rest: .zero,
                cooldown: .zero
            )
        )

        #expect(list.summary(of: preset) == "12 × 30:00 / Off")
    }

    @Test func `A Stopwatch summary is its length`() {
        let list = PresetList(workoutType: .stopwatch)

        #expect(list.summary(of: Preset(name: "Run", settings: WorkoutType.stopwatch.firstLaunch)) == "10:00")
    }

    @Test func `An Open Rounds summary is its Rest, or Off`() {
        let list = PresetList(workoutType: .openRounds)
        var noRest = WorkoutType.openRounds.firstLaunch
        noRest[.rest] = 0

        #expect(list.summary(of: Preset(name: "Heavy", settings: WorkoutType.openRounds.firstLaunch)) == "Rest 1:00")
        #expect(list.summary(of: Preset(name: "Circuit", settings: noRest)) == "Rest Off")
    }

    @Test func `An Open Rounds summary with a number of Rounds puts them before its Rest`() {
        let list = PresetList(workoutType: .openRounds)
        var five = WorkoutType.openRounds.firstLaunch
        five[.rounds] = 5
        var one = five
        one[.rounds] = 1
        one[.rest] = 0

        #expect(list.summary(of: Preset(name: "Five", settings: five)) == "5 Rounds · Rest 1:00")
        #expect(list.summary(of: Preset(name: "One", settings: one)) == "1 Round · Rest Off")
    }
}
