// PROTOTYPE, throw away. Setup B: no list and no pickers. Every value has large minus and plus buttons
// on one screen. Holding a button repeats.
import SwiftUI

struct SetupB: View {
    @Bindable var state: ProbeState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Field.allCases) { field in
                HStack(spacing: 12) {
                    step(field, up: false)
                    VStack(spacing: 0) {
                        Text(field.title).font(.subheadline.weight(.medium)).foregroundStyle(
                            .secondary)
                        Text(field.text(state.values[keyPath: field.keyPath]))
                            .font(
                                .system(size: 40, weight: .bold, design: .rounded).monospacedDigit()
                            )
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    step(field, up: true)
                }
                .frame(maxHeight: .infinity)
                if field != .cooldown { Divider() }
            }
            Button {
                state.start()
            } label: {
                Text("Start · \(clock(state.values.total))")
                    .font(.title2.bold().monospacedDigit())
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .padding(.horizontal)
        .navigationTitle("Temper")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ field: Field, up: Bool) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.15)) {
                state.values[keyPath: field.keyPath] = field.stepped(
                    state.values[keyPath: field.keyPath], up: up)
            }
        } label: {
            Image(systemName: up ? "plus" : "minus")
                .font(.title.bold())
                .frame(width: 60, height: 60)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel("\(up ? "More" : "Less") \(field.title)")
    }
}
