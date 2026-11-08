extension PresetList {
    /// The short line under a Preset's name in Manage Presets: Rounds × Work / Rest for Intervals, with "Off" for
    /// no Rest, the length for a Stopwatch, and the Rest for Open Rounds, as "Rest 1:00" or "Rest Off". Prepare and
    /// Cooldown are left out to keep it short.
    public func summary(of preset: Preset) -> String {
        let settings = preset.settings
        switch workoutType {
        case .intervals:
            let rest = settings.rest > .zero ? settings.rest.shortClockText(rounding: .up) : "Off"
            return "\(settings.rounds) × \(settings.work.shortClockText(rounding: .up)) / \(rest)"
        case .stopwatch:
            return settings.work.shortClockText(rounding: .up)
        case .openRounds:
            return "Rest \(settings.rest > .zero ? settings.rest.shortClockText(rounding: .up) : "Off")"
        }
    }
}
