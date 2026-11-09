import SwiftUI
import TemperCore

struct CompleteScreen: View {
    /// The Workout record's active time, the same total the Live Activity shows.
    let total: Duration
    let done: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        VStack(spacing: 24) {
            Spacer()
            CompleteHeading(checkmarkSize: 96)
            Text(total.clockText(rounding: .down))
                .font(.title2.monospacedDigit())
                .foregroundStyle(colors.secondary)
                .accessibilityLabel(total.spokenText(rounding: .down))
            Spacer()
            CompleteDoneButton(done: done)
        }
        .frame(maxWidth: .infinity)
        .background(colors.background.ignoresSafeArea())
    }
}
