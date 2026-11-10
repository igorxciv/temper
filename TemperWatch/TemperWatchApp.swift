import HealthKit
import SwiftUI
import TemperCore
import WatchKit

/// The Watch app: a companion to the iPhone app, which carries it onto the Watch. Every Workout starts on the iPhone,
/// which opens the Watch at Start, and the Watch follows it.
@main
struct TemperWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate

    var body: some Scene {
        WindowGroup {
            WatchRootView(session: .shared)
        }
    }
}

/// Receives the iPhone's request to open the Watch for a Workout.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        WatchSession.shared.handle(workoutConfiguration)
    }
}

/// Shows the screen the session's flow is on.
struct WatchRootView: View {
    let session: WatchSession

    var body: some View {
        switch session.screen {
        case .idle:
            IdleScreen()
        case .waiting:
            WaitingScreen()
        case .running(let phase):
            WatchRunningScreen(phase: phase)
        case .complete(let completion):
            WatchCompleteScreen(completion: completion, done: session.done)
        case .updateNeeded:
            UpdateNeededScreen()
        }
    }
}
