import SwiftUI

/// "Workout complete", written in black marker at the top of both complete screens.
struct CompleteHeading: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text("Workout complete")
            .font(.largeTitle.bold())
            .foregroundStyle(BoardInk(contrast: contrast).marker)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
