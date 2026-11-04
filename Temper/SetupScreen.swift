import SwiftUI
import TemperCore

/// Where a Workout Type gets its values, and where End Workout and Done return to.
///
/// Has to fit on the iPhone SE, 375 by 667 pt, with the tab bar and Start, at every text size.
struct SetupScreen: View {
    let workoutType: WorkoutType
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    @State private var editing: WorkoutValue?

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let settings = remembered[workoutType]
        let workout = workoutType.makeWorkout(from: settings)

        // The rows fill the screen and don't need to scroll. The scroll view is there so a drag stretches them
        // and they spring back.
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(workoutType.values) { value in
                    let text = value.text(for: settings[value])

                    Button {
                        editing = value
                    } label: {
                        ValueRow(value: value, text: text)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value.title), \(text)")

                    if value != workoutType.values.last {
                        Rectangle().fill(colors.separator).frame(height: 1)
                    }
                }
            }
            // The visible height, inside the bars, so the rows share it as they did before they could scroll.
            .containerRelativeFrame(.vertical)
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        // In a bar, so Start stays put while the rows stretch under it.
        .safeAreaBar(edge: .bottom) {
            Button {
                start(workoutType, workout)
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
            .padding(.horizontal)
        }
        .background(colors.background.ignoresSafeArea())
        .navigationTitle(workoutType.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { value in
            ValueSheet(value: value, amount: settings[value]) { draft in
                remembered[workoutType][value] = draft
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
                        // 45% keeps the word a backdrop, at about 3:1 against the background. 60% reaches about
                        // 5:1 under Increase Contrast. A prototype's 32% read too faint.
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
