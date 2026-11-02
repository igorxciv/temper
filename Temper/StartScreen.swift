import SwiftUI
import TemperCore

/// A stand-in for the setup screen: it starts the fixed Workout, and it is where End Workout and Done
/// return to.
struct StartScreen: View {
    let total: Duration
    let start: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        VStack {
            Spacer()
            Button(action: start) {
                Text("Start · \(total.clockText)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(colors.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.glassProminent)
            .tint(colors.accent)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer()
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(colors.background.ignoresSafeArea())
    }
}
