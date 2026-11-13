import SwiftUI
import TemperCore

/// Edits a draft of one value. Confirm hands it back, and swiping the sheet away discards it.
struct ValueSheet: View {
    let workoutType: WorkoutType
    let value: WorkoutValue
    let confirm: (Int) -> Void

    @State private var draft: Int

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dismiss) private var dismiss

    init(workoutType: WorkoutType, value: WorkoutValue, amount: Int, confirm: @escaping (Int) -> Void) {
        self.workoutType = workoutType
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
                .foregroundStyle(phase?.ring ?? ink.secondary)
                .padding(.top, 20)
            wheels
                .foregroundStyle(phase?.text ?? ink.text)
                // A band behind the center row, so the chosen value stands out at arm's length.
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(phase?.track ?? ink.separator)
                        .frame(height: DigitWheel.rowHeight)
                }
            if let zeroText {
                // 00:00 alone could read as a wheel left unset, and ∞ could puzzle, so zero is named as setup names it.
                Text(zeroText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(phase?.ring ?? ink.secondary)
                    .lineLimit(1)
                    // Always laid out, so the wheels don't shift as the draft crosses zero.
                    .opacity(draft == 0 ? 1 : 0)
                    .accessibilityHidden(draft != 0)
            }
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

    /// What zero means, if the value allows it: Off for Prepare, Rest and Cooldown, and until Stop for Open Rounds'
    /// Rounds.
    private var zeroText: String? {
        guard workoutType.clamped(0, as: value) == 0 else { return nil }
        return value.isTime ? "Off" : "until Stop"
    }

    @ViewBuilder private var wheels: some View {
        if value.isTime {
            HStack(spacing: 0) {
                DigitWheel(
                    values: WorkoutValue.minuteChoices,
                    selection: minutes,
                    label: "\(value.title) minutes",
                    digits: twoDigits
                )
                Text(":")
                    .font(.system(size: 54, weight: .semibold))
                    .accessibilityHidden(true)
                DigitWheel(
                    values: WorkoutValue.secondChoices,
                    selection: seconds,
                    label: "\(value.title) seconds",
                    digits: twoDigits
                )
            }
        } else {
            DigitWheel(
                values: workoutType.roundChoices,
                selection: Binding {
                    draft
                } set: {
                    draft = workoutType.clamped($0, as: value)
                },
                label: value.title,
                digits: value.text(for:),
                spokenValue: { $0 == WorkoutType.roundsUntilStop ? "until Stop" : "\($0)" }
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
