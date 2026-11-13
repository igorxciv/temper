import SwiftUI
import TemperCore

/// The running screen's ring, run full: a closed ring in the color of the last Phase that ran, drawn round once as the
/// complete screen appears, with what the Workout came to inside it.
///
/// The success haptic plays as the ring closes. With Reduce Motion the ring is simply there, closed. With no last Phase
/// to carry on from, it's in the secondary color, since amber means act here.
struct CompleteRing<Content: View>: View {
    /// The last Phase that ran, or `nil` if it isn't known.
    let kind: Phase.Kind?
    let lineWidth: CGFloat
    @ViewBuilder let content: Content

    @State private var isDrawn = false
    @State private var isClosed = false

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ink = InkColors(contrast: contrast)
        let phase = kind.map { PhaseColors(kind: $0, contrast: contrast) }

        ZStack {
            Circle().stroke(phase?.track ?? ink.separator, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: isDrawn ? 1 : 0)
                .stroke(phase?.ring ?? ink.secondary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            content
        }
        // A stroke straddles its path, so half the line's width keeps the ring inside its frame.
        .padding(lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            if reduceMotion {
                isDrawn = true
                isClosed = true
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    isDrawn = true
                } completion: {
                    isClosed = true
                }
            }
        }
        .sensoryFeedback(.success, trigger: isClosed) { _, closed in closed }
    }
}

/// "Workout complete", over both complete screens.
struct CompleteTitle: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text("Workout complete")
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(InkColors(contrast: contrast).text)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            // The ring and total keep their room on the iPhone SE at the largest sizes.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityAddTraits(.isHeader)
    }
}

/// What a Workout's Rounds ran, as "8 × 0:40 Work · 0:20 Rest", each Phase in its color. Nothing for a Workout
/// without a set number of Rounds, whose total says it all.
struct CompleteRecap: View {
    let board: PlanBoard

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        ForEach(board.items.indices, id: \.self) { index in
            if case .rounds(.times(let times), let lines, _) = board.items[index] {
                let ran = lines.filter { $0.length != .off }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(times) ×").foregroundStyle(colors.secondary)
                        ForEach(ran.indices, id: \.self) { lineIndex in
                            if lineIndex > 0 {
                                Text("·").foregroundStyle(colors.secondary)
                            }
                            lineText(ran[lineIndex])
                        }
                    }
                    VStack(spacing: 2) {
                        Text("\(times) ×").foregroundStyle(colors.secondary)
                        ForEach(ran.indices, id: \.self) { lineIndex in
                            lineText(ran[lineIndex])
                        }
                    }
                }
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    (["\(times) Rounds"] + ran.map(\.spokenText)).joined(separator: ", "))
            }
        }
    }

    private func lineText(_ line: PlanBoard.Line) -> some View {
        Text("\(line.time) \(line.kind.name)")
            .foregroundStyle(PhaseColors(kind: line.kind, contrast: contrast).ring)
    }
}
