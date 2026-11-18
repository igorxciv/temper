import SwiftUI

/// The one place Temper asks for Health permission, for the iPhone and the Watch together, so the Watch can show the
/// heart rate. It never asks at Start or at the end, so Start stays one tap. Its row follows the statuses, read again
/// whenever Temper comes to the front, so a change made in the Health app shows here.
struct AppleWatchSection: View {
    let health: HealthAccess
    let colors: InkColors

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            Group {
                switch health.row {
                case .allowHeartRate:
                    // The whole row asks, with the action in amber where a status sits once it's answered.
                    Button(action: requestPermission) {
                        LabeledContent {
                            Text("Allow").foregroundStyle(colors.accent)
                        } label: {
                            Text("Heart Rate").foregroundStyle(colors.text)
                        }
                        .contentShape(.rect)
                    }
                    .accessibilityLabel("Allow Heart Rate")
                case .allowed:
                    status("Allowed")
                case .notAllowed:
                    status("Not Allowed")
                case nil:
                    EmptyView()
                }
            }
            .listRowBackground(colors.raised)
        } header: {
            Text("Apple Watch").foregroundStyle(colors.secondary)
        } footer: {
            Text((health.row ?? .allowHeartRate).footer).foregroundStyle(colors.secondary)
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await health.refreshStatus()
            }
        }
    }

    /// The row once Health has its answer: what was decided, as a status rather than something to tap.
    private func status(_ value: String) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(colors.secondary)
        } label: {
            Text("Heart Rate")
        }
    }

    private func requestPermission() {
        Task { await health.requestPermission() }
    }
}
