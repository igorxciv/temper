import SwiftUI
import TemperCore

/// Start, in black marker at the foot of a Plan, with the Workout's length when it has one.
///
/// It sits in a bottom bar, so it stays in the thumb's reach and in place while the board scrolls under it.
struct StartButton: View {
    let workout: Workout
    let start: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)

        Button(action: start) {
            Text(workout.totalDuration.map { "Start · \($0.shortClockText(rounding: .up))" } ?? "Start")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(ink.onMarker)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(ink.marker)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
        .padding(.top, 8)
        .padding(.bottom, 6)
        .padding(.horizontal)
    }
}
