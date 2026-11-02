extension Duration {
    /// Minutes and seconds as `00:00`, with no hours. Part of a second rounds up, so a Phase reads
    /// its full length as it starts and `00:00` only once it has ended.
    public nonisolated var clockText: String {
        let (seconds, attoseconds) = components
        let wholeSeconds = max(0, seconds + (attoseconds > 0 ? 1 : 0))
        return "\(padded(wholeSeconds / 60)):\(padded(wholeSeconds % 60))"
    }

    private nonisolated func padded(_ value: Int64) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
