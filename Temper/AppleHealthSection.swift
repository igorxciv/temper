import SwiftUI

/// The one place Temper asks for Health permission, for the iPhone and the Watch together. It never asks at Start or at
/// the end, so Start stays one tap and training never waits on Health. Its row follows the write status and whether
/// the full set would prompt, read again whenever Temper comes to the front, so a change made in the Health app shows
/// here. Once workouts are allowed, a switch turns saving off and on without going to the Health app.
struct AppleHealthSection: View {
    @Bindable var health: HealthSaves
    let colors: InkColors

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            Group {
                switch health.row {
                case .saveWorkouts:
                    Button("Save Workouts to Health", action: requestPermission)
                        .foregroundStyle(colors.accent)
                case .allowHeartRate:
                    saveToggle
                    Button("Allow Heart Rate", action: requestPermission)
                        .foregroundStyle(colors.accent)
                case .saving, .off:
                    saveToggle
                case .notAllowed:
                    Text("Not allowed")
                case nil:
                    EmptyView()
                }
            }
            .listRowBackground(colors.raised)
        } header: {
            Text("Apple Health").foregroundStyle(colors.secondary)
        } footer: {
            Text((health.row ?? .saveWorkouts).footer).foregroundStyle(colors.secondary)
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await health.refreshStatus()
            }
        }
    }

    private var saveToggle: some View {
        Toggle("Save Workouts to Health", isOn: $health.isOn)
    }

    private func requestPermission() {
        Task { await health.requestPermission() }
    }
}
