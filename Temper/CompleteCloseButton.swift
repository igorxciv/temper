import SwiftUI

/// Close, in black marker at the foot of both complete screens, which leaves for the Plan the Workout started from.
///
/// It isn't Done, which ends an open Phase. It sits where Start sat, in the same thumb zone.
struct CompleteCloseButton: View {
    let close: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)

        Button(action: close) {
            Text("Close")
                .font(.title2.bold())
                .foregroundStyle(ink.onMarker)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(ink.marker)
        // The screens give the larger text to what's above instead, so Close can't crowd it off an iPhone SE.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
        .padding(.top, 8)
        .padding(.bottom, 6)
        .padding(.horizontal)
    }
}
