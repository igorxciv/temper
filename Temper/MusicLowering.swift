import Foundation
import Observation

/// The owner's Settings switch for lowering other apps' audio, such as music, while a Cue speaks. It's on until they
/// turn it off. It's read at Start, and can't change during a Workout, since Settings isn't on screen then.
@Observable
final class MusicLowering {
    /// Where ``isOn`` is kept.
    static let isOnKey = "lowersMusic"

    var isOn: Bool {
        didSet { defaults.set(isOn, forKey: Self.isOnKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOn = defaults.object(forKey: Self.isOnKey) as? Bool ?? true
    }
}
