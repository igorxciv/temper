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

    /// Force-quitting, or iOS ending the app, ends the Workout, because nothing about it is saved.
    @Test func `A launch opens setup, with no Workout to bring back`() {
        let runner = WorkoutRunner()

        #expect(runner.snapshot == nil)
    }
}

struct RememberedValuesTests {
    /// A `UserDefaults` suite no other test or launch can see, emptied when the test ends.
    private func withThrowawayDefaults(_ body: (UserDefaults) -> Void) throws {
        let suite = "RememberedValuesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func `A first launch has the first-launch values and Dip on`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)

            #expect(remembered.settings == WorkoutType.intervals.firstLaunch)
            #expect(remembered.isDipOn)
        }
    }

    @Test func `Every value restores on the next launch`() throws {
        try withThrowawayDefaults { defaults in
            let edited = WorkoutSettings(
                prepare: .zero,
                rounds: 12,
                work: .seconds(1800),
                rest: .seconds(5),
                cooldown: .seconds(95)
            )

            RememberedValues(defaults: defaults).settings = edited

            #expect(RememberedValues(defaults: defaults).settings == edited)
        }
    }

    @Test func `Dip turned off restores as off`() throws {
        try withThrowawayDefaults { defaults in
            RememberedValues(defaults: defaults).isDipOn = false

            #expect(!RememberedValues(defaults: defaults).isDipOn)
        }
    }

    @Test func `Changing Dip leaves the values at their defaults`() throws {
        try withThrowawayDefaults { defaults in
            RememberedValues(defaults: defaults).isDipOn = false

            #expect(RememberedValues(defaults: defaults).settings == WorkoutType.intervals.firstLaunch)
        }
    }

    @Test func `Stored amounts outside a value's range restore clamped`() throws {
        try withThrowawayDefaults { defaults in
            let remembered = RememberedValues(defaults: defaults)
            var edited = remembered.settings
            edited[.rounds] = 0
            edited[.work] = 0
            edited[.cooldown] = 9000
            remembered.settings = edited

            let restored = RememberedValues(defaults: defaults).settings

            #expect(restored.rounds == 1)
            #expect(restored.work == .seconds(5))
            #expect(restored.cooldown == .seconds(1800))
            _ = WorkoutType.intervals.makeWorkout(from: restored)
        }
    }
}
