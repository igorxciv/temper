/// What the Open Rounds complete screen shows of a Workout record: the total active time, the number of Rounds and
/// each Round's Work time, with what VoiceOver says for each.
///
/// Every time rounds down, as the time elapsed does on the running screen, so a row matches the Work time the Rest
/// line showed.
public nonisolated struct RoundsSummary: Equatable, Sendable {
    /// One Round's Work time. The last can be a Work cut short by Stop.
    public struct Row: Equatable, Sendable, Identifiable {
        public let round: Int
        /// The Work time, as `1:42`.
        public let time: String
        /// What VoiceOver says for the row, such as "Round 1, 1 minute 42 seconds".
        public let spokenTime: String

        public var id: Int { round }

        public init(round: Int, time: String, spokenTime: String) {
            self.round = round
            self.time = time
            self.spokenTime = spokenTime
        }
    }

    /// The total active time, as `23:10`.
    public let total: String
    /// What VoiceOver says for the total, such as "Total 23 minutes 10 seconds".
    public let spokenTotal: String
    /// The number of Rounds, as "12 Rounds" or "1 Round", which VoiceOver reads as it is.
    public let countText: String
    public let rows: [Row]

    public init<Instant>(record: WorkoutRecord<Instant>) {
        let total = Duration.seconds(record.activeTime.wholeSeconds(rounding: .down))
        self.total = total.clockText
        spokenTotal = "Total \(total.spokenText(rounding: .down))"
        let workTimes = record.workTimes
        countText = workTimes.count == 1 ? "1 Round" : "\(workTimes.count) Rounds"
        rows = workTimes.enumerated().map { index, time in
            Row(
                round: index + 1,
                time: time.shortClockText(rounding: .down),
                spokenTime: "Round \(index + 1), \(time.spokenText(rounding: .down))"
            )
        }
    }
}
