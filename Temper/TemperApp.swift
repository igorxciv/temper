import SwiftUI
import TemperCore

@main
struct TemperApp: App {
    /// Placeholder until the running screen arrives.
    static let placeholderWorkout = Workout(phases: [
        Phase(kind: .prepare, duration: .seconds(10)),
        Phase(kind: .work, duration: .seconds(30), round: 1),
    ])

    var body: some Scene {
        WindowGroup {
            Text("Temper: \(Self.placeholderWorkout.phases.count) Phases")
        }
    }
}
