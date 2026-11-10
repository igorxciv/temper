import Foundation
import Testing

@testable import TemperCore

/// The mirrored session carries at most 100 KB per 10 s. Only `end` grows with the Workout, so it alone could reach
/// that, and nothing throttles it.
nonisolated struct MessageToWatchSizeTests {
    private typealias Instant = ManualClock.Instant

    /// 200 Rounds of Open Rounds, each Work ended by hand at an uneven time, then a Rest, with a Pause in every Work,
    /// on a real wall clock, so each date encodes at full length.
    private var longOpenRounds: HealthRecord {
        var phases: [WorkoutRecord<Instant>.RecordedPhase] = []
        var pauses: [Range<Instant>] = []
        var time = Duration.zero
        for round in 1...200 {
            let work = Instant(offset: time)
            pauses.append(work.advanced(by: .seconds(10.123_457))..<work.advanced(by: .seconds(25.987_654)))
            let rest = work.advanced(by: .seconds(97.314_159))
            let next = rest.advanced(by: .seconds(60))
            phases.append(.init(kind: .work, round: round, start: work, end: rest))
            phases.append(.init(kind: .rest, round: round, start: rest, end: next))
            time = Instant(offset: .zero).duration(to: next)
        }
        let record = WorkoutRecord(
            start: Instant(offset: .zero), end: Instant(offset: time), pauses: pauses, phases: phases)
        return HealthRecord(
            record, of: .openRounds, workoutID: UUID(), attempt: 1,
            anchor: ClockAnchor(
                instant: Instant(offset: .zero), date: Date(timeIntervalSince1970: 1_794_321_987.654_321))
        )!
    }

    @Test func `The end of a 200-Round Open Rounds encodes well under the session's 100 KB`() throws {
        let size = try MessageToWatch.end(longOpenRounds).json().count

        #expect(size < 50_000)
    }
}
