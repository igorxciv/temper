import Foundation
import TemperCore
import Testing
import UIKit

@testable import Temper

struct TemperAppTests {
    @Test func `The app launches into a window`() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        #expect(scenes.contains { !$0.windows.isEmpty })
    }

    @Test func `The app may play audio in the background and has no file sharing keys`() {
        let info = Bundle.main.infoDictionary ?? [:]

        #expect(info["UIBackgroundModes"] as? [String] == ["audio"])
        #expect(info["UIFileSharingEnabled"] == nil)
        #expect(info["LSSupportsOpeningDocumentsInPlace"] == nil)
    }

    @Test func `The app offers Live Activities and carries the extension that draws them`() throws {
        let info = Bundle.main.infoDictionary ?? [:]
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        let widgets = try #require(Bundle(url: plugIns.appending(path: "TemperWidgets.appex")))
        let appID = try #require(Bundle.main.bundleIdentifier)

        #expect(info["NSSupportsLiveActivities"] as? Bool == true)
        #expect(widgets.bundleIdentifier == "\(appID).widgets")
    }

    /// Temper only writes workouts to Health and reads nothing, so it has no read string.
    @Test func `The app needs HealthKit and explains why it writes to Health`() {
        let info = Bundle.main.infoDictionary ?? [:]

        #expect(
            info["NSHealthUpdateUsageDescription"] as? String == "Temper saves each Workout to Health when it ends.")
        #expect(info["NSHealthShareUsageDescription"] == nil)
        #expect((info["UIRequiredDeviceCapabilities"] as? [String])?.contains("healthkit") == true)
    }

    /// Force-quitting, or iOS ending the app, ends the Workout, because nothing about it is saved.
    @Test func `A launch opens setup, with no Workout to bring back`() {
        let runner = WorkoutRunner()

        #expect(runner.snapshot == nil)
    }
}

/// One test swaps the app's runner for a fake, so none of these may overlap.
@Suite(.serialized)
struct LiveActivityButtonTests {
    private final class FakeControls: WorkoutControls {
        private(set) var taps: [String] = []

        func pause() { taps.append("pause") }
        func resume() { taps.append("resume") }
        func done() { taps.append("done") }
    }

    /// The system may launch the app to run a button, so the runner is set at launch.
    @Test func `The buttons reach the app's Workout runner`() {
        #expect(LiveActivityControls.workout is WorkoutRunner)
    }

    @Test func `Pause and Resume reach the Workout`() async throws {
        let app = LiveActivityControls.workout
        defer { LiveActivityControls.workout = app }
        let fake = FakeControls()
        LiveActivityControls.workout = fake

        _ = try await PauseWorkoutIntent().perform()
        _ = try await ResumeWorkoutIntent().perform()

        #expect(fake.taps == ["pause", "resume"])
    }

    @Test func `Done reaches the Workout`() async throws {
        let app = LiveActivityControls.workout
        defer { LiveActivityControls.workout = app }
        let fake = FakeControls()
        LiveActivityControls.workout = fake

        _ = try await DoneWorkoutIntent().perform()

        #expect(fake.taps == ["done"])
    }

    /// Shortcuts and Spotlight would offer them with no Live Activity in sight.
    @Test func `The buttons stay out of Shortcuts and Spotlight`() {
        #expect(!PauseWorkoutIntent.isDiscoverable)
        #expect(!ResumeWorkoutIntent.isDiscoverable)
        #expect(!DoneWorkoutIntent.isDiscoverable)
    }

    /// As in the widget extension, where nothing sets the Workout.
    @Test func `With no Workout to reach, a button does nothing`() async throws {
        let app = LiveActivityControls.workout
        defer { LiveActivityControls.workout = app }
        LiveActivityControls.workout = nil

        _ = try await PauseWorkoutIntent().perform()
        _ = try await ResumeWorkoutIntent().perform()
        _ = try await DoneWorkoutIntent().perform()
    }
}

/// Runs the body with a `UserDefaults` suite no other test or launch can see, emptied when it ends.
private func withThrowawayDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let suite = "TemperTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    try body(defaults)
}

struct RememberedValuesTests {
    @Test func `A first launch opens on Intervals, with every type's first-launch values and Dip on`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)

            #expect(remembered.selectedTab == .workoutType(.intervals))
            #expect(remembered[.intervals] == WorkoutType.intervals.firstLaunch)
            #expect(remembered[.stopwatch] == WorkoutType.stopwatch.firstLaunch)
            #expect(remembered.isDipOn)
        }
    }

    /// Before Workout Types, Temper stored one set of values under these keys.
    @Test func `An upgrade keeps the values from before Workout Types as the Intervals values`() throws {
        try withThrowawayDefaults { defaults in
            defaults.set(0, forKey: "prepare")
            defaults.set(12, forKey: "rounds")
            defaults.set(1800, forKey: "work")
            defaults.set(5, forKey: "rest")
            defaults.set(95, forKey: "cooldown")
            defaults.set(false, forKey: "dip")

            let remembered = RememberedValues(defaults: defaults)

            #expect(
                remembered[.intervals]
                    == WorkoutSettings(
                        prepare: .zero,
                        rounds: 12,
                        work: .seconds(1800),
                        rest: .seconds(5),
                        cooldown: .seconds(95)
                    )
            )
            #expect(remembered[.stopwatch] == WorkoutType.stopwatch.firstLaunch)
            #expect(remembered.selectedTab == .workoutType(.intervals))
            #expect(!remembered.isDipOn)
        }
    }

    @Test func `Each type's values restore on the next launch without touching the other's`() throws {
        try withThrowawayDefaults { defaults in
            let intervals = WorkoutSettings(
                prepare: .zero,
                rounds: 12,
                work: .seconds(1800),
                rest: .seconds(5),
                cooldown: .seconds(95)
            )
            var stopwatch = WorkoutType.stopwatch.firstLaunch
            stopwatch[.prepare] = 0
            stopwatch[.work] = 1500

            RememberedValues(defaults: defaults)[.intervals] = intervals
            #expect(RememberedValues(defaults: defaults)[.stopwatch] == WorkoutType.stopwatch.firstLaunch)

            RememberedValues(defaults: defaults)[.stopwatch] = stopwatch

            let restored = RememberedValues(defaults: defaults)
            #expect(restored[.intervals] == intervals)
            #expect(restored[.stopwatch] == stopwatch)
        }
    }

    @Test func `The Stopwatch saves only Prepare and Work, under its own keys`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered[.stopwatch][.prepare] = 20
            remembered[.stopwatch][.work] = 300
            remembered[.stopwatch][.rounds] = 9

            #expect(defaults.object(forKey: "stopwatch.prepare") as? Int == 20)
            #expect(defaults.object(forKey: "stopwatch.work") as? Int == 300)
            #expect(defaults.object(forKey: "prepare") == nil)
            #expect(defaults.object(forKey: "work") == nil)
            #expect(defaults.object(forKey: "rounds") == nil)
            #expect(defaults.object(forKey: "stopwatch.rounds") == nil)
        }
    }

    @Test func `The tab bar offers Intervals, Stopwatch and Open Rounds, in that order`() {
        #expect(RootTab.workoutTypes == [.intervals, .stopwatch, .openRounds])
    }

    @Test func `Open Rounds opens on Prepare Off and a Rest of 01:00 at first launch`() throws {
        try withThrowawayDefaults { defaults in
            #expect(RememberedValues(defaults: defaults)[.openRounds].prepare == .zero)
            #expect(RememberedValues(defaults: defaults)[.openRounds].rest == .seconds(60))
        }
    }

    @Test(arguments: [(9000, 1800), (-10, 0), (0, 0)])
    func `A stored Open Rounds Rest restores clamped, with Off kept`(stored: Int, restored: Int) throws {
        try withThrowawayDefaults { defaults in
            defaults.set(stored, forKey: "openRounds.rest")

            #expect(RememberedValues(defaults: defaults)[.openRounds].rest == .seconds(restored))
        }
    }

    @Test func `Open Rounds can be the type the next launch opens on`() throws {
        try withThrowawayDefaults { defaults in
            RememberedValues(defaults: defaults).selectedTab = .workoutType(.openRounds)

            #expect(RememberedValues(defaults: defaults).selectedTab == .workoutType(.openRounds))
        }
    }

    /// An upgrade from a build with no Open Rounds tab finds only these keys.
    @Test func `An upgrade keeps every key and the last-used Workout Type, and Open Rounds starts fresh`() throws {
        try withThrowawayDefaults { defaults in
            let stored: [String: Any] = [
                "prepare": 0, "rounds": 12, "work": 1800, "rest": 5, "cooldown": 95,
                "stopwatch.prepare": 20, "stopwatch.work": 300,
                "workoutType": "stopwatch", "dip": false,
                "presets.intervals": Data(#"[{"id": "\#(UUID().uuidString)", "name": "Long", "values": {}}]"#.utf8),
            ]
            for (key, value) in stored {
                defaults.set(value, forKey: key)
            }

            let remembered = RememberedValues(defaults: defaults)

            #expect(remembered.selectedTab == .workoutType(.stopwatch))
            #expect(remembered[.intervals].rounds == 12)
            #expect(remembered[.stopwatch].work == .seconds(300))
            #expect(remembered.presets(of: .intervals).presets.map(\.name) == ["Long"])
            #expect(!remembered.isDipOn)
            #expect(remembered[.openRounds] == WorkoutType.openRounds.firstLaunch)
            #expect(remembered.presets(of: .openRounds).presets.isEmpty)
            for (key, value) in stored {
                #expect(defaults.object(forKey: key) as? NSObject == value as? NSObject, "\(key)")
            }
            #expect(defaults.object(forKey: "openRounds.rest") == nil)
        }
    }

    @Test func `The Open Rounds Rest saves under its own key and restores`() throws {
        try withThrowawayDefaults { defaults in
            #expect(RememberedValues(defaults: defaults)[.openRounds] == WorkoutType.openRounds.firstLaunch)

            RememberedValues(defaults: defaults)[.openRounds][.rest] = 90

            #expect(defaults.object(forKey: "openRounds.rest") as? Int == 90)
            #expect(defaults.object(forKey: "rest") == nil)
            #expect(RememberedValues(defaults: defaults)[.openRounds].rest == .seconds(90))
        }
    }

    @Test func `The Open Rounds Prepare saves under its own key and restores`() throws {
        try withThrowawayDefaults { defaults in
            RememberedValues(defaults: defaults)[.openRounds][.prepare] = 15

            #expect(defaults.object(forKey: "openRounds.prepare") as? Int == 15)
            #expect(defaults.object(forKey: "prepare") == nil)
            #expect(RememberedValues(defaults: defaults)[.openRounds].prepare == .seconds(15))
        }
    }

    @Test func `Selecting a Workout Type's tab makes it the type the next launch opens on`() throws {
        try withThrowawayDefaults { defaults in
            RememberedValues(defaults: defaults).selectedTab = .workoutType(.stopwatch)

            #expect(RememberedValues(defaults: defaults).selectedTab == .workoutType(.stopwatch))
        }
    }

    @Test func `Settings is never saved as the last-used tab`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered.selectedTab = .workoutType(.stopwatch)
            remembered.selectedTab = .settings

            #expect(remembered.selectedTab == .settings)
            #expect(RememberedValues(defaults: defaults).selectedTab == .workoutType(.stopwatch))
        }
    }

    @Test func `An unknown last-used Workout Type falls back to Intervals`() throws {
        try withThrowawayDefaults { defaults in
            defaults.set("emom", forKey: "workoutType")

            #expect(RememberedValues(defaults: defaults).selectedTab == .workoutType(.intervals))
        }
    }

    @Test func `Dip turned off restores as off`() throws {
        try withThrowawayDefaults { defaults in
            RememberedValues(defaults: defaults).isDipOn = false

            #expect(!RememberedValues(defaults: defaults).isDipOn)
        }
    }

    @Test func `Changing Dip leaves every type's values at their defaults`() throws {
        try withThrowawayDefaults { defaults in
            RememberedValues(defaults: defaults).isDipOn = false

            let restored = RememberedValues(defaults: defaults)
            for workoutType in WorkoutType.allCases {
                #expect(restored[workoutType] == workoutType.firstLaunch)
            }
        }
    }

    @Test func `Stored Intervals amounts outside a value's range restore clamped`() throws {
        try withThrowawayDefaults { defaults in
            defaults.set(0, forKey: "rounds")
            defaults.set(0, forKey: "work")
            defaults.set(9000, forKey: "cooldown")

            let restored = RememberedValues(defaults: defaults)[.intervals]

            #expect(restored.rounds == 1)
            #expect(restored.work == .seconds(5))
            #expect(restored.cooldown == .seconds(1800))
            _ = WorkoutType.intervals.makeWorkout(from: restored)
        }
    }

    @Test func `Stored Stopwatch amounts outside a value's range restore clamped`() throws {
        try withThrowawayDefaults { defaults in
            defaults.set(-10, forKey: "stopwatch.prepare")
            defaults.set(9000, forKey: "stopwatch.work")

            let restored = RememberedValues(defaults: defaults)[.stopwatch]

            #expect(restored.prepare == .zero)
            #expect(restored.work == .seconds(1800))
            _ = WorkoutType.stopwatch.makeWorkout(from: restored)
        }
    }

    @Test func `A Stopwatch Work of zero restores at its shortest length`() throws {
        try withThrowawayDefaults { defaults in
            defaults.set(0, forKey: "stopwatch.work")

            #expect(RememberedValues(defaults: defaults)[.stopwatch].work == .seconds(5))
        }
    }
}

struct RememberedPresetsTests {
    private let tabata = WorkoutSettings(
        prepare: .seconds(5),
        rounds: 8,
        work: .seconds(20),
        rest: .seconds(10),
        cooldown: .seconds(10)
    )

    private func store(_ json: String, forKey key: String, in defaults: UserDefaults) {
        defaults.set(Data(json.utf8), forKey: key)
    }

    @Test func `An upgrade with only today's keys has no Presets, nothing picked, and keeps today's values`() throws {
        try withThrowawayDefaults { defaults in
            defaults.set(12, forKey: "rounds")
            defaults.set(300, forKey: "stopwatch.work")

            let remembered = RememberedValues(defaults: defaults)

            for workoutType in WorkoutType.allCases {
                #expect(remembered.presets(of: workoutType).presets.isEmpty)
                #expect(remembered.presets(of: workoutType).pickedID == nil)
            }
            #expect(remembered[.intervals].rounds == 12)
            #expect(remembered[.stopwatch].work == .seconds(300))
        }
    }

    @Test func `Each type's Presets and pick restore on the next launch, independently of the other's`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered[.intervals] = tabata
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)
            remembered[.intervals] = WorkoutType.intervals.firstLaunch
            try remembered.saveAsNewPreset(named: "Long", of: .intervals)
            let tabataID = remembered.presets(of: .intervals).presets[0].id
            remembered.pickPreset(tabataID, of: .intervals)
            try remembered.saveAsNewPreset(named: "Tabata", of: .stopwatch)

            let restored = RememberedValues(defaults: defaults)

            #expect(restored.presets(of: .intervals) == remembered.presets(of: .intervals))
            #expect(restored.presets(of: .intervals).presets.map(\.name) == ["Tabata", "Long"])
            #expect(restored.presets(of: .intervals).picked?.settings == tabata)
            #expect(restored.presets(of: .stopwatch) == remembered.presets(of: .stopwatch))
            #expect(restored.presets(of: .stopwatch).presets.map(\.name) == ["Tabata"])
            #expect(restored.presets(of: .stopwatch).subtitle(for: restored[.stopwatch]) == "Tabata")
        }
    }

    @Test func `Picking a Preset writes its values into the type's remembered values, which restore too`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered[.intervals] = tabata
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)
            let tabataID = try #require(remembered.presets(of: .intervals).pickedID)
            remembered[.intervals] = WorkoutType.intervals.firstLaunch

            remembered.pickPreset(tabataID, of: .intervals)

            #expect(remembered[.intervals] == tabata)
            #expect(RememberedValues(defaults: defaults)[.intervals] == tabata)
            #expect(remembered[.stopwatch] == WorkoutType.stopwatch.firstLaunch)
        }
    }

    @Test func `A relaunch recomputes modified exactly as before, from the restored values`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered[.intervals] = tabata
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)
            remembered[.intervals].work = .seconds(30)
            try remembered.saveAsNewPreset(named: "Run", of: .stopwatch)

            let restored = RememberedValues(defaults: defaults)

            #expect(restored.presets(of: .intervals).subtitle(for: restored[.intervals]) == "Tabata · Modified")
            #expect(restored.presets(of: .stopwatch).subtitle(for: restored[.stopwatch]) == "Run")
            restored[.intervals].work = tabata.work
            #expect(restored.presets(of: .intervals).subtitle(for: restored[.intervals]) == "Tabata")
        }
    }

    @Test func `Editing a value on setup leaves the picked Preset as it was saved`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered[.intervals] = tabata
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)

            remembered[.intervals].rounds = 12

            #expect(remembered.presets(of: .intervals).picked?.settings == tabata)
            #expect(RememberedValues(defaults: defaults).presets(of: .intervals).picked?.settings == tabata)
        }
    }

    @Test func `Updating the picked Preset saves setup's values over it, and they restore`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)
            remembered[.intervals] = tabata

            remembered.updatePickedPreset(of: .intervals)

            #expect(remembered.presets(of: .intervals).picked?.settings == tabata)
            let restored = RememberedValues(defaults: defaults)
            #expect(restored.presets(of: .intervals).picked?.settings == tabata)
            #expect(restored.presets(of: .intervals).subtitle(for: restored[.intervals]) == "Tabata")
        }
    }

    @Test func `A rename and a delete restore on the next launch, and the pick survives the rename`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered[.intervals] = tabata
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)
            try remembered.saveAsNewPreset(named: "Long", of: .intervals)
            try remembered.saveAsNewPreset(named: "Short", of: .intervals)
            let ids = remembered.presets(of: .intervals).presets.map(\.id)
            remembered.pickPreset(ids[0], of: .intervals)

            try remembered.renamePreset(ids[0], to: "Sprints", of: .intervals)
            remembered.deletePreset(ids[1], of: .intervals)

            let restored = RememberedValues(defaults: defaults).presets(of: .intervals)
            #expect(restored.presets.map(\.name) == ["Sprints", "Short"])
            #expect(restored.pickedID == ids[0])
        }
    }

    @Test func `A new order restores on the next launch, and the pick survives the move`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)
            try remembered.saveAsNewPreset(named: "Long", of: .intervals)
            try remembered.saveAsNewPreset(named: "Short", of: .intervals)
            let shortID = try #require(remembered.presets(of: .intervals).pickedID)

            remembered.movePresets(fromOffsets: IndexSet(integer: 2), toOffset: 0, of: .intervals)

            let restored = RememberedValues(defaults: defaults).presets(of: .intervals)
            #expect(restored.presets.map(\.name) == ["Short", "Tabata", "Long"])
            #expect(restored.pickedID == shortID)
        }
    }

    @Test func `Deleting the picked Preset restores as nothing picked and leaves the values on setup`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered[.intervals] = tabata
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)

            remembered.deletePreset(try #require(remembered.presets(of: .intervals).pickedID), of: .intervals)

            let restored = RememberedValues(defaults: defaults)
            #expect(restored.presets(of: .intervals).presets.isEmpty)
            #expect(restored.presets(of: .intervals).pickedID == nil)
            #expect(defaults.object(forKey: "pickedPreset.intervals") == nil)
            #expect(restored[.intervals] == tabata)
        }
    }

    @Test func `Presets save under presets and pickedPreset keys, with only the type's own values`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            try remembered.saveAsNewPreset(named: "Run", of: .stopwatch)
            let preset = try #require(remembered.presets(of: .stopwatch).picked)

            let data = try #require(defaults.data(forKey: "presets.stopwatch"))
            let stored = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(stored.count == 1)
            #expect(stored.first?["id"] as? String == preset.id.uuidString)
            #expect(stored.first?["name"] as? String == "Run")
            #expect(stored.first?["values"] as? [String: Int] == ["prepare": 10, "work": 600])
            #expect(defaults.string(forKey: "pickedPreset.stopwatch") == preset.id.uuidString)
            #expect(defaults.object(forKey: "presets.intervals") == nil)
        }
    }

    @Test func `An Open Rounds Preset saves its Prepare and Rest, under its own keys, and restores`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            remembered[.openRounds][.prepare] = 15
            remembered[.openRounds][.rest] = 90
            try remembered.saveAsNewPreset(named: "Squats", of: .openRounds)
            let preset = try #require(remembered.presets(of: .openRounds).picked)

            let data = try #require(defaults.data(forKey: "presets.openRounds"))
            let stored = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(stored.first?["name"] as? String == "Squats")
            #expect(stored.first?["values"] as? [String: Int] == ["prepare": 15, "rest": 90])
            #expect(defaults.string(forKey: "pickedPreset.openRounds") == preset.id.uuidString)

            remembered[.openRounds][.rest] = 0
            let restored = RememberedValues(defaults: defaults)
            #expect(restored.presets(of: .openRounds).subtitle(for: restored[.openRounds]) == "Squats · Modified")
            restored.pickPreset(preset.id, of: .openRounds)
            #expect(RememberedValues(defaults: defaults)[.openRounds].prepare == .seconds(15))
            #expect(RememberedValues(defaults: defaults)[.openRounds].rest == .seconds(90))
        }
    }

    /// Open Rounds had no Prepare row before, so its Presets were saved with only a Rest.
    @Test func `An Open Rounds Preset saved before Prepare picks with Prepare Off`() throws {
        try withThrowawayDefaults { defaults in
            let id = UUID()
            let stored = #"[{"id": "\#(id.uuidString)", "name": "Squats", "values": {"rest": 90}}]"#
            defaults.set(Data(stored.utf8), forKey: "presets.openRounds")
            let remembered = RememberedValues(defaults: defaults)
            remembered[.openRounds][.prepare] = 20

            remembered.pickPreset(id, of: .openRounds)

            #expect(remembered[.openRounds].prepare == .zero)
            #expect(remembered[.openRounds].rest == .seconds(90))
        }
    }

    /// The name sheet's Save and Return both reach these, so a name with a problem must save nothing.
    @Test func `Saving or renaming under a name with a problem throws it and saves nothing`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            try remembered.saveAsNewPreset(named: "Tabata", of: .intervals)
            try remembered.saveAsNewPreset(named: "Long", of: .intervals)
            let longID = try #require(remembered.presets(of: .intervals).pickedID)
            let taken = PresetNameProblem.taken(existingName: "Tabata", workoutType: .intervals)

            #expect(throws: taken) {
                try remembered.saveAsNewPreset(named: "tabata", of: .intervals)
            }
            #expect(throws: PresetNameProblem.empty) {
                try remembered.saveAsNewPreset(named: " ", of: .intervals)
            }
            #expect(throws: taken) {
                try remembered.renamePreset(longID, to: "TABATA", of: .intervals)
            }

            let restored = RememberedValues(defaults: defaults).presets(of: .intervals)
            #expect(restored.presets.map(\.name) == ["Tabata", "Long"])
            #expect(restored.pickedID == longID)
        }
    }

    @Test(arguments: ["E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "not an id"])
    func `A picked id that matches no Preset, or can't be read, restores as nothing picked`(id: String) throws {
        try withThrowawayDefaults { defaults in
            try RememberedValues(defaults: defaults).saveAsNewPreset(named: "Tabata", of: .intervals)
            defaults.set(id, forKey: "pickedPreset.intervals")

            let restored = RememberedValues(defaults: defaults).presets(of: .intervals)

            #expect(restored.presets.map(\.name) == ["Tabata"])
            #expect(restored.pickedID == nil)
        }
    }

    @Test func `Stored Preset values restore clamped, and missing ones at first launch`() throws {
        try withThrowawayDefaults { defaults in
            store(
                #"[{"id": "\#(UUID().uuidString)", "name": "Odd", "values": {"rounds": 0, "work": 9000, "rest": 7}}]"#,
                forKey: "presets.intervals",
                in: defaults
            )

            let preset = try #require(RememberedValues(defaults: defaults).presets(of: .intervals).presets.first)

            #expect(
                preset.settings
                    == WorkoutSettings(
                        prepare: .seconds(10),
                        rounds: 1,
                        work: .seconds(1800),
                        rest: .seconds(5),
                        cooldown: .seconds(60)
                    )
            )
        }
    }

    @Test func `Unreadable Presets restore as an empty list and leave the remembered values alone`() throws {
        try withThrowawayDefaults { defaults in
            defaults.set(15, forKey: "prepare")
            store("not json", forKey: "presets.intervals", in: defaults)
            defaults.set("not data", forKey: "presets.stopwatch")

            let remembered = RememberedValues(defaults: defaults)

            #expect(remembered.presets(of: .intervals).presets.isEmpty)
            #expect(remembered.presets(of: .stopwatch).presets.isEmpty)
            #expect(remembered[.intervals].prepare == .seconds(15))
            #expect(remembered[.stopwatch] == WorkoutType.stopwatch.firstLaunch)
        }
    }

    @Test func `A single bad stored Preset is dropped, and the rest survive`() throws {
        try withThrowawayDefaults { defaults in
            let longName = String(repeating: "a", count: 31)
            store(
                """
                [
                    {"id": "\(UUID().uuidString)", "name": "First", "values": {"work": 30}},
                    {"id": "not an id", "name": "Bad id", "values": {}},
                    {"id": "\(UUID().uuidString)", "name": "\(longName)", "values": {}},
                    {"id": "\(UUID().uuidString)", "values": {}},
                    {"id": "\(UUID().uuidString)", "name": "Last", "values": {"work": 45}}
                ]
                """,
                forKey: "presets.stopwatch",
                in: defaults
            )

            let presets = RememberedValues(defaults: defaults).presets(of: .stopwatch).presets

            #expect(presets.map(\.name) == ["First", "Last"])
            #expect(presets.map(\.settings.work) == [.seconds(30), .seconds(45)])
        }
    }
}
