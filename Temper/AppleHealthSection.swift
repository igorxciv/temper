import SwiftUI

/// The one place Temper asks for Health permission, for the iPhone and the Watch together. It never asks at Start or at
/// the end, so Start stays one tap and training never waits on Health. Its row follows the write status and whether
/// the full set would prompt, read again whenever Temper comes to the front, so a change made in the Health app shows
/// here.
struct AppleHealthSection: View {
    let health: HealthSaves
    let colors: InkColors

    @Environment(\.scenePhase) private var scenePhase

    private let savesText = "Saves each Workout of 1 minute or more when it ends, with heart rate from Apple Watch."

    var body: some View {
        Group {
            switch health.row {
            case .saveWorkouts:
                section(footer: savesText) {
                    requestButton("Save Workouts to Health")
                }
            case .allowHeartRate:
                section(footer: "Apple Watch shows your heart rate and saves it to Health.") {
                    requestButton("Allow Heart Rate")
                }
            case .saving:
                section(footer: "\(savesText) Turn this off in the Health app.") {
                    LabeledContent("Saving to Health") {
                        Image(systemName: "checkmark")
                            .foregroundStyle(colors.accent)
                            .accessibilityHidden(true)
                    }
                }
            case .notAllowed:
                section(footer: "Allow Temper under Settings › Health › Data Access & Devices.") {
                    Text("Not allowed")
                }
            case nil:
                section(footer: savesText) {
                    EmptyView()
                }
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await health.refreshStatus()
            }
        }
    }

    private func requestButton(_ title: LocalizedStringKey) -> some View {
        Button(title) {
            Task { await health.requestPermission() }
        }
        .foregroundStyle(colors.accent)
    }

    private func section(footer: String, @ViewBuilder row: () -> some View) -> some View {
        Section {
            row()
                .listRowBackground(colors.raised)
        } header: {
            Text("Apple Health").foregroundStyle(colors.secondary)
        } footer: {
            Text(footer).foregroundStyle(colors.secondary)
        }
    }
}
