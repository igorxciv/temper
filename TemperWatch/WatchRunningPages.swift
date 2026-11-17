import SwiftUI
import TemperCore

/// A running Workout on the Watch: the running screen, with the secondary page a swipe right away.
///
/// The capsule is the iPhone's quick action, so in Open Rounds, where it's Done, Pause and Resume live only on the
/// secondary page. Stop lives only there, away from the capsule, so a Workout runs from Start to Stop on the Watch.
struct WatchRunningPages: View {
    let phase: WatchPhase
    /// False during a dropout, when both pages dim their controls and say "iPhone not connected".
    let isConnected: Bool
    let heartRate: LiveHeartRate
    /// Sends a tap to the iPhone. The update it causes redraws the pages. During a dropout it only gets the failure
    /// haptic.
    let tap: (WatchCommand) -> Void
    /// Stops following the Workout on the Watch, offered only during a dropout.
    let end: () -> Void

    private enum Page {
        case controls
        case running
    }

    @State private var page = Page.running

    var body: some View {
        TabView(selection: $page) {
            WatchControlsPage(phase: phase, isConnected: isConnected, end: end) { command in
                tap(command)
                // Back to the time, to watch the Pause or Resume take hold, as the prototype the owner judged did.
                if command != .stop, isConnected {
                    page = .running
                }
            }
            .tag(Page.controls)
            WatchRunningScreen(phase: phase, isConnected: isConnected, heartRate: heartRate, tap: tap)
                .tag(Page.running)
        }
        .tabViewStyle(.page)
    }
}

/// The secondary page: two wide capsules low on the screen, Pause or Resume above Stop.
///
/// Stop asks by a second tap rather than a dialog, as ``StopConfirmation`` sets out. A tap on Pause or Resume in
/// between cancels the ask, so only two taps on Stop in a row end the Workout.
///
/// During a dropout Pause or Resume dims in place, under "iPhone not connected" at the top, and like every tap only gets
/// the failure haptic. Stop becomes End, which asks the same way, since the iPhone app may have gone and the dropout can
/// last 10 minutes. End stops following the Workout on the Watch, and the iPhone carries on.
private struct WatchControlsPage: View {
    let phase: WatchPhase
    let isConnected: Bool
    let end: () -> Void
    let tap: (WatchCommand) -> Void

    @State private var stopConfirmation = StopConfirmation()

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let colors = PhaseColors(kind: phase.kind, contrast: contrast)
        let stopColors = StopColors(contrast: contrast)
        let dim = isLuminanceReduced

        // Redrawn when an asking Stop goes back to Stop.
        TimelineView(.explicit(stopConfirmation.expiry.map { [$0] } ?? [])) { context in
            let isArmed = stopConfirmation.isArmed(at: context.date)
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                WatchCapsule(
                    title: phase.pauseOrResume.title, symbol: phase.pauseOrResume.symbol, fill: colors.ring,
                    ink: colors.background, dim: dim
                ) {
                    stopConfirmation = StopConfirmation()
                    tap(phase.pauseOrResume)
                }
                .accessibilityHint(isConnected ? "" : NotConnectedMark.title)
                .opacity(isConnected ? 1 : 0.3)
                WatchCapsule(
                    title: isArmed ? "Tap to end" : isConnected ? WatchCommand.stop.title : "End",
                    symbol: WatchCommand.stop.symbol,
                    fill: isArmed ? stopColors.red : stopColors.darkRed,
                    ink: isArmed ? stopColors.onRed : stopColors.red,
                    outline: stopColors.red, dim: dim
                ) {
                    guard stopConfirmation.tap(at: .now) == .end else { return }
                    if isConnected {
                        tap(.stop)
                    } else {
                        end()
                    }
                }
                .accessibilityHint(stopHint(isArmed: isArmed))
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if !isConnected {
                NotConnectedMark(size: 13, dim: dim)
                    .padding(.horizontal, 8)
            }
        }
        .background((dim ? Color.black : colors.background).ignoresSafeArea())
        // A dropout starting or ending between the two taps mustn't turn one into the other.
        .onChange(of: isConnected) {
            stopConfirmation = StopConfirmation()
        }
    }

    private func stopHint(isArmed: Bool) -> String {
        switch (isConnected, isArmed) {
        case (true, true): "Ends the Workout"
        case (true, false): "Tap twice to end the Workout"
        case (false, true): "Stops following the Workout on Apple Watch. The iPhone carries on."
        case (false, false): "\(NotConnectedMark.title). Tap twice to stop following the Workout on Apple Watch."
        }
    }
}

#Preview("Secondary page, Open Rounds Work") {
    WatchRunningPages(
        phase: WatchPhase(
            kind: .work, round: 2, start: .now.addingTimeInterval(-40), end: nil, pausedAt: nil, countsUp: true,
            line: .value("2", caption: .before("Round"), spoken: "Round 2"), capsule: .done),
        isConnected: true, heartRate: LiveHeartRate(), tap: { _ in }, end: {})
}

#Preview("Secondary page, dropout") {
    WatchRunningPages(
        phase: WatchPhase(
            kind: .work, round: 2, start: .now.addingTimeInterval(-40), end: nil, pausedAt: nil, countsUp: true,
            line: .value("2", caption: .before("Round"), spoken: "Round 2"), capsule: .done),
        isConnected: false, heartRate: LiveHeartRate(), tap: { _ in }, end: {})
}
