import Testing

@testable import TemperCore

/// `nonisolated` because the Workout engine reads the Timeline off the main actor.
nonisolated struct TimelineTests {
    private let prepare = Phase(kind: .prepare, duration: .seconds(10))
    private let firstWork = Phase(kind: .work, duration: .seconds(30), round: 1)
    private let rest = Phase(kind: .rest, duration: .seconds(15), round: 1)
    private let secondWork = Phase(kind: .work, duration: .seconds(30), round: 2)
    private let cooldown = Phase(kind: .cooldown, duration: .seconds(60))

    /// Phases start at 0, 10, 40, 55 and 85 s, and the Workout finishes at 145 s.
    private var timeline: Timeline {
        Timeline(workout: Workout(phases: [prepare, firstWork, rest, secondWork, cooldown]))
    }

    @Test func `The first Phase runs with its full time left at zero`() {
        let position = timeline.position(at: .zero)

        #expect(position.phase == prepare)
        #expect(position.timeLeft == .seconds(10))
    }

    @Test func `Time left counts down inside a Phase`() {
        let position = timeline.position(at: .milliseconds(47_250))

        #expect(position.phase == rest)
        #expect(position.timeLeft == .milliseconds(7_750))
    }

    @Test func `A Phase's end is the start of the next Phase, with its full time left`() {
        let position = timeline.position(at: .seconds(40))

        #expect(position.phase == rest)
        #expect(position.timeLeft == .seconds(15))
    }

    @Test(arguments: [145, 146, 10_000])
    func `At or past the total length the Workout is finished with no time left`(seconds: Int) {
        let position = timeline.position(at: .seconds(seconds))

        #expect(position.phase == nil)
        #expect(position.timeLeft == .zero)
        #expect(position.isFinished)
    }

    @Test func `A Workout with one Work runs that Work and then finishes`() {
        let timeline = Timeline(workout: Workout(phases: [firstWork]))

        #expect(timeline.position(at: .seconds(29)).phase == firstWork)
        #expect(timeline.position(at: .seconds(30)).isFinished)
    }

    @Test func `Prepare has no Cue, so the next Cue from a Prepare is the first Work`() {
        #expect(timeline.position(at: .zero).nextCue == UpcomingCue(cue: .work, due: .seconds(10)))
    }

    @Test func `The next Cue names the Phase that follows the current one`() {
        #expect(timeline.position(at: .seconds(20)).nextCue == UpcomingCue(cue: .rest, due: .seconds(40)))
        #expect(timeline.position(at: .seconds(60)).nextCue == UpcomingCue(cue: .cooldown, due: .seconds(85)))
    }

    @Test func `A Cue due exactly now is still the next Cue`() {
        #expect(timeline.position(at: .seconds(40)).nextCue == UpcomingCue(cue: .rest, due: .seconds(40)))
    }

    @Test func `The last Phase leads to Workout complete, due at the finish`() {
        #expect(timeline.position(at: .seconds(100)).nextCue == UpcomingCue(cue: .workoutComplete, due: .seconds(145)))
        #expect(timeline.position(at: .seconds(145)).nextCue == UpcomingCue(cue: .workoutComplete, due: .seconds(145)))
    }

    @Test func `Past the finish there is no next Cue`() {
        #expect(timeline.position(at: .seconds(146)).nextCue == nil)
    }

    @Test func `A Workout that opens on Work has its Cue due at zero`() {
        let timeline = Timeline(workout: Workout(phases: [firstWork, rest, secondWork]))

        #expect(timeline.position(at: .zero).nextCue == UpcomingCue(cue: .work, due: .zero))
    }

    @Test func `With no Rest, each Work is followed by another Work Cue`() {
        let timeline = Timeline(workout: Workout(phases: [firstWork, secondWork]))

        #expect(timeline.position(at: .seconds(1)).nextCue == UpcomingCue(cue: .work, due: .seconds(30)))
    }

    @Test func `With no Cooldown, the last Work leads to Workout complete`() {
        let timeline = Timeline(workout: Workout(phases: [prepare, firstWork]))

        #expect(timeline.position(at: .seconds(11)).nextCue == UpcomingCue(cue: .workoutComplete, due: .seconds(40)))
    }

    @Test func `Time spent counts up inside a Phase`() {
        #expect(timeline.position(at: .milliseconds(47_250)).elapsed == .milliseconds(7_250))
        #expect(timeline.position(at: .seconds(40)).elapsed == .zero)
    }

    // MARK: Open Phases

    private let openWork = Phase(kind: .work, length: .open, round: 1)

    /// A Prepare of 10 s, then an open Work, then a Rest that can't be placed until the Work is marked Done.
    private var openTimeline: Timeline {
        Timeline(workout: Workout(phases: [prepare, openWork, rest]))
    }

    @Test(arguments: [10, 11, 100_000])
    func `An open Phase holds the position with no time left, however long it runs`(seconds: Int) {
        let position = openTimeline.position(at: .seconds(seconds))

        #expect(position.phase == openWork)
        #expect(position.timeLeft == .zero)
        #expect(position.elapsed == .seconds(seconds - 10))
        #expect(!position.isFinished)
    }

    @Test func `An open Phase's own Cue is due at its start`() {
        #expect(openTimeline.position(at: .seconds(5)).nextCue == UpcomingCue(cue: .work, due: .seconds(10)))
        #expect(openTimeline.position(at: .seconds(10)).nextCue == UpcomingCue(cue: .work, due: .seconds(10)))
    }

    @Test func `Once an open Phase has started, no Cue is upcoming`() {
        #expect(openTimeline.position(at: .milliseconds(10_001)).nextCue == nil)
        #expect(openTimeline.position(at: .seconds(100_000)).nextCue == nil)
    }

    // MARK: The "10 seconds" Cue

    /// Open Rounds with a Rest of `rest` seconds, its first Work marked Done at 40 s.
    private func openRounds(rest: Int) -> Timeline? {
        var settings = WorkoutType.openRounds.firstLaunch
        settings[.rest] = rest
        return Timeline(workout: WorkoutType.openRounds.makeWorkout(from: settings)).markingDone(at: .seconds(40))
    }

    @Test func `In Open Rounds, "10 seconds" is due 10s before the Rest that Done placed ends`() {
        let timeline = openRounds(rest: 60)

        #expect(timeline?.position(at: .seconds(41)).nextCue == UpcomingCue(cue: .tenSeconds, due: .seconds(90)))
        #expect(
            timeline?.position(at: .milliseconds(90_001)).nextCue == UpcomingCue(cue: .countdown, due: .seconds(95)))
    }

    @Test func `An Open Rounds Rest of 00:20 has "10 seconds" halfway through`() {
        #expect(
            openRounds(rest: 20)?.position(at: .seconds(41)).nextCue == UpcomingCue(cue: .tenSeconds, due: .seconds(50))
        )
    }

    @Test func `An Open Rounds Rest under 00:20 has no "10 seconds"`() {
        #expect(
            openRounds(rest: 15)?.position(at: .seconds(41)).nextCue == UpcomingCue(cue: .countdown, due: .seconds(50)))
    }

    @Test func `Intervals has no "10 seconds", however long its Rest`() {
        var settings = WorkoutType.intervals.firstLaunch
        settings[.rest] = 60
        let timeline = Timeline(workout: WorkoutType.intervals.makeWorkout(from: settings))

        // Round 1's Rest runs from 50 to 110 s.
        #expect(timeline.position(at: .seconds(51)).nextCue == UpcomingCue(cue: .countdown, due: .seconds(105)))
    }

    // MARK: A Phase that runs past its set length

    private let stopwatchWork = Phase(kind: .work, length: .runsPast(.seconds(600)))

    /// A Stopwatch: Prepare 00:10, then a Work of 10:00 that reaches its set length at 610 s and runs on until Done.
    private var stopwatch: Timeline {
        Timeline(workout: Workout(phases: [prepare, stopwatchWork]))
    }

    @Test func `A Phase that runs past its set length counts its time left down to it`() {
        let position = stopwatch.position(at: .seconds(310))

        #expect(position.phase == stopwatchWork)
        #expect(position.timeLeft == .seconds(300))
        #expect(!position.runsOpen)
    }

    @Test(arguments: [610, 611, 100_000])
    func `Past its set length it holds the position with no time left, however long it runs`(seconds: Int) {
        let position = stopwatch.position(at: .seconds(seconds))

        #expect(position.phase == stopwatchWork)
        #expect(position.timeLeft == .zero)
        #expect(position.elapsed == .seconds(seconds - 10))
        #expect(position.runsOpen)
    }

    @Test func `Finish is due at its set length, and Workout complete never is`() {
        #expect(stopwatch.position(at: .seconds(11)).nextCue == UpcomingCue(cue: .finish, due: .seconds(610)))
        #expect(stopwatch.position(at: .seconds(610)).nextCue == UpcomingCue(cue: .finish, due: .seconds(610)))
        #expect(stopwatch.position(at: .milliseconds(610_001)).nextCue == nil)
    }

    @Test func `It has no finish until Done`() {
        #expect(stopwatch.finish == nil)
    }

    @Test(arguments: [10, 300, 609])
    func `Done before its set length ends nothing`(seconds: Int) {
        #expect(stopwatch.markingDone(at: .seconds(seconds)) == nil)
    }

    @Test func `Done past its set length finishes the Workout there, with no Cue for it`() {
        let done = stopwatch.markingDone(at: .seconds(882))

        #expect(done?.finish == .seconds(882))
        #expect(done?.position(at: .seconds(882)).isFinished == true)
        #expect(done?.position(at: .seconds(700)).nextCue == nil)
    }

    // MARK: The Countdown

    private func countingDown(_ phases: [Phase], repeatingRound: [Phase] = []) -> Timeline {
        Timeline(workout: Workout(phases: phases, repeatingRound: repeatingRound, countsDown: true))
    }

    @Test func `The Countdown is due 5s before each Phase ends, ahead of the Cue at its end`() {
        let timeline = countingDown([prepare, firstWork, rest, secondWork, cooldown])

        #expect(
            timeline.position(at: .zero).cues == [
                UpcomingCue(cue: .countdown, due: .seconds(5)), UpcomingCue(cue: .work, due: .seconds(10)),
            ])
        #expect(
            timeline.position(at: .seconds(100)).cues == [
                UpcomingCue(cue: .countdown, due: .seconds(140)),
                UpcomingCue(cue: .workoutComplete, due: .seconds(145)),
            ])
    }

    @Test func `A Workout that doesn't count down has no Countdown`() {
        #expect(timeline.position(at: .zero).cues == [UpcomingCue(cue: .work, due: .seconds(10))])
    }

    @Test func `A Prepare starts silently, so one of 00:05 counts down from its start`() {
        let timeline = countingDown([Phase(kind: .prepare, duration: .seconds(5)), firstWork])

        #expect(timeline.position(at: .zero).nextCue == UpcomingCue(cue: .countdown, due: .zero))
    }

    @Test(arguments: [5, 9])
    func `A Phase under 00:10 has no room for the Countdown after its own Cue`(seconds: Int) {
        let work = Phase(kind: .work, duration: .seconds(seconds), round: 1)
        let timeline = countingDown([work])

        #expect(timeline.position(at: .zero).cues == [UpcomingCue(cue: .workoutComplete, due: .seconds(seconds))])
    }

    @Test func `A Phase of 00:10 counts down right after its own Cue's room`() {
        let timeline = countingDown([Phase(kind: .work, duration: .seconds(10), round: 1)])

        #expect(timeline.position(at: .zero).nextCue == UpcomingCue(cue: .work, due: .zero))
        #expect(timeline.position(at: .seconds(1)).nextCue == UpcomingCue(cue: .countdown, due: .seconds(5)))
    }

    @Test func `A Phase that runs past its set length counts down to Finish`() {
        let timeline = countingDown([Phase(kind: .work, length: .runsPast(.seconds(600)))])

        #expect(
            timeline.position(at: .seconds(1)).cues == [
                UpcomingCue(cue: .countdown, due: .seconds(595)), UpcomingCue(cue: .finish, due: .seconds(600)),
            ])
    }

    @Test func `An open Phase has no Countdown, and the Rest Done places after it counts down`() {
        let openWork = Phase(kind: .work, length: .open, round: 1)
        let timeline = countingDown([openWork, rest, secondWork])

        #expect(timeline.position(at: .zero).cues == [])
        #expect(
            timeline.markingDone(at: .seconds(40))?.position(at: .seconds(40)).cues == [
                UpcomingCue(cue: .countdown, due: .seconds(50)), UpcomingCue(cue: .work, due: .seconds(55)),
            ])
    }

    // MARK: The Cues still to come in a Phase

    @Test func `A Phase's Cues to come end with the next Phase's Cue, due at its end`() {
        #expect(timeline.position(at: .zero).cues == [UpcomingCue(cue: .work, due: .seconds(10))])
        #expect(timeline.position(at: .seconds(20)).cues == [UpcomingCue(cue: .rest, due: .seconds(40))])
    }

    @Test func `The last Phase's Cues to come end with Workout complete`() {
        #expect(timeline.position(at: .seconds(100)).cues == [UpcomingCue(cue: .workoutComplete, due: .seconds(145))])
    }

    /// The Cue due as a Phase starts is its own, already due, so a Phase reached at its exact start doesn't carry it.
    @Test func `A Cue due exactly now is not still to come`() {
        #expect(timeline.position(at: .seconds(40)).cues == [UpcomingCue(cue: .work, due: .seconds(55))])
    }

    @Test func `An Open Rounds Rest has "10 seconds" and then Work to come`() {
        #expect(
            openRounds(rest: 60)?.position(at: .seconds(40)).cues == [
                UpcomingCue(cue: .tenSeconds, due: .seconds(90)), UpcomingCue(cue: .countdown, due: .seconds(95)),
                UpcomingCue(cue: .work, due: .seconds(100)),
            ])
        #expect(openRounds(rest: 60)?.position(at: .seconds(95)).cues == [UpcomingCue(cue: .work, due: .seconds(100))])
    }

    @Test func `An open Phase has no Cue to come, since nothing after it is placed`() {
        #expect(openTimeline.position(at: .seconds(10)).cues == [])
        #expect(openTimeline.position(at: .seconds(500)).cues == [])
    }

    @Test func `A Phase that runs past its set length has "Finish" to come, and nothing once past it`() {
        #expect(stopwatch.position(at: .seconds(300)).cues == [UpcomingCue(cue: .finish, due: .seconds(610))])
        #expect(stopwatch.position(at: .seconds(610)).cues == [])
    }

    @Test func `A finished Workout has no Cue to come`() {
        #expect(timeline.position(at: .seconds(145)).cues == [])
    }

    // MARK: Exercises

    private let squats = Phase(kind: .work, duration: .seconds(30), round: 1, exercise: Exercise("Squats"))

    /// The Cue due exactly at `seconds`, as the Phase starting then begins.
    private func cue(at seconds: Double, in timeline: Timeline) -> UpcomingCue? {
        timeline.position(at: .seconds(seconds)).nextCue
    }

    /// A Plan's Workout counts down. A 12 s Rest has 7 s before its Countdown and an 8 s Rest has none, so both have
    /// room, and a 10 s Rest's Countdown starts just as its room ends. A 4 s Rest has no room.
    @Test(arguments: [(12.0, true), (10, true), (8, true), (4, false)])
    func `A Rest says the next Exercise with 5s before its Countdown or end, and otherwise the Work says it`(
        restSeconds: Double, saysNext: Bool
    ) {
        let rest = Phase(kind: .rest, duration: .seconds(restSeconds))
        let timeline = Timeline(workout: Workout(phases: [rest, squats], countsDown: true))

        let squatsName = Exercise("Squats")
        #expect(cue(at: 0, in: timeline) == UpcomingCue(cue: .rest, due: .zero, exercise: saysNext ? squatsName : nil))
        #expect(
            cue(at: restSeconds, in: timeline)
                == UpcomingCue(cue: .work, due: .seconds(restSeconds), exercise: saysNext ? nil : squatsName))
    }

    /// A Prepare has no Cue of its own, so its Countdown can start at once. Saying the next Exercise needs the same
    /// room before the Countdown as any other Phase, so a Prepare under 10 s keeps its Countdown and leaves the
    /// Exercise to the Work.
    @Test(arguments: [(15.0, true), (10, true), (8, false), (4, false)])
    func `A Prepare says the next Exercise at its start when it has room, keeping its Countdown`(
        prepareSeconds: Double, saysNext: Bool
    ) {
        let prepare = Phase(kind: .prepare, duration: .seconds(prepareSeconds))
        let timeline = Timeline(workout: Workout(phases: [prepare, squats], countsDown: true))

        let squatsName = Exercise("Squats")
        let start = timeline.position(at: .zero)
        if saysNext {
            #expect(start.nextCue == UpcomingCue(cue: .prepare, due: .zero, exercise: squatsName))
        } else {
            #expect(start.nextCue?.cue != .prepare)
        }
        if prepareSeconds >= 5 {
            #expect(start.cues.contains(UpcomingCue(cue: .countdown, due: .seconds(prepareSeconds - 5))))
        }
        #expect(
            cue(at: prepareSeconds, in: timeline)
                == UpcomingCue(cue: .work, due: .seconds(prepareSeconds), exercise: saysNext ? nil : squatsName))
    }

    @Test func `A Cooldown before a named Work says it's next`() {
        let cooldown = Phase(kind: .cooldown, duration: .seconds(60))
        let timeline = Timeline(workout: Workout(phases: [cooldown, squats], countsDown: true))

        #expect(cue(at: 0, in: timeline)?.exercise == Exercise("Squats"))
        #expect(cue(at: 60, in: timeline)?.exercise == nil)
    }

    @Test func `A named Work after another Work, or after an open Rest, says its Exercise over its own gong`() throws {
        let openRest = Phase(kind: .rest, length: .open)
        let pushUps = Phase(kind: .work, duration: .seconds(30), round: 2, exercise: Exercise("Push-ups"))
        let timeline = try #require(
            Timeline(workout: Workout(phases: [squats, pushUps, openRest, squats], countsDown: true))
                .markingDone(at: .seconds(70)))

        #expect(cue(at: 0, in: timeline) == UpcomingCue(cue: .work, due: .zero, exercise: Exercise("Squats")))
        #expect(
            cue(at: 30, in: timeline) == UpcomingCue(cue: .work, due: .seconds(30), exercise: Exercise("Push-ups")))
        #expect(cue(at: 60, in: timeline) == UpcomingCue(cue: .rest, due: .seconds(60)))
        #expect(cue(at: 70, in: timeline) == UpcomingCue(cue: .work, due: .seconds(70), exercise: Exercise("Squats")))
    }

    @Test func `A Prepare before an unnamed Work stays silent, and that Work says only Work`() {
        let prepare = Phase(kind: .prepare, duration: .seconds(10))
        let timeline = Timeline(
            workout: Workout(phases: [prepare, firstWork, rest, squats], countsDown: true))

        #expect(cue(at: 0, in: timeline) == UpcomingCue(cue: .countdown, due: .seconds(5)))
        #expect(cue(at: 40, in: timeline) == UpcomingCue(cue: .rest, due: .seconds(40), exercise: Exercise("Squats")))
        #expect(cue(at: 10, in: timeline) == UpcomingCue(cue: .work, due: .seconds(10)))
    }

    @Test func `"10 seconds" keeps its time before a Rest that says the next Exercise`() {
        let rest = Phase(kind: .rest, duration: .seconds(30))
        let timeline = Timeline(workout: Workout(phases: [rest, squats], warnsBeforeRestEnds: true, countsDown: true))

        #expect(
            timeline.position(at: .zero).cues == [
                UpcomingCue(cue: .tenSeconds, due: .seconds(20)),
                UpcomingCue(cue: .countdown, due: .seconds(25)),
                UpcomingCue(cue: .work, due: .seconds(30)),
            ])
    }

    @Test func `A timed Phase before a named Work knows its Exercise is next, even with no room to say it`() {
        let shortRest = Phase(kind: .rest, duration: .seconds(3))
        let prepare = Phase(kind: .prepare, duration: .seconds(10))
        let pushUps = Phase(kind: .work, duration: .seconds(30), round: 2, exercise: Exercise("Push-ups"))
        let timeline = Timeline(workout: Workout(phases: [prepare, squats, shortRest, pushUps], countsDown: true))

        #expect(timeline.position(at: .seconds(5)).nextExercise == Exercise("Squats"))
        #expect(timeline.position(at: .seconds(20)).nextExercise == nil)
        #expect(timeline.position(at: .seconds(41)).nextExercise == Exercise("Push-ups"))
    }

    @Test func `A Rest before a named Work knows it's next, an open Rest doesn't, and neither does the last Phase`()
        throws
    {
        let openRest = Phase(kind: .rest, length: .open)
        let timeline = Timeline(workout: Workout(phases: [rest, squats, openRest, squats, rest], countsDown: true))

        #expect(timeline.position(at: .seconds(1)).nextExercise == Exercise("Squats"))
        #expect(timeline.position(at: .seconds(50)).nextExercise == nil)
        let afterDone = try #require(timeline.markingDone(at: .seconds(60)))
        #expect(afterDone.position(at: .seconds(95)).nextExercise == nil)
    }
}
