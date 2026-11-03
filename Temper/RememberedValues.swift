import Foundation
import Observation
import TemperCore

/// A tab in the tab bar: one per Workout Type, then Settings.
enum RootTab: Hashable {
    case workoutType(WorkoutType)
    case settings
}

/// Each Workout Type's last-used values, the last-used Workout Type, and the Dip setting. Each change saves at
/// once, and nothing about a running Workout is ever stored here.
@Observable
final class RememberedValues {
    /// The Intervals values, under the keys Temper used before it had Workout Types, so an upgrade keeps them.
    private var intervals: WorkoutSettings {
        didSet { save(intervals, oldValue, of: .intervals) }
    }

    private var stopwatch: WorkoutSettings {
        didSet { save(stopwatch, oldValue, of: .stopwatch) }
    }

    /// The Workout Type Temper opens on, which is the last one whose tab was selected.
    private(set) var lastUsed: WorkoutType {
        didSet { defaults.set(lastUsed.rawValue, forKey: Self.workoutTypeKey) }
    }

    /// Whether the Settings tab is showing. Never saved, so a launch always opens on a Workout Type.
    private var isOnSettings = false

    var isDipOn: Bool {
        didSet {
            defaults.set(isDipOn, forKey: Self.dipKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private static let workoutTypeKey = "workoutType"
    private static let dipKey = "dip"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        intervals = Self.restore(.intervals, from: defaults)
        stopwatch = Self.restore(.stopwatch, from: defaults)
        lastUsed = defaults.string(forKey: Self.workoutTypeKey).flatMap(WorkoutType.init) ?? .intervals
        isDipOn = defaults.object(forKey: Self.dipKey) as? Bool ?? true
    }

    /// A Workout Type's values. Only the values on its setup save.
    subscript(workoutType: WorkoutType) -> WorkoutSettings {
        get {
            switch workoutType {
            case .intervals: intervals
            case .stopwatch: stopwatch
            }
        }
        set {
            switch workoutType {
            case .intervals: intervals = newValue
            case .stopwatch: stopwatch = newValue
            }
        }
    }

    /// The tab showing. Selecting a Workout Type's tab makes it the last-used Workout Type, and selecting
    /// Settings doesn't, so leaving a Workout always comes back to the tab it started from.
    var selectedTab: RootTab {
        get { isOnSettings ? .settings : .workoutType(lastUsed) }
        set {
            switch newValue {
            case .workoutType(let workoutType):
                isOnSettings = false
                if lastUsed != workoutType {
                    lastUsed = workoutType
                }
            case .settings:
                isOnSettings = true
            }
        }
    }

    private func save(_ settings: WorkoutSettings, _ oldSettings: WorkoutSettings, of workoutType: WorkoutType) {
        for value in workoutType.values where settings[value] != oldSettings[value] {
            defaults.set(settings[value], forKey: value.defaultsKey(for: workoutType))
        }
    }

    private static func restore(_ workoutType: WorkoutType, from defaults: UserDefaults) -> WorkoutSettings {
        var settings = workoutType.firstLaunch
        for value in workoutType.values {
            if let stored = defaults.object(forKey: value.defaultsKey(for: workoutType)) as? Int {
                settings[value] = value.clamped(stored)
            }
        }
        return settings
    }
}

extension WorkoutValue {
    /// Intervals keeps the keys from before Workout Types, and every other type prefixes its own name.
    fileprivate func defaultsKey(for workoutType: WorkoutType) -> String {
        let name =
            switch self {
            case .prepare: "prepare"
            case .rounds: "rounds"
            case .work: "work"
            case .rest: "rest"
            case .cooldown: "cooldown"
            }
        return workoutType == .intervals ? name : "\(workoutType.rawValue).\(name)"
    }
}
