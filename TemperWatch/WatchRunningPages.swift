import SwiftUI
import TemperCore

/// A running Workout on the Watch: the running screen, with the secondary page a swipe right away.
///
/// The capsule is the iPhone's quick action, so in Open Rounds, where it's Done, Pause and Resume live only on the
/// secondary page. Stop lives only there, away from the capsule, so a Workout runs from Start to Stop on the Watch.
struct WatchRunningPages: View {
    let phase: WatchPhase
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
                // Back to the time, to watch the Pause or Resume take hold.
                if command != .stop {
                    page = .running
                }
            }
            .tag(Page.controls)
            WatchRunningScreen(phase: phase, tap: tap)
                .tag(Page.running)
        }
        .tabViewStyle(.page)
    }
}

/// The secondary page: two wide capsules low on the screen, Pause or Resume above Stop.
///
/// Stop asks by a second tap rather than a dialog. The first tap turns it solid red, reading "Tap to end". A second
/// tap within 3 s ends the Workout, and after 3 s it goes back to Stop.
private struct WatchControlsPage: View {
    let phase: WatchPhase
    let tap: (WatchCommand) -> Void

    @State private var stop = StopConfirmation()

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let colors = PhaseColors(kind: phase.kind, contrast: contrast)
        let stopColors = StopColors(contrast: contrast)
        let dim = isLuminanceReduced

        // Redrawn when an asking Stop goes back to Stop.
        TimelineView(.explicit(stop.expiry.map { [$0] } ?? [])) { context in
            let isArmed = stop.isArmed(at: context.date)
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                WatchCapsule(
                    title: phase.pauseCommand == .pause ? "Pause" : "Resume",
                    symbol: phase.pauseCommand == .pause ? "pause.fill" : "play.fill",
                    fill: colors.ring, ink: colors.background, dim: dim
                ) {
                    tap(phase.pauseCommand)
                }
                WatchCapsule(
                    title: isArmed ? "Tap to end" : "Stop", symbol: "xmark",
                    fill: isArmed ? stopColors.red : stopColors.darkRed,
                    ink: isArmed ? stopColors.onRed : stopColors.red,
                    outline: stopColors.red, dim: dim
                ) {
                    if stop.tap(at: .now) == .end {
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

/// A full-width capsule about 56 pt tall, as on the running screen: filled awake, outlined in Always On.
struct WatchCapsule: View {
    let title: String
    let symbol: String
    let fill: Color
    let ink: Color
    /// The outline and text in Always On, which is the fill unless it's too dark to read on black.
    var outline: Color?
    let dim: Bool
    let action: () -> Void

    var body: some View {
        let outline = (outline ?? fill).opacity(dim ? 0.55 : 1)
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 21, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(dim ? outline : ink)
                .background {
                    if dim {
                        Capsule().strokeBorder(outline, lineWidth: 2)
                    } else {
                        Capsule().fill(fill)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // The time is the point of the running screen, so the capsule can't grow into it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

#Preview("Secondary page, Open Rounds Work") {
    WatchRunningPages(
        phase: WatchPhase(
            kind: .work, round: 2, start: .now.addingTimeInterval(-40), end: nil, pausedAt: nil, countsUp: true,
            line: .value("2", caption: .before("Round"), spoken: "Round 2"), capsule: .done),
        tap: { _ in })
}
