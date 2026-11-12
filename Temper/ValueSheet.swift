import SwiftUI
import TemperCore

/// Edits a draft of one value on a small board of its own. Confirm hands it back, and swiping the sheet away discards
/// it.
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
        let ink = BoardInk(contrast: contrast)
        // A time is written in its Phase's ink, as its line is on the board, and Rounds in black marker.
        let lineInk = value.phaseKind.map { ink.ink($0) } ?? ink.marker

        VStack(spacing: 8) {
            Text(value.title)
                .font(.headline)
                .foregroundStyle(lineInk)
                .padding(.top, 20)
            wheels
                .foregroundStyle(lineInk)
                // A quiet band behind the center row, so the chosen value stands out at arm's length.
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(ink.panel)
                        .frame(height: DigitWheel.rowHeight)
                }
            if allowsOff {
                // 00:00 alone could read as a wheel left unset, so it's named the way the board names it.
                Text("Off")
                    .font(.subheadline)
                    .foregroundStyle(ink.ghost)
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
                    .foregroundStyle(ink.onMarker)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .tint(ink.marker)
            .padding(.bottom, 6)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer()
        }
        .padding(.horizontal)
        .fontDesign(.rounded)
        .presentationDetents([.medium])
        .presentationBackground(ink.ground)
    }

    /// Whether the value can be turned off, as Prepare, Rest and Cooldown are by setting them to zero.
    private var allowsOff: Bool {
        value.isTime && value.clamped(0) == 0
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
                values: WorkoutValue.roundChoices,
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
