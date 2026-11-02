// PROTOTYPE, throw away. The chosen setup screen: the screen is only the preview, and tapping a
// value opens a sheet with the custom wheel. Each row carries its label as a large secondary word
// in its Phase's color, behind the value, and this round compares three ways to make it recede.
// Rounds has no Phase, so it wears brass. Thread, Italic and Edge labels are in this branch's
// history at 11379f3.
import SwiftUI

enum LabelStyle: String, CaseIterable {
    case stamped, outline, fade

    var title: String {
        switch self {
        case .stamped: "Stamped"
        case .outline: "Outline"
        case .fade: "Fade"
        }
    }

    var next: LabelStyle {
        let all = Self.allCases
        return all[((all.firstIndex(of: self) ?? 0) + 1) % all.count]
    }
}

struct SetupF: View {
    @Bindable var state: ProbeState

    private var colors: ThemeColors { state.theme.colors }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Field.allCases) { field in
                Button {
                    state.editing = field
                } label: {
                    row(field)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(field.title) \(field.text(state.values[keyPath: field.keyPath]))")
                if field != .cooldown {
                    Rectangle().fill(colors.separator).frame(height: 1)
                }
            }
            StartButton(state: state)
                .padding(.top, 8)
        }
        .padding(.horizontal)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Temper")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $state.editing) { field in
            let sheet = sheetColors(field)
            VStack(spacing: 8) {
                Text(field.title).font(.headline).foregroundStyle(sheet.title).padding(.top, 20)
                FieldEditor(state: state, field: field)
                    .foregroundStyle(sheet.text)
            }
            .padding(.horizontal)
            .presentationDetents([.medium])
            .presentationBackground(sheet.background)
        }
    }

    private func row(_ field: Field) -> some View {
        ZStack {
            word(field)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask {
                    // Dissolves just before the digits begin, so a long word never runs under them.
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.5),
                            .init(color: .clear, location: 0.6),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .accessibilityHidden(true)
            Text(field.text(state.values[keyPath: field.keyPath]))
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(colors.text)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func word(_ field: Field) -> some View {
        let base = Text(field.title)
            .font(.system(size: 60, weight: .bold, design: .rounded))
            .lineLimit(1)
            .fixedSize()
        switch state.labelStyle {
        case .stamped:
            base
                .foregroundStyle(stampColor(field))
                .shadow(color: .white.opacity(0.14), radius: 0, y: 0.75)
                .shadow(color: .black.opacity(0.7), radius: 0, y: -0.75)
        case .outline:
            ZStack {
                ForEach(0..<12, id: \.self) { step in
                    let angle = Double(step) / 12 * 2 * .pi
                    base
                        .foregroundStyle(titleColor(field).opacity(0.6))
                        .offset(x: cos(angle) * 1, y: sin(angle) * 1)
                }
                base.foregroundStyle(colors.background)
            }
        case .fade:
            base.foregroundStyle(titleColor(field).opacity(0.5))
        }
    }

    /// The dark tone a Phase already uses for its ring's track. Rounds has no Phase, so it gets the
    /// same treatment from brass.
    private func stampColor(_ field: Field) -> Color {
        field.phaseKind.map { state.theme.phase($0).track }
            ?? colors.accent.mix(with: colors.background, by: 0.72)
    }

    private func titleColor(_ field: Field) -> Color {
        field.phaseKind.map { state.theme.phase($0).ring } ?? colors.accent
    }

    private func sheetColors(_ field: Field) -> (background: Color, title: Color, text: Color) {
        guard let kind = field.phaseKind else {
            return (colors.raised, colors.accent, colors.text)
        }
        let phase = state.theme.phase(kind)
        return (phase.background, phase.ring, phase.text)
    }
}
