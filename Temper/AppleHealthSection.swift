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
                    LabeledContent("Save Workouts to Health") {
                        permissionButton("Turn On")
                    }
                    // One element, read as "Save Workouts to Health, Turn On, button", that the button's action runs.
                    .accessibilityElement(children: .combine)
                case .allowHeartRate:
                    LabeledContent("Saving to Health") {
                        permissionButton("Allow Heart Rate")
                    }
                    .accessibilityElement(children: .combine)
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

    /// The row's action, as a small black-marker capsule at its trailing edge, so it reads as a button and not a label.
    private func permissionButton(_ title: LocalizedStringKey) -> some View {
        Button(action: requestPermission) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(ink.onMarker)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(ink.marker)
    }

    private func requestPermission() {
        Task { await health.requestPermission() }
    }
}
