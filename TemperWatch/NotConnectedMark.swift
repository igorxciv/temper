import SwiftUI

/// "iPhone not connected", in yellow, shown for as long as a dropout lasts. The Watch keeps recording meanwhile, so
/// the Phase name and heart rate stay beside it.
struct NotConnectedMark: View {
    /// What the mark says, which is also why a dimmed control does nothing.
    static let title = "iPhone not connected"

    private static let yellow = Color(hex: 0xFFD60A)

    let size: Double
    let dim: Bool

    var body: some View {
        Label(Self.title, systemImage: "iphone.slash")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Self.yellow.opacity(dim ? 0.6 : 1))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

#Preview {
    NotConnectedMark(size: 14, dim: false)
}
