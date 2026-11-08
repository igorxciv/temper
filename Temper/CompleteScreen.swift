import SwiftUI
import TemperCore

struct CompleteScreen: View {
    /// The Workout's length, or `nil` if it has none to show.
    let total: Duration?
    let done: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        VStack(spacing: 24) {
            Spacer()
            CompleteHeading(checkmarkSize: 96)
            if let total {
                Text(total.clockText)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(colors.secondary)
                    .accessibilityLabel(total.spokenText(rounding: .up))
            }
            Spacer()
            CompleteDoneButton(done: done)
        }
        .frame(maxWidth: .infinity)
        .background(colors.background.ignoresSafeArea())
    }
}
