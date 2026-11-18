import SwiftUI

/// Settings' Heart Rate row, the one place Temper asks for Health permission, for the iPhone and the Watch together,
/// so the Watch can show the heart rate. It never asks at Start or at the end, so Start stays one tap. Settings reads
/// the statuses again whenever Temper comes to the front, so a change made in the Health app shows here.
struct HeartRateSetting: View {
    let row: HeartRateRow
    let colors: InkColors
    let requestPermission: () -> Void

    var body: some View {
        LabeledContent {
            switch row {
            case .allowHeartRate:
                // The action in amber where a status sits once it's answered.
                Button("Allow", action: requestPermission)
                    .foregroundStyle(colors.accent)
                    .accessibilityLabel("Allow Heart Rate")
            case .allowed:
                Text("Allowed").foregroundStyle(colors.secondary)
            case .notAllowed:
                Text("Not Allowed").foregroundStyle(colors.secondary)
            }
        } label: {
            Label {
                Text("Heart Rate")
                Text(row.subtitle).foregroundStyle(colors.secondary)
            } icon: {
                Image(systemName: "heart")
            }
        }
    }
}
