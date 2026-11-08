import SwiftUI

/// The one place Temper asks to write to Health. Its row follows the write status, read again whenever Temper comes
/// to the front, so a change made in the Health app shows here.
struct AppleHealthSection: View {
    let health: HealthSaves
    let colors: InkColors

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            switch health.writeStatus {
            case .notDetermined:
                Button("Save Workouts to Health") {
                    Task { await health.requestPermission() }
                }
                .foregroundStyle(colors.accent)
                .listRowBackground(colors.raised)
            case .allowed:
                LabeledContent("Saving to Health") {
                    Image(systemName: "checkmark")
                        .foregroundStyle(colors.accent)
                        .accessibilityHidden(true)
                }
                .listRowBackground(colors.raised)
            case .denied:
                Text("Not allowed")
                    .listRowBackground(colors.raised)
            case nil:
                EmptyView()
            }
        } header: {
            Text("Apple Health").foregroundStyle(colors.secondary)
        } footer: {
            Text(footer).foregroundStyle(colors.secondary)
        }
        .onAppear { health.refreshStatus() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                health.refreshStatus()
            }
        }
    }

    private var footer: String {
        switch health.writeStatus {
        case .notDetermined, nil: "Saves each Workout of 1 minute or more when it ends."
        case .allowed: "Saves each Workout of 1 minute or more when it ends. Turn this off in the Health app."
        case .denied: "Allow Temper under Settings › Health › Data Access & Devices."
        }
    }
}
