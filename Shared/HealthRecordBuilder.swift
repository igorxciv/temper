import HealthKit
import TemperCore

extension HKWorkoutBuilder {
    /// Adds what a Health record holds to a builder that has begun collecting: its sync identifier and version, a
    /// `pause` and `resume` event per Pause, and one activity per Phase with `TemperPhase` and `TemperRound` metadata.
    ///
    /// The iPhone's save and the Watch's both call it, so the two copies of a Workout carry identical times and Health
    /// can keep either one. Ending collection at `record.end` and finishing are left to the caller.
    func add(_ record: HealthRecord, configuration: HKWorkoutConfiguration) async throws {
        try await addMetadata([
            HKMetadataKeySyncIdentifier: record.syncIdentifier,
            HKMetadataKeySyncVersion: record.syncVersion,
        ])
        let events = record.pauses.flatMap { pause in
            [
                HKWorkoutEvent(
                    type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil),
                HKWorkoutEvent(
                    type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil),
            ]
        }
        if !events.isEmpty {
            try await addWorkoutEvents(events)
        }
        for activity in record.activities {
            var metadata: [String: Any] = [HealthRecord.Activity.phaseMetadataKey: activity.phaseMetadataValue]
            if let round = activity.round {
                metadata[HealthRecord.Activity.roundMetadataKey] = round
            }
            try await addWorkoutActivity(
                HKWorkoutActivity(
                    workoutConfiguration: configuration, start: activity.start, end: activity.end, metadata: metadata))
        }
    }
}
