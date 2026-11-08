import Testing

@testable import TemperCore

nonisolated struct WorkoutSnapshotTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>

    private let work = Phase(kind: .work, duration: .seconds(40), round: 3)

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func running(_ phase: Phase, endsAt end: Double, rounds: Int = 8) -> Snapshot {
        Snapshot(progress: .running(phase: phase, endsAt: at(end)), rounds: rounds)
    }

    // MARK: Time left

    @Test func `While running, the time left is the time to the Phase's end`() {
        #expect(running(work, endsAt: 100).timeLeft(at: at(62.5)) == .seconds(37.5))
    }

    @Test(arguments: [100.0, 100.001, 5_000.0])
    func `The time left stays at zero from the Phase's end until the next snapshot`(now: Double) {
        #expect(running(work, endsAt: 100).timeLeft(at: at(now)) == .zero)
    }

    @Test func `While Paused, the time left ignores now`() {
        let snapshot = Snapshot(progress: .paused(phase: work, timeLeft: .seconds(12)), rounds: 8)

        #expect(snapshot.timeLeft(at: at(1)) == .seconds(12))
        #expect(snapshot.timeLeft(at: at(9_000)) == .seconds(12))
    }

    @Test(arguments: [Snapshot.Progress.finished(.lasting(0)), .stopped(.lasting(0))])
    private func `An ended Workout has no time left`(progress: Snapshot.Progress) {
        #expect(Snapshot(progress: progress, rounds: 8).timeLeft(at: at(1)) == .zero)
    }

    // MARK: The ring

    @Test func `The ring is full as a Phase starts and empties as time runs out`() {
        let snapshot = running(work, endsAt: 100)

        #expect(snapshot.fractionLeft(at: at(60)) == 1)
        #expect(snapshot.fractionLeft(at: at(90)) == 0.25)
        #expect(snapshot.fractionLeft(at: at(100)) == 0)
    }

    @Test func `The ring clamps at empty past the Phase's end`() {
        #expect(running(work, endsAt: 100).fractionLeft(at: at(150)) == 0)
    }

    @Test func `The ring clamps at full before the Phase starts`() {
        #expect(running(work, endsAt: 100).fractionLeft(at: at(10)) == 1)
    }

    @Test func `The ring holds its place during a Pause`() {
        let snapshot = Snapshot(progress: .paused(phase: work, timeLeft: .seconds(10)), rounds: 8)

        #expect(snapshot.fractionLeft(at: at(9_000)) == 0.25)
    }

    @Test func `An ended Workout's ring is empty`() {
        #expect(Snapshot(progress: .finished(.lasting(0)), rounds: 8).fractionLeft(at: at(1)) == 0)
    }

    // MARK: Time spent

    @Test func `A Phase with a set length has spent the time it no longer has left`() {
        #expect(running(work, endsAt: 100).elapsed(at: at(70)) == .seconds(10))
        #expect(
            Snapshot(progress: .paused(phase: work, timeLeft: .seconds(12)), rounds: 8).elapsed(at: at(1))
                == .seconds(28))
    }

    @Test func `An ended Workout has spent no time in a Phase`() {
        #expect(Snapshot(progress: .finished(.lasting(0)), rounds: 8).elapsed(at: at(1)) == .zero)
    }

    // MARK: Open Phases

    private let openWork = Phase(kind: .work, length: .open, round: 3)

    @Test func `A running open Phase counts the time since its start, and has no time left`() {
        let snapshot = Snapshot(progress: .runningOpen(phase: openWork, startedAt: at(100)), rounds: nil)

        #expect(snapshot.phase == openWork)
        #expect(!snapshot.isPaused)
        #expect(snapshot.elapsed(at: at(137.5)) == .seconds(37.5))
        #expect(snapshot.timeLeft(at: at(137.5)) == .zero)
        #expect(snapshot.fractionLeft(at: at(137.5)) == 0)
    }

    @Test func `A running open Phase has spent no time before its start`() {
        let snapshot = Snapshot(progress: .runningOpen(phase: openWork, startedAt: at(100)), rounds: nil)

        #expect(snapshot.elapsed(at: at(99)) == .zero)
    }

    @Test func `A Paused open Phase holds the time it had spent, ignoring now`() {
        let snapshot = Snapshot(progress: .pausedOpen(phase: openWork, elapsed: .seconds(42)), rounds: nil)

        #expect(snapshot.phase == openWork)
        #expect(snapshot.isPaused)
        #expect(snapshot.elapsed(at: at(1)) == .seconds(42))
        #expect(snapshot.elapsed(at: at(9_000)) == .seconds(42))
        #expect(snapshot.timeLeft(at: at(1)) == .zero)
    }

    @Test func `The screen stays awake through an open Phase, running or Paused`() {
        #expect(Snapshot(progress: .runningOpen(phase: openWork, startedAt: at(1)), rounds: nil).keepsScreenAwake)
        #expect(Snapshot(progress: .pausedOpen(phase: openWork, elapsed: .seconds(1)), rounds: nil).keepsScreenAwake)
    }

    // MARK: Staying awake

    @Test func `The screen stays awake while running and during a Pause`() {
        #expect(running(work, endsAt: 100).keepsScreenAwake)
        #expect(Snapshot(progress: .paused(phase: work, timeLeft: .seconds(1)), rounds: 8).keepsScreenAwake)
    }

    @Test func `The screen sleeps normally once the Workout has ended`() {
        #expect(!Snapshot(progress: .finished(.lasting(0)), rounds: 8).keepsScreenAwake)
        #expect(!Snapshot(progress: .stopped(.lasting(0)), rounds: 8).keepsScreenAwake)
    }
}
