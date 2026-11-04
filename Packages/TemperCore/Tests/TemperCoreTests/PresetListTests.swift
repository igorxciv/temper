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

    @Test func `With nothing picked nothing is modified`() throws {
        let list = PresetList(workoutType: .intervals)

        #expect(list.isModified(tabata) == false)
    }

    @Test func `The picked Preset is modified once a value on setup differs from it`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        var edited = tabata

        #expect(list.isModified(edited) == false)
        edited.rest = .seconds(15)
        #expect(list.isModified(edited))
    }

    @Test func `Setting the value back clears modified`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        var edited = tabata
        edited.rounds = 12
        edited.rounds = 8

        #expect(list.isModified(edited) == false)
    }

    @Test func `A Stopwatch Preset ignores Rounds, Rest and Cooldown`() throws {
        var list = PresetList(workoutType: .stopwatch)
        try list.saveAsNew(named: "Run", settings: WorkoutType.stopwatch.firstLaunch)
        var edited = WorkoutType.stopwatch.firstLaunch
        edited.rounds = 12
        edited.rest = .seconds(30)
        edited.cooldown = .seconds(60)

        #expect(list.isModified(edited) == false)
        edited.prepare = .seconds(15)
        #expect(list.isModified(edited))
    }

    @Test func `Updating replaces the picked Preset's settings and clears modified`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        try list.saveAsNew(named: "Long", settings: WorkoutType.intervals.firstLaunch)
        var edited = WorkoutType.intervals.firstLaunch
        edited.rounds = 3

        list.updatePicked(with: edited)

        #expect(list.presets.map(\.settings) == [tabata, edited])
        #expect(list.isModified(edited) == false)
        #expect(list.subtitle(for: edited) == "Long")
    }

    @Test func `An updated Stopwatch Preset keeps first-launch values outside Prepare and Work`() throws {
        var list = PresetList(workoutType: .stopwatch)
        try list.saveAsNew(named: "Run", settings: WorkoutType.stopwatch.firstLaunch)

        list.updatePicked(with: tabata)

        #expect(
            list.picked?.settings
                == WorkoutSettings(prepare: .seconds(5), rounds: 1, work: .seconds(20), rest: .zero, cooldown: .zero)
        )
    }

    @Test func `Updating with nothing picked changes nothing`() throws {
        var list = PresetList(
            workoutType: .intervals,
            restoring: [Preset(name: "Tabata", settings: tabata)],
            pickedID: nil
        )
        let before = list

        list.updatePicked(with: WorkoutType.intervals.firstLaunch)

        #expect(list == before)
    }

    @Test func `With nothing picked there is no subtitle`() {
        #expect(PresetList(workoutType: .intervals).subtitle(for: tabata) == nil)
    }

    @Test func `The picked Preset's name is the subtitle while it isn't modified`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)

        #expect(list.subtitle(for: tabata) == "Tabata")
    }

    @Test func `A modified Preset's subtitle says so`() throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        var edited = tabata
        edited.work = .seconds(30)

        #expect(list.subtitle(for: edited) == "Tabata · Modified")
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
        #expect(list.subtitle(for: tabata) == "Sprints")
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
        #expect(list.subtitle(for: WorkoutType.intervals.firstLaunch) == nil)
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

    @Test(arguments: [
        (IndexSet(integer: 0), 3, ["Long", "Short", "Tabata"]),
        (IndexSet(integer: 2), 0, ["Short", "Tabata", "Long"]),
        (IndexSet([0, 2]), 2, ["Long", "Tabata", "Short"]),
        (IndexSet(integer: 1), 1, ["Tabata", "Long", "Short"]),
    ])
    func `Moving Presets reorders them as onMove's offsets say and keeps the pick`(
        offsets: IndexSet,
        destination: Int,
        order: [String]
    ) throws {
        var list = PresetList(workoutType: .intervals)
        try list.saveAsNew(named: "Tabata", settings: tabata)
        try list.saveAsNew(named: "Long", settings: WorkoutType.intervals.firstLaunch)
        try list.saveAsNew(named: "Short", settings: tabata)
        let longID = list.presets[1].id
        _ = list.pick(longID)

        list.move(fromOffsets: offsets, toOffset: destination)

        #expect(list.presets.map(\.name) == order)
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
        #expect(list.subtitle(for: tabata) == nil)
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
