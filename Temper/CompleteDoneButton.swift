import SwiftUI

/// The Done at the foot of both complete screens, which leaves for setup.
struct CompleteDoneButton: View {
    let done: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Button(action: done) {
            Text("Done")
                .font(.title2.bold())
                .foregroundStyle(colors.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(colors.accent)
        .padding([.horizontal, .bottom])
    }
}
