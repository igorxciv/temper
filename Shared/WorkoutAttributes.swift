import ActivityKit
import TemperCore

/// The Live Activity of a running Workout. Everything it shows changes during the Workout, so all of it is in the
/// state and none is fixed at Start.
///
/// The app and the widget extension both compile this file, because both name the type.
nonisolated struct WorkoutAttributes: ActivityAttributes {
    typealias ContentState = LiveActivityState
}
