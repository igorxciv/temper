// PROTOTYPE, throw away. Fifth round: three ways to show Rounds, drawn from Temper's own world
// instead of a line of text. Each one fills through a Round, across its Work and its Rest.
import SwiftUI

enum RoundStyle: String, CaseIterable {
    case temper, chalk, bezel

    var title: String {
        switch self {
        case .temper: "Temper bar"
        case .chalk: "Chalk"
        case .bezel: "Bezel"
        }
    }

    var next: RoundStyle {
        let all = Self.allCases
        return all[((all.firstIndex(of: self) ?? 0) + 1) % all.count]
    }
}

/// The oxide colors steel takes as it tempers, from straw to blue, lifted so they read on dark
/// surfaces. Brass, Ink's accent, is the straw stage.
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

/// A steel bar: the oxide colors are revealed left to right, with a cut at each Round.
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

/// Five-bar gates in chalk. A stroke draws itself upward as its Round runs.
struct ChalkTally: View {
    let count: Int
    let filled: Double
    let done: Color
    let current: Color
    let future: Color
    let surface: Color
    var maxSpacing: CGFloat = 15

    var body: some View {
        Canvas { context, size in
            let layout = fit(in: size)
            let spacing = layout.spacing
            let height = spacing * 3.1
            let gateWidth = spacing * 3
            let gap = spacing * 1.7
            let gates = (count + 4) / 5
            let columns = gates / layout.rows + (gates % layout.rows == 0 ? 0 : 1)
            var rowWidth = CGFloat(columns) * gateWidth + CGFloat(columns - 1) * gap
            if layout.rows == 1, count % 5 != 0 { rowWidth -= CGFloat(4 - count % 5) * spacing }
            let originX = (size.width - rowWidth) / 2
            let block = CGFloat(layout.rows) * height + CGFloat(layout.rows - 1) * spacing
            let originY = (size.height - block) / 2

            // Unlit strokes go first, so a gate's dim slash never crosses a lit stroke.
            let order = (0..<count).sorted {
                (Double($0) < filled ? 1 : 0, $0) < (Double($1) < filled ? 1 : 0, $1)
            }
            for index in order {
                let gate = index / 5
                let x = originX + CGFloat(gate % columns) * (gateWidth + gap)
                let y = originY + CGFloat(gate / columns) * (height + spacing)
                let path = stroke(index, x: x, y: y, spacing: spacing, height: height)
                let width = max(1.5, spacing * 0.36)
                let style = StrokeStyle(lineWidth: width, lineCap: .round)
                if Double(index + 1) <= filled {
                    context.stroke(path, with: .color(done), style: style)
                    grain(&context, index, x: x, y: y, spacing: spacing, height: height)
                } else {
                    context.stroke(path, with: .color(future), style: style)
                    if Double(index) < filled {
                        let part = path.trimmedPath(from: 0, to: filled - Double(index))
                        context.stroke(part, with: .color(current), style: style)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func fit(in size: CGSize) -> (spacing: CGFloat, rows: Int) {
        let gates = (count + 4) / 5
        var best: (spacing: CGFloat, rows: Int) = (1, 1)
        for rows in 1...max(gates, 1) {
            let columns = CGFloat(gates / rows + (gates % rows == 0 ? 0 : 1))
            let across = size.width / (columns * 3 + (columns - 1) * 1.7 + 0.8)
            let down = size.height / (CGFloat(rows) * 3.1 + CGFloat(rows - 1) + 0.8)
            let spacing = min(across, down, maxSpacing)
            if spacing > best.spacing { best = (spacing, rows) }
        }
        return best
    }

    private func wobble(_ seed: Int, _ salt: Int) -> CGFloat {
        let value = sin(Double(seed * 127 + salt * 311) + 0.5) * 43758.5453
        return CGFloat(value - value.rounded(.down)) * 2 - 1
    }

    /// Drawn from the bottom up, because that's how a hand marks a tally.
    private func stroke(_ index: Int, x: CGFloat, y: CGFloat, spacing: CGFloat, height: CGFloat)
        -> Path
    {
        let slot = index % 5
        let hand = spacing * 0.16
        var path = Path()
        if slot == 4 {
            path.move(
                to: CGPoint(
                    x: x - spacing * 0.5 + wobble(index, 1) * hand,
                    y: y + height * 0.84 + wobble(index, 2) * hand))
            path.addQuadCurve(
                to: CGPoint(
                    x: x + spacing * 3.5 + wobble(index, 3) * hand,
                    y: y + height * 0.14 + wobble(index, 4) * hand),
                control: CGPoint(
                    x: x + spacing * 1.5 + wobble(index, 5) * hand,
                    y: y + height * 0.5 + wobble(index, 6) * hand))
        } else {
            let column = x + CGFloat(slot) * spacing
            path.move(
                to: CGPoint(
                    x: column + wobble(index, 1) * hand,
                    y: y + height + wobble(index, 2) * hand))
            path.addQuadCurve(
                to: CGPoint(x: column + wobble(index, 3) * hand, y: y + wobble(index, 4) * hand),
                control: CGPoint(
                    x: column + wobble(index, 5) * hand * 1.4,
                    y: y + height / 2))
        }
        return path
    }

    /// Specks of the surface showing through, so a finished stroke reads as chalk.
    private func grain(
        _ context: inout GraphicsContext, _ index: Int, x: CGFloat, y: CGFloat,
        spacing: CGFloat, height: CGFloat
    ) {
        guard spacing >= 6, index % 5 != 4 else { return }
        let column = x + CGFloat(index % 5) * spacing
        let specks = Int(height / 2.5)
        for speck in 0..<specks {
            let across = wobble(index, 20 + speck) * spacing * 0.17
            let along = CGFloat(speck) / CGFloat(max(specks - 1, 1)) * height
            let radius = 0.45 + abs(wobble(index, 60 + speck)) * 0.55
            let dot = CGRect(
                x: column + across - radius, y: y + along - radius,
                width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: dot), with: .color(surface.opacity(0.6)))
        }
    }
}

/// Pips around a dial, like the markers on a watch bezel. The current one fills from its center.
struct RoundDial: View {
    let count: Int
    let filled: Double
    let done: Color
    let current: Color
    let future: Color
    var maxPip: CGFloat = 9

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 - maxPip
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let pitch = 2 * .pi * radius / CGFloat(count)
            let pip = min(maxPip * 0.72, pitch * 0.34)
            let active = Int(filled)

            func dot(_ spot: CGPoint, _ size: CGFloat, _ color: Color) {
                let rect = CGRect(
                    x: spot.x - size, y: spot.y - size, width: size * 2, height: size * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            for index in 0..<count {
                let angle = -CGFloat.pi / 2 + 2 * .pi * CGFloat(index) / CGFloat(count)
                let spot = CGPoint(
                    x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if index < active {
                    dot(spot, pip, done)
                } else if index == active {
                    let large = min(maxPip, pitch * 0.44)
                    dot(spot, large, future)
                    dot(spot, large * (filled - Double(active)), current)
                } else {
                    dot(spot, pip * 0.8, future)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The Round number, set large enough to read from across a room, with the total beside it.
struct RoundCount: View {
    let runner: Runner
    var size: CGFloat = 64
    /// Temper bar gives the number its Round's oxide color. The others leave it plain.
    var usesOxide = false

    private var tint: Color? {
        guard usesOxide, runner.phase.kind != .prepare else { return nil }
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

/// The Rounds row on setup, where the mark previews the Workout at its finished state.
struct RoundsPreview: View {
    let state: ProbeState

    private var colors: ThemeColors { state.theme.colors }
    private var count: Int { state.values.rounds }

    var body: some View {
        VStack(spacing: 0) {
            Text("Rounds").font(.subheadline.weight(.semibold))
                .foregroundStyle(colors.accent)
            switch state.roundStyle {
            case .temper:
                number(52)
                TemperBar(
                    count: count, filled: Double(count), track: colors.separator,
                    cut: colors.background, height: 12
                )
                .padding(.horizontal, 44)
            case .chalk:
                number(52)
                ChalkTally(
                    count: count, filled: Double(count), done: colors.text,
                    current: colors.text, future: colors.separator, surface: colors.background,
                    maxSpacing: 7
                )
                .frame(height: 26)
                .padding(.horizontal, 44)
            case .bezel:
                ZStack {
                    RoundDial(
                        count: count, filled: Double(count), done: colors.accent,
                        current: colors.accent, future: colors.separator, maxPip: 3.5
                    )
                    .frame(width: 92, height: 92)
                    number(40)
                }
                .padding(.top, 2)
            }
        }
    }

    private func number(_ size: CGFloat) -> some View {
        Text("\(count)")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(colors.text)
    }
}

/// The finished mark on the complete screen: the Workout's record of what was done.
struct RoundsFinished: View {
    let state: ProbeState

    private var colors: ThemeColors { state.theme.colors }
    private var count: Int { state.values.rounds }

    var body: some View {
        switch state.roundStyle {
        case .temper:
            TemperBar(
                count: count, filled: Double(count), track: colors.separator,
                cut: colors.background, height: 44
            )
            .padding(.horizontal)
        case .chalk:
            ChalkTally(
                count: count, filled: Double(count), done: colors.text, current: colors.text,
                future: colors.separator, surface: colors.background, maxSpacing: 22
            )
            .frame(height: 110)
            .padding(.horizontal)
        case .bezel:
            ZStack {
                RoundDial(
                    count: count, filled: Double(count), done: colors.accent,
                    current: colors.accent, future: colors.separator
                )
                .frame(width: 220, height: 220)
                Text("\(count)")
                    .font(.system(size: 76, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(colors.text)
            }
        }
    }
}
