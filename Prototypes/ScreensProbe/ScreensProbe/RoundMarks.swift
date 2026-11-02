// PROTOTYPE, throw away. The chosen way to show Rounds on the running screen: a Temper bar and a
// large Round number. Chalk and Bezel are in this branch's history at 31084cb.
import SwiftUI

/// The oxide colors steel takes as it tempers, from straw to blue, lifted so they read on dark
/// surfaces. Brass, Ink's accent, is roughly the straw stage.
private let oxideHex: [UInt32] = [0xF7E8AE, 0xE6B566, 0xDD9A63, 0xC48BD0, 0x8F9CF5, 0x6FBDF5]

private let oxideStops: [Color] = oxideHex.indices.map {
    oxide(at: Double($0) / Double(oxideHex.count - 1))
}

/// The oxide color at a position along the Workout, from 0 at the first Round to 1 at the last.
func oxide(at position: Double) -> Color {
    let scaled = min(max(position, 0), 1) * Double(oxideHex.count - 1)
    let lower = min(Int(scaled), oxideHex.count - 2)
    let amount = scaled - Double(lower)
    func channel(_ shift: UInt32) -> Double {
        let from = Double(oxideHex[lower] >> shift & 0xFF)
        let to = Double(oxideHex[lower + 1] >> shift & 0xFF)
        return (from + (to - from) * amount) / 255
    }
    return Color(red: channel(16), green: channel(8), blue: channel(0))
}

/// A steel bar: the oxide colors are revealed left to right, with a cut at each Round. A mark
/// fills across its Round's Work and Rest.
struct TemperBar: View {
    let count: Int
    let filled: Double
    let track: Color
    let cut: Color
    var height: CGFloat = 26

    var body: some View {
        Canvas { context, size in
            let bar = CGRect(origin: .zero, size: size)
            context.clip(to: Path(roundedRect: bar, cornerRadius: min(7, height * 0.3)))
            context.fill(Path(bar), with: .color(track))
            let width = size.width * min(filled / Double(count), 1)
            context.fill(
                Path(CGRect(x: 0, y: 0, width: width, height: size.height)),
                with: .linearGradient(
                    Gradient(colors: oxideStops),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0))
            )
            context.fill(
                Path(CGRect(x: 0, y: 0, width: width, height: max(1, size.height * 0.14))),
                with: .color(.white.opacity(0.28))
            )
            let pitch = size.width / CGFloat(count)
            let every = pitch < 6 ? 5 : 1
            let cutWidth = min(3, max(1, pitch * 0.12))
            for index in 1..<max(count, 1) where index % every == 0 {
                let x = pitch * CGFloat(index) - cutWidth / 2
                context.fill(
                    Path(CGRect(x: x, y: 0, width: cutWidth, height: size.height)),
                    with: .color(cut))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// The Round number, set large enough to read from across a room and wearing its Round's oxide
/// color, with the total beside it.
struct RoundCount: View {
    let runner: Runner
    var size: CGFloat = 64

    private var tint: Color? {
        guard runner.phase.kind != .prepare else { return nil }
        let round = runner.phase.round ?? runner.rounds
        return oxide(at: (Double(round) - 0.5) / Double(runner.rounds))
    }

    var body: some View {
        Group {
            if runner.isPaused {
                Text("Paused").font(.system(size: size * 0.66, weight: .semibold, design: .rounded))
            } else if runner.phase.kind == .prepare {
                pair("\(runner.rounds)", runner.rounds == 1 ? "Round" : "Rounds")
            } else {
                pair(
                    "\(runner.phase.round ?? runner.rounds)",
                    "of \(runner.rounds)")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(height: size * 1.15)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func pair(_ big: String, _ small: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.14) {
            Text(big)
                .font(.system(size: size, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.foreground))
            Text(small)
                .font(
                    .system(size: size * 0.5, weight: .medium, design: .rounded).monospacedDigit()
                )
                .opacity(0.72)
        }
    }

    private var label: String {
        if runner.isPaused { return "Paused" }
        if let round = runner.phase.round { return "Round \(round) of \(runner.rounds)" }
        return runner.rounds == 1 ? "1 Round" : "\(runner.rounds) Rounds"
    }
}
