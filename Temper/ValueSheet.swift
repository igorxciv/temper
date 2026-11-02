import SwiftUI
import TemperCore

/// Edits a draft of one value. Confirm hands it back, and swiping the sheet away discards it.
struct ValueSheet: View {
    let value: WorkoutValue
    let confirm: (Int) -> Void

    @State private var draft: Int

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dismiss) private var dismiss

    init(value: WorkoutValue, amount: Int, confirm: @escaping (Int) -> Void) {
        self.value = value
        self.confirm = confirm
        _draft = State(initialValue: amount)
    }

    var body: some View {
        let ink = InkColors(contrast: contrast)
        let phase = value.phaseKind.map { PhaseColors(kind: $0, contrast: contrast) }

        VStack(spacing: 8) {
            Text(value.title)
                .font(.headline)
                .foregroundStyle(phase?.ring ?? ink.accent)
                .padding(.top, 20)
            wheels
                .foregroundStyle(phase?.text ?? ink.text)
            Button {
                confirm(draft)
                dismiss()
            } label: {
                Text("Confirm")
                    .font(.title2.bold())
                    .foregroundStyle(ink.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.glassProminent)
            .tint(ink.accent)
            .padding(.bottom, 6)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer()
        }
        .padding(.horizontal)
        .fontDesign(.rounded)
        .presentationDetents([.medium])
        .presentationBackground(phase?.background ?? ink.raised)
    }

    @ViewBuilder private var wheels: some View {
        if value.isTime {
            HStack(spacing: 0) {
                DigitWheel(
                    values: Array(0...30),
                    selection: minutes,
                    label: "\(value.title) minutes",
                    digits: twoDigits
                )
                Text(":")
                    .font(.system(size: 54, weight: .semibold))
                    .accessibilityHidden(true)
                DigitWheel(
                    values: Array(stride(from: 0, to: 60, by: 5)),
                    selection: seconds,
                    label: "\(value.title) seconds",
                    digits: twoDigits
                )
            }
        } else {
            DigitWheel(
                values: Array(1...99),
                selection: Binding {
                    draft
                } set: {
                    draft = value.clamped($0)
                },
                label: value.title,
                digits: { "\($0)" }
            )
        }
    }

    private var minutes: Binding<Int> {
        Binding {
            draft / 60
        } set: {
            draft = value.amount(minutes: $0, seconds: draft % 60)
        }
    }

    private var seconds: Binding<Int> {
        Binding {
            draft % 60
        } set: {
            draft = value.amount(minutes: draft / 60, seconds: $0)
        }
    }

    private func twoDigits(_ number: Int) -> String {
        number < 10 ? "0\(number)" : "\(number)"
    }
}

extension WorkoutValue {
    /// The value's name: its Phase's, or "Rounds".
    var title: String {
        phaseKind?.name ?? "Rounds"
    }
}
