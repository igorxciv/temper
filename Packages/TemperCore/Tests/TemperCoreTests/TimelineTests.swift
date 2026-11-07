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
}
