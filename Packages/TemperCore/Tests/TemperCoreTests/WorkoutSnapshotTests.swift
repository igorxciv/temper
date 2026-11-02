import Testing

@testable import TemperCore

nonisolated struct WorkoutSnapshotTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>

    private let prepare = Phase(kind: .prepare, duration: .seconds(10))
    private let work = Phase(kind: .work, duration: .seconds(40), round: 3)
    private let rest = Phase(kind: .rest, duration: .seconds(20), round: 3)
    private let cooldown = Phase(kind: .cooldown, duration: .seconds(60))

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

    @Test(arguments: [Snapshot.Progress.finished, .stopped])
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
        #expect(Snapshot(progress: .finished, rounds: 8).fractionLeft(at: at(1)) == 0)
    }

    // MARK: The Round line

    @Test func `Prepare shows the Rounds ahead`() {
        #expect(
            running(prepare, endsAt: 10).roundLine
                == .count(number: 8, caption: "Rounds", spoken: "8 Rounds")
        )
    }

    @Test func `Prepare before a single Round uses the singular`() {
        #expect(
            running(prepare, endsAt: 10, rounds: 1).roundLine
                == .count(number: 1, caption: "Round", spoken: "1 Round")
        )
    }

    @Test func `Work and Rest show their Round and the total`() {
        let expected = RoundLine.count(number: 3, caption: "of 8", spoken: "Round 3 of 8")

        #expect(running(work, endsAt: 100).roundLine == expected)
        #expect(running(rest, endsAt: 100).roundLine == expected)
    }

    @Test func `Cooldown shows the last Round and speaks the total`() {
        #expect(
            running(cooldown, endsAt: 100).roundLine
                == .count(number: 8, caption: "of 8", spoken: "8 Rounds")
        )
    }

    @Test func `Cooldown after a single Round speaks the singular`() {
        #expect(
            running(cooldown, endsAt: 100, rounds: 1).roundLine
                == .count(number: 1, caption: "of 1", spoken: "1 Round")
        )
    }

    @Test(arguments: [Phase.Kind.prepare, .work, .rest, .cooldown])
    func `A Pause in any Phase shows Paused`(kind: Phase.Kind) {
        let phase = Phase(kind: kind, duration: .seconds(10), round: kind == .work ? 1 : nil)
        let snapshot = Snapshot(progress: .paused(phase: phase, timeLeft: .seconds(1)), rounds: 8)

        #expect(snapshot.roundLine == .paused)
    }

    @Test func `An ended Workout has no Round line`() {
        #expect(Snapshot(progress: .finished, rounds: 8).roundLine == nil)
    }

    // MARK: Staying awake

    @Test func `The screen stays awake while running and during a Pause`() {
        #expect(running(work, endsAt: 100).keepsScreenAwake)
        #expect(Snapshot(progress: .paused(phase: work, timeLeft: .seconds(1)), rounds: 8).keepsScreenAwake)
    }

    @Test func `The screen sleeps normally once the Workout has ended`() {
        #expect(!Snapshot(progress: .finished, rounds: 8).keepsScreenAwake)
        #expect(!Snapshot(progress: .stopped, rounds: 8).keepsScreenAwake)
    }
}
