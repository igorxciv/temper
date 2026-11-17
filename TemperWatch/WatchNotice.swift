import SwiftUI
import TemperCore

/// A mark, a title and a smaller line under it, centred: the shape of every Watch screen outside a running Workout's.
/// A screen that can hold for minutes while the iPhone app may have gone has End under it, and the others have nothing
/// to press.
struct WatchNotice<Mark: View>: View {
    let title: String
    let message: String?
    var end: (() -> Void)? = nil
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
                if let end {
                    EndCapsule(dim: dim, action: end)
                        .padding(.top, 8)
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

/// End on the Watch, which stops following the Workout here and leaves it running on the iPhone.
struct EndCapsule: View {
    /// What End does, for VoiceOver.
    static let hint = "Stops following the Workout on Apple Watch. The iPhone carries on."

    let dim: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = StopColors(contrast: contrast)
        WatchCapsule(
            title: "End", symbol: WatchCommand.stop.symbol, fill: colors.darkRed, ink: colors.red, outline: colors.red,
            dim: dim, action: action
        )
        .accessibilityHint(Self.hint)
    }
}

/// From the iPhone's request until its first update, which can take 47 s or more. Nothing about the Workout is known
/// yet, not even its Workout Type. End lets the Watch go back to idle without waiting out the 10 minutes. It takes one
/// tap, unlike End during a dropout, because nothing has shown on the Watch yet, so there's no heart rate to lose.
struct WaitingScreen: View {
    let end: () -> Void

    var body: some View {
        WatchNotice(title: "Connecting to iPhone", message: "Your Workout has started on the iPhone.", end: end) {
            ProgressView()
                .controlSize(.large)
        }
    }
}

/// The iPhone sent messages of a version this Watch can't follow. The Watch has ended its session, and the iPhone runs
/// the Workout alone.
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
    WaitingScreen(end: {})
}

#Preview("Update Temper") {
    UpdateNeededScreen()
}
