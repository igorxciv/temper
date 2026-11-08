// PROTOTYPE, throwaway. See Frame.swift. The running screen is #76's variant A: the iPhone layout shrunk, with one
// capsule about 56 pt tall for the quick action. Variants B and C from #76 are in this branch's history.

import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double(hex >> 16 & 0xFF) / 255,
            green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let heart = Color(hex: 0xFF5A5F)
    static let warning = Color(hex: 0xFFD60A)
    static let stop = Color(hex: 0xFF5A5F)
}

/// Temper's Phase colors from `Shared/Ink.swift`, and an Always On look built from them.
struct Palette {
    let background: Color
    let ring: Color
    let track: Color
    let text: Color
    let secondary: Color
    let isAlwaysOn: Bool

    init(phase: PhaseKind, isAlwaysOn: Bool) {
        let hex: (background: UInt32, ring: UInt32, track: UInt32, text: UInt32) =
            switch phase {
            case .prepare: (0x0F2433, 0x8FCBEF, 0x274A60, 0xEFF8FD)
            case .work: (0x351C17, 0xFFAE8A, 0x59332A, 0xFFF5F0)
            case .rest: (0x0F2A2B, 0x86DCCB, 0x254A48, 0xF0FBF8)
            case .cooldown: (0x18223F, 0xAFC4FF, 0x2F3D66, 0xF3F6FF)
            }
        self.init(hex: hex, isAlwaysOn: isAlwaysOn)
    }

    /// The app's own colors, for the screens outside a Phase.
    static func app(isAlwaysOn: Bool) -> Palette {
        Palette(hex: (0x11151D, 0xE6B566, 0x2E3643, 0xF3F1EA), isAlwaysOn: isAlwaysOn)
    }

    private init(hex: (background: UInt32, ring: UInt32, track: UInt32, text: UInt32), isAlwaysOn: Bool) {
        self.isAlwaysOn = isAlwaysOn
        // Always On: a black screen, nothing bright, and the same layout, so nothing moves on wrist-down.
        background = isAlwaysOn ? .black : Color(hex: hex.background)
        ring = Color(hex: hex.ring).opacity(isAlwaysOn ? 0.55 : 1)
        track = Color(hex: hex.track).opacity(isAlwaysOn ? 0.6 : 1)
        text = Color(hex: hex.text).opacity(isAlwaysOn ? 0.7 : 1)
        secondary = Color(hex: hex.text).opacity(isAlwaysOn ? 0.4 : 0.65)
    }
}

/// What the running screen gets from the host.
public struct ScreenInput {
    public var frame: Frame
    public var isAlwaysOn: Bool
    public var heart: HeartVariant
    /// `nil` while connected. Otherwise where "iPhone not connected" goes.
    public var dropout: DropoutVariant?
    public var tap: () -> Void

    public init(
        frame: Frame, isAlwaysOn: Bool, heart: HeartVariant, dropout: DropoutVariant?, tap: @escaping () -> Void
    ) {
        self.frame = frame
        self.isAlwaysOn = isAlwaysOn
        self.heart = heart
        self.dropout = dropout
        self.tap = tap
    }

    var palette: Palette { Palette(phase: frame.phase, isAlwaysOn: isAlwaysOn) }
}

// MARK: - Pieces

/// The zone's color, from cool to hot. Dimmed in Always On.
func zoneColor(_ zone: Int, isAlwaysOn: Bool) -> Color {
    let hex: UInt32 =
        switch zone {
        case 1: 0x9DB4D3
        case 2: 0x7FD6A0
        case 3: 0xF5D76E
        case 4: 0xFFA35C
        default: 0xFF5A5F
        }
    return Color(hex: hex).opacity(isAlwaysOn ? 0.55 : 1)
}

/// The heart-rate slot, in the variant picked. A dash until the first reading.
public struct HeartSlot: View {
    let reading: HeartReading
    let variant: HeartVariant
    let palette: Palette

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(palette.isAlwaysOn ? palette.secondary : Color.heart)
            Text(reading.bpm.map(String.init) ?? "--")
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundStyle(palette.text)
            if let zone = reading.zone {
                switch variant {
                case .bpm:
                    EmptyView()
                case .zoneNumber:
                    Text("Z\(zone)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(palette.isAlwaysOn ? zoneColor(zone, isAlwaysOn: true) : .black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background {
                            if palette.isAlwaysOn {
                                Capsule().strokeBorder(zoneColor(zone, isAlwaysOn: true), lineWidth: 1)
                            } else {
                                Capsule().fill(zoneColor(zone, isAlwaysOn: false))
                            }
                        }
                case .zoneMeter:
                    ZoneMeter(zone: zone, palette: palette)
                }
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}

/// Five short bars, rising, with the current zone lit in its color and the ones below it in the track color.
private struct ZoneMeter: View {
    let zone: Int
    let palette: Palette

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(1...5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index == zone ? zoneColor(index, isAlwaysOn: palette.isAlwaysOn) : palette.track)
                    .frame(width: 3.5, height: 5 + CGFloat(index) * 1.6)
            }
        }
        .padding(.leading, 1)
    }
}

/// A thin bar of the Phase's progress. An open Work shows only the track.
struct PhaseBar: View {
    let remaining: Double?
    let palette: Palette

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                if let remaining {
                    Capsule()
                        .fill(palette.ring)
                        .frame(width: max(proxy.size.width * remaining, 4))
                }
            }
        }
        .frame(height: 5)
    }
}

struct TimeText: View {
    let time: String
    let size: CGFloat
    let palette: Palette

    var body: some View {
        Text(time)
            .font(.system(size: size, weight: .semibold).monospacedDigit())
            .foregroundStyle(palette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

struct NotConnectedMark: View {
    let size: CGFloat
    let palette: Palette

    var body: some View {
        Label("iPhone not connected", systemImage: "iphone.slash")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(palette.isAlwaysOn ? Color.warning.opacity(0.6) : Color.warning)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// No highlight and no shrink, so a press never moves or hides what's under the thumb.
struct PlainPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// A full-width capsule about 56 pt tall: filled awake, outlined in Always On.
struct Capsule56: View {
    let label: String
    let symbol: String
    let fill: Color
    let ink: Color
    let isAlwaysOn: Bool

    var body: some View {
        Label(label, systemImage: symbol)
            .font(.system(size: 21, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(isAlwaysOn ? fill : ink)
            .background {
                if isAlwaysOn {
                    Capsule().strokeBorder(fill, lineWidth: 2)
                } else {
                    Capsule().fill(fill)
                }
            }
            .contentShape(Capsule())
    }
}

// MARK: - Running

/// The iPhone's layout shrunk: Phase name and heart rate, the time, a bar, the line, then the capsule. Everything
/// above the capsule ignores taps. During a dropout the time holds what it last heard and the capsule dims in place.
public struct RunningScreen: View {
    let input: ScreenInput

    public init(input: ScreenInput) {
        self.input = input
    }

    public var body: some View {
        let palette = input.palette
        let frame = input.frame
        let action = frame.action
        let isConnected = input.dropout == nil

        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if input.dropout == .header {
                    NotConnectedMark(size: 15, palette: palette)
                } else {
                    Text(frame.phase.name)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(palette.ring)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 2)
                    HeartSlot(reading: frame.heart, variant: input.heart, palette: palette)
                }
            }
            TimeText(time: frame.time, size: 54, palette: palette)
            PhaseBar(remaining: frame.remaining, palette: palette)
                .padding(.vertical, 3)
            Group {
                if input.dropout == .line {
                    NotConnectedMark(size: 14, palette: palette)
                } else {
                    Text(frame.line)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 4)
            Button(action: input.tap) {
                Capsule56(
                    label: action.label, symbol: action.symbol, fill: palette.ring, ink: palette.background,
                    isAlwaysOn: palette.isAlwaysOn)
            }
            .buttonStyle(PlainPress())
            .opacity(action.isEnabled && isConnected ? 1 : 0.3)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.ignoresSafeArea())
    }
}
