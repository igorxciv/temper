import SwiftUI
import TemperCore

/// Where a Workout gets its values, and where End Workout and Done return to.
struct SetupScreen: View {
    @Bindable var remembered: RememberedValues
    let start: (Workout) -> Void

    @State private var editing: WorkoutValue?

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let workout = remembered.settings.makeWorkout()

        VStack(spacing: 0) {
            ForEach(WorkoutValue.allCases) { value in
                let text = value.text(for: remembered.settings[value])

                Button {
                    editing = value
                } label: {
                    ValueRow(value: value, text: text)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value.title), \(text)")

                if value != .cooldown {
                    Rectangle().fill(colors.separator).frame(height: 1)
                }
            }
            Button {
                start(workout)
            } label: {
                Text("Start · \(workout.totalDuration.clockText)")
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
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .padding(.horizontal)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Temper")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsScreen(remembered: remembered)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(item: $editing) { value in
            ValueSheet(value: value, amount: remembered.settings[value]) { draft in
                remembered.settings[value] = draft
            }
        }
    }
}

/// One setup row: the hollow word dissolves into the space the digits leave, so the fade follows the
/// real digit width on every screen.
private struct ValueRow: View {
    let value: WorkoutValue
    let text: String

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        HStack(spacing: 6) {
            // An overlay on empty space, because the word's own width must not widen the row.
            Color.clear
                .overlay(alignment: .leading) {
                    HollowWord(
                        word: value.title,
                        color: value.phaseKind.map { PhaseColors(kind: $0, contrast: contrast).ring } ?? colors.accent,
                        fill: colors.background,
                        opacity: contrast == .increased ? 0.6 : 0.45
                    )
                    .padding(.leading, 1)
                }
                .mask {
                    HStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 36)
                    }
                }
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 52, weight: .semibold).monospacedDigit())
                .foregroundStyle(colors.text)
                .fixedSize()
        }
    }
}

/// Opaque copies composited first, so the single opacity is the color you actually see.
private struct HollowWord: View {
    let word: String
    let color: Color
    let fill: Color
    let opacity: Double

    var body: some View {
        let base = Text(word)
            .font(.system(size: 60, weight: .bold))
            .lineLimit(1)
            .fixedSize()

        ZStack {
            ForEach(0..<12, id: \.self) { step in
                let angle = Double(step) / 12 * 2 * .pi
                base.foregroundStyle(color).offset(x: cos(angle), y: sin(angle))
            }
            base.foregroundStyle(fill)
        }
        .compositingGroup()
        .opacity(opacity)
    }
}
