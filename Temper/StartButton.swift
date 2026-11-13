import SwiftUI
import TemperCore

/// Start, in amber at the foot of setup and Describe, with the Workout's length when it ends by itself:
/// "Start · 08:50". A Workout with a Phase that waits for Done has no length to promise, so it says only "Start".
struct StartButton: View {
    let workout: Workout
    let board: PlanBoard
    let start: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Button(action: start) {
            Text(title)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(colors.onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.glassProminent)
        .tint(colors.accent)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
    }

    private var title: String {
        let endsAtDone = board.allLines.contains { line in
            switch line.length {
            case .open, .runsPast: true
            case .set, .off: false
            }
        }
        guard !endsAtDone, let total = workout.totalDuration else { return "Start" }
        return "Start · \(total.clockText)"
    }
}
