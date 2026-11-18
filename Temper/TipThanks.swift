import SwiftUI
import TemperCore

/// How big a thank-you a tip gets: the bigger the tip, the more confetti.
enum TipCelebration: Equatable {
    case small
    case medium
    case large

    /// A tip Temper doesn't know by its ID is thanked as a small one.
    init(productID: Tip.ID) {
        self =
            switch productID {
            case "tip.large": .large
            case "tip.medium": .medium
            default: .small
            }
    }

    var title: String {
        switch self {
        case .small: "Thank you!"
        case .medium: "Thank you so much!"
        case .large: "Thank you, truly!"
        }
    }

    /// The ring bursts once it closes. A medium tip adds cannons from the bottom corners, and a large one a second
    /// burst from the ring as they land.
    var bursts: [Confetti.Burst] {
        let ring = Confetti.Burst(origin: .ring, delay: 0, count: 70)
        let cannons = [
            Confetti.Burst(origin: .leadingCorner, delay: 0.35, count: 45),
            Confetti.Burst(origin: .trailingCorner, delay: 0.35, count: 45),
        ]
        switch self {
        case .small: return [ring]
        case .medium: return [ring] + cannons
        case .large: return [ring] + cannons + [Confetti.Burst(origin: .ring, delay: 0.9, count: 90)]
        }
    }
}

/// What the tip jar turns into once a tip goes through: a ring closes round a heart in the four Phase colors, as a
/// whole Workout would, then bursts into confetti in the same colors, behind the ring and the words. Never amber, since
/// amber means act.
///
/// The success haptic plays as the ring closes, and a soft one with each later burst. With Reduce Motion the ring is
/// simply there, closed round the heart, with no confetti.
struct TipThanks: View {
    let celebration: TipCelebration

    @State private var progress = 0.0
    @State private var isClosed = false
    @State private var confetti: Confetti?
    @State private var confettiStart = Date.now
    /// Counts the bursts after the first, for their haptics.
    @State private var laterBursts = 0

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let order: [Phase.Kind] = [.prepare, .work, .rest, .cooldown]
    private static let lineWidth: CGFloat = 14

    var body: some View {
        let ink = InkColors(contrast: contrast)

        VStack(spacing: 20) {
            Spacer(minLength: 0)
            ring(ink: ink)
                // It gives way to the words on the iPhone SE at large text sizes, but stays big enough to read as a
                // ring.
                .frame(minWidth: 72, maxWidth: 150, minHeight: 72, maxHeight: 150)
                .layoutPriority(-1)
                .anchorPreference(key: RingBoundsKey.self, value: .bounds) { $0 }
            VStack(spacing: 6) {
                Text(celebration.title)
                    .font(.title2.bold())
                    .foregroundStyle(ink.text)
                    .accessibilityAddTraits(.isHeader)
                Text("Your tip keeps Temper on the App Store.")
                    .font(.body)
                    .foregroundStyle(ink.secondary)
            }
            .multilineTextAlignment(.center)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .opacity(isClosed ? 1 : 0)
            .offset(y: isClosed || reduceMotion ? 0 : 10)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Behind the ring and the words, so the thanks stays readable while it falls.
        .backgroundPreferenceValue(RingBoundsKey.self) { anchor in
            if let confetti, let anchor {
                GeometryReader { proxy in
                    ConfettiView(
                        confetti: confetti, start: confettiStart, ring: proxy[anchor],
                        palette: Self.order.map { PhaseColors(kind: $0, contrast: contrast).ring } + [ink.text])
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .onAppear(perform: celebrate)
        .sensoryFeedback(.success, trigger: isClosed) { _, closed in closed }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: laterBursts)
    }

    private func ring(ink: InkColors) -> some View {
        ZStack {
            Circle().stroke(ink.separator, lineWidth: Self.lineWidth)
            ForEach(Self.order.indices, id: \.self) { index in
                QuarterArc(index: index, progress: progress)
                    .stroke(
                        PhaseColors(kind: Self.order[index], contrast: contrast).ring,
                        style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
            }
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(PhaseColors(kind: .work, contrast: contrast).ring)
                .symbolEffect(.breathe.plain, isActive: isClosed && !reduceMotion)
                .scaleEffect(isClosed ? 0.42 : 0)
                .accessibilityHidden(true)
        }
        // A stroke straddles its path, so half the line's width keeps the ring inside its frame.
        .padding(Self.lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
    }

    private func celebrate() {
        if reduceMotion {
            progress = 1
            isClosed = true
            return
        }
        withAnimation(.easeInOut(duration: 1)) {
            progress = 1
        } completion: {
            withAnimation(.bouncy(duration: 0.5, extraBounce: 0.25)) {
                isClosed = true
            }
            confettiStart = .now
            confetti = Confetti(bursts: celebration.bursts)
            Task { await hapticsForLaterBursts() }
        }
    }

    /// A soft tap as each burst after the ring's is thrown.
    private func hapticsForLaterBursts() async {
        let delays = Set(celebration.bursts.map(\.delay).filter { $0 > 0 }).sorted()
        for delay in delays {
            try? await Task.sleep(until: .now + .seconds(delay - Date.now.timeIntervalSince(confettiStart)))
            laterBursts += 1
        }
    }
}

/// One Phase's quarter of the thank-you ring, drawn as far as `progress` has come round. The quarters leave a small
/// gap between them, so each color reads on its own.
private nonisolated struct QuarterArc: Shape {
    let index: Int
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// The gap between quarters, as a fraction of the ring, wide enough to show past the round caps.
    private static let gap = 0.06

    func path(in rect: CGRect) -> Path {
        let start = Double(index) / 4 + Self.gap / 2
        let end = min(progress, Double(index + 1) / 4 - Self.gap / 2)
        var path = Path()
        guard end > start else { return path }
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(360 * start - 90), endAngle: .degrees(360 * end - 90), clockwise: false)
        return path
    }
}

/// Where the thank-you ring is, so the confetti bursts from it.
private struct RingBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
