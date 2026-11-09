import Testing

@testable import TemperCore

struct WorkoutTypeTests {
    private func stopwatch(prepare: Duration = .seconds(10), work: Duration = .seconds(600)) -> Workout {
        // Rounds, Rest and Cooldown are set to show a Stopwatch ignores them.
        WorkoutType.stopwatch.makeWorkout(
            from: WorkoutSettings(prepare: prepare, rounds: 8, work: work, rest: .seconds(20), cooldown: .seconds(60))
        )
    }

    @Test func `Intervals comes before Stopwatch, then Open Rounds`() {
        #expect(WorkoutType.allCases == [.intervals, .stopwatch, .openRounds])
    }

    @Test func `Each Workout Type has its title and tab icon`() {
        #expect(WorkoutType.intervals.title == "Intervals")
        #expect(WorkoutType.intervals.systemImage == "repeat")
        #expect(WorkoutType.stopwatch.title == "Stopwatch")
        #expect(WorkoutType.stopwatch.systemImage == "stopwatch")
        #expect(WorkoutType.openRounds.title == "Open Rounds")
        #expect(WorkoutType.openRounds.systemImage == "dumbbell")
    }

    @Test func `Each Workout Type has its setup rows, top to bottom`() {
        #expect(WorkoutType.intervals.values == [.prepare, .rounds, .work, .rest, .cooldown])
        #expect(WorkoutType.stopwatch.values == [.prepare, .work])
        #expect(WorkoutType.openRounds.values == [.prepare, .rest])
    }

    @Test func `The raw values are the ones remembered as the last-used Workout Type`() {
        #expect(WorkoutType(rawValue: "intervals") == .intervals)
        #expect(WorkoutType(rawValue: "stopwatch") == .stopwatch)
        #expect(WorkoutType(rawValue: "openRounds") == .openRounds)
    }

    @Test func `Intervals first launches at Prepare 00:10, 8 Rounds of 00:40 and 00:20, and Cooldown 01:00`() {
        let expected = WorkoutSettings(
            prepare: .seconds(10),
            rounds: 8,
            work: .seconds(40),
            rest: .seconds(20),
            cooldown: .seconds(60)
        )

        #expect(WorkoutType.intervals.firstLaunch == expected)
    }

    @Test func `A Stopwatch first launches at Prepare 00:10 and Work 10:00`() {
        let settings = WorkoutType.stopwatch.firstLaunch

        #expect(settings.prepare == .seconds(10))
        #expect(settings.work == .seconds(600))
    }

    @Test func `Open Rounds first launches at Prepare Off and Rest 01:00`() {
        #expect(WorkoutType.openRounds.firstLaunch.prepare == .zero)
        #expect(WorkoutType.openRounds.firstLaunch.rest == .seconds(60))
    }

    private func openRounds(prepare: Duration = .zero, rest: Duration) -> Workout {
        // Rounds, Work and Cooldown are set to show Open Rounds ignores them.
        WorkoutType.openRounds.makeWorkout(
            from: WorkoutSettings(prepare: prepare, rounds: 8, work: .seconds(40), rest: rest, cooldown: .seconds(60))
        )
    }

    @Test func `With Prepare Off, Open Rounds repeats an open Work and its Rest until Stop`() {
        let expected = Workout(
            phases: [],
            repeatingRound: [Phase(kind: .work, length: .open), Phase(kind: .rest, duration: .seconds(60))],
            warnsBeforeRestEnds: true
        )

        #expect(openRounds(rest: .seconds(60)) == expected)
    }

    @Test func `A zero Rest is dropped, so Open Rounds repeats the open Work alone`() {
        let expected = Workout(
            phases: [],
            repeatingRound: [Phase(kind: .work, length: .open)],
            warnsBeforeRestEnds: true
        )

        #expect(openRounds(rest: .zero) == expected)
    }

    @Test func `Open Rounds runs its Prepare once, before the first Round`() {
        let expected = Workout(
            phases: [Phase(kind: .prepare, duration: .seconds(10))],
            repeatingRound: [Phase(kind: .work, length: .open), Phase(kind: .rest, duration: .seconds(60))],
            warnsBeforeRestEnds: true
        )

        #expect(openRounds(prepare: .seconds(10), rest: .seconds(60)) == expected)
    }

    @Test func `After its Prepare, Open Rounds numbers the first Work as Round 1`() {
        let workout = openRounds(prepare: .seconds(10), rest: .seconds(60))

        let expected = [
            Phase(kind: .prepare, duration: .seconds(10)),
            Phase(kind: .work, length: .open, round: 1),
            Phase(kind: .rest, duration: .seconds(60), round: 1),
            Phase(kind: .work, length: .open, round: 2),
        ]
        #expect(Array(workout.phasesInOrder.prefix(4)) == expected)
    }

    @Test(arguments: [WorkoutType.intervals, .stopwatch])
    func `Only Open Rounds warns before a Rest ends`(type: WorkoutType) {
        #expect(!type.makeWorkout(from: type.firstLaunch).warnsBeforeRestEnds)
    }

    @Test func `Open Rounds has no total length and no set number of Rounds`() {
        let workout = WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch)

        #expect(workout.totalDuration == nil)
        #expect(workout.rounds == nil)
    }

    @Test func `A Stopwatch is a Prepare, then one Work with no Round that runs past its set length`() {
        let expected = [
            Phase(kind: .prepare, duration: .seconds(10)),
            Phase(kind: .work, length: .runsPast(.seconds(600))),
        ]

        #expect(stopwatch() == Workout(phases: expected))
    }

    @Test func `A zero Prepare is dropped, so a Stopwatch opens on Work`() {
        #expect(stopwatch(prepare: .zero) == Workout(phases: [Phase(kind: .work, length: .runsPast(.seconds(600)))]))
    }

    @Test func `A Stopwatch's set length is its Prepare plus its Work, and it has no Rounds`() {
        let workout = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)

        #expect(workout.totalDuration == .seconds(610))
        #expect(workout.rounds == 0)
    }

    @Test func `A Stopwatch needs a Work`() async {
        await #expect(processExitsWith: .failure) {
            _ = WorkoutType.stopwatch.makeWorkout(
                from: WorkoutSettings(prepare: .seconds(10), rounds: 1, work: .zero, rest: .zero, cooldown: .zero)
            )
        }
    }
}
