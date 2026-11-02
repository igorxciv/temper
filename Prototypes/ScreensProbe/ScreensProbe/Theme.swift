// PROTOTYPE, throw away. The chosen dark design system: Ink. Every screen reads these color tokens.
// Tide and Plum are in this branch's history at b8542a3.
import SwiftUI

struct ThemeColors {
    let background: Color
    let raised: Color
    let separator: Color
    let text: Color
    let secondary: Color
    let accent: Color
    let onAccent: Color
}

struct PhaseColors {
    let background: Color
    let ring: Color
    let track: Color
    let text: Color
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

enum Theme {
    case ink
    /// The proposed set for Increase Contrast: darker grounds, brighter marks, and tracks that
    /// clear 3:1 against both the ground and the ring.
    case inkIncreased

    var colors: ThemeColors {
        if self == .inkIncreased {
            return ThemeColors(
                background: Color(hex: 0x0A0D13),
                raised: Color(hex: 0x161B24),
                separator: Color(hex: 0x6A7486),
                text: Color(hex: 0xFFFFFF),
                secondary: Color(hex: 0xD3D6DB),
                accent: Color(hex: 0xF3CA85),
                onAccent: Color(hex: 0x1A1101)
            )
        }
        return ThemeColors(
            background: Color(hex: 0x11151D),
            raised: Color(hex: 0x1B212C),
            separator: Color(hex: 0x2E3643),
            text: Color(hex: 0xF3F1EA),
            secondary: Color(hex: 0xA9ADB5),
            accent: Color(hex: 0xE6B566),
            onAccent: Color(hex: 0x221702)
        )
    }

    func phase(_ kind: PhaseKind) -> PhaseColors {
        let hex: (background: UInt32, ring: UInt32, track: UInt32, text: UInt32) =
            switch (self, kind) {
            case (.ink, .prepare): (0x0F2433, 0x8FCBEF, 0x274A60, 0xEFF8FD)
            case (.ink, .work): (0x351C17, 0xFFAE8A, 0x59332A, 0xFFF5F0)
            case (.ink, .rest): (0x0F2A2B, 0x86DCCB, 0x254A48, 0xF0FBF8)
            case (.ink, .cooldown): (0x18223F, 0xAFC4FF, 0x2F3D66, 0xF3F6FF)
            case (.inkIncreased, .prepare): (0x081A27, 0xB5E0FA, 0x4A748C, 0xFFFFFF)
            case (.inkIncreased, .work): (0x2A120E, 0xFFC6AB, 0x986149, 0xFFFFFF)
            case (.inkIncreased, .rest): (0x071F20, 0xA8EFE1, 0x447E77, 0xFFFFFF)
            case (.inkIncreased, .cooldown): (0x0F1830, 0xC9D7FF, 0x586DAC, 0xFFFFFF)
            }
        return PhaseColors(
            background: Color(hex: hex.background),
            ring: Color(hex: hex.ring),
            track: Color(hex: hex.track),
            text: Color(hex: hex.text)
        )
    }
}

extension Field {
    /// The Phase a value configures. Rounds has none.
    var phaseKind: PhaseKind? {
        switch self {
        case .prepare: .prepare
        case .rounds: nil
        case .work: .work
        case .rest: .rest
        case .cooldown: .cooldown
        }
    }
}
