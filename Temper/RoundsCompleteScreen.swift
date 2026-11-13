import SwiftUI
import TemperCore

/// Open Rounds' complete screen, after Stop: the ring closed in the last Phase's color around the total active time,
/// the number of Rounds under it, then each Round's Work time.
///
/// Only the list scrolls, so the ring and Close stay put however many Rounds there were. Has to hold together on the
/// iPhone SE, 375 by 667 pt, at every text size.
struct RoundsCompleteScreen: View {
    let summary: RoundsSummary
    /// The Workout record's active time, for the Health line.
    let activeTime: Duration
    /// The last Phase that ran, whose color the ring closes in.
    let lastPhase: Phase.Kind?
    let health: HealthSaves
    let close: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        VStack(spacing: 12) {
            CompleteTitle()
                .padding(.top, 16)
                .padding(.horizontal)
            CompleteRing(kind: lastPhase, lineWidth: 14) {
                Text(summary.total)
                    // Set above any ring's width, so the ring decides the size, as on the running screen.
                    .font(.system(size: 120, weight: .semibold).monospacedDigit())
                    .foregroundStyle(colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .padding(.horizontal, 26)
                    .accessibilityLabel("Total, \(summary.spokenTotal)")
            }
            // Smaller than the Plan's ring, since the Rounds below need the room.
            .frame(width: 180, height: 180)
            Text(summary.countText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            List {
                Section {
                    ForEach(summary.rows) { row in
                        HStack {
                            Text("Round \(row.round)")
                                .foregroundStyle(colors.text)
                            Spacer()
                            Text(row.time)
                                .monospacedDigit()
                                .foregroundStyle(PhaseColors(kind: .work, contrast: contrast).ring)
                        }
                        .font(.title3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .listRowBackground(colors.raised)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(row.spokenTime)
                    }
                } header: {
                    Text("Work").foregroundStyle(colors.secondary)
                } footer: {
                    CompleteHealthLine(health: health, activeTime: activeTime)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .padding(.top, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.top, 0, for: .scrollContent)
        }
        .frame(maxWidth: .infinity)
        .safeAreaBar(edge: .bottom) {
            CompleteCloseButton(close: close)
        }
        .background(colors.background.ignoresSafeArea())
    }
}
