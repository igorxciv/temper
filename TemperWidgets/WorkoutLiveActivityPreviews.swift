import SwiftUI
import TemperCore
import WidgetKit

/// States built the way the app builds them, from a snapshot, so the previews show what a Workout sends.
private enum PreviewStates {
    static let work = state(
        .intervals, .running(phase: Phase(kind: .work, duration: .seconds(40), round: 3), endsAt: .now + .seconds(23)))
    static let pausedRest = state(
        .intervals, .paused(phase: Phase(kind: .rest, duration: .seconds(20), round: 3), timeLeft: .seconds(12)))
    static let stopwatchWork = state(
        .stopwatch, .running(phase: Phase(kind: .work, duration: .seconds(600)), endsAt: .now + .seconds(380)))
    static let complete = state(
        .intervals, .finished(WorkoutRecord(start: .now, end: .now + .seconds(530), pauses: [], phases: [])))
    static let openWork = state(
        .openRounds, .runningOpen(phase: Phase(kind: .work, length: .open, round: 3), startedAt: .now - .seconds(64)))
    static let openRoundsRest = state(
        .openRounds, .running(phase: Phase(kind: .rest, duration: .seconds(90), round: 3), endsAt: .now + .seconds(52)),
        previousOpenPhaseTime: .seconds(102))
    static let openRoundsStopped = state(
        .openRounds, .stopped(WorkoutRecord(start: .now, end: .now + .seconds(1_390), pauses: [], phases: [])))

    private static func state(
        _ workoutType: WorkoutType,
        _ progress: WorkoutSnapshot<ContinuousClock.Instant>.Progress,
        previousOpenPhaseTime: Duration? = nil
    ) -> LiveActivityState {
        let workout = workoutType.makeWorkout(from: workoutType.firstLaunch)
        let snapshot = WorkoutSnapshot(
            progress: progress, rounds: workout.rounds, previousOpenPhaseTime: previousOpenPhaseTime)
        let display = RunningDisplay(workout: workout, snapshot: snapshot)
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
    PreviewStates.openWork
    PreviewStates.openRoundsRest
    PreviewStates.openRoundsStopped
}

#Preview("Island, compact", as: .dynamicIsland(.compact), using: WorkoutAttributes()) {
    WorkoutLiveActivity()
} contentStates: {
    PreviewStates.work
    PreviewStates.pausedRest
    PreviewStates.complete
    PreviewStates.openWork
}

#Preview("Island, expanded", as: .dynamicIsland(.expanded), using: WorkoutAttributes()) {
    WorkoutLiveActivity()
} contentStates: {
    PreviewStates.work
    PreviewStates.stopwatchWork
    PreviewStates.openWork
    PreviewStates.openRoundsRest
}

#Preview("Island, minimal", as: .dynamicIsland(.minimal), using: WorkoutAttributes()) {
    WorkoutLiveActivity()
} contentStates: {
    PreviewStates.work
}
