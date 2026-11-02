// PROTOTYPE, throw away. Setup C: the Workout reads as a sentence above a strip showing its real shape.
// Tapping a value opens one focused sheet with presets for common values.
import SwiftUI

struct SetupC: View {
    @Bindable var state: ProbeState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(clock(state.values.total))
                .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
            Text("total").font(.subheadline).foregroundStyle(.secondary)
            Strip(phases: state.values.phases)
                .frame(height: 28)
                .padding(.vertical, 16)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 14) {
                line("Prepare for", .prepare, "")
                line("then", .rounds, "Rounds of")
                line("    ", .work, "Work")
                line("    ", .rest, "Rest")
                line("Cooldown", .cooldown, "")
            }
            .font(.title2)
            Spacer(minLength: 0)
            Button {
                state.start()
            } label: {
                Text("Start").font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.glassProminent)
            .padding(.bottom, 6)
        }
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $state.editing) { field in
            PresetSheet(state: state, field: field)
                .presentationDetents([.medium])
        }
    }

    private func line(_ before: String, _ field: Field, _ after: String) -> some View {
        HStack(spacing: 10) {
            Text(before)
            Button(field.text(state.values[keyPath: field.keyPath])) { state.editing = field }
                .font(.title2.bold().monospacedDigit())
                .buttonStyle(.glass)
                .controlSize(.large)
            Text(after)
        }
    }
}

private struct Strip: View {
    let phases: [PhaseItem]

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, phases.reduce(0) { $0 + $1.seconds })
            let gap = phases.count > 40 ? 0.0 : 2.0
            let usable = proxy.size.width - gap * Double(phases.count - 1)
            HStack(spacing: gap) {
                ForEach(phases.indices, id: \.self) { index in
                    phases[index].kind.fill
                        .frame(
                            width: max(1, usable * Double(phases[index].seconds) / Double(total)))
                }
            }
        }
        .clipShape(.rect(cornerRadius: 6))
    }
}

private struct PresetSheet: View {
    @Bindable var state: ProbeState
    let field: Field
    @Environment(\.dismiss) private var dismiss

    private var value: Int { state.values[keyPath: field.keyPath] }

    var body: some View {
        VStack(spacing: 20) {
            Text(field.title).font(.headline).padding(.top, 20)
            HStack {
                step(up: false)
                Text(field.text(value))
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(maxWidth: .infinity)
                step(up: true)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(field.presets, id: \.self) { preset in
                    Button {
                        state.values[keyPath: field.keyPath] = preset
                        dismiss()
                    } label: {
                        Text(field.text(preset))
                            .font(.headline.monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.glass)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    private func step(up: Bool) -> some View {
        Button {
            state.values[keyPath: field.keyPath] = field.stepped(value, up: up)
        } label: {
            Image(systemName: up ? "plus" : "minus").font(.title2.bold()).frame(
                width: 52, height: 52)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
    }
}
