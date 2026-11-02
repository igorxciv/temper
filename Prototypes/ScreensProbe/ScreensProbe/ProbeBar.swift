// PROTOTYPE, throw away. Not part of any design: it switches variants and shows the state.
import SwiftUI

extension View {
    /// Each screen gets the bar itself, because an inset on the root doesn't reach into a NavigationStack.
    /// While the bar is hidden, the screen has exactly the layout it would have in the real app.
    @ViewBuilder
    func probeBar(_ state: ProbeState) -> some View {
        #if DEBUG
            if state.noBar {
                self
            } else if state.barVisible {
                safeAreaInset(edge: .bottom, spacing: 0) { ProbeBar(state: state) }
            } else {
                overlay(alignment: .bottomTrailing) {
                    Button {
                        state.barVisible = true
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
    struct ProbeBar: View {
        @Bindable var state: ProbeState

        private var onRunning: Bool { state.runner != nil }

        var body: some View {
            HStack(spacing: 10) {
                arrow("chevron.left", by: -1)
                VStack(spacing: 2) {
                    Text(title).font(.caption.bold())
                    Text(detail).font(.caption2)
                }
                .frame(maxWidth: .infinity)
                arrow("chevron.right", by: 1)
                if let runner = state.runner, !runner.isDone {
                    barButton("forward.end.fill") { runner.skip() }
                }
                barButton("eye.slash") { state.barVisible = false }
            }
            .monospaced()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.yellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black, in: Capsule())
            .overlay(Capsule().stroke(.yellow, lineWidth: 1))
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
        }

        private var title: String {
            let screen = !state.path.isEmpty ? "SETTINGS" : onRunning ? "RUNNING" : "SETUP"
            return "THEME \(state.theme.rawValue) · \(screen)"
        }

        private var detail: String {
            if let runner = state.runner {
                let round = runner.phase.round.map { " \($0)/\(runner.rounds)" } ?? ""
                let pause = runner.isPaused ? " paused" : ""
                return "\(runner.phase.kind.rawValue)\(round) \(runner.timeText)\(pause)"
            }
            let v = state.values
            return
                "P\(clock(v.prepare)) R\(v.rounds) W\(clock(v.work)) r\(clock(v.rest)) C\(clock(v.cooldown)) dip:\(state.dip ? "on" : "off")"
        }

        private func arrow(_ symbol: String, by offset: Int) -> some View {
            barButton(symbol) {
                let all = Theme.allCases
                let position = all.firstIndex(of: state.theme) ?? 0
                state.theme = all[(position + offset + all.count) % all.count]
            }
        }

        private func barButton(_ symbol: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: symbol).frame(width: 30, height: 32)
            }
        }
    }
#endif
