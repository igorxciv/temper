import Foundation
import Observation
import TemperCore

/// The last-used Workout values and the Dip setting. Each change saves at once, and nothing about a
/// running Workout is ever stored here.
@Observable
final class RememberedValues {
    var settings: WorkoutSettings {
        didSet {
            for value in WorkoutValue.allCases where settings[value] != oldValue[value] {
                defaults.set(settings[value], forKey: value.defaultsKey)
            }
        }
    }

    var isDipOn: Bool {
        didSet {
            defaults.set(isDipOn, forKey: Self.dipKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private static let dipKey = "dip"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var settings = WorkoutType.intervals.firstLaunch
        for value in WorkoutValue.allCases {
            if let stored = defaults.object(forKey: value.defaultsKey) as? Int {
                settings[value] = value.clamped(stored)
            }
        }
        self.settings = settings
        isDipOn = defaults.object(forKey: Self.dipKey) as? Bool ?? true
    }
}

extension WorkoutValue {
    fileprivate var defaultsKey: String {
        switch self {
        case .prepare: "prepare"
        case .rounds: "rounds"
        case .work: "work"
        case .rest: "rest"
        case .cooldown: "cooldown"
        }
    }
}
