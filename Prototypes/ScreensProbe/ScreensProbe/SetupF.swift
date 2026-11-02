// PROTOTYPE, throw away. The chosen setup screen: the screen is only the preview, and tapping a
// value opens a sheet with the custom wheel. Each value and sheet wears its Phase's colors, so
// setup previews how the Workout will look. Rounds has no Phase, so it wears brass.
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
                    VStack(spacing: 0) {
                        Text(field.title).font(.subheadline.weight(.semibold))
                            .foregroundStyle(titleColor(field))
                        Text(field.text(state.values[keyPath: field.keyPath]))
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(colors.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
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
