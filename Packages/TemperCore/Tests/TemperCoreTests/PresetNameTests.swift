import Testing

@testable import TemperCore

struct PresetNameTests {
    private func intervals(named names: String...) throws -> PresetList {
        var list = PresetList(workoutType: .intervals)
        for name in names {
            try list.saveAsNew(named: name, settings: WorkoutType.intervals.firstLaunch)
        }
        return list
    }

    @Test func `A name with no problem passes`() throws {
        #expect(try intervals(named: "Tabata").nameProblem("Long") == nil)
    }

    @Test(arguments: ["", " ", "\n", " \t\n "])
    func `A name that is empty once trimmed is empty`(name: String) throws {
        #expect(try intervals().nameProblem(name) == .empty)
    }

    @Test func `Spaces and newlines around a name are trimmed, and the trimmed name is saved`() throws {
        var list = try intervals()

        try list.saveAsNew(named: "  Tabata \n", settings: WorkoutType.intervals.firstLaunch)

        #expect(list.picked?.name == "Tabata")
        #expect(list.nameProblem("Tabata\n") == .taken(existingName: "Tabata", workoutType: .intervals))
    }

    @Test func `A name of 30 characters passes, counting an emoji as one`() throws {
        let list = try intervals()

        #expect(list.nameProblem(String(repeating: "a", count: 30)) == nil)
        #expect(list.nameProblem(String(repeating: "a", count: 29) + "🏋️‍♀️") == nil)
        #expect(list.nameProblem("  " + String(repeating: "a", count: 30) + "  ") == nil)
    }

    @Test func `A name of 31 characters is too long`() throws {
        let list = try intervals()

        #expect(list.nameProblem(String(repeating: "a", count: 31)) == .tooLong)
        #expect(list.nameProblem(String(repeating: "🏋️‍♀️", count: 31)) == .tooLong)
    }

    @Test func `A name another Preset of the type has, ignoring case, is taken`() throws {
        let list = try intervals(named: "Tabata", "Long")

        #expect(list.nameProblem("tABATA") == .taken(existingName: "Tabata", workoutType: .intervals))
    }

    @Test func `Each Workout Type's names are its own`() throws {
        var stopwatch = PresetList(workoutType: .stopwatch)
        try stopwatch.saveAsNew(named: "Morning", settings: WorkoutType.stopwatch.firstLaunch)

        #expect(try intervals(named: "Morning").picked?.name == "Morning")
        #expect(stopwatch.picked?.name == "Morning")
    }

    @Test func `An empty name is reported before a long one`() throws {
        #expect(try intervals().nameProblem(String(repeating: " ", count: 40)) == .empty)
    }

    @Test func `Saving a name with a problem throws it and leaves the list alone`() throws {
        var list = try intervals(named: "Tabata")
        let before = list

        #expect(throws: PresetNameProblem.taken(existingName: "Tabata", workoutType: .intervals)) {
            try list.saveAsNew(named: "tabata", settings: WorkoutType.intervals.firstLaunch)
        }
        #expect(throws: PresetNameProblem.empty) {
            try list.saveAsNew(named: " ", settings: WorkoutType.intervals.firstLaunch)
        }
        #expect(list == before)
    }

    @Test func `The name sheet's footer says why Save is disabled, except for an empty name`() {
        #expect(PresetNameProblem.empty.footer == nil)
        #expect(PresetNameProblem.tooLong.footer == "Names are 30 characters at most.")
        #expect(
            PresetNameProblem.taken(existingName: "Tabata", workoutType: .intervals).footer
                == "Another Intervals Preset is called “Tabata”."
        )
        #expect(
            PresetNameProblem.taken(existingName: "Run", workoutType: .stopwatch).footer
                == "Another Stopwatch Preset is called “Run”."
        )
    }
}
