import SwiftUI
import TemperCore

struct CompleteScreen: View {
    let total: Duration
    let done: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(colors.accent)
                .accessibilityHidden(true)
            Text("Workout complete")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(colors.text)
                .multilineTextAlignment(.center)
            Text(total.clockText)
                .font(.title2.monospacedDigit())
                .foregroundStyle(colors.secondary)
                .accessibilityLabel(total.spokenText(rounding: .up))
            Spacer()
            Button(action: done) {
                Text("Done")
                    .font(.title2.bold())
                    .foregroundStyle(colors.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .tint(colors.accent)
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(colors.background.ignoresSafeArea())
    }
}
