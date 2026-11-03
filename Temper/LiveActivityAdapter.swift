import ActivityKit
import Foundation
import TemperCore

/// How long the complete state stays on the Lock Screen and the Watch if Done is never tapped.
private let completeShownFor: TimeInterval = 5 * 60

/// Keeps the Workout's Live Activity in step with the snapshots. The Live Activity appears on the Lock Screen,
/// in the Dynamic Island and in the Apple Watch Smart Stack. The adapter decides nothing, and shows each state
/// it's given in the order it was given.
///
/// One adapter serves one Workout. Each change waits for the one before, so a quick Pause and Resume can't land
/// out of order. If Live Activities are off, or a request fails, the Workout runs the same without one.
final class LiveActivityAdapter {
    private let changes: AsyncStream<LiveActivityState?>.Continuation

    init() {
        let (states, changes) = AsyncStream.makeStream(of: LiveActivityState?.self)
        self.changes = changes
        Task { await Self.follow(states) }
    }

    /// Shows a state, or with `nil` ends the Live Activity at once, even one showing the complete state.
    func show(_ state: LiveActivityState?) {
        changes.yield(state)
        if state == nil {
            changes.finish()
        }
    }

    /// Ends any Live Activity left from an earlier launch, such as one iOS stopped mid-Workout.
    static func endLeftovers() async {
        for activity in Activity<WorkoutAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func follow(_ states: AsyncStream<LiveActivityState?>) async {
        var activity: Activity<WorkoutAttributes>?
        for await state in states {
            guard let state else {
                await activity?.end(nil, dismissalPolicy: .immediate)
                return
            }
            let content = ActivityContent(state: state, staleDate: nil)
            switch (state, activity) {
            case (.phase, nil):
                // A request only succeeds with Temper at the front. The first snapshot comes moments after Start,
                // so it's asked for then. Later changes are allowed in the background.
                activity = try? Activity.request(attributes: WorkoutAttributes(), content: content)
            case (.phase, let activity?):
                await activity.update(content)
            case (.complete, let activity?):
                await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(completeShownFor)))
            case (.complete, nil):
                break
            }
        }
    }
}
