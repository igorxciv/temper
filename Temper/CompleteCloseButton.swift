import SwiftUI

/// Close, in amber at the foot of both complete screens, which leaves for setup. It sits where Start sat.
///
/// It isn't Done, which ends an open Phase.
struct CompleteCloseButton: View {
    let close: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Button(action: close) {
            Text("Close")
                .font(.title2.bold())
                .foregroundStyle(colors.onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(colors.accent)
        // The screens give the larger text to what's above instead, so Close can't crowd it off an iPhone SE.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
        .padding(.top, 8)
        .padding(.bottom, 6)
        .padding(.horizontal)
    }
}
