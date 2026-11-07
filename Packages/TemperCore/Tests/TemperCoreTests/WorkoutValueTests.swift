import Testing

@testable import TemperCore

struct WorkoutValueTests {
    @Test func `30 minutes forces the seconds to 00`() {
        #expect(WorkoutValue.work.amount(minutes: 30, seconds: 25) == 1800)
        #expect(WorkoutValue.cooldown.amount(minutes: 30, seconds: 55) == 1800)
    }

    @Test func `Work can't go below 00:05`() {
        #expect(WorkoutValue.work.amount(minutes: 0, seconds: 0) == 5)
    }

    @Test(arguments: [WorkoutValue.prepare, .rest, .cooldown])
    func `An optional Phase can be turned off`(value: WorkoutValue) {
        #expect(value.amount(minutes: 0, seconds: 0) == 0)
    }

    @Test func `Minutes and seconds combine into seconds`() {
        #expect(WorkoutValue.rest.amount(minutes: 2, seconds: 15) == 135)
    }

    @Test func `The wheels offer 1 to 99 Rounds, 00 to 30 minutes and seconds in steps of 5`() {
        #expect(WorkoutValue.roundChoices == Array(1...99))
        #expect(WorkoutValue.minuteChoices == Array(0...30))
        #expect(WorkoutValue.secondChoices == [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55])
    }

    @Test(arguments: WorkoutValue.allCases)
    func `Every wheel choice below the limits is kept as it is`(value: WorkoutValue) {
        if value.isTime {
            for minutes in WorkoutValue.minuteChoices.dropLast() {
                for seconds in WorkoutValue.secondChoices where value != .work || minutes * 60 + seconds >= 5 {
                    #expect(value.amount(minutes: minutes, seconds: seconds) == minutes * 60 + seconds)
                }
            }
        } else {
            #expect(WorkoutValue.roundChoices.allSatisfy { value.clamped($0) == $0 })
        }
    }

    @Test func `Rounds stay between 1 and 99`() {
        #expect(WorkoutValue.rounds.clamped(0) == 1)
        #expect(WorkoutValue.rounds.clamped(100) == 99)
        #expect(WorkoutValue.rounds.clamped(42) == 42)
    }

    @Test func `A time falls back to a 5-second step inside its range`() {
        #expect(WorkoutValue.rest.clamped(17) == 15)
        #expect(WorkoutValue.rest.clamped(-20) == 0)
        #expect(WorkoutValue.work.clamped(3) == 5)
        #expect(WorkoutValue.prepare.clamped(9000) == 1800)
    }

    @Test func `A time reads as a clock, zero reads Off, and Rounds read as a number`() {
        #expect(WorkoutValue.work.text(for: 40) == "00:40")
        #expect(WorkoutValue.cooldown.text(for: 60) == "01:00")
        #expect(WorkoutValue.prepare.text(for: 0) == "Off")
        #expect(WorkoutValue.rounds.text(for: 8) == "8")
    }

    @Test func `Only a time has wheels for minutes and seconds`() {
        #expect(WorkoutValue.rest.isTime)
        #expect(!WorkoutValue.rounds.isTime)
        #expect(WorkoutValue.rest.phaseKind == .rest)
        #expect(WorkoutValue.rounds.phaseKind == nil)
    }

    @Test func `Settings read and write each value by its amount`() {
        var settings = WorkoutType.intervals.firstLaunch

        settings[.prepare] = 0
        settings[.rounds] = 3
        settings[.work] = 125
        settings[.rest] = 15
        settings[.cooldown] = 1800

        let expected = WorkoutSettings(
            prepare: .zero,
            rounds: 3,
            work: .seconds(125),
            rest: .seconds(15),
            cooldown: .seconds(1800)
        )
        #expect(settings == expected)
        #expect(WorkoutValue.allCases.map { settings[$0] } == [0, 3, 125, 15, 1800])
    }

    @Test func `Turning a Phase off skips it in the Workout and in the total`() {
        var settings = WorkoutType.intervals.firstLaunch

        settings[.prepare] = WorkoutValue.prepare.amount(minutes: 0, seconds: 0)
        settings[.rest] = WorkoutValue.rest.amount(minutes: 0, seconds: 0)
        settings[.cooldown] = WorkoutValue.cooldown.amount(minutes: 0, seconds: 0)

        let workout = WorkoutType.intervals.makeWorkout(from: settings)
        #expect(workout.phases.allSatisfy { $0.kind == .work })
        #expect(workout.totalDuration == .seconds(320))
    }

    @Test func `The widest total keeps counting in minutes`() {
        var settings = WorkoutType.intervals.firstLaunch

        settings[.rounds] = 4
        settings[.work] = 1800
        settings[.prepare] = 0
        settings[.rest] = 0
        settings[.cooldown] = 0

        #expect(WorkoutType.intervals.makeWorkout(from: settings).totalDuration?.clockText == "120:00")
    }
}
