import Foundation
import Observation

/// The owner's Settings switch for setting times to the second. Off, the seconds wheel offers every 5 seconds, as it
/// always has. It changes only what the wheel offers, so times already set keep their seconds either way.
@Observable
final class SecondsWheel {
    /// Where ``offersEverySecond`` is kept.
    static let offersEverySecondKey = "secondsWheel.everySecond"

    var offersEverySecond: Bool {
        didSet { defaults.set(offersEverySecond, forKey: Self.offersEverySecondKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        offersEverySecond = defaults.bool(forKey: Self.offersEverySecondKey)
    }
}
