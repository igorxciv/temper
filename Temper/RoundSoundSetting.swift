import Foundation
import Observation

/// The owner's Settings choice of Round Sound. It's the gong until they pick another. It's read at Start, and can't
/// change during a Workout, since Settings isn't on screen then.
@Observable
final class RoundSoundSetting {
    /// Where ``sound`` is kept.
    static let soundKey = "roundSound"

    var sound: RoundSound {
        didSet { defaults.set(sound.rawValue, forKey: Self.soundKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sound = defaults.string(forKey: Self.soundKey).flatMap(RoundSound.init(rawValue:)) ?? .gong
    }
}
