import SwiftUI
import TemperCore
import WidgetKit

/// States built the way the app builds them, from a snapshot, so the previews show what a Workout sends.
private enum PreviewStates {
    static let intervals = WorkoutType.intervals.makeWorkout(from: WorkoutType.intervals.firstLaunch)
    static let stopwatch = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)

    static let work = state(
        .intervals, .running(phase: Phase(kind: .work, duration: .seconds(40), round: 3), endsAt: .now + .seconds(23)))
    static let pausedRest = state(
        .intervals, .paused(phase: Phase(kind: .rest, duration: .seconds(20), round: 3), timeLeft: .seconds(12)))
    static let stopwatchWork = state(
        .stopwatch, .running(phase: Phase(kind: .work, duration: .seconds(600)), endsAt: .now + .seconds(380)))
    static let complete = state(
        .intervals, .finished(WorkoutRecord(start: .now, end: .now + .seconds(530), pauses: [], phases: [])))

    private static func state(
        _ workoutType: WorkoutType,
        _ progress: WorkoutSnapshot<ContinuousClock.Instant>.Progress
    ) -> LiveActivityState {
        let workout = workoutType == .intervals ? intervals : stopwatch
        let snapshot = WorkoutSnapshot(progress: progress, rounds: workout.rounds)
        let display = RunningDisplay(workoutType: workoutType, workout: workout, snapshot: snapshot)
        return display.liveActivityState(at: .now, date: .now) ?? .complete(total: "", spokenTotal: "")
    }
}

#Preview("Lock Screen", as: .content, using: WorkoutAttributes()) {
    WorkoutLiveActivity()
} contentStates: {
    PreviewStates.work
    PreviewStates.pausedRest
    PreviewStates.stopwatchWork
    PreviewStates.complete
}

#Preview("Island, compact", as: .dynamicIsland(.compact), using: WorkoutAttributes()) {
    WorkoutLiveActivity()
} contentStates: {
    PreviewStates.work
    PreviewStates.pausedRest
    PreviewStates.complete
}

#Preview("Island, expanded", as: .dynamicIsland(.expanded), using: WorkoutAttributes()) {
    WorkoutLiveActivity()
} contentStates: {
    PreviewStates.work
    PreviewStates.stopwatchWork
}

#Preview("Island, minimal", as: .dynamicIsland(.minimal), using: WorkoutAttributes()) {
    WorkoutLiveActivity()
} contentStates: {
    PreviewStates.work
}
