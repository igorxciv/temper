import SwiftUI

/// A Preset's name over its value summary, with a checkmark when it's the picked one.
struct PresetRow: View {
    let name: String
    let summary: String
    let isPicked: Bool
    let rename: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Button(action: rename) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(colors.text)
                    Text(summary)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(colors.secondary)
                }
                Spacer()
                if isPicked {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(colors.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}
