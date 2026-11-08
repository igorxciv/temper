/// What one attempt at saving a Health workout came to.
enum HealthSaveOutcome {
    /// Health returned the workout.
    case saved
    /// Health returned neither a workout nor an error. A save while locked can do this and still land, or not.
    case unverified
    case failed
    /// Health refused because Temper isn't allowed to write.
    case notAllowed
}
