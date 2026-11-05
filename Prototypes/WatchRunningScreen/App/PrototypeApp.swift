// PROTOTYPE, throwaway. See Screens/Frame.swift. Runs on a real Watch, because no watchOS Simulator runtime is
// assumed. Swipe right for Stop, left for the prototype's controls.

import SwiftUI
import WatchKit

@main
struct PrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeHost()
        }
    }
}

/// How far the Crown has to turn in one go to count as the quick action.
enum CrownFirmness: String, CaseIterable, Identifiable {
    case light = "Light"
    case firm = "Firm"
    case veryFirm = "Very firm"

    var id: String { rawValue }

    /// In Crown units at `.low` sensitivity. Tune these on the wrist.
    var threshold: Double {
        switch self {
        case .light: 0.6
        case .firm: 1.2
        case .veryFirm: 2.2
        }
    }
}

struct PrototypeHost: View {
    @State private var variant: Variant = .button
    @State private var scenario: Scenario = .openWork
    @State private var workout = FakeWorkout(scenario: .openWork, now: .now)
    @State private var forcesAlwaysOn = false
    @State private var showsHeartRate = true
    @State private var crownFirmness: CrownFirmness = .firm
    @State private var page = 1
    @State private var isConfirmingStop = false

    @State private var crown = 0.0
    @State private var crownAnchor: Double?
    @State private var crownFired = false
    @State private var flash = 0.0

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TabView(selection: $page) {
            stopPage.tag(0)
            runningPage.tag(1)
            controlsPage.tag(2)
        }
        .tabViewStyle(.page)
        .task {
            while !Task.isCancelled {
                workout.advance(to: .now)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        .onChange(of: scenario) { _, scenario in
            workout = FakeWorkout(scenario: scenario, now: .now)
        }
    }

    private var isAlwaysOn: Bool { forcesAlwaysOn || isLuminanceReduced }

    // MARK: Running

    private var runningPage: some View {
        TimelineView(.periodic(from: .now, by: isAlwaysOn ? 1 : 0.25)) { context in
            RunningScreen(
                variant: variant,
                input: ScreenInput(
                    frame: workout.frame(at: context.date),
                    isAlwaysOn: isAlwaysOn,
                    showsHeartRate: showsHeartRate,
                    tap: quickAction
                )
            )
        }
        .overlay { Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false) }
        .overlay(alignment: .topTrailing) { crownMeter }
        .focusable()
        .focusEffectDisabled()
        .digitalCrownRotation(
            $crown, from: -10_000, through: 10_000, sensitivity: .low, isContinuous: true,
            isHapticFeedbackEnabled: true,
            onChange: crownTurned, onIdle: crownStopped
        )
    }

    private func quickAction() {
        if workout.quickAction(at: .now) {
            WKInterfaceDevice.current().play(.success)
            flash = 0.35
            withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
        } else {
            WKInterfaceDevice.current().play(.failure)
        }
    }

    // MARK: Crown backup

    private var crownProgress: Double {
        guard let crownAnchor, !crownFired else { return 0 }
        return min(abs(crown - crownAnchor) / crownFirmness.threshold, 1)
    }

    /// Fills beside the Crown while it turns, so a turn's firmness can be judged.
    @ViewBuilder
    private var crownMeter: some View {
        if crownProgress > 0 {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 5, height: 60)
                .overlay(alignment: .bottom) {
                    Capsule().fill(.white).frame(width: 5, height: 60 * crownProgress)
                }
                .padding(.top, 30)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func crownTurned(_ event: DigitalCrownEvent) {
        let anchor = crownAnchor ?? event.offset
        crownAnchor = anchor
        guard !crownFired, abs(event.offset - anchor) >= crownFirmness.threshold else { return }
        // One turn fires once. The Crown has to rest before it can fire again.
        crownFired = true
        quickAction()
    }

    private func crownStopped() {
        crownAnchor = nil
        crownFired = false
    }

    // MARK: Stop

    private var stopPage: some View {
        VStack(spacing: 8) {
            Button(role: .destructive) {
                isConfirmingStop = true
            } label: {
                Label("Stop", systemImage: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            Text("Stop keeps its confirmation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .confirmationDialog("End this Workout?", isPresented: $isConfirmingStop) {
            Button("End Workout", role: .destructive) {
                workout = FakeWorkout(scenario: scenario, now: .now)
                page = 1
            }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: Prototype controls

    private var controlsPage: some View {
        NavigationStack {
            List {
                Picker("Variant", selection: $variant) {
                    ForEach(Variant.allCases) { Text("\($0.rawValue) \($0.name)").tag($0) }
                }
                Picker("Scenario", selection: $scenario) {
                    ForEach(Scenario.allCases) { Text($0.rawValue).tag($0) }
                }
                Button("Restart scenario") {
                    workout = FakeWorkout(scenario: scenario, now: .now)
                    page = 1
                }
                Toggle("Force Always On", isOn: $forcesAlwaysOn)
                Toggle("Heart-rate slot", isOn: $showsHeartRate)
                Picker("Crown turn", selection: $crownFirmness) {
                    ForEach(CrownFirmness.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .navigationTitle("Prototype")
        }
    }
}
