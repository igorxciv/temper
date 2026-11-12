import SwiftUI

/// The round-nib marker's stroke: a little thicker than a hairline, with round ends, and never quite straight.
///
/// Marker strokes draw structure on the board, such as brackets, ticks and underlines, and never letters, which stay
/// in SF Rounded so they read at a glance.
nonisolated extension StrokeStyle {
    static let marker = StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
}

/// A square bracket opening to the right, drawn the way a coach brackets the lines that repeat.
nonisolated struct MarkerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, 14)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + arm, y: rect.minY + 1))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 1, y: rect.minY + 3),
            control: CGPoint(x: rect.minX + arm * 0.45, y: rect.minY - 0.5))
        // The spine bows a hair outward, as a hand pulling a marker down a board does.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 2, y: rect.maxY - 3),
            control: CGPoint(x: rect.minX - 1.5, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + arm + 1, y: rect.maxY - 1),
            control: CGPoint(x: rect.minX + arm * 0.5, y: rect.maxY + 0.5))
        return path
    }
}

/// A tick, as a coach marks a line done: a short downstroke and a long flick up to the right.
nonisolated struct MarkerTick: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY),
            control: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.8))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.35))
        return path
    }
}

/// An underline that sags a little in the middle and lifts at the end.
nonisolated struct MarkerUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + 1))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY - 1.5),
            control1: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.midY + 2.5),
            control2: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.midY - 0.5))
        return path
    }
}
