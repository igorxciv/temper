// PROTOTYPE, throw away. A custom wheel: big digits that fade and shrink away from the center,
// with no selection pill, plus the editor that shows it for any Field.
import SwiftUI

struct DigitWheel: View {
    let values: [Int]
    @Binding var selection: Int
    let label: String
    var rowHeight: CGFloat = 68
    var format: (Int) -> String = { "\($0)" }

    @State private var position: Int?
    @State private var isScrolling = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        Text(format(value))
                            .font(.system(size: 54, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                            .frame(height: rowHeight)
                            .visualEffect { content, geometry in
                                let height = geometry.bounds(of: .scrollView)?.height ?? 1
                                let distance = abs(
                                    geometry.frame(in: .scrollView).midY - height / 2)
                                let amount = min(distance / (height / 2), 1)
                                return content.opacity(1 - 0.85 * amount).scaleEffect(
                                    1 - 0.35 * amount)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.vertical, (proxy.size.height - rowHeight) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .center)
            .onAppear { position = selection }
            .onChange(of: position) { _, new in
                if let new, new != selection { selection = new }
            }
            // While scrolling, the wheel leads. Writing back then would yank it to a stale value.
            .onScrollPhaseChange { _, phase in
                isScrolling = phase != .idle
                if phase == .idle, let position, position != selection { selection = position }
            }
            .onChange(of: selection) { _, new in
                if !isScrolling, position != new { withAnimation { position = new } }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(format(selection))
        .accessibilityAdjustableAction { direction in
            let index = values.firstIndex(of: selection) ?? 0
            let next = direction == .increment ? index + 1 : index - 1
            if values.indices.contains(next) { selection = values[next] }
        }
    }
}

/// One wheel for Rounds, or minutes and seconds wheels for a time.
struct FieldEditor: View {
    @Binding var draft: Int
    let field: Field

    private var value: Binding<Int> {
        Binding {
            draft
        } set: {
            draft = field.clamped($0)
        }
    }

    var body: some View {
        if field == .rounds {
            DigitWheel(values: field.options, selection: value, label: field.title)
                .id(field)
        } else {
            HStack(spacing: 0) {
                DigitWheel(
                    values: Array(0...30),
                    selection: Binding {
                        value.wrappedValue / 60
                    } set: {
                        value.wrappedValue = $0 * 60 + value.wrappedValue % 60
                    },
                    label: "\(field.title) minutes",
                    format: { String(format: "%02d", $0) }
                )
                Text(":")
                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                    .accessibilityHidden(true)
                DigitWheel(
                    values: Array(stride(from: 0, to: 60, by: 5)),
                    selection: Binding {
                        value.wrappedValue % 60
                    } set: {
                        value.wrappedValue = value.wrappedValue / 60 * 60 + $0
                    },
                    label: "\(field.title) seconds",
                    format: { String(format: "%02d", $0) }
                )
            }
            .id(field)
        }
    }
}

struct StartButton: View {
    let state: ProbeState

    var body: some View {
        Button {
            state.start()
        } label: {
            Text("Start · \(clock(state.values.total))")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(state.theme.colors.onAccent)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.glassProminent)
        .padding(.bottom, 6)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
    }
}
