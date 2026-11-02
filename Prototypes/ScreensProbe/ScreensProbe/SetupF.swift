// PROTOTYPE, throw away. The chosen setup screen: the screen is only the preview, and tapping a
// value opens a sheet with the custom wheel. Each row carries its label as a large, dim, hollow
// word in its Phase's color, with the value on the right. Rounds has no Phase, so it wears brass.
// Other label treatments are in this branch's history at 11379f3 and 8617a1c.
import SwiftUI

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
        // The word takes what the digits leave and dissolves over its last 36 pt, so the fade follows
        // the real digit width on every screen instead of a fixed share of it.
        HStack(spacing: 6) {
            // An overlay on empty space, because the word's own width must not widen the row.
            Color.clear
                .overlay(alignment: .leading) { word(field).padding(.leading, 1) }
                .mask {
                    HStack(spacing: 0) {
                        Color.black
                        LinearGradient(
                            colors: [.black, .clear], startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 36)
                    }
                }
                .accessibilityHidden(true)
            Text(field.text(state.values[keyPath: field.keyPath]))
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(colors.text)
                .fixedSize()
        }
    }

    /// Opaque copies composited first, so the single opacity below is the color you actually see.
    private func word(_ field: Field) -> some View {
        let base = Text(field.title)
            .font(.system(size: 60, weight: .bold, design: .rounded))
            .lineLimit(1)
            .fixedSize()
        return ZStack {
            ForEach(0..<12, id: \.self) { step in
                let angle = Double(step) / 12 * 2 * .pi
                base
                    .foregroundStyle(titleColor(field))
                    .offset(x: cos(angle) * 1, y: sin(angle) * 1)
            }
            base.foregroundStyle(colors.background)
        }
        .compositingGroup()
        .opacity(state.labelOpacity)
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
