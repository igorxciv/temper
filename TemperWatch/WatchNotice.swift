import SwiftUI

/// A mark, a title and a smaller line under it, centred, with nothing to press: the shape of every Watch screen
/// outside a running Workout's.
struct WatchNotice<Mark: View>: View {
    let title: String
    let message: String?
    @ViewBuilder let mark: Mark

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let ink = InkColors(contrast: contrast)
        // Always On keeps the layout on black and dims the rest, so nothing moves on wrist-down.
        let dim = isLuminanceReduced
        ScrollView {
            VStack(spacing: 6) {
                mark
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(ink.accent.opacity(dim ? 0.55 : 1))
                    .tint(ink.accent.opacity(dim ? 0.55 : 1))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ink.text.opacity(dim ? 0.7 : 1))
                if let message {
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

/// From the iPhone's request until its first update, which can take 47 s or more. Nothing about the Workout is known
/// yet, not even its Workout Type.
struct WaitingScreen: View {
    var body: some View {
        WatchNotice(title: "Connecting to iPhone", message: "Your Workout has started on the iPhone.") {
            ProgressView()
                .controlSize(.large)
        }
    }
}

/// The iPhone sent messages of a version this Watch can't follow. The Watch has ended its session without saving, and
/// the iPhone runs and saves the Workout alone.
struct UpdateNeededScreen: View {
    var body: some View {
        WatchNotice(
            title: "Update Temper",
            message: "This Workout runs on the iPhone. Update Temper on both to follow the next one here."
        ) {
            Image(systemName: "arrow.down.circle")
        }
    }
}

#Preview("Connecting to iPhone") {
    WaitingScreen()
}

#Preview("Update Temper") {
    UpdateNeededScreen()
}
