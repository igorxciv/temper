import SwiftUI

/// Confetti for a tip: round pieces thrown out in bursts, which slow in the air, flutter and fall. Every piece is
/// worked out from its age alone, so a frame needs no state from the one before, and the same seed throws the same
/// confetti.
struct Confetti: Equatable {
    /// Where a burst is thrown from.
    enum Origin: Equatable {
        /// The center of the thank-you ring, thrown out all round.
        case ring
        /// A bottom corner, thrown up and in.
        case leadingCorner
        case trailingCorner
    }

    struct Burst: Equatable {
        let origin: Origin
        /// Seconds after the confetti starts.
        let delay: TimeInterval
        let count: Int
    }

    enum Shape: CaseIterable {
        case dot
        case strip
        case ring
        case heart
    }

    struct Piece: Equatable {
        let origin: Origin
        let shape: Shape
        /// An index into the palette the view draws with.
        let color: Int
        let birth: TimeInterval
        let lifetime: TimeInterval
        /// Points per second, with y down.
        let velocity: CGVector
        let size: CGFloat
        /// Turns in the plane of the screen, radians per second.
        let spin: Double
        /// Turns about its own axis, radians per second, so a strip shows its edge as it tumbles.
        let flip: Double
        /// Where its flutter starts, in radians.
        let phase: Double
    }

    /// Where a piece is at one moment, measured from its origin.
    struct Pose: Equatable {
        let offset: CGVector
        let rotation: Double
        /// The piece's height against its width, as it tumbles: 1 face on, 0 edge on.
        let flipScale: Double
        let opacity: Double
    }

    /// How quickly the air slows a piece, per second. Falling, it settles at `gravity / drag` points per second.
    static let drag = 2.4
    /// Points per second squared.
    static let gravity = 620.0
    /// The palette the view draws with has this many colors.
    static let colorCount = 5

    let pieces: [Piece]
    /// Seconds until the last piece has gone.
    let duration: TimeInterval

    init(bursts: [Burst], seed: UInt64 = .random(in: .min ... .max)) {
        var random = SplitMix64(seed: seed)
        pieces = bursts.flatMap { burst in
            (0..<burst.count).map { _ in Self.piece(for: burst, using: &random) }
        }
        duration = pieces.map { $0.birth + $0.lifetime }.max() ?? 0
    }

    /// Where `piece` is `time` seconds after the confetti started, or `nil` before it's thrown and after it's gone.
    static func pose(of piece: Piece, at time: TimeInterval) -> Pose? {
        let age = time - piece.birth
        guard age >= 0, age < piece.lifetime else { return nil }
        // Linear drag, solved exactly, so a piece's path doesn't depend on the frame rate.
        let slowing = (1 - exp(-drag * age)) / drag
        let flutter = 9 * sin(piece.phase + 6 * age) * min(age / 0.6, 1)
        let offset = CGVector(
            dx: piece.velocity.dx * slowing + flutter,
            dy: piece.velocity.dy * slowing + gravity / drag * (age - slowing))
        let growIn = min(age / 0.12, 1)
        let fadeOut = min((piece.lifetime - age) / 0.6, 1)
        return Pose(
            offset: offset,
            rotation: piece.spin * age,
            flipScale: cos(piece.phase + piece.flip * age),
            opacity: growIn * fadeOut)
    }

    private static func piece(for burst: Burst, using random: inout SplitMix64) -> Piece {
        let angle: Double
        let speed: Double
        switch burst.origin {
        case .ring:
            angle = .random(in: 0..<(2 * .pi), using: &random)
            speed = .random(in: 260...820, using: &random)
        case .leadingCorner:
            // Up and to the right, within about 25° of 60° above the horizon.
            angle = -.pi / 3 + .random(in: -0.45...0.45, using: &random)
            speed = .random(in: 900...1500, using: &random)
        case .trailingCorner:
            angle = -2 * .pi / 3 + .random(in: -0.45...0.45, using: &random)
            speed = .random(in: 900...1500, using: &random)
        }
        // Hearts are a treat, one piece in ten.
        let shape: Shape =
            Double.random(in: 0..<1, using: &random) < 0.1
            ? .heart : [Shape.dot, .strip, .ring].randomElement(using: &random) ?? .dot
        return Piece(
            origin: burst.origin,
            shape: shape,
            color: .random(in: 0..<colorCount, using: &random),
            birth: burst.delay + .random(in: 0...0.08, using: &random),
            lifetime: .random(in: 2.2...3.2, using: &random),
            velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
            size: .random(in: 7...12, using: &random),
            spin: .random(in: -6...6, using: &random),
            flip: .random(in: 4...11, using: &random),
            phase: .random(in: 0..<(2 * .pi), using: &random))
    }
}

/// A small, fast generator that a seed fully decides, so confetti can be thrown again the same way.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Draws `confetti` from `start`, redrawing every display frame until its last piece has gone.
struct ConfettiView: View {
    let confetti: Confetti
    let start: Date
    /// The ring's frame, in this view's space. Its pieces start on the ring, so none cover what's inside it.
    let ring: CGRect
    /// One color per palette index.
    let palette: [Color]

    @State private var isFinished = false

    var body: some View {
        TimelineView(.animation(paused: isFinished)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince(start)
                let heart = context.resolve(Image(systemName: "heart.fill"))
                for piece in confetti.pieces {
                    guard let pose = Confetti.pose(of: piece, at: time) else { continue }
                    let origin = start(of: piece, in: size)
                    var layer = context
                    layer.opacity = pose.opacity
                    layer.translateBy(x: origin.x + pose.offset.dx, y: origin.y + pose.offset.dy)
                    layer.rotate(by: .radians(pose.rotation))
                    layer.scaleBy(x: 1, y: pose.flipScale)
                    draw(piece, color: palette[piece.color % palette.count], heart: heart, in: &layer)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(confetti.duration - Date.now.timeIntervalSince(start)))
            isFinished = true
        }
    }

    /// Where `piece` is thrown from: on the ring in the direction it's thrown, or a bottom corner.
    private func start(of piece: Confetti.Piece, in size: CGSize) -> CGPoint {
        switch piece.origin {
        case .ring:
            let speed = max(hypot(piece.velocity.dx, piece.velocity.dy), 1)
            let radius = min(ring.width, ring.height) / 2
            return CGPoint(
                x: ring.midX + piece.velocity.dx / speed * radius, y: ring.midY + piece.velocity.dy / speed * radius)
        case .leadingCorner: return CGPoint(x: 0, y: size.height)
        case .trailingCorner: return CGPoint(x: size.width, y: size.height)
        }
    }

    private func draw(
        _ piece: Confetti.Piece, color: Color, heart: GraphicsContext.ResolvedImage, in context: inout GraphicsContext
    ) {
        let s = piece.size
        switch piece.shape {
        case .dot:
            context.fill(Path(ellipseIn: CGRect(x: -s / 2, y: -s / 2, width: s, height: s)), with: .color(color))
        case .strip:
            let rect = CGRect(x: -s * 0.8, y: -s * 0.28, width: s * 1.6, height: s * 0.56)
            context.fill(Path(roundedRect: rect, cornerRadius: s * 0.28), with: .color(color))
        case .ring:
            let rect = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
            context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: s * 0.26)
        case .heart:
            var tinted = heart
            tinted.shading = .color(color)
            let side = s * 1.4
            context.draw(tinted, in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
        }
    }
}
