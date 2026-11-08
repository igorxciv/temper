// PROTOTYPE, throwaway. See Frame.swift. Every Watch screen other than the running page.

import SwiftUI

/// A symbol, a title and a smaller line under it, centred: the shape of the screens with nothing to press.
private struct Notice<Accessory: View>: View {
    let symbol: String
    let title: String
    let message: String
    let palette: Palette
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(spacing: 6) {
            accessory
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(palette.ring)
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(palette.text)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(palette.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
    }
}

/// Before any Workout: the Watch can't start one.
public struct IdleScreen: View {
    let isAlwaysOn: Bool

    public init(isAlwaysOn: Bool) {
        self.isAlwaysOn = isAlwaysOn
    }

    public var body: some View {
        Notice(
            symbol: "iphone", title: "Start on iPhone", message: "Pick a Workout on your iPhone and tap Start.",
            palette: .app(isAlwaysOn: isAlwaysOn)
        ) { EmptyView() }
    }
}

/// From `handle(_:)` until the iPhone's first message, which can take 47 s or more. Nothing about the Workout is
/// known yet, not even its type.
public struct WaitingScreen: View {
    let isAlwaysOn: Bool

    public init(isAlwaysOn: Bool) {
        self.isAlwaysOn = isAlwaysOn
    }

    public var body: some View {
        let palette = Palette.app(isAlwaysOn: isAlwaysOn)
        VStack(spacing: 10) {
            Spinner(color: palette.ring)
            Text("Connecting to iPhone")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("Your Workout has started on the iPhone.")
                .font(.system(size: 14))
                .foregroundStyle(palette.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
    }
}

/// A turning arc. `ProgressView` doesn't draw into the snapshots, so this stands in for it on both.
private struct Spinner: View {
    let color: Color
    @State private var isTurning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .frame(width: 34, height: 34)
            .rotationEffect(.degrees(isTurning ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isTurning)
            .onAppear { isTurning = true }
    }
}

/// After a missed 10 s window. The session records in the background until Stop, but there are no controls and no
/// heart rate. L2 also shows the time, read-only.
public struct RunningOnIPhoneScreen: View {
    let variant: LateVariant
    let frame: Frame
    let isAlwaysOn: Bool

    public init(variant: LateVariant, frame: Frame, isAlwaysOn: Bool) {
        self.variant = variant
        self.frame = frame
        self.isAlwaysOn = isAlwaysOn
    }

    public var body: some View {
        switch variant {
        case .message:
            Notice(
                symbol: "iphone", title: "Running on iPhone",
                message: "Control this Workout on the iPhone or its Live Activity.",
                palette: .app(isAlwaysOn: isAlwaysOn)
            ) { EmptyView() }
        case .readOnly:
            let palette = Palette(phase: frame.phase, isAlwaysOn: isAlwaysOn)
            VStack(alignment: .leading, spacing: 2) {
                Text(frame.phase.name)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(palette.ring)
                TimeText(time: frame.time, size: 54, palette: palette)
                PhaseBar(remaining: frame.remaining, palette: palette)
                    .padding(.vertical, 3)
                Text(frame.line)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Label("Running on iPhone", systemImage: "iphone")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().strokeBorder(palette.track, lineWidth: 2))
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(palette.background.ignoresSafeArea())
        }
    }
}

// MARK: - Secondary page

/// A swipe right of the running screen: Pause or Resume, and Stop. Both dim in place during a dropout.
public struct ControlsPage: View {
    let variant: ControlsVariant
    let isPaused: Bool
    let isConnected: Bool
    /// S2 only: Stop has been tapped once and waits for a second tap.
    let isStopArmed: Bool
    let isAlwaysOn: Bool
    let pause: () -> Void
    let stop: () -> Void

    public init(
        variant: ControlsVariant, isPaused: Bool, isConnected: Bool, isStopArmed: Bool, isAlwaysOn: Bool,
        pause: @escaping () -> Void, stop: @escaping () -> Void
    ) {
        self.variant = variant
        self.isPaused = isPaused
        self.isConnected = isConnected
        self.isStopArmed = isStopArmed
        self.isAlwaysOn = isAlwaysOn
        self.pause = pause
        self.stop = stop
    }

    private var pauseLabel: String { isPaused ? "Resume" : "Pause" }
    private var pauseSymbol: String { isPaused ? "play.fill" : "pause.fill" }
    private var stopLabel: String { isStopArmed ? "Tap to end" : "Stop" }

    public var body: some View {
        let palette = Palette.app(isAlwaysOn: isAlwaysOn)
        Group {
            switch variant {
            case .stacked:
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button(action: pause) {
                        Capsule56(
                            label: pauseLabel, symbol: pauseSymbol, fill: palette.ring, ink: palette.background,
                            isAlwaysOn: isAlwaysOn)
                    }
                    .buttonStyle(PlainPress())
                    Button(action: stop) {
                        Capsule56(
                            label: stopLabel, symbol: "xmark", fill: isStopArmed ? .stop : .stop.opacity(0.25),
                            ink: isStopArmed ? .black : .stop, isAlwaysOn: isAlwaysOn)
                    }
                    .buttonStyle(PlainPress())
                }
                .padding(.horizontal, 6)
            case .circles:
                VStack(spacing: 10) {
                    Spacer(minLength: 0)
                    HStack(spacing: 14) {
                        circle(
                            label: stopLabel, symbol: "xmark", color: .stop, isFilled: isStopArmed, action: stop,
                            palette: palette)
                        circle(
                            label: pauseLabel, symbol: pauseSymbol, color: palette.ring, isFilled: false,
                            action: pause, palette: palette)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .opacity(isConnected ? 1 : 0.3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if !isConnected {
                NotConnectedMark(size: 13, palette: palette)
                    .padding(.horizontal, 8)
            }
        }
        .background(palette.background.ignoresSafeArea())
    }

    private func circle(
        label: String, symbol: String, color: Color, isFilled: Bool, action: @escaping () -> Void, palette: Palette
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(isFilled ? .black : color)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(isFilled ? color : color.opacity(isAlwaysOn ? 0.15 : 0.25)))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainPress())
    }
}

/// S1's look, drawn for the snapshots. The Watch app uses the system's own `confirmationDialog`.
public struct StopDialogMock: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Text("End this Workout?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("End Workout")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.stop)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(Color(white: 0.18)))
            Text("Keep Going")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(Color(white: 0.18)))
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Complete

/// After Stop or the Workout's end: the iPhone's complete screen shrunk. Open Rounds adds the Round count and each
/// Round's Work time. C2 adds the heart rate the Watch recorded. Done goes back to "Start on iPhone".
public struct CompleteScreen: View {
    let variant: CompleteVariant
    let summary: Summary
    let isAlwaysOn: Bool
    /// `false` in the snapshots, which can't draw a `ScrollView`. They show the first screenful, top-aligned.
    let scrolls: Bool
    let done: () -> Void

    public init(
        variant: CompleteVariant, summary: Summary, isAlwaysOn: Bool, scrolls: Bool = true,
        done: @escaping () -> Void
    ) {
        self.variant = variant
        self.summary = summary
        self.isAlwaysOn = isAlwaysOn
        self.scrolls = scrolls
        self.done = done
    }

    public var body: some View {
        let palette = Palette.app(isAlwaysOn: isAlwaysOn)
        Group {
            if scrolls {
                ScrollView { content(palette: palette) }
            } else {
                Color.clear
                    .overlay(alignment: .top) {
                        content(palette: palette).fixedSize(horizontal: false, vertical: true)
                    }
                    .clipped()
            }
        }
        .background(palette.background.ignoresSafeArea())
    }

    private func content(palette: Palette) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(palette.ring)
            Text("Workout complete")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(summary.total)
                .font(.system(size: 26, weight: .semibold).monospacedDigit())
                .foregroundStyle(palette.text)
            if summary.type == .openRounds {
                Text(summary.rounds.count == 1 ? "1 Round" : "\(summary.rounds.count) Rounds")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.secondary)
            }
            if variant == .heart {
                HStack(spacing: 10) {
                    heartStat(label: "Avg", value: summary.averageBPM, palette: palette)
                    heartStat(label: "Max", value: summary.maximumBPM, palette: palette)
                }
                .padding(.top, 2)
            }
            if summary.type == .openRounds {
                VStack(spacing: 4) {
                    ForEach(Array(summary.rounds.enumerated()), id: \.offset) { index, time in
                        HStack {
                            Text("Round \(index + 1)")
                            Spacer()
                            Text(time).monospacedDigit()
                        }
                        .font(.system(size: 15))
                        .foregroundStyle(palette.text)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x1B212C)))
                    }
                }
                .padding(.top, 6)
            }
            Button(action: done) {
                Capsule56(
                    label: "Done", symbol: "checkmark", fill: palette.ring, ink: palette.background,
                    isAlwaysOn: isAlwaysOn)
            }
            .buttonStyle(PlainPress())
            .padding(.top, 8)
        }
        .padding(.horizontal, 6)
    }

    private func heartStat(label: String, value: Int, palette: Palette) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.heart)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(palette.secondary)
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(palette.text)
        }
    }
}
