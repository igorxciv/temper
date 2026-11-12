import SwiftUI

/// A Preset's name over its value summary, with a checkmark when it's the picked one.
struct PresetRow: View {
    let name: String
    let summary: String
    let isPicked: Bool
    let rename: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)

        Button(action: rename) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(ink.marker)
                    Text(summary)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(ink.secondary)
                }
                Spacer()
                if isPicked {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(ink.marker)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}
