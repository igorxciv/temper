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
                        case .a: SetupA(state: state)
                        case .b: SetupB(state: state)
                        case .c: SetupC(state: state)
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
                case .a: RunningA(state: state, runner: runner)
                case .b: RunningB(state: state, runner: runner)
                case .c: RunningC(state: state, runner: runner)
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

extension PhaseKind {
    /// High-contrast pairs. Each Phase also shows its name, so color is never the only signal.
    var fill: Color {
        switch self {
        case .prepare: Color(red: 1.0, green: 0.8, blue: 0.0)
        case .work: Color(red: 0.78, green: 0.07, blue: 0.09)
        case .rest: Color(red: 0.2, green: 0.82, blue: 0.48)
        case .cooldown: Color(red: 0.04, green: 0.28, blue: 0.72)
        }
    }

    var onFill: Color {
        switch self {
        case .prepare, .rest: .black
        case .work, .cooldown: .white
        }
    }
}
