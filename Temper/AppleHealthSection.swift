import SwiftUI
import TemperCore

/// The one place Temper asks for Health permission, for the iPhone and the Watch together. It never asks at Start or at
/// the end, so Start stays one tap and training never waits on Health. Its row follows the write status and whether
/// the full set would prompt, read again whenever Temper comes to the front, so a change made in the Health app shows
/// here.
struct AppleHealthSection: View {
    let health: HealthSaves
    let ink: BoardInk

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            Group {
                switch health.row {
                case .saveWorkouts:
                    Button("Save Workouts to Health", action: requestPermission)
                        .bold()
                        .foregroundStyle(ink.marker)
                case .allowHeartRate:
                    LabeledContent("Saving to Health") {
                        Button("Allow Heart Rate", action: requestPermission)
                            .bold()
                            .foregroundStyle(ink.marker)
                    }
                case .saving:
                    LabeledContent("Saving to Health") {
                        // In Rest's ink, the board's calm color, since nothing is left to do.
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(ink.ink(.rest))
                            .accessibilityHidden(true)
                    }
                case .notAllowed:
                    Text("Not allowed").foregroundStyle(ink.secondary)
                case nil:
                    EmptyView()
                }
            }
            .listRowBackground(ink.row)
        } header: {
            Text("Apple Health").foregroundStyle(ink.marker)
        } footer: {
            Text((health.row ?? .saveWorkouts).footer).foregroundStyle(ink.secondary)
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
