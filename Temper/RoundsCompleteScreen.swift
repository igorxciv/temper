import SwiftUI
import TemperCore

/// Open Rounds' complete screen, after Stop: the total active time, the number of Rounds and each Round's Work time.
///
/// Only the list scrolls, so the header and Done stay put however many Rounds there were. Has to hold together on the
/// iPhone SE, 375 by 667 pt, at every text size.
struct RoundsCompleteScreen: View {
    let summary: RoundsSummary
    let done: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(colors.accent)
                    .accessibilityHidden(true)
                Text("Workout complete")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(colors.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Group {
                    Text(summary.total)
                        .font(.title2.monospacedDigit())
                        .accessibilityLabel(summary.spokenTotal)
                    Text(summary.countText)
                        .font(.title3)
                }
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
            .padding(.top, 24)
            .padding(.horizontal)

            List(summary.rows) { row in
                HStack {
                    Text("Round \(row.round)")
                    Spacer()
                    Text(row.time)
                        .monospacedDigit()
                }
                .font(.title3)
                .foregroundStyle(colors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .listRowBackground(colors.raised)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.spokenTime)
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.top, 0, for: .scrollContent)

            Button(action: done) {
                Text("Done")
                    .font(.title2.bold())
                    .foregroundStyle(colors.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .tint(colors.accent)
            .padding([.horizontal, .bottom])
            // The list grows with the text instead, so Done can't push it off the screen.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .frame(maxWidth: .infinity)
        .background(colors.background.ignoresSafeArea())
    }
}
