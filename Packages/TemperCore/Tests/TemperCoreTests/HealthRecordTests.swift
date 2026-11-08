import Foundation
import Testing

@testable import TemperCore

nonisolated struct HealthRecordTests {
    private typealias Record = WorkoutRecord<ManualClock.Instant>

    private let workoutID = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!

    /// The engine instant read at the end, and the wall clock at that moment.
    private let anchorInstant = ManualClock.Instant(offset: .seconds(1_000))
    private let anchorDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    /// The wall-clock date of an instant `seconds` into the engine clock, given the anchor pair.
    private func date(_ seconds: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: 800_000_000 - 1_000 + seconds)
    }

    private func phase(_ kind: Phase.Kind, round: Int? = nil, from start: Double, to end: Double)
        -> Record.RecordedPhase
    {
        Record.RecordedPhase(kind: kind, round: round, start: at(start), end: at(end))
    }

    private func healthRecord(
        _ record: Record,
        of workoutType: WorkoutType = .intervals,
        attempt: Int = 1
    ) -> HealthRecord? {
        HealthRecord(
            record, of: workoutType, workoutID: workoutID, attempt: attempt, at: anchorInstant, date: anchorDate)
    }

    /// A Stopwatch's Work from `start` to `end` with no Prepare and no Pause.
    private func stopwatch(from start: Double, to end: Double, pauses: [Range<ManualClock.Instant>] = []) -> Record {
        Record(start: at(start), end: at(end), pauses: pauses, phases: [phase(.work, from: start, to: end)])
    }

    // MARK: Whether to save

    @Test func `Under 1 minute of active time saves nothing`() {
        #expect(healthRecord(stopwatch(from: 100, to: 159.999)) == nil)
    }

    @Test func `Exactly 1 minute of active time saves`() {
        #expect(healthRecord(stopwatch(from: 100, to: 160)) != nil)
    }

    @Test func `A Pause doesn't count towards the minute`() {
        let record = stopwatch(from: 100, to: 170, pauses: [at(120)..<at(130.001)])

        #expect(healthRecord(record) == nil)
    }

    // MARK: Activity type

    @Test(arguments: [
        (WorkoutType.intervals, HealthRecord.ActivityType.highIntensityIntervalTraining),
        (.stopwatch, .other),
        (.openRounds, .traditionalStrengthTraining),
    ])
    func `Each Workout Type saves as its activity type`(
        workoutType: WorkoutType, activityType: HealthRecord.ActivityType
    ) {
        #expect(healthRecord(stopwatch(from: 0, to: 90), of: workoutType)?.activityType == activityType)
    }

    // MARK: Dates

    @Test func `The start and end dates come from the anchor pair`() throws {
        let health = try #require(healthRecord(stopwatch(from: 100, to: 250.5)))

        #expect(health.start == Date(timeIntervalSinceReferenceDate: 799_999_100))
        #expect(health.end == Date(timeIntervalSinceReferenceDate: 799_999_250.5))
    }

    @Test func `An anchor read later than the end places the dates the same`() throws {
        let record = stopwatch(from: 100, to: 250)
        let later = try #require(
            HealthRecord(record, of: .intervals, workoutID: workoutID, attempt: 1, at: at(1_600), date: date(1_600))
        )

        #expect(later.start == date(100))
        #expect(later.end == date(250))
    }

    @Test func `The Health workout spans the whole Workout, Prepare and Cooldown included`() throws {
        let record = Record(
            start: at(0),
            end: at(100),
            pauses: [],
            phases: [
                phase(.prepare, from: 0, to: 10),
                phase(.work, from: 10, to: 40),
                phase(.cooldown, from: 40, to: 100),
            ]
        )

        let health = try #require(healthRecord(record))

        #expect(health.start == date(0))
        #expect(health.end == date(100))
    }

    // MARK: Pauses

    @Test func `Each Pause saves as a pause and resume pair`() throws {
        let record = stopwatch(from: 0, to: 200, pauses: [at(30)..<at(45), at(100)..<at(130.25)])

        let health = try #require(healthRecord(record))

        #expect(
            health.pauses == [
                HealthRecord.Pause(start: date(30), end: date(45)),
                HealthRecord.Pause(start: date(100), end: date(130.25)),
            ]
        )
    }

    @Test func `A Pause still on at Stop resumes at the Stop`() throws {
        // The engine records a Pause still on at Stop as ending at the Stop.
        let record = stopwatch(from: 0, to: 200, pauses: [at(120)..<at(200)])

        let health = try #require(healthRecord(record))

        #expect(health.pauses == [HealthRecord.Pause(start: date(120), end: date(200))])
        #expect(health.end == date(200))
    }

    // MARK: Activities

    private func activity(_ phase: Phase.Kind, round: Int? = nil, from start: Double, to end: Double)
        -> HealthRecord.Activity
    {
        HealthRecord.Activity(phase: phase, round: round, start: date(start), end: date(end))
    }

    @Test func `Each Phase that ran saves as an activity with its Phase and Round`() throws {
        let record = Record(
            start: at(0),
            end: at(145),
            pauses: [],
            phases: [
                phase(.prepare, from: 0, to: 10),
                phase(.work, round: 1, from: 10, to: 40),
                phase(.rest, round: 1, from: 40, to: 55),
                phase(.work, round: 2, from: 55, to: 85),
                phase(.cooldown, from: 85, to: 145),
            ]
        )

        let health = try #require(healthRecord(record))

        #expect(
            health.activities == [
                activity(.prepare, from: 0, to: 10),
                activity(.work, round: 1, from: 10, to: 40),
                activity(.rest, round: 1, from: 40, to: 55),
                activity(.work, round: 2, from: 55, to: 85),
                activity(.cooldown, from: 85, to: 145),
            ]
        )
    }

    @Test func `An activity's metadata names its Phase and Round`() {
        #expect(HealthRecord.Activity.phaseMetadataKey == "TemperPhase")
        #expect(HealthRecord.Activity.roundMetadataKey == "TemperRound")
        #expect(activity(.prepare, from: 0, to: 10).phaseMetadataValue == "prepare")
        #expect(activity(.work, round: 1, from: 0, to: 10).phaseMetadataValue == "work")
        #expect(activity(.rest, round: 1, from: 0, to: 10).phaseMetadataValue == "rest")
        #expect(activity(.cooldown, from: 0, to: 10).phaseMetadataValue == "cooldown")
    }

    @Test func `A Phase cut short by Stop ends at the Stop`() throws {
        let record = Record(
            start: at(0),
            end: at(100),
            pauses: [],
            phases: [phase(.work, round: 1, from: 0, to: 70), phase(.rest, round: 1, from: 70, to: 100)]
        )

        let health = try #require(healthRecord(record, of: .openRounds))

        #expect(health.activities.last == activity(.rest, round: 1, from: 70, to: 100))
        #expect(health.end == date(100))
    }

    @Test func `An activity spans a Pause inside its Phase`() throws {
        let record = Record(
            start: at(0),
            end: at(130),
            pauses: [at(20)..<at(50)],
            phases: [phase(.work, round: 1, from: 0, to: 90), phase(.rest, round: 1, from: 90, to: 130)]
        )

        let health = try #require(healthRecord(record, of: .openRounds))

        #expect(
            health.activities == [
                activity(.work, round: 1, from: 0, to: 90),
                activity(.rest, round: 1, from: 90, to: 130),
            ]
        )
        #expect(health.pauses == [HealthRecord.Pause(start: date(20), end: date(50))])
    }

    @Test func `A Phase that would start at the very Stop isn't saved`() throws {
        let record = Record(
            start: at(0),
            end: at(90),
            pauses: [],
            phases: [phase(.work, round: 1, from: 0, to: 90), phase(.rest, round: 1, from: 90, to: 90)]
        )

        let health = try #require(healthRecord(record, of: .openRounds))

        #expect(health.activities == [activity(.work, round: 1, from: 0, to: 90)])
    }

    // MARK: Saving once

    @Test func `The sync identifier is the Workout's UUID and the version is the attempt number`() throws {
        let health = try #require(healthRecord(stopwatch(from: 0, to: 90), attempt: 2))

        #expect(health.workoutID == workoutID)
        #expect(health.syncIdentifier == "6F9619FF-8B86-D011-B42D-00C04FC964FF")
        #expect(health.syncVersion == 2)
    }

    @Test func `A later attempt raises only the version`() throws {
        let record = stopwatch(from: 0, to: 90, pauses: [at(10)..<at(20)])
        let first = try #require(healthRecord(record, attempt: 1))

        #expect(first.withSyncVersion(3) == healthRecord(record, attempt: 3))
    }

    @Test func `A pending save decodes to the same record`() throws {
        let record = Record(
            start: at(0),
            end: at(130),
            pauses: [at(20)..<at(50.125)],
            phases: [phase(.work, round: 1, from: 0, to: 90), phase(.rest, round: 1, from: 90, to: 130)]
        )
        let health = try #require(healthRecord(record, of: .openRounds, attempt: 2))

        let decoded = try JSONDecoder().decode(HealthRecord.self, from: JSONEncoder().encode(health))

        #expect(decoded == health)
    }
}
