extension PresetList {
    /// The short line under a Preset's name in Manage Presets: Rounds × Work / Rest for Intervals, with "Off" for
    /// no Rest, the length for a Stopwatch, and the Rest for Open Rounds, as "Rest 1:00" or "Rest Off", after its
    /// number of Rounds when it has one, as "8 Rounds · Rest 1:00". Prepare and Cooldown are left out to keep it
    /// short.
    public func summary(of preset: Preset) -> String {
        let settings = preset.settings
        switch workoutType {
        case .intervals:
            let rest = settings.rest > .zero ? settings.rest.shortClockText(rounding: .up) : "Off"
            return "\(settings.rounds) × \(settings.work.shortClockText(rounding: .up)) / \(rest)"
        case .stopwatch:
            return settings.work.shortClockText(rounding: .up)
        case .openRounds:
            let rest = "Rest \(settings.rest > .zero ? settings.rest.shortClockText(rounding: .up) : "Off")"
            switch settings.rounds {
            case WorkoutType.roundsUntilStop: return rest
            case 1: return "1 Round · \(rest)"
            case let rounds: return "\(rounds) Rounds · \(rest)"
            }
        }
    }
}
