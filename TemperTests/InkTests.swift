import SwiftUI
import TemperCore
import Testing

@testable import Temper

/// The Increase Contrast colors, measured as WCAG contrast ratios.
struct InkTests {
    private func luminance(_ color: Color) -> Double {
        let resolved = color.resolve(in: EnvironmentValues())
        return 0.2126 * Double(resolved.linearRed) + 0.7152 * Double(resolved.linearGreen)
            + 0.0722 * Double(resolved.linearBlue)
    }

    private func contrast(_ first: Color, _ second: Color) -> Double {
        let (a, b) = (luminance(first), luminance(second))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// The weakest Phase measures 17.13:1 for text on background (Rest), and 11.68:1 for ring on background,
    /// 3.36:1 for ring on track and 3.476:1 for track on background (all Work). Each floor sits just under that.
    @Test(arguments: [Phase.Kind.prepare, .work, .rest, .cooldown])
    func `Every Phase keeps its Increase Contrast ratios`(kind: Phase.Kind) {
        let colors = PhaseColors(kind: kind, contrast: .increased)

        #expect(contrast(colors.text, colors.background) >= 17.1)
        #expect(contrast(colors.ring, colors.background) >= 11.6)
        #expect(contrast(colors.ring, colors.track) >= 3.35)
        #expect(contrast(colors.track, colors.background) >= 3.45)
    }
}
