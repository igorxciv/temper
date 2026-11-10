import SwiftUI
import TemperCore

/// A running Workout on the Watch: the running screen, with the secondary page a swipe right away.
///
/// The capsule is the iPhone's quick action, so in Open Rounds, where it's Done, Pause and Resume live only on the
/// secondary page. Stop lives only there, away from the capsule, so a Workout runs from Start to Stop on the Watch.
struct WatchRunningPages: View {
    let phase: WatchPhase
    let heartRate: LiveHeartRate
    /// Sends a tap to the iPhone. The update it causes redraws the pages.
    let tap: (WatchCommand) -> Void

    private enum Page {
        case controls
        case running
    }

    @State private var page = Page.running

    var body: some View {
        TabView(selection: $page) {
            WatchControlsPage(phase: phase) { command in
                tap(command)
                // Back to the time, to watch the Pause or Resume take hold, as the prototype the owner judged did.
                if command != .stop {
                    page = .running
                }
            }
            .tag(Page.controls)
            WatchRunningScreen(phase: phase, heartRate: heartRate, tap: tap)
                .tag(Page.running)
        }
        .tabViewStyle(.page)
    }
}

/// The secondary page: two wide capsules low on the screen, Pause or Resume above Stop.
///
/// Stop asks by a second tap rather than a dialog, as ``StopConfirmation`` sets out. A tap on Pause or Resume in
/// between cancels the ask, so only two taps on Stop in a row end the Workout.
private struct WatchControlsPage: View {
    let phase: WatchPhase
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
                WatchCapsule(
                    title: isArmed ? "Tap to end" : WatchCommand.stop.title, symbol: WatchCommand.stop.symbol,
                    fill: isArmed ? stopColors.red : stopColors.darkRed,
                    ink: isArmed ? stopColors.onRed : stopColors.red,
                    outline: stopColors.red, dim: dim
                ) {
                    if stopConfirmation.tap(at: .now) == .end {
                        tap(.stop)
                    }
                }
                .accessibilityHint(isArmed ? "Ends the Workout" : "Tap twice to end the Workout")
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background((dim ? Color.black : colors.background).ignoresSafeArea())
    }
}

#Preview("Secondary page, Open Rounds Work") {
    WatchRunningPages(
        phase: WatchPhase(
            kind: .work, round: 2, start: .now.addingTimeInterval(-40), end: nil, pausedAt: nil, countsUp: true,
            line: .value("2", caption: .before("Round"), spoken: "Round 2"), capsule: .done),
        heartRate: LiveHeartRate(), tap: { _ in })
}
