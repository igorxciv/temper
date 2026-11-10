import SwiftUI
import TemperCore

/// The iPhone's complete screen shrunk: the checkmark, "Workout complete" and the total. Open Rounds adds the Round
/// count and each Round's Work time. It scrolls, and Done at the end goes back to idle. The iPhone leaves its own
/// complete screen separately.
struct WatchCompleteScreen: View {
    let completion: Completion
    let done: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let ink = InkColors(contrast: contrast)
        let dim = isLuminanceReduced

        ScrollView {
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(ink.accent.opacity(dim ? 0.55 : 1))
                    .accessibilityHidden(true)
                Text("Workout complete")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ink.text.opacity(dim ? 0.7 : 1))
                    .multilineTextAlignment(.center)
                switch completion {
                case .total(let total):
                    TotalText(
                        text: total.clockText(rounding: .down), spoken: total.spokenText(rounding: .down), ink: ink)
                case .rounds(let summary):
                    TotalText(text: summary.total, spoken: summary.spokenTotal, ink: ink)
                    Text(summary.countText)
                        .font(.footnote)
                        .foregroundStyle(ink.secondary)
                    VStack(spacing: 4) {
                        ForEach(summary.rows) { row in
                            RoundRow(row: row, ink: ink)
                        }
                    }
                    .padding(.top, 6)
                }
                Button(action: done) {
                    Label("Done", systemImage: "checkmark")
                        .font(.system(size: 21, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(ink.onAccent)
                        .background(Capsule().fill(ink.accent))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 6)
        }
        .background((dim ? Color.black : ink.background).ignoresSafeArea())
    }
}

private struct TotalText: View {
    let text: String
    let spoken: String
    let ink: InkColors

    var body: some View {
        Text(text)
            .font(.system(size: 26, weight: .semibold).monospacedDigit())
            .foregroundStyle(ink.secondary)
            .accessibilityLabel(spoken)
    }
}

private struct RoundRow: View {
    let row: RoundsSummary.Row
    let ink: InkColors

    var body: some View {
        HStack {
            Text("Round \(row.round)")
            Spacer()
            Text(row.time)
                .monospacedDigit()
        }
        .font(.body)
        .foregroundStyle(ink.text)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(RoundedRectangle(cornerRadius: 10).fill(ink.raised))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenTime)
    }
}

#Preview("Intervals") {
    WatchCompleteScreen(completion: .total(.seconds(530))) {}
}
