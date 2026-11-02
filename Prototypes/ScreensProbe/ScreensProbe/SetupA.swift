// PROTOTYPE, throw away. Setup A: the standard iOS answer, a grouped Form with inline wheels.
import SwiftUI

struct SetupA: View {
    @Bindable var state: ProbeState

    var body: some View {
        Form {
            Section { row(.prepare) }
            Section {
                row(.rounds)
                row(.work)
                row(.rest)
            }
            Section {
                row(.cooldown)
            } footer: {
                Text("Set Cooldown to 0:00 to skip it.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Temper")
        .safeAreaBar(edge: .bottom) {
            Button {
                state.start()
            } label: {
                Text("Start · \(clock(state.values.total))")
                    .font(.title3.bold().monospacedDigit())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private func row(_ field: Field) -> some View {
        Button {
            withAnimation { state.editing = state.editing == field ? nil : field }
        } label: {
            LabeledContent(field.title) {
                Text(field.text(state.values[keyPath: field.keyPath]))
                    .monospacedDigit()
                    .foregroundStyle(state.editing == field ? Color.accentColor : .secondary)
            }
        }
        .foregroundStyle(.primary)
        if state.editing == field {
            if field == .rounds { roundsWheel } else { timeWheels(field) }
        }
    }

    private var roundsWheel: some View {
        Picker("Rounds", selection: $state.values.rounds) {
            ForEach(Field.rounds.options, id: \.self) { Text("\($0)").tag($0) }
        }
        .pickerStyle(.wheel)
    }

    private func timeWheels(_ field: Field) -> some View {
        let binding = Binding {
            state.values[keyPath: field.keyPath]
        } set: {
            state.values[keyPath: field.keyPath] = field.clamped($0)
        }
        let top = (field.options.last ?? 0) / 60
        return HStack(spacing: 0) {
            Picker("Minutes", selection: minutes(binding)) {
                ForEach(0...top, id: \.self) { Text("\($0) min").tag($0) }
            }
            .pickerStyle(.wheel)
            Picker("Seconds", selection: seconds(binding)) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) {
                    Text("\($0) sec").tag($0)
                }
            }
            .pickerStyle(.wheel)
        }
    }

    private func minutes(_ total: Binding<Int>) -> Binding<Int> {
        Binding {
            total.wrappedValue / 60
        } set: {
            total.wrappedValue = $0 * 60 + total.wrappedValue % 60
        }
    }

    private func seconds(_ total: Binding<Int>) -> Binding<Int> {
        Binding {
            total.wrappedValue % 60 / 5 * 5
        } set: {
            total.wrappedValue = total.wrappedValue / 60 * 60 + $0
        }
    }
}
