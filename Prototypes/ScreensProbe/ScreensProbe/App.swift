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

    var body: some View {
        Group {
            if let runner = state.runner {
                RunningHost(state: state, runner: runner)
            } else {
                NavigationStack(path: $state.path) {
                    Group {
                        switch state.setup {
                        case .d: SetupD(state: state)
                        case .e: SetupE(state: state)
                        case .f: SetupF(state: state)
                        }
                    }
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
                switch state.running {
                case .d:
                    RunningRing(state: state, runner: runner, style: .neutral, design: .rounded)
                case .e:
                    RunningRing(state: state, runner: runner, style: .tinted, design: .rounded)
                case .f:
                    RunningRing(state: state, runner: runner, style: .neutral, design: .default)
                }
            }
        }
        .probeBar(state)
    }
}

struct CompleteScreen: View {
    let state: ProbeState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(.green)
            Text("Workout complete").font(.largeTitle.bold())
            Text(clock(state.values.total)).font(.title2.monospacedDigit()).foregroundStyle(
                .secondary)
            Spacer()
            Button {
                state.stop()
            } label: {
                Text("Done").font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .padding()
        }
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
