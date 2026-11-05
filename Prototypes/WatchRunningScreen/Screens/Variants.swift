// PROTOTYPE, throwaway. See Frame.swift.

import SwiftUI

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double(hex >> 16 & 0xFF) / 255,
            green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Temper's Work and Rest colors from `Shared/Ink.swift`, and an Always On look built from them.
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
            case .work: (0x351C17, 0xFFAE8A, 0x59332A, 0xFFF5F0)
            case .rest: (0x0F2A2B, 0x86DCCB, 0x254A48, 0xF0FBF8)
            }
        self.isAlwaysOn = isAlwaysOn
        // Always On: a black screen, nothing bright, and the same layout, so nothing moves on wrist-down.
        background = isAlwaysOn ? .black : Color(hex: hex.background)
        ring = Color(hex: hex.ring).opacity(isAlwaysOn ? 0.55 : 1)
        track = Color(hex: hex.track).opacity(isAlwaysOn ? 0.6 : 1)
        text = Color(hex: hex.text).opacity(isAlwaysOn ? 0.7 : 1)
        secondary = Color(hex: hex.text).opacity(isAlwaysOn ? 0.4 : 0.65)
    }
}

/// What every variant gets from the host.
public struct ScreenInput {
    public var frame: Frame
    public var isAlwaysOn: Bool
    public var showsHeartRate: Bool
    public var tap: () -> Void

    public init(frame: Frame, isAlwaysOn: Bool, showsHeartRate: Bool, tap: @escaping () -> Void) {
        self.frame = frame
        self.isAlwaysOn = isAlwaysOn
        self.showsHeartRate = showsHeartRate
        self.tap = tap
    }

    var palette: Palette { Palette(phase: frame.phase, isAlwaysOn: isAlwaysOn) }

    /// "Round 3 · Work 1:42", as under the iPhone ring.
    var line: String {
        [frame.roundLine, frame.detail].compactMap(\.self).joined(separator: " · ")
    }
}

/// The variant picked on the controls page.
public struct RunningScreen: View {
    let variant: Variant
    let input: ScreenInput

    public init(variant: Variant, input: ScreenInput) {
        self.variant = variant
        self.input = input
    }

    public var body: some View {
        switch variant {
        case .button: LargeButtonScreen(input: input)
        case .band: BandScreen(input: input)
        case .anywhere: AnywhereScreen(input: input)
        }
    }
}

// MARK: - Pieces

/// A slot kept for a heart rate later. It shows a dash, because nothing is measured yet.
private struct HeartSlot: View {
    let palette: Palette

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
                .foregroundStyle(palette.isAlwaysOn ? palette.secondary : Color(hex: 0xFF5A5F))
            Text("--")
                .foregroundStyle(palette.secondary)
        }
        .font(.system(size: 15, weight: .semibold).monospacedDigit())
    }
}

/// A thin bar of the time left. An open Work shows only the track.
private struct PhaseBar: View {
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

private struct TimeText: View {
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

/// No highlight and no shrink, so a press never moves or hides what's under the thumb.
private struct PlainPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - A: Large button

/// The iPhone's layout shrunk: information on top, then one wide button about 56 pt tall across the bottom.
/// Everything above the button ignores taps.
private struct LargeButtonScreen: View {
    let input: ScreenInput

    var body: some View {
        let palette = input.palette
        let action = input.frame.action

        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(input.frame.phaseName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(palette.ring)
                Spacer(minLength: 4)
                if input.showsHeartRate {
                    HeartSlot(palette: palette)
                }
            }
            TimeText(time: input.frame.time, size: 54, palette: palette)
            PhaseBar(remaining: input.frame.remaining, palette: palette)
                .padding(.vertical, 3)
            Text(input.line)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Button(action: input.tap) {
                Label(action.label, systemImage: action.symbol)
                    .font(.system(size: 21, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(palette.isAlwaysOn ? palette.ring : palette.background)
                    .background {
                        if palette.isAlwaysOn {
                            Capsule().strokeBorder(palette.ring, lineWidth: 2)
                        } else {
                            Capsule().fill(palette.ring)
                        }
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(PlainPress())
            .opacity(action.isEnabled ? 1 : 0.3)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.ignoresSafeArea())
    }
}

// MARK: - B: Half-screen band

/// Information in the top half, and the bottom half of the glass, edge to edge and into the corners, as the button.
/// A thumb landing anywhere low on the Watch hits it.
private struct BandScreen: View {
    let input: ScreenInput

    var body: some View {
        let palette = input.palette
        let action = input.frame.action

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(input.frame.phaseName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(palette.ring)
                    Spacer(minLength: 4)
                    if input.showsHeartRate {
                        HeartSlot(palette: palette)
                    }
                }
                TimeText(time: input.frame.time, size: 46, palette: palette)
                PhaseBar(remaining: input.frame.remaining, palette: palette)
                    .padding(.vertical, 2)
                Text(input.line)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: input.tap) {
                VStack(spacing: 2) {
                    Image(systemName: action.symbol)
                        .font(.system(size: 26, weight: .bold))
                    Text(action.label)
                        .font(.system(size: 24, weight: .bold))
                }
                .foregroundStyle(palette.isAlwaysOn ? palette.ring : palette.background)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if palette.isAlwaysOn {
                        UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                            .strokeBorder(palette.ring, lineWidth: 2)
                    } else {
                        UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                            .fill(palette.ring)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainPress())
            .opacity(action.isEnabled ? 1 : 0.3)
            .ignoresSafeArea(edges: [.horizontal, .bottom])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.ignoresSafeArea())
    }
}

// MARK: - C: Tap anywhere

/// No button at all. The whole screen is the quick action, so the space goes to a much bigger time and a progress
/// line around the screen's edge. A small hint at the bottom says what a tap does.
private struct AnywhereScreen: View {
    let input: ScreenInput

    var body: some View {
        let palette = input.palette
        let action = input.frame.action

        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(input.frame.phaseName)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(palette.ring)
                Spacer(minLength: 4)
                if input.showsHeartRate {
                    HeartSlot(palette: palette)
                }
            }
            Spacer(minLength: 0)
            TimeText(time: input.frame.time, size: 76, palette: palette)
            Text(input.line)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Label(action.hint, systemImage: action.isEnabled ? "hand.tap" : "hourglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Only the color and the edge line run under the clock and into the corners.
        .background {
            ZStack {
                palette.background
                EdgeProgress(remaining: input.frame.remaining, palette: palette)
            }
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: input.tap)
    }
}

/// The time left drawn around the display's edge. An open Work shows only the track.
private struct EdgeProgress: View {
    let remaining: Double?
    let palette: Palette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 38, style: .continuous)
        ZStack {
            shape.inset(by: 3).stroke(palette.track, lineWidth: 5)
            if let remaining {
                shape.inset(by: 3).trim(from: 0, to: remaining).stroke(
                    palette.ring, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }
    }
}
