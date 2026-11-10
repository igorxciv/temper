import Foundation
import Testing

@testable import TemperCore

/// The messages cross the mirrored workout session as JSON.
nonisolated struct MessageToWatchTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private static let workoutID = UUID(uuidString: "6A1F1A57-0C3E-4D52-9E33-6E3D2C1B0A99")!

    private static let record = HealthRecord(
        WorkoutRecord(
            start: ManualClock.Instant(offset: .zero), end: ManualClock.Instant(offset: .seconds(90)), pauses: [],
            phases: [.init(kind: .work, round: nil, start: .init(offset: .zero), end: .init(offset: .seconds(90)))]),
        of: .stopwatch, workoutID: workoutID, attempt: 1,
        anchor: ClockAnchor(instant: ManualClock.Instant(offset: .zero), date: start))

    @Test(arguments: [
        MessageToWatch.begin(
            workoutID: workoutID, start: start, workoutType: .openRounds, inTime: true, version: MessageToWatch.version),
        .update(.ended(.total(.seconds(530)))),
        .update(
            .phase(
                WatchPhase(
                    kind: .work, round: nil, start: start, end: start.addingTimeInterval(600), pausedAt: nil,
                    countsUp: true, line: .value("10:00", caption: .before("of"), spoken: "of 10 minutes"),
                    capsule: .pause))),
        .end(nil),
        .end(record),
        .discard,
    ])
    func `A message arrives as it was sent`(message: MessageToWatch) throws {
        #expect(try MessageToWatch(json: message.json()) == message)
    }

    @Test func `Data that isn't a message fails to decode`() {
        #expect(throws: (any Error).self) { try MessageToWatch(json: Data("{\"tap\":{}}".utf8)) }
    }
}
