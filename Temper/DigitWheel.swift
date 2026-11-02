import SwiftUI

/// A vertical wheel of big digits that fade and shrink away from the center, with no selection pill.
struct DigitWheel: View {
    let values: [Int]
    @Binding var selection: Int
    let label: String
    let digits: (Int) -> String

    private let rowHeight: CGFloat = 68

    @State private var position: Int?
    @State private var isScrolling = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        Text(digits(value))
                            .font(.system(size: 54, weight: .semibold).monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .frame(height: rowHeight)
                            .visualEffect { content, geometry in
                                let height = geometry.bounds(of: .scrollView)?.height ?? 1
                                let distance = abs(geometry.frame(in: .scrollView).midY - height / 2)
                                let amount = min(distance / (height / 2), 1)
                                return content.opacity(1 - 0.85 * amount).scaleEffect(1 - 0.35 * amount)
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
            .onScrollPhaseChange { _, phase in
                isScrolling = phase != .idle
            }
            // While scrolling, the wheel leads: writing back then would yank it to an old value.
            .onChange(of: selection) { _, new in
                if !isScrolling { settle(on: new) }
            }
            // A wheel that came to rest on a value the range refused moves back to the one the draft kept.
            .onChange(of: isScrolling) { _, scrolling in
                if !scrolling { settle(on: selection) }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
        .accessibilityHidden(true)
        // On its own view, because an element on the scroll view takes a frame larger than the wheel, which
        // would run over Confirm.
        .overlay {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityValue("\(selection)")
                .accessibilityAdjustableAction { direction in
                    guard let index = values.firstIndex(of: selection) else { return }
                    let next = direction == .increment ? index + 1 : index - 1
                    if values.indices.contains(next) { selection = values[next] }
                }
        }
    }

    private func settle(on value: Int) {
        if position != value {
            withAnimation { position = value }
        }
    }
}
