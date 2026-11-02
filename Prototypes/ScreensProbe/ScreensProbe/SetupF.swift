// PROTOTYPE, throw away. The chosen setup screen: the screen is only the preview, and tapping a
// value opens a sheet with the custom wheel. Each value and sheet wears its Phase's colors, so
// setup previews how the Workout will look.
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
                    Group {
                        if field == .rounds {
                            RoundsPreview(state: state)
                        } else {
                            VStack(spacing: 0) {
                                Text(field.title).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(titleColor(field))
                                Text(field.text(state.values[keyPath: field.keyPath]))
                                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(colors.text)
                            }
                        }
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
                if field == .rounds { roundsSheetMark }
                FieldEditor(state: state, field: field)
                    .foregroundStyle(sheet.text)
                    .overlay {
                        if field == .rounds, state.roundStyle == .bezel {
                            RoundDial(
                                count: state.values.rounds, filled: Double(state.values.rounds),
                                done: colors.accent, current: colors.accent,
                                future: colors.separator, maxPip: 5
                            )
                            .frame(width: 216, height: 216)
                            .allowsHitTesting(false)
                        }
                    }
            }
            .padding(.horizontal)
            .presentationDetents([.medium])
            .presentationBackground(sheet.background)
        }
    }

    /// The mark above the Rounds wheel redraws as the wheel turns. Bezel wraps the wheel instead.
    @ViewBuilder
    private var roundsSheetMark: some View {
        switch state.roundStyle {
        case .temper:
            TemperBar(
                count: state.values.rounds, filled: Double(state.values.rounds),
                track: colors.separator, cut: colors.raised, height: 20
            )
            .padding(.top, 8)
        case .chalk:
            ChalkTally(
                count: state.values.rounds, filled: Double(state.values.rounds),
                done: colors.text, current: colors.text, future: colors.separator,
                surface: colors.raised, maxSpacing: 12
            )
            .frame(height: 52)
        case .bezel:
            EmptyView()
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
