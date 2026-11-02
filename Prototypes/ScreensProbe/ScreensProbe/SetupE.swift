// PROTOTYPE, throw away. Setup E: small previews along the top, one huge value, and a horizontal
// ruler dial instead of a vertical wheel, so one thumb sets any value with one gesture.
import SwiftUI

struct SetupE: View {
    @Bindable var state: ProbeState
    @State private var selected: Field = .work

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Field.allCases) { field in
                    Button {
                        selected = field
                    } label: {
                        VStack(spacing: 2) {
                            Text(field.title).font(.caption.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(field.text(state.values[keyPath: field.keyPath]))
                                .font(.system(.headline, design: .rounded).monospacedDigit())
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(selected == field ? .primary : .secondary)
                        .background(
                            selected == field ? Color.secondary.opacity(0.14) : .clear,
                            in: .rect(cornerRadius: 14)
                        )
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            Text(selected.title).font(.title2.weight(.medium)).foregroundStyle(.secondary)
            Text(selected.text(state.values[keyPath: selected.keyPath]))
                .font(.system(size: 112, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            RulerDial(state: state, field: selected)
                .id(selected)
                .frame(height: 120)
            Spacer(minLength: 0)
            StartButton(state: state)
        }
        .padding(.horizontal)
        .navigationTitle("Temper")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if let editing = state.editing { selected = editing } }
    }
}

private struct RulerDial: View {
    @Bindable var state: ProbeState
    let field: Field

    @State private var position: Int?

    private let tickWidth: CGFloat = 12

    private var value: Int { state.values[keyPath: field.keyPath] }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(field.options, id: \.self) { option in
                        tick(option).frame(width: tickWidth, height: proxy.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, (proxy.size.width - tickWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .center)
            .onAppear { position = value }
            .onChange(of: position) { _, new in
                if let new { state.values[keyPath: field.keyPath] = new }
            }
            .sensoryFeedback(.selection, trigger: value)
            .overlay {
                Capsule().fill(.primary).frame(width: 4, height: 64).allowsHitTesting(false)
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.2),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .accessibilityElement()
        .accessibilityLabel(field.title)
        .accessibilityValue(field.text(value))
        .accessibilityAdjustableAction { direction in
            let options = field.options
            let index = options.firstIndex(of: value) ?? 0
            let next = direction == .increment ? index + 1 : index - 1
            if options.indices.contains(next) {
                state.values[keyPath: field.keyPath] = options[next]
                position = options[next]
            }
        }
    }

    private func tick(_ option: Int) -> some View {
        let isRounds = field == .rounds
        let isMajor = isRounds ? option % 5 == 0 : option % 30 == 0
        let hasLabel = isRounds ? option % 10 == 0 : option % 60 == 0
        return VStack(spacing: 6) {
            Capsule()
                .fill(isMajor ? Color.primary : Color.secondary.opacity(0.5))
                .frame(width: isMajor ? 3 : 2, height: isMajor ? 40 : 22)
            if hasLabel {
                Text(isRounds ? "\(option)" : "\(option / 60)m")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(width: 0)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}
