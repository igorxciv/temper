// PROTOTYPE, throw away. Third round: one dark design system across the whole app. Each theme is
// a full set of color tokens, and every screen reads from them.
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

enum Theme: String, CaseIterable {
    case tide = "Tide"
    case plum = "Plum"
    case ink = "Ink"

    var colors: ThemeColors {
        switch self {
        case .tide:
            ThemeColors(
                background: Color(hex: 0x0F2A28),
                raised: Color(hex: 0x173835),
                separator: Color(hex: 0x25483F),
                text: Color(hex: 0xF1FBF8),
                secondary: Color(hex: 0xA6C7C0),
                accent: Color(hex: 0x8FE3D4),
                onAccent: Color(hex: 0x0F2A28)
            )
        case .plum:
            ThemeColors(
                background: Color(hex: 0x1C1424),
                raised: Color(hex: 0x2A1F35),
                separator: Color(hex: 0x3D3049),
                text: Color(hex: 0xF7F2FA),
                secondary: Color(hex: 0xBBAEC6),
                accent: Color(hex: 0xFFB38A),
                onAccent: Color(hex: 0x2A1508)
            )
        case .ink:
            ThemeColors(
                background: Color(hex: 0x11151D),
                raised: Color(hex: 0x1B212C),
                separator: Color(hex: 0x2E3643),
                text: Color(hex: 0xF3F1EA),
                secondary: Color(hex: 0xA9ADB5),
                accent: Color(hex: 0xE6B566),
                onAccent: Color(hex: 0x221702)
            )
        }
    }

    func phase(_ kind: PhaseKind) -> PhaseColors {
        let hex: (background: UInt32, ring: UInt32, track: UInt32, text: UInt32) =
            switch (self, kind) {
            case (.tide, .prepare): (0x2B2210, 0xF8DE9C, 0x4D3F22, 0xFBF7EF)
            case (.tide, .work): (0x33191A, 0xFFAD96, 0x573230, 0xFFF6F3)
            case (.tide, .rest): (0x0F2A28, 0x8FE3D4, 0x25483F, 0xF1FBF8)
            case (.tide, .cooldown): (0x182340, 0xBCCBFF, 0x303F66, 0xF4F6FF)
            case (.plum, .prepare): (0x30230F, 0xF6CF8D, 0x523E22, 0xFCF6EC)
            case (.plum, .work): (0x3A1522, 0xFF9FB2, 0x5E2A3B, 0xFFF3F5)
            case (.plum, .rest): (0x14282F, 0x8FDDE0, 0x274A52, 0xF0FAFB)
            case (.plum, .cooldown): (0x241F48, 0xBDB8FF, 0x3D3770, 0xF5F4FF)
            case (.ink, .prepare): (0x2A2411, 0xEFD98F, 0x4A4122, 0xFAF6E8)
            case (.ink, .work): (0x351C17, 0xFFAE8A, 0x59332A, 0xFFF5F0)
            case (.ink, .rest): (0x0F2A2B, 0x86DCCB, 0x254A48, 0xF0FBF8)
            case (.ink, .cooldown): (0x18223F, 0xAFC4FF, 0x2F3D66, 0xF3F6FF)
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
