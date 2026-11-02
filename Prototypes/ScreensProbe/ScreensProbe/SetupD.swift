// PROTOTYPE, throw away. Setup D: a preview of every value on top and an always-open custom wheel
// below. Tapping a value points the wheel at it.
import SwiftUI

struct SetupD: View {
    @Bindable var state: ProbeState
    @State private var selected: Field = .work

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                ForEach(Field.allCases) { field in
                    Button {
                        selected = field
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(field.title).font(.title3.weight(.medium))
                            Spacer()
                            Text(field.text(state.values[keyPath: field.keyPath]))
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected == field ? .primary : .secondary)
                        .background(
                            selected == field ? Color.secondary.opacity(0.14) : .clear,
                            in: .capsule
                        )
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected == field ? .isSelected : [])
                }
            }
            FieldEditor(state: state, field: selected)
                .frame(maxHeight: .infinity)
                .clipped()
            StartButton(state: state)
        }
        .padding(.horizontal)
        .navigationTitle("Temper")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if let editing = state.editing { selected = editing } }
    }
}
