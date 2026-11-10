import Observation
import TemperCore

/// The heart rate of the Workout the session follows, from its start until the next one starts.
@Observable
final class LiveHeartRate {
    var current = WorkoutHeartRate(zones: nil)
}
