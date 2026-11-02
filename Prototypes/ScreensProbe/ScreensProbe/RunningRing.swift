// PROTOTYPE, throw away. Running D, E and F: the layout the owner liked in the first round, with a
// ring for the time left. Colors and type come from research/running-colors. They differ only in
// palette and font design, so the variants compare those two things directly.
import SwiftUI

struct RingPalette {
    let background: Color
    let track: Color
    let text: Color
    let ring: Color
    let name: Color
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double(hex >> 16 & 0xFF) / 255,
            green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension PhaseKind {
    /// Direction A, dark: a neutral background with a Phase-colored ring and name.
    var neutralDark: RingPalette {
        let accent: UInt32 =
            switch self {
            case .prepare: 0xF5D06F
            case .work: 0xFF8A66
            case .rest: 0x66DCCA
            case .cooldown: 0x9DB4FF
            }
        return RingPalette(
            background: Color(hex: 0x101114),
            track: Color(hex: 0x2C2E33),
            text: Color(hex: 0xF5F5F7),
            ring: Color(hex: accent),
            name: Color(hex: accent)
        )
    }

    /// Direction A, light.
    var neutralLight: RingPalette {
        let colors: (ring: UInt32, name: UInt32) =
            switch self {
            case .prepare: (0x9A6F00, 0x7A5900)
            case .work: (0xAD3A1B, 0xA63716)
            case .rest: (0x007A6C, 0x006B5F)
            case .cooldown: (0x3D5BC4, 0x3552B5)
            }
        return RingPalette(
            background: Color(hex: 0xF7F6F3),
            track: Color(hex: 0xDEDCD6),
            text: Color(hex: 0x16171A),
            ring: Color(hex: colors.ring),
            name: Color(hex: colors.name)
        )
    }

    /// Direction B: a deep Phase-tinted background with a lighter tonal ring.
    var tinted: RingPalette {
        let colors: (background: UInt32, ring: UInt32, track: UInt32, text: UInt32) =
            switch self {
            case .prepare: (0x2B2210, 0xF8DE9C, 0x4D3F22, 0xFBF7EF)
            case .work: (0x33191A, 0xFFAD96, 0x573230, 0xFFF6F3)
            case .rest: (0x0F2A28, 0x8FE3D4, 0x25483F, 0xF1FBF8)
            case .cooldown: (0x182340, 0xBCCBFF, 0x303F66, 0xF4F6FF)
            }
        return RingPalette(
            background: Color(hex: colors.background),
            track: Color(hex: colors.track),
            text: Color(hex: colors.text),
            ring: Color(hex: colors.ring),
            name: Color(hex: colors.ring)
        )
    }
}

struct RunningRing: View {
    enum Style {
        case neutral, tinted
    }

    let state: ProbeState
    let runner: Runner
    let style: Style
    let design: Font.Design

    @Environment(\.colorScheme) private var scheme

    private var palette: RingPalette {
        let kind = runner.phase.kind
        switch style {
        case .tinted: return kind.tinted
        case .neutral: return scheme == .dark ? kind.neutralDark : kind.neutralLight
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(runner.phase.kind.rawValue)
                .font(.system(size: 56, weight: .semibold, design: design))
                .foregroundStyle(palette.name)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(palette.track, lineWidth: 20)
                Circle()
                    .trim(from: 0, to: max(0, 1 - runner.phaseProgress))
                    .stroke(palette.ring, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(runner.timeText)
                    .font(.system(size: 132, weight: .semibold, design: design).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 28)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(10)
            Text(footerText)
                .font(.system(size: 40, weight: .semibold, design: design).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button {
                    runner.togglePause()
                } label: {
                    Label(
                        runner.isPaused ? "Resume" : "Pause",
                        systemImage: runner.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, minHeight: 72)
                }
                .buttonStyle(.glass)
                Button {
                    state.confirmStop = true
                } label: {
                    Image(systemName: "stop.fill").font(.title.bold()).frame(width: 72, height: 72)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Stop")
                .stopConfirmation(state)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .preferredColorScheme(style == .tinted ? .dark : nil)
    }

    private var footerText: String {
        if runner.isPaused { return "Paused" }
        return runner.phase.round.map { "Round \($0) of \(runner.rounds)" } ?? " "
    }
}
