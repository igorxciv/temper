import Foundation
import Testing

@testable import TemperCore

/// Which wrist haptics the Watch schedules and plays for each update: each Cue once, at its date or on arrival.
nonisolated struct CueHapticsTests {
    /// The wall clock at zero seconds into each test.
    private let zero = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func date(_ seconds: Double) -> Date {
        zero.addingTimeInterval(seconds)
    }

    private func cue(_ cue: Cue, at seconds: Double) -> WatchCue {
        WatchCue(cue: cue, date: date(seconds))
    }

    private func phase(
        _ kind: Phase.Kind, round: Int? = 1, start: Double, pausedAt: Double? = nil, cues: [WatchCue] = []
    ) -> WatchState {
        .phase(
            WatchPhase(
                kind: kind, round: round, start: date(start), end: nil, pausedAt: pausedAt.map(date), countsUp: false,
                line: nil, capsule: .pause, cues: cues))
    }

    /// The plan for the last of `updates`, each arriving at its time in seconds, after the ones before it.
    private func plan(after updates: (WatchState, arrival: Double)...) -> CueHaptics.Plan {
        var haptics = CueHaptics()
        var plan = CueHaptics.Plan()
        for (state, arrival) in updates {
            plan = haptics.plan(for: state, arrivingAt: date(arrival))
        }
        return plan
    }

    private func expected(cancels: Bool = false, now: Cue? = nil, schedules: [WatchCue] = []) -> CueHaptics.Plan {
        CueHaptics.Plan(cancelsScheduled: cancels, playsNow: now, schedules: schedules)
    }

    @Test func `An update schedules the haptics of its Cues to come, at their dates`() {
        let rest = phase(.rest, start: -5, cues: [cue(.tenSeconds, at: 20), cue(.work, at: 30)])

        #expect(plan(after: (rest, 0.05)) == expected(schedules: [cue(.tenSeconds, at: 20), cue(.work, at: 30)]))
    }

    @Test func `Prepare plays nothing as it starts`() {
        let prepare = phase(.prepare, round: nil, start: 0, cues: [cue(.work, at: 10)])

        #expect(plan(after: (prepare, 0)) == expected(schedules: [cue(.work, at: 10)]))
    }

    @Test func `A Stopwatch's Work schedules "Finish" at its set length`() {
        let work = phase(.work, round: nil, start: -5, cues: [cue(.finish, at: 600)])

        #expect(plan(after: (work, 0)) == expected(schedules: [cue(.finish, at: 600)]))
    }

    @Test func `A haptic that came due before the next Phase's update played on time, so it doesn't play again`() {
        let work = phase(.work, start: 0, cues: [cue(.rest, at: 20)])
        let rest = phase(.rest, start: 20, cues: [cue(.work, at: 30)])

        #expect(plan(after: (work, 0), (rest, 20.05)) == expected(schedules: [cue(.work, at: 30)]))
    }

    /// Nothing marks an open Phase's end until Done, so nothing was scheduled for the Phase after it.
    @Test func `A Phase reached at Done plays its Cue on arrival`() {
        let rest = phase(.rest, start: 42, cues: [cue(.work, at: 102)])

        #expect(
            plan(after: (phase(.work, start: 0), 0), (rest, 42.06))
                == expected(now: .rest, schedules: [cue(.work, at: 102)]))
    }

    /// The Watch's clock can run a few milliseconds behind the iPhone's.
    @Test func `A Phase that arrives before its scheduled haptic cancels it, and plays its Cue on arrival instead`() {
        let work = phase(.work, start: 0, cues: [cue(.rest, at: 20)])
        let rest = phase(.rest, start: 20, cues: [cue(.work, at: 30)])

        #expect(
            plan(after: (work, 0), (rest, 19.99))
                == expected(cancels: true, now: .rest, schedules: [cue(.work, at: 30)]))
    }

    @Test func `A Pause cancels what's scheduled, and Resume schedules it again at its new date`() {
        let work = phase(.work, start: 0, cues: [cue(.rest, at: 20)])
        let paused = phase(.work, start: 0, pausedAt: 5)
        let resumed = phase(.work, start: 60, cues: [cue(.rest, at: 80)])

        #expect(plan(after: (work, 0), (paused, 5)) == expected(cancels: true))
        #expect(plan(after: (work, 0), (paused, 5), (resumed, 65)) == expected(schedules: [cue(.rest, at: 80)]))
    }

    /// Resume moves a Phase's start later by the Pause, so it can look as new as a Phase just begun.
    @Test func `An update for the same Phase doesn't play its Cue again`() {
        let rest = phase(.rest, start: 10)
        let paused = phase(.rest, start: 10, pausedAt: 10.3)
        let resumed = phase(.rest, start: 19.7)

        #expect(plan(after: (phase(.work, start: 0), 0.05), (rest, 10.05)) == expected(now: .rest))
        #expect(
            plan(after: (phase(.work, start: 0), 0.05), (rest, 10.05), (paused, 10.35), (resumed, 20.05)) == expected())
    }

    /// The iPhone resends its latest update to a Watch that joins late or reconnects.
    @Test func `A Phase that began over a second before its update arrived plays no Cue on arrival`() {
        let work = phase(.work, start: 0, cues: [cue(.rest, at: 20)])

        #expect(plan(after: (work, 1.7)) == expected(schedules: [cue(.rest, at: 20)]))
    }

    @Test func `A Cue whose date has passed by the time its update arrives isn't scheduled`() {
        let rest = phase(.rest, start: -5, cues: [cue(.tenSeconds, at: 20), cue(.work, at: 30)])

        #expect(plan(after: (rest, 25)) == expected(schedules: [cue(.work, at: 30)]))
    }

    @Test func `Workout complete plays at its date, and the end that follows plays nothing more`() {
        let work = phase(.work, start: 0, cues: [cue(.workoutComplete, at: 20)])

        #expect(plan(after: (work, 0), (.ended(.total(.seconds(20))), 20.05)) == expected())
    }

    /// Only Intervals says Workout complete, and it ends on its complete screen only when it finishes.
    @Test func `A finish that arrives before Workout complete's haptic plays it on arrival instead`() {
        let work = phase(.work, start: 0, cues: [cue(.workoutComplete, at: 20)])

        #expect(
            plan(after: (work, 0), (.ended(.total(.seconds(20))), 19.99))
                == expected(cancels: true, now: .workoutComplete))
    }

    @Test func `A Stop cancels the haptics still to come`() {
        let work = phase(.work, start: 0, cues: [cue(.rest, at: 20)])

        #expect(plan(after: (work, 0), (.ended(nil), 8)) == expected(cancels: true))
    }

    @Test func `Cancelling all reports whether anything was scheduled`() {
        var haptics = CueHaptics()
        let nothingScheduled = haptics.cancelAll()
        _ = haptics.plan(for: phase(.work, start: 0, cues: [cue(.rest, at: 20)]), arrivingAt: date(0))
        let restScheduled = haptics.cancelAll()
        let cancelledAgain = haptics.cancelAll()

        #expect(!nothingScheduled)
        #expect(restScheduled)
        #expect(!cancelledAgain)
    }

    // MARK: Each Cue's haptic

    @Test(arguments: [
        (Cue.work, WristHaptic.Tap.notification, 2),
        (.rest, .notification, 1),
        (.cooldown, .notification, 3),
        (.workoutComplete, .success, 2),
        (.tenSeconds, .click, 3),
        (.finish, .success, 2),
    ])
    func `Each Cue has its own count of one kind of tap`(cue: Cue, tap: WristHaptic.Tap, count: Int) {
        #expect(cue.wristHaptic == WristHaptic(tap: tap, count: count))
    }

    @Test func `The taps start 0.7 s apart`() {
        #expect(WristHaptic(tap: .click, count: 3).offsets == [.zero, .milliseconds(700), .milliseconds(1_400)])
    }
}
