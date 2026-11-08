extension PresetList {
    /// The short line under a Preset's name in Manage Presets: Rounds × Work / Rest for Intervals, with "Off" for
    /// no Rest, and the length for a Stopwatch. Prepare and Cooldown are left out to keep it short.
    public func summary(of preset: Preset) -> String {
        let settings = preset.settings
        switch workoutType {
        case .intervals:
            let rest = settings.rest > .zero ? Self.shortClockText(settings.rest) : "Off"
            return "\(settings.rounds) × \(Self.shortClockText(settings.work)) / \(rest)"
        case .stopwatch:
            return Self.shortClockText(settings.work)
        case .openRounds:
            return "Rest \(settings.rest > .zero ? Self.shortClockText(settings.rest) : "Off")"
        }
    }

    /// Minutes and seconds with no leading zero on the minutes, as `0:20`, since a summary isn't a clock face.
    private static func shortClockText(_ duration: Duration) -> String {
        let seconds = duration.wholeSeconds(rounding: .up)
        let secondsText = seconds % 60 < 10 ? "0\(seconds % 60)" : "\(seconds % 60)"
        return "\(seconds / 60):\(secondsText)"
    }
}
