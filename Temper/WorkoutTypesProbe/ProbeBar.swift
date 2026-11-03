// PROTOTYPE, throw away. Not part of any design: it switches variants and shows the state.
import SwiftUI

extension View {
    /// Each screen gets the bar itself, because an inset on the root doesn't reach into a NavigationStack.
    /// While the bar is hidden, the screen has exactly the layout it would have in the app.
    @ViewBuilder
    func probeBar(_ probe: ProbeState) -> some View {
        #if DEBUG
            if probe.noBar {
                self
            } else if probe.isBarVisible {
                safeAreaInset(edge: .bottom, spacing: 0) { ProbeBar(probe: probe) }
            } else {
                overlay(alignment: .bottomTrailing) {
                    Button {
                        probe.isBarVisible = true
                    } label: {
                        Circle().fill(.yellow).frame(width: 10, height: 10).padding(12)
                    }
                    .accessibilityLabel("Show prototype bar")
                    .ignoresSafeArea()
                }
            }
        #else
            self
        #endif
    }
}

#if DEBUG
    private struct ProbeBar: View {
        @Bindable var probe: ProbeState

        var body: some View {
            HStack(spacing: 2) {
                barButton("chevron.left", "Previous variant") { probe.cycleVariant(by: -1) }
                VStack(spacing: 2) {
                    Text("PROTOTYPE · \(probe.variant.rawValue.uppercased()) \(probe.variant.name)")
                        .font(.caption.bold())
                    Text("last: \(probe.type.rawValue) · line: \(probe.line.name)")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                barButton("chevron.right", "Next variant") { probe.cycleVariant(by: 1) }
                barButton("text.line.last.and.arrowtriangle.forward", "Next Stopwatch line") { probe.cycleLine() }
                barButton("eye.slash", "Hide prototype bar") { probe.isBarVisible = false }
            }
            .monospaced()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.yellow)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(.black, in: Capsule())
            .overlay(Capsule().stroke(.yellow, lineWidth: 1))
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
            .dynamicTypeSize(...DynamicTypeSize.large)
        }

        private func barButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: symbol).frame(width: 30, height: 32)
            }
            .accessibilityLabel(label)
        }
    }
#endif
