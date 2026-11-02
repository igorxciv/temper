// PROTOTYPE, throw away. Setup F: the big-stepper look without the buttons. The screen is only the
// preview, and tapping a value opens a sheet with the custom wheel.
import SwiftUI

struct SetupF: View {
    @Bindable var state: ProbeState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Field.allCases) { field in
                Button {
                    state.editing = field
                } label: {
                    VStack(spacing: 0) {
                        Text(field.title).font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(field.text(state.values[keyPath: field.keyPath]))
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if field != .cooldown { Divider() }
            }
            StartButton(state: state)
                .padding(.top, 8)
        }
        .padding(.horizontal)
        .navigationTitle("Temper")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $state.editing) { field in
            VStack(spacing: 8) {
                Text(field.title).font(.headline).padding(.top, 20)
                FieldEditor(state: state, field: field)
            }
            .padding(.horizontal)
            .presentationDetents([.medium])
            .presentationBackground(Color(.systemBackground))
        }
    }
}
