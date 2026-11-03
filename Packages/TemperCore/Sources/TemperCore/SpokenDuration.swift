extension Duration {
    /// Minutes and seconds in English words for VoiceOver, such as "4 minutes 56 seconds", "10 minutes" or
    /// "0 seconds". There are no hours, to match `clockText`, so `120:00` reads "120 minutes".
    ///
    /// Written by hand rather than with `Duration.UnitsFormatStyle`, so tests don't depend on the Mac's locale.
    /// Temper is English only.
    public nonisolated func spokenText(rounding: SecondsRounding) -> String {
        let wholeSeconds = wholeSeconds(rounding: rounding)
        let minutes = wholeSeconds / 60
        let seconds = wholeSeconds % 60
        var parts: [String] = []
        if minutes > 0 {
            parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }
        if seconds > 0 || minutes == 0 {
            parts.append(seconds == 1 ? "1 second" : "\(seconds) seconds")
        }
        return parts.joined(separator: " ")
    }
}
