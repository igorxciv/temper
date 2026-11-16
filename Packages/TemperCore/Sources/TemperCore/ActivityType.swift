/// The kind of exercise the Watch's workout session runs as, which shapes how Apple Watch works out the energy it
/// counts. The raw values name the HealthKit `HKWorkoutActivityType` cases they stand for, and a saved Plan stores
/// them.
public nonisolated enum ActivityType: String, Codable, Hashable, Sendable {
    case highIntensityIntervalTraining
    case other
    case traditionalStrengthTraining

    /// Intervals is High Intensity Interval Training, Stopwatch is Other, and Open Rounds is Traditional Strength
    /// Training.
    public init(_ workoutType: WorkoutType) {
        switch workoutType {
        case .intervals: self = .highIntensityIntervalTraining
        case .stopwatch: self = .other
        case .openRounds: self = .traditionalStrengthTraining
        }
    }
}
