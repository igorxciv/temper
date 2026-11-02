// PROTOTYPE, throw away.
import SwiftUI
import UIKit

@main
struct ScreensProbeApp: App {
    @State private var state = ProbeState()

    var body: some Scene {
        WindowGroup { RootView(state: state) }
    }
}

struct RootView: View {
    @Bindable var state: ProbeState
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if let runner = state.runner {
                RunningHost(state: state, runner: runner)
            } else {
                NavigationStack(path: $state.path) {
                    SetupF(state: state)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink(value: Route.settings) {
                                    Label("Settings", systemImage: "gearshape")
                                }
                            }
                        }
                        .probeBar(state)
                        .navigationDestination(for: Route.self) { _ in
                            SettingsScreen(state: state).probeBar(state)
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(state.theme.colors.accent)
        .onChange(of: contrast, initial: true) { _, new in
            state.systemIncreasedContrast = new == .increased
        }
        .onChange(of: state.runner == nil, initial: true) { _, idle in
            UIApplication.shared.isIdleTimerDisabled = !idle
        }
    }
}

struct RunningHost: View {
    @Bindable var state: ProbeState
    let runner: Runner

    var body: some View {
        Group {
            if runner.isDone {
                CompleteScreen(state: state)
            } else {
                RunningRing(state: state, runner: runner)
            }
        }
        .probeBar(state)
    }
}

struct CompleteScreen: View {
    let state: ProbeState

    private var colors: ThemeColors { state.theme.colors }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(colors.accent)
            Text("Workout complete")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(colors.text)
            Text(clock(state.values.total))
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .foregroundStyle(colors.secondary)
            Spacer()
            Button {
                state.stop()
            } label: {
                Text("Done")
                    .font(.title2.bold())
                    .foregroundStyle(colors.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(colors.background.ignoresSafeArea())
    }
}

extension View {
    /// Attached to the Stop button so the dialog originates from it.
    func stopConfirmation(_ state: ProbeState) -> some View {
        @Bindable var state = state
        return confirmationDialog(
            "End this Workout?", isPresented: $state.confirmStop, titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) { state.stop() }
            Button("Keep Going", role: .cancel) {}
        }
    }
}
