import TemperCore

/// A Health workout not yet confirmed saved: the record for its next attempt, and how many attempts made with
/// protected data available it has used.
struct PendingHealthSave: Codable, Hashable {
    let record: HealthRecord
    let countedAttempts: Int
}
