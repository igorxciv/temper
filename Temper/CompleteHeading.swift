import SwiftUI

/// The checkmark and "Workout complete" that open both complete screens. They're two views, so the stack they're in
/// spaces them as it spaces the rest.
struct CompleteHeading: View {
    /// The checkmark's point size.
    let checkmarkSize: CGFloat

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: checkmarkSize))
            .foregroundStyle(colors.accent)
            .accessibilityHidden(true)
        Text("Workout complete")
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(colors.text)
            .multilineTextAlignment(.center)
    }
}
