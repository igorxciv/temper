// PROBE, throwaway. Readable names for HealthKit states in the log.

import HealthKit

extension HKWorkoutSessionState {
    nonisolated var label: String {
        switch self {
        case .notStarted: "notStarted"
        case .running: "running"
        case .ended: "ended"
        case .paused: "paused"
        case .prepared: "prepared"
        case .stopped: "stopped"
        @unknown default: "unknown \(rawValue)"
        }
    }
}

extension HKAuthorizationStatus {
    nonisolated var label: String {
        switch self {
        case .notDetermined: "not determined"
        case .sharingDenied: "denied"
        case .sharingAuthorized: "allowed"
        @unknown default: "unknown"
        }
    }
}
