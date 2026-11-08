import Foundation
import HealthKit
import TemperCore

/// Saves Health workouts with HealthKit: one `HKWorkoutBuilder` per attempt, built after the Workout from its record,
/// with no workout session and no samples. Temper only writes workouts, so it never asks to read anything.
struct HealthKitWorkouts: HealthWorkoutStore {
    private let healthStore = HKHealthStore()

    var writeStatus: HealthWriteStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .denied }
        switch healthStore.authorizationStatus(for: .workoutType()) {
        case .notDetermined: return .notDetermined
        case .sharingAuthorized: return .allowed
        case .sharingDenied: return .denied
        @unknown default: return .denied
        }
    }

    func requestPermission() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // The status is read again afterward, so a failure needs nothing more.
        try? await healthStore.requestAuthorization(toShare: [.workoutType()], read: [])
    }

    func save(_ record: HealthRecord) async -> HealthSaveOutcome {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = record.activityType.healthKit
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: record.start)
            try await builder.addMetadata([
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
                try await builder.addWorkoutEvents(events)
            }
            for activity in record.activities {
                var metadata: [String: Any] = [HealthRecord.Activity.phaseMetadataKey: activity.phaseMetadataValue]
                if let round = activity.round {
                    metadata[HealthRecord.Activity.roundMetadataKey] = round
                }
                try await builder.addWorkoutActivity(
                    HKWorkoutActivity(
                        workoutConfiguration: configuration, start: activity.start, end: activity.end,
                        metadata: metadata
                    )
                )
            }
            try await builder.endCollection(at: record.end)
            // A locked save can return no workout and no error, saved or not, so only a workout counts.
            return try await builder.finishWorkout() == nil ? .unverified : .saved
        } catch let error as HKError
            where error.code == .errorAuthorizationDenied || error.code == .errorAuthorizationNotDetermined
        {
            return .notAllowed
        } catch {
            return .failed
        }
    }
}

extension HealthRecord.ActivityType {
    fileprivate var healthKit: HKWorkoutActivityType {
        switch self {
        case .highIntensityIntervalTraining: .highIntensityIntervalTraining
        case .other: .other
        case .traditionalStrengthTraining: .traditionalStrengthTraining
        }
    }
}
