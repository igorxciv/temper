import Foundation
import Testing

@testable import TemperCore

struct PresetListTests {
    private let tabata = WorkoutSettings(
        prepare: .seconds(5),
        rounds: 8,
        work: .seconds(20),
        rest: .seconds(10),
        cooldown: .seconds(10)
    )

    @Test func `Saving as new appends the Preset at the end and picks it`() throws {
        var list = PresetList(workoutType: .intervals)

        try list.saveAsNew(named: "Tabata", settings: tabata)
        try list.saveAsNew(named: "Long", settings: WorkoutType.intervals.firstLaunch)

        #expect(list.presets.map(\.name) == ["Tabata", "Long"])
        #expect(list.presets.map(\.settings) == [tabata, WorkoutType.intervals.firstLaunch])
        #expect(list.picked?.name == "Long")
    }

    @Test func `A saved Stopwatch Preset keeps first-launch values outside Prepare and Work`() throws {
        var list = PresetList(workoutType: .stopwatch)

        try list.saveAsNew(named: "Run", settings: tabata)

        #expect(
            list.picked?.settings
                == WorkoutSettings(prepare: .seconds(5), rounds: 1, work: .seconds(20), rest: .zero, cooldown: .zero)
        )
    }

    @Test func `Picking a Preset picks it and hands back its settings`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        try list.saveAsNew(named: "Long", settings: WorkoutType.intervals.firstLaunch)
        let tabataID = list.presets[0].id

        #expect(list.pick(tabataID) == tabata)
        #expect(list.picked?.name == "Tabata")
    }

    @Test func `Picking the picked Preset again still hands back its settings`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        let tabataID = list.presets[0].id

        #expect(list.pick(tabataID) == tabata)
        #expect(list.pick(tabataID) == tabata)
        #expect(list.pickedID == tabataID)
    }

    @Test func `Picking an unknown Preset changes nothing and hands back nothing`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        let before = list

        #expect(list.pick(UUID()) == nil)
        #expect(list == before)
    }

    @Test func `With nothing picked there is no subtitle`() {
        #expect(PresetList(workoutType: .intervals).subtitle == nil)
    }

    @Test func `The picked Preset's name is the subtitle`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)

        #expect(list.subtitle == "Tabata")
    }

    @Test func `Renaming a Preset trims the new name and keeps the pick`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        try list.saveAsNew(named: "Long", settings: WorkoutType.intervals.firstLaunch)
        let tabataID = list.presets[0].id
        _ = list.pick(tabataID)

        try list.rename(tabataID, to: " Sprints ")

        #expect(list.presets.map(\.name) == ["Sprints", "Long"])
        #expect(list.picked?.id == tabataID)
        #expect(list.picked?.settings == tabata)
        #expect(list.subtitle == "Sprints")
    }

    @Test func `Renaming a Preset to a case-only change of its own name is allowed`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        let tabataID = list.presets[0].id

        #expect(list.nameProblem("tabata", excluding: tabataID) == nil)
        try list.rename(tabataID, to: "tabata")

        #expect(list.presets.map(\.name) == ["tabata"])
    }

    @Test func `Renaming a Preset to another Preset's name throws and changes nothing`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        try list.saveAsNew(named: "Long", settings: WorkoutType.intervals.firstLaunch)
        let before = list

        #expect(throws: PresetNameProblem.taken(existingName: "Tabata", workoutType: .intervals)) {
            try list.rename(before.presets[1].id, to: "TABATA")
        }
        #expect(list == before)
    }

    @Test func `Deleting the picked Preset removes it and leaves nothing picked`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        try list.saveAsNew(named: "Long", settings: WorkoutType.intervals.firstLaunch)

        list.delete(list.presets[1].id)

        #expect(list.presets.map(\.name) == ["Tabata"])
        #expect(list.pickedID == nil)
        #expect(list.subtitle == nil)
    }

    @Test func `Deleting another Preset keeps the pick`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        try list.saveAsNew(named: "Long", settings: WorkoutType.intervals.firstLaunch)
        let longID = list.presets[1].id

        list.delete(list.presets[0].id)

        #expect(list.presets.map(\.name) == ["Long"])
        #expect(list.pickedID == longID)
    }

    @Test func `A restored list keeps its order and its pick`() {
        let tabataPreset = Preset(name: "Tabata", settings: tabata)
        let long = Preset(name: "Long", settings: WorkoutType.intervals.firstLaunch)

        let list = PresetList(workoutType: .intervals, restoring: [tabataPreset, long], pickedID: long.id)

        #expect(list.presets == [tabataPreset, long])
        #expect(list.picked == long)
    }

    @Test func `A restored pick that matches no Preset restores as nothing picked`() {
        let list = PresetList(
            workoutType: .intervals,
            restoring: [Preset(name: "Tabata", settings: tabata)],
            pickedID: UUID()
        )

        #expect(list.pickedID == nil)
        #expect(list.subtitle == nil)
    }

    @Test func `Restoring drops a Preset whose name fails the name check, and keeps the rest`() {
        let kept = Preset(name: "Tabata", settings: tabata)
        let tooLong = Preset(name: String(repeating: "a", count: 31), settings: tabata)
        let duplicate = Preset(name: "TABATA", settings: tabata)
        let empty = Preset(name: " ", settings: tabata)

        let list = PresetList(
            workoutType: .intervals,
            restoring: [kept, tooLong, duplicate, empty],
            pickedID: duplicate.id
        )

        #expect(list.presets == [kept])
        #expect(list.pickedID == nil)
    }
}
