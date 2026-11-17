import Testing

@testable import TemperCore

struct PlanBoardTests {
    @Test func `Intervals writes Prepare, its Rounds bracketed under their count, then Cooldown`() {
        let board = PlanBoard(workoutType: .intervals, settings: WorkoutType.intervals.firstLaunch)

        #expect(
            board.items == [
                .line(.init(kind: .prepare, length: .set(.seconds(10)), value: .prepare)),
                .rounds(
                    .times(8),
                    [
                        .init(kind: .work, length: .set(.seconds(40)), value: .work),
                        .init(kind: .rest, length: .set(.seconds(20)), value: .rest),
                    ],
                    value: .rounds
                ),
                .line(.init(kind: .cooldown, length: .set(.seconds(60)), value: .cooldown)),
            ]
        )
        #expect(board.note == "The last Round skips Rest.")
    }

    @Test func `An Off value keeps its line, so it can be turned back on where it stands`() {
        var settings = WorkoutType.intervals.firstLaunch
        settings[.prepare] = 0
        settings[.rest] = 0

        let board = PlanBoard(workoutType: .intervals, settings: settings)

        #expect(board.allLines.map(\.time) == ["Off", "0:40", "Off", "1:00"])
        // With Rest Off, the last Round has no Rest to skip.
        #expect(board.note == nil)
    }

    @Test func `One Round has no Rest to skip`() {
        var settings = WorkoutType.intervals.firstLaunch
        settings[.rounds] = 1

        #expect(PlanBoard(workoutType: .intervals, settings: settings).note == nil)
    }

    @Test func `A Stopwatch's Work reads as its set length, then until Done`() {
        let board = PlanBoard(workoutType: .stopwatch, settings: WorkoutType.stopwatch.firstLaunch)
        let work = board.allLines[1]

        #expect(work.time == "10:00")
        #expect(work.caption == "then until Done")
        #expect(work.value == .work)
        #expect(board.note == "Work counts on past 10:00 until you tap Done.")
    }

    @Test func `Open Rounds shows its open Work, which no value edits, under Rounds until Stop and no Cooldown`() {
        let board = PlanBoard(workoutType: .openRounds, settings: WorkoutType.openRounds.firstLaunch)

        #expect(
            board.items == [
                .line(.init(kind: .prepare, length: .off, value: .prepare)),
                .rounds(
                    .untilStop,
                    [
                        .init(kind: .work, length: .open),
                        .init(kind: .rest, length: .set(.seconds(60)), value: .rest),
                    ],
                    value: .rounds
                ),
            ]
        )
        #expect(board.allLines[1].time == "Open")
        #expect(board.allLines[1].caption == "until Done")
        #expect(
            board.note
                == "Tap Done to end each open Work. Rounds repeat until you Stop. "
                + "Set a number of Rounds to add a Cooldown.")
    }

    @Test func `Open Rounds with a number of Rounds shows its Cooldown after them`() {
        var settings = WorkoutType.openRounds.firstLaunch
        settings[.rounds] = 5

        let board = PlanBoard(workoutType: .openRounds, settings: settings)

        #expect(
            board.items == [
                .line(.init(kind: .prepare, length: .off, value: .prepare)),
                .rounds(
                    .times(5),
                    [
                        .init(kind: .work, length: .open),
                        .init(kind: .rest, length: .set(.seconds(60)), value: .rest),
                    ],
                    value: .rounds
                ),
                .line(.init(kind: .cooldown, length: .off, value: .cooldown)),
            ]
        )
        #expect(board.note == "Tap Done to end each open Work. The last Round skips Rest.")
    }

    @Test func `A described Plan reads as its Blocks, with no setup value to edit`() {
        let plan = Plan(
            activity: .traditionalStrengthTraining,
            blocks: [
                .rounds(
                    .times(10),
                    [PlannedPhase(kind: .work, length: .open), PlannedPhase(kind: .rest, duration: .seconds(60))]
                )
            ]
        )

        let board = PlanBoard(plan: plan)

        #expect(
            board.items == [
                .rounds(
                    .times(10),
                    [
                        .init(kind: .work, length: .open, exercisePlace: Plan.PhasePlace(block: 0, phase: 0)),
                        .init(kind: .rest, length: .set(.seconds(60))),
                    ],
                    value: nil
                )
            ]
        )
        #expect(board.allLines.allSatisfy { $0.value == nil })
        #expect(board.note == "Tap Done to end each open Work. The last Round skips Rest.")
    }

    @Test func `VoiceOver reads each line's Phase and length in words`() {
        #expect(PlanBoard.Line(kind: .rest, length: .set(.seconds(80))).spokenText == "Rest, 1 minute 20 seconds")
        #expect(PlanBoard.Line(kind: .prepare, length: .off).spokenText == "Prepare, Off")
        #expect(PlanBoard.Line(kind: .work, length: .open).spokenText == "Work, open until Done")
    }

    // MARK: Exercises

    private let circuit = Plan(
        activity: .highIntensityIntervalTraining,
        blocks: [
            .phase(PlannedPhase(kind: .prepare, duration: .seconds(10))),
            .rounds(
                .times(3),
                [
                    PlannedPhase(kind: .work, duration: .seconds(30), exercise: Exercise("Lunches")),
                    PlannedPhase(kind: .rest, duration: .seconds(15)),
                    PlannedPhase(kind: .work, duration: .seconds(30)),
                ]
            ),
        ]
    )

    @Test func `A described Plan's Work lines show their Exercise and can rename it, and no other line can`() {
        let lines = PlanBoard(plan: circuit).allLines

        #expect(lines.map(\.exercise?.name) == [nil, "Lunches", nil, nil])
        #expect(lines.map { $0.exercisePlace != nil } == [false, true, false, true])
        #expect(lines[1].spokenText == "Lunches, Work, 30 seconds")
    }

    @Test func `A Workout Type's lines never rename an Exercise`() {
        let board = PlanBoard(workoutType: .intervals, settings: WorkoutType.intervals.firstLaunch)

        #expect(board.allLines.allSatisfy { $0.exercisePlace == nil })
    }

    @Test func `Renaming a line's Exercise changes only that Work, and a blank name clears it`() throws {
        let lines = PlanBoard(plan: circuit).allLines
        let misheard = try #require(lines[1].exercisePlace)
        let unnamed = try #require(lines[3].exercisePlace)

        let renamed = circuit.renamingExercise(at: misheard, to: "  Lunges ").renamingExercise(
            at: unnamed, to: "Squats")
        let cleared = renamed.renamingExercise(at: misheard, to: " ")

        #expect(PlanBoard(plan: renamed).allLines.map(\.exercise?.name) == [nil, "Lunges", nil, "Squats"])
        #expect(PlanBoard(plan: cleared).allLines.map(\.exercise?.name) == [nil, nil, nil, "Squats"])
        #expect(PlanBoard(plan: renamed).allLines.map(\.time) == PlanBoard(plan: circuit).allLines.map(\.time))
    }
}
