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

/// An iPhone symbol and where to go next, centred, with nothing to press.
struct IdleNotice: View {
    let idle: WatchIdle

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let ink = InkColors(contrast: contrast)
        // Always On keeps the layout on black and dims the rest, so nothing moves on wrist-down.
        let dim = isLuminanceReduced
        ScrollView {
            VStack(spacing: 6) {
                Image(systemName: "iphone")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(ink.accent.opacity(dim ? 0.55 : 1))
                    .accessibilityHidden(true)
                Text(idle.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ink.text.opacity(dim ? 0.7 : 1))
                if let message = idle.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(ink.secondary.opacity(dim ? 0.6 : 1))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
        }
        // Centred while it fits, scrolling only at the largest text sizes.
        .defaultScrollAnchor(.center, for: .alignment)
        .scrollBounceBehavior(.basedOnSize)
        .background(dim ? Color.black : ink.background)
    }
}

#Preview("Start on iPhone") {
    IdleNotice(idle: .startOnIPhone)
}

#Preview("Turn on Apple Health") {
    IdleNotice(idle: .turnOnHealth)
}
