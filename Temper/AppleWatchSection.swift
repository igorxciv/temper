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
                    Button("Allow Heart Rate", action: requestPermission)
                        .foregroundStyle(colors.accent)
                case .allowed:
                    LabeledContent("Heart Rate") {
                        Image(systemName: "checkmark")
                            .foregroundStyle(colors.text)
                            .accessibilityHidden(true)
                    }
                case .notAllowed:
                    Text("Not allowed")
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

    private func requestPermission() {
        Task { await health.requestPermission() }
    }
}
