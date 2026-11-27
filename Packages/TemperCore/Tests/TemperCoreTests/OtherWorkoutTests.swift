import Foundation
import Testing

@testable import TemperCore

nonisolated struct OtherWorkoutTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func `With no session of its own lately, the Watch counts the last minute's readings`() {
        #expect(OtherWorkout.countStart(now: now, ownSessionEnded: nil) == now.addingTimeInterval(-60))
        #expect(
            OtherWorkout.countStart(now: now, ownSessionEnded: now.addingTimeInterval(-300))
                == now.addingTimeInterval(-60))
    }

    /// Temper's own session collects readings at a workout's pace, and they'd look like another app's workout.
    @Test func `After its own session ended within the minute, the Watch counts only from that end`() {
        let ended = now.addingTimeInterval(-20)

        #expect(OtherWorkout.countStart(now: now, ownSessionEnded: ended) == ended)
    }

    /// Outside a workout Apple Watch measures heart rate every few minutes, and under one every few seconds.
    @Test func `Readings at a workout's pace mean another workout is running, and the background pace doesn't`() {
        #expect(!OtherWorkout.isRunning(readings: 0))
        #expect(!OtherWorkout.isRunning(readings: 2))
        #expect(!OtherWorkout.isRunning(readings: 4))
        #expect(OtherWorkout.isRunning(readings: 5))
        #expect(OtherWorkout.isRunning(readings: 12))
    }
}
