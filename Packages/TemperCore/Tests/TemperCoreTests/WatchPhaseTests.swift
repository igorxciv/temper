import Foundation
import Testing

@testable import TemperCore

/// The Watch draws a Phase's time and bar from its dates, the way the iPhone's ring rounds them.
nonisolated struct WatchPhaseTests {
    private let date = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func phase(
        start: Double, end: Double?, pausedAt: Double? = nil, countsUp: Bool = false
    ) -> WatchPhase {
        WatchPhase(
            kind: .work, round: 3, start: date.addingTimeInterval(start), end: end.map(date.addingTimeInterval),
            pausedAt: pausedAt.map(date.addingTimeInterval), countsUp: countsUp, line: nil, capsule: .pause)
    }

    @Test func `Counting down, the time left rounds up and the bar empties`() {
        let work = phase(start: -32.5, end: 7.5)

        #expect(work.time(at: date) == "00:08")
        #expect(work.spokenTime(at: date) == "8 seconds left")
        #expect(work.fill(at: date) == 0.1875)
    }

    @Test func `Counting down, the time holds at zero past the end, until the next update`() {
        let work = phase(start: -40, end: 0)

        #expect(work.time(at: date.addingTimeInterval(3)) == "00:00")
        #expect(work.fill(at: date.addingTimeInterval(3)) == 0)
    }

    @Test func `A Paused Phase holds its time and bar at the Pause`() {
        let work = phase(start: -30, end: 10, pausedAt: 0)

        #expect(work.time(at: date.addingTimeInterval(500)) == "00:10")
        #expect(work.fill(at: date.addingTimeInterval(500)) == 0.25)
    }

    @Test func `An open Phase counts up, rounding down, over an empty bar`() {
        let work = phase(start: -30, end: nil, countsUp: true)

        #expect(work.time(at: date.addingTimeInterval(0.9)) == "00:30")
        #expect(work.spokenTime(at: date.addingTimeInterval(0.9)) == "30 seconds elapsed")
        #expect(work.fill(at: date) == 0)
    }

    @Test func `A Stopwatch's Work fills its bar up to its set length, then keeps counting over a full bar`() {
        let work = phase(start: -450, end: 150, countsUp: true)

        #expect(work.time(at: date) == "07:30")
        #expect(work.fill(at: date) == 0.75)
        #expect(work.time(at: date.addingTimeInterval(422.5)) == "14:32")
        #expect(work.fill(at: date.addingTimeInterval(422.5)) == 1)
    }

    @Test func `Past an hour the time keeps counting in minutes`() {
        let work = phase(start: -4_335, end: nil, countsUp: true)

        #expect(work.time(at: date) == "72:15")
    }

    /// The Watch and the iPhone show the same second, give or take the clocks' few milliseconds.
    @Test(arguments: [0.0, 4.2, 9.999, 10, 25.5, 40, 41])
    func `The Watch shows the same time and bar as the iPhone's ring`(seconds: Double) throws {
        typealias Instant = ManualClock.Instant
        let display = RunningDisplay<Instant>(
            workoutType: .intervals,
            workout: WorkoutType.intervals.makeWorkout(from: WorkoutType.intervals.firstLaunch),
            snapshot: WorkoutSnapshot(
                progress: .running(
                    phase: Phase(kind: .work, duration: .seconds(40), round: 1), endsAt: .init(offset: .seconds(40))),
                rounds: 8))
        guard case .phase(let watch) = display.watchState(at: Instant(offset: .zero), date: date) else {
            Issue.record("Expected a Phase")
            return
        }
        let ring = display.ring(at: Instant(offset: .seconds(seconds)))
        let later = date.addingTimeInterval(seconds)

        #expect(watch.time(at: later) == ring.time)
        #expect(watch.spokenTime(at: later) == ring.spokenTime)
        #expect(abs(watch.fill(at: later) - ring.fill) < 1e-9)
    }
}
