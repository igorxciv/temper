import SwiftUI

/// The Watch app: a companion to the iPhone app, which carries it onto the Watch. Every Workout starts on the iPhone,
/// so outside one the Watch only says so.
@main
struct TemperWatchApp: App {
    var body: some Scene {
        WindowGroup {
            IdleScreen()
        }
    }
}
