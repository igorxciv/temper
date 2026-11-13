import SwiftUI
import TemperCore

/// The end of a Workout that ran its Phases: the running screen's ring closed in the last Phase's color with the total
/// inside, what the Rounds ran, and whether the Workout goes to Health.
///
/// Has to hold together on the iPhone SE, 375 by 667 pt, at every text size.
struct CompleteScreen: View {
    /// The Plan the Workout ran, for its recap, or `nil` if it isn't known.
    let board: PlanBoard?
    /// The Workout record's active time, the same total the Live Activity shows.
    let total: Duration
    /// The last Phase that ran, whose color the ring closes in.
    let lastPhase: Phase.Kind?
    let health: HealthSaves
    let close: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        VStack(spacing: 20) {
            CompleteTitle()
                .padding(.top, 16)
            Spacer(minLength: 0)
            CompleteRing(kind: lastPhase, lineWidth: 18) {
                Text(total.clockText(rounding: .down))
                    // Set above any ring's width, so the ring decides the size, as on the running screen.
                    .font(.system(size: 120, weight: .semibold).monospacedDigit())
                    .foregroundStyle(colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(.horizontal, 36)
                    .accessibilityLabel("Total, \(total.spokenText(rounding: .down))")
            }
            // It gives way to the text around it, but never below a size the total reads at.
            .frame(minWidth: 160, maxWidth: 300, minHeight: 160)
            .layoutPriority(-1)
            if let board {
                CompleteRecap(board: board)
            }
            Spacer(minLength: 0)
            CompleteHealthLine(health: health, activeTime: total, alignment: .center)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .padding(.horizontal)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .safeAreaBar(edge: .bottom) {
            CompleteCloseButton(close: close)
        }
        .background(colors.background.ignoresSafeArea())
    }
}
