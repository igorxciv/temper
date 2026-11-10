import Foundation
import Testing

@testable import TemperCore

/// The Health record the Watch builds by itself, from the updates it heard, when the iPhone's record never arrives.
nonisolated struct HeardHealthRecordTests {
    private let workoutID = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// The date `seconds` after the Start.
    private func at(_ seconds: Double) -> Date {
        start.addingTimeInterval(seconds)
    }

    /// An update of a Phase as the Watch heard it. `start` and `end` are in seconds after the Start.
    private func heard(
        _ kind: Phase.Kind, round: Int? = nil, from start: Double, to end: Double?, pausedAt: Double? = nil,
        countsUp: Bool = false
    ) -> WatchPhase {
        WatchPhase(
            kind: kind, round: round, start: at(start), end: end.map(at), pausedAt: pausedAt.map(at),
            countsUp: countsUp, line: nil, capsule: .pause)
    }

    private func record(
        _ heard: [WatchPhase], of workoutType: WorkoutType = .intervals, lastContact: Double
    ) -> HealthRecord? {
        HealthRecord(
            heard: heard,
            begin: MessageToWatch.Begin(workoutID: workoutID, start: start, workoutType: workoutType),
            lastContact: at(lastContact))
    }

    private func activity(_ kind: Phase.Kind, round: Int? = nil, from start: Double, to end: Double)
        -> HealthRecord.Activity
    {
        HealthRecord.Activity(phase: kind, round: round, start: at(start), end: at(end))
    }

    // MARK: Span

    @Test func `It spans the Start in begin to the last contact, under the Workout's ID at the Watch's version`()
        throws
    {
        let record = try #require(record([heard(.work, round: 1, from: 0, to: 300)], lastContact: 200))

        #expect(record.start == start)
        #expect(record.end == at(200))
        #expect(record.workoutID == workoutID)
        #expect(record.syncVersion == 1_000_000)
    }

    @Test(arguments: [
        (WorkoutType.intervals, HealthRecord.ActivityType.highIntensityIntervalTraining),
        (.stopwatch, .other),
        (.openRounds, .traditionalStrengthTraining),
    ])
    func `Its activity type comes from the Workout Type in begin`(
        workoutType: WorkoutType, activityType: HealthRecord.ActivityType
    ) {
        let record = record([heard(.work, from: 0, to: nil, countsUp: true)], of: workoutType, lastContact: 90)

        #expect(record?.activityType == activityType)
    }

    /// As after a Watch app crash, which loses what was heard before it.
    @Test func `With nothing heard, it still spans the Start to the last contact, with no activities`() throws {
        let record = try #require(record([], lastContact: 90))

        #expect(record.end == at(90))
        #expect(record.activities == [])
        #expect(record.pauses == [])
    }

    // MARK: Activities

    @Test func `Each Phase heard is an activity from its start to the next one's start, the last to the end`() throws {
        let record = try #require(
            record(
                [
                    heard(.prepare, from: 0, to: 10), heard(.work, round: 1, from: 10, to: 50),
                    heard(.rest, round: 1, from: 50, to: 60), heard(.work, round: 2, from: 60, to: 100),
                ], lastContact: 80))

        #expect(
            record.activities == [
                activity(.prepare, from: 0, to: 10), activity(.work, round: 1, from: 10, to: 50),
                activity(.rest, round: 1, from: 50, to: 60), activity(.work, round: 2, from: 60, to: 80),
            ])
    }

    /// Work 1 was heard, then nothing until Work 3. Rest 1, Work 2 and Rest 2 ran unheard, from 50 to 110.
    @Test func `A Phase ends no later than its own end, so a gap left by a dropout has no activity`() throws {
        let record = try #require(
            record(
                [heard(.work, round: 1, from: 10, to: 50), heard(.work, round: 3, from: 110, to: 150)],
                lastContact: 200))

        #expect(
            record.activities == [
                activity(.work, round: 1, from: 10, to: 50), activity(.work, round: 3, from: 110, to: 150),
            ])
    }

    @Test func `An open Work runs to the next Phase heard`() throws {
        let record = try #require(
            record(
                [
                    heard(.work, round: 1, from: 10, to: nil, countsUp: true),
                    heard(.rest, round: 1, from: 95, to: 155),
                ], of: .openRounds, lastContact: 120))

        #expect(
            record.activities == [
                activity(.work, round: 1, from: 10, to: 95), activity(.rest, round: 1, from: 95, to: 120),
            ])
    }

    /// Its `end` is only where it reaches its set length. It keeps running until Done.
    @Test func `A Stopwatch's Work runs on past its set length`() throws {
        let record = try #require(
            record([heard(.work, from: 0, to: 60, countsUp: true)], of: .stopwatch, lastContact: 200))

        #expect(record.activities == [activity(.work, from: 0, to: 200)])
    }

    // MARK: Pauses

    /// Work 1 from 10 to 50, Paused at 20 and Resumed at 35, so it ends at 65.
    private var pausedAndResumed: [WatchPhase] {
        [
            heard(.work, round: 1, from: 10, to: 50), heard(.work, round: 1, from: 10, to: 50, pausedAt: 20),
            heard(.work, round: 1, from: 25, to: 65), heard(.rest, round: 1, from: 65, to: 75),
        ]
    }

    @Test func `A Pause runs from its tap for as long as the next update moved the Phase's start`() throws {
        let record = try #require(record(pausedAndResumed, lastContact: 120))

        #expect(record.pauses == [HealthRecord.Pause(start: at(20), end: at(35))])
    }

    @Test func `A Paused and Resumed Phase is one activity, from its first start to its moved end`() throws {
        let record = try #require(record(pausedAndResumed, lastContact: 120))

        #expect(
            record.activities == [
                activity(.work, round: 1, from: 10, to: 65), activity(.rest, round: 1, from: 65, to: 75),
            ])
    }

    /// A state published again during a Pause holds the same time, so its dates all move on together.
    @Test func `A Pause heard twice before its Resume is one Pause`() throws {
        let record = try #require(
            record(
                [
                    heard(.work, round: 1, from: 10, to: 50, pausedAt: 20),
                    heard(.work, round: 1, from: 16, to: 56, pausedAt: 26),
                    heard(.work, round: 1, from: 25, to: 65),
                ], lastContact: 120))

        #expect(record.pauses == [HealthRecord.Pause(start: at(20), end: at(35))])
    }

    @Test func `A Pause still on at the end ends at the end, and its Phase with it`() throws {
        let record = try #require(
            record(
                [heard(.work, round: 1, from: 10, to: 50), heard(.work, round: 1, from: 10, to: 50, pausedAt: 90)],
                lastContact: 300))

        #expect(record.pauses == [HealthRecord.Pause(start: at(90), end: at(300))])
        #expect(record.activities == [activity(.work, round: 1, from: 10, to: 300)])
    }

    /// Nothing heard says how long it lasted.
    @Test func `A Pause whose Resume a dropout hid isn't recorded`() throws {
        let record = try #require(
            record(
                [heard(.work, round: 1, from: 10, to: 50, pausedAt: 20), heard(.rest, round: 1, from: 80, to: 90)],
                lastContact: 120))

        #expect(record.pauses == [])
        #expect(
            record.activities == [
                activity(.work, round: 1, from: 10, to: 50), activity(.rest, round: 1, from: 80, to: 90),
            ])
    }

    // MARK: Whether to save

    @Test func `Under 1 minute of active time there's no record`() {
        #expect(record([heard(.work, from: 0, to: nil, countsUp: true)], lastContact: 59.5) == nil)
    }

    @Test func `Exactly 1 minute of active time makes a record`() {
        #expect(record([heard(.work, from: 0, to: nil, countsUp: true)], lastContact: 60) != nil)
    }

    /// 70 s from the Start to the last contact, less a Pause of 10.5 s.
    @Test func `A Pause doesn't count towards the minute`() {
        let heard = [
            heard(.work, from: 0, to: nil, pausedAt: 20, countsUp: true),
            heard(.work, from: 10.5, to: nil, countsUp: true),
        ]

        #expect(record(heard, lastContact: 70) == nil)
    }
}
