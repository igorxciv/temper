import SwiftUI

/// The one place Temper asks to write to Health. Its row follows the write status, read again whenever Temper comes
/// to the front, so a change made in the Health app shows here.
struct AppleHealthSection: View {
    let health: HealthSaves
    let colors: InkColors

    @Environment(\.scenePhase) private var scenePhase

    private let savesText = "Saves each Workout of 1 minute or more when it ends."

    var body: some View {
        Group {
            switch health.writeStatus {
            case .notDetermined:
                section(footer: savesText) {
                    Button("Save Workouts to Health") {
                        Task { await health.requestPermission() }
                    }
                    .foregroundStyle(colors.accent)
                }
            case .allowed:
                section(footer: "\(savesText) Turn this off in the Health app.") {
                    LabeledContent("Saving to Health") {
                        Image(systemName: "checkmark")
                            .foregroundStyle(colors.accent)
                            .accessibilityHidden(true)
                    }
                }
            case .denied:
                section(footer: "Allow Temper under Settings › Health › Data Access & Devices.") {
                    Text("Not allowed")
                }
            case nil:
                section(footer: savesText) {
                    EmptyView()
                }
            }
        }
        .onAppear { health.refreshStatus() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                health.refreshStatus()
            }
        }
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
