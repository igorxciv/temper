import SwiftUI
import TemperCore

/// The Watch outside a Workout.
///
/// The workout status is read each time the app comes to the front, so turning on Apple Health on the iPhone shows on
/// the next raise.
struct IdleScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var idle = WatchIdle(workoutsAllowed: WatchHealth.workoutsAllowed)

    var body: some View {
        IdleNotice(idle: idle)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    idle = WatchIdle(workoutsAllowed: WatchHealth.workoutsAllowed)
                }
            }
    }
}

/// An iPhone symbol and where to go next.
struct IdleNotice: View {
    let idle: WatchIdle

    var body: some View {
        WatchNotice(title: idle.title, message: idle.message) {
            Image(systemName: "iphone")
        }
    }
}

#Preview("Start on iPhone") {
    IdleNotice(idle: .startOnIPhone)
}

#Preview("Turn on Apple Health") {
    IdleNotice(idle: .turnOnHealth)
}
