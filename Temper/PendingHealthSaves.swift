import Foundation
import TemperCore

/// A Health workout not yet confirmed saved: the record for its next attempt, and how many attempts made with
/// protected data available it has used.
struct PendingHealthSave: Codable, Hashable {
    let record: HealthRecord
    let countedAttempts: Int
}

/// The pending saves, kept in `UserDefaults`, which an app can use once the iPhone has been unlocked after starting.
struct PendingHealthSaves {
    private static let key = "pendingHealthSaves"

    let defaults: UserDefaults

    var all: [PendingHealthSave] {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        return (try? JSONDecoder().decode([PendingHealthSave].self, from: data)) ?? []
    }

    func save(for workoutID: UUID) -> PendingHealthSave? {
        all.first { $0.record.workoutID == workoutID }
    }

    /// Adds `save`, or replaces the one for the same Workout.
    func put(_ save: PendingHealthSave) {
        store(all.filter { $0.record.workoutID != save.record.workoutID } + [save])
    }

    func remove(_ workoutID: UUID) {
        store(all.filter { $0.record.workoutID != workoutID })
    }

    private func store(_ saves: [PendingHealthSave]) {
        if saves.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else if let data = try? JSONEncoder().encode(saves) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
