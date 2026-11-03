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
