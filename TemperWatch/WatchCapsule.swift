import SwiftUI
import TemperCore

/// A full-width capsule about 56 pt tall, as on the running screen and the secondary page: filled awake, outlined in
/// Always On.
struct WatchCapsule: View {
    let title: String
    let symbol: String
    let fill: Color
    let ink: Color
    /// The outline and text in Always On, which is the fill unless it's too dark to read on black.
    var outline: Color?
    let dim: Bool
    let action: () -> Void

    var body: some View {
        let outline = (outline ?? fill).opacity(dim ? 0.55 : 1)
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 21, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(dim ? outline : ink)
                .background {
                    if dim {
                        Capsule().strokeBorder(outline, lineWidth: 2)
                    } else {
                        Capsule().fill(fill)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // The time is the point of the running screen, so the capsule can't grow into it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension WatchCommand {
    /// What a capsule that sends the command says.
    var title: String {
        switch self {
        case .done: "Done"
        case .pause: "Pause"
        case .resume: "Resume"
        case .stop: "Stop"
        }
    }

    var symbol: String {
        switch self {
        case .done: "checkmark"
        case .pause: "pause.fill"
        case .resume: "play.fill"
        case .stop: "xmark"
        }
    }
}
