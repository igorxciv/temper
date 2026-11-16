import Foundation
import HealthKit
import TemperCore

/// Reads and asks for Temper's Health permission with HealthKit. Temper saves nothing to Health: the permission is for
/// the Watch's workout session, which shows the heart rate during a Workout.
///
/// It asks for one fixed set, whether or not a Watch is paired: sharing workouts, which Apple's guide asks of any app
/// that runs a workout session, and reading what the Watch needs for its heart rate and Zones. The Watch's grant is
/// the iPhone's, so the Watch never asks.
struct HealthKitPermissions: HealthPermissionStore {
    static let shareTypes: Set<HKSampleType> = [.workoutType()]
    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate), HKQuantityType(.restingHeartRate), HKCharacteristicType(.dateOfBirth),
    ]

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

    /// An unknown status counts as unnecessary, so Settings doesn't offer a tap that might ask for nothing.
    var requestStatus: HealthRequestStatus {
        get async {
            guard HKHealthStore.isHealthDataAvailable(),
                let status = try? await healthStore.statusForAuthorizationRequest(
                    toShare: Self.shareTypes, read: Self.readTypes)
            else { return .unnecessary }
            switch status {
            case .shouldRequest: return .shouldRequest
            case .unnecessary, .unknown: return .unnecessary
            @unknown default: return .unnecessary
            }
        }
    }

    func requestPermission() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // The status is read again afterward, so a failure needs nothing more.
        try? await healthStore.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
    }
}

extension ActivityType {
    var healthKit: HKWorkoutActivityType {
        switch self {
        case .highIntensityIntervalTraining: .highIntensityIntervalTraining
        case .other: .other
        case .traditionalStrengthTraining: .traditionalStrengthTraining
        }
    }
}
