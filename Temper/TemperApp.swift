import SwiftUI
import TemperCore

@main
struct TemperApp: App {
    /// Placeholder until the screens are designed in #11.
    static let placeholderWorkout = Workout(prepare: .seconds(10), rounds: 1, work: .seconds(30), rest: .zero)

    var body: some Scene {
        WindowGroup {
            Text("Temper: \(Self.placeholderWorkout.phases.count) Phases")
        }
    }
}
