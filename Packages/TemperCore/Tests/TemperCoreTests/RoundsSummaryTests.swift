import Testing

@testable import TemperCore

nonisolated struct RoundsSummaryTests {
    private typealias Record = WorkoutRecord<ManualClock.Instant>

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func work(_ round: Int, from start: Double, to end: Double) -> Record.RecordedPhase {
        Record.RecordedPhase(kind: .work, round: round, start: at(start), end: at(end))
    }

    private func rest(_ round: Int, from start: Double, to end: Double) -> Record.RecordedPhase {
        Record.RecordedPhase(kind: .rest, round: round, start: at(start), end: at(end))
    }

    @Test func `Each Round's Work time is a row, rounding down, with no Rest`() {
        let record = Record(
            start: at(0),
            end: at(230),
            pauses: [],
            phases: [work(1, from: 0, to: 102.9), rest(1, from: 102.9, to: 162.9), work(2, from: 162.9, to: 230)]
        )

        let summary = RoundsSummary(record: record)

        #expect(
            summary.rows == [
                RoundsSummary.Row(round: 1, time: "1:42", spokenTime: "Round 1, 1 minute 42 seconds"),
                RoundsSummary.Row(round: 2, time: "1:07", spokenTime: "Round 2, 1 minute 7 seconds"),
            ]
        )
        #expect(summary.count == "2 Rounds")
    }

    @Test func `One Round reads in the singular`() {
        let record = Record(start: at(0), end: at(5), pauses: [], phases: [work(1, from: 0, to: 5)])

        #expect(RoundsSummary(record: record).count == "1 Round")
    }

    @Test func `The total is the active time, rounding down, read with its label`() {
        let record = Record(
            start: at(0),
            end: at(1_420.6),
            pauses: [at(100)..<at(130)],
            phases: [work(1, from: 0, to: 1_420.6)]
        )

        let summary = RoundsSummary(record: record)

        #expect(summary.total == "23:10")
        #expect(summary.spokenTotal == "Total 23 minutes 10 seconds")
        #expect(summary.rows.map(\.time) == ["23:10"])
    }

    /// A Workout Stopped before its first Work started has nothing to list.
    @Test func `A record with no Work has no rows and reads 0 Rounds`() {
        let summary = RoundsSummary(record: Record.lasting(0))

        #expect(summary.rows.isEmpty)
        #expect(summary.count == "0 Rounds")
        #expect(summary.total == "00:00")
    }
}
