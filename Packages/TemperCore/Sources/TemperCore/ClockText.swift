extension Duration {
    /// Which way part of a second goes when a time is shown or spoken in whole seconds.
    public nonisolated enum SecondsRounding: Sendable {
        /// For time left, so a Phase reads its full length as it starts and zero only once it has ended.
        case up
        /// For time elapsed, so a Phase reads zero as it starts and its full length only once it has ended.
        case down
    }

    /// Minutes and seconds as `00:00`, with no hours. Part of a second rounds up, so a Phase reads
    /// its full length as it starts and `00:00` only once it has ended.
    public nonisolated var clockText: String {
        let wholeSeconds = wholeSeconds(rounding: .up)
        return "\(padded(wholeSeconds / 60)):\(padded(wholeSeconds % 60))"
    }

    /// Minutes and seconds with no leading zero on the minutes, as `1:42`, for a time that isn't a clock face, such
    /// as a Work time or a Preset's values. There are no hours, so `72:15` reads as it does in `clockText`.
    public nonisolated func shortClockText(rounding: SecondsRounding) -> String {
        let wholeSeconds = wholeSeconds(rounding: rounding)
        return "\(wholeSeconds / 60):\(padded(wholeSeconds % 60))"
    }

    /// The time in whole seconds, with a negative time as zero.
    public nonisolated func wholeSeconds(rounding: SecondsRounding) -> Int64 {
        guard self > .zero else { return 0 }
        let (seconds, attoseconds) = components
        switch rounding {
        case .up: return seconds + (attoseconds > 0 ? 1 : 0)
        case .down: return seconds
        }
    }

    private nonisolated func padded(_ value: Int64) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
