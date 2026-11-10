import SwiftUI
import TemperCore

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double(hex >> 16 & 0xFF) / 255,
            green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The app's dark design system. There is no light variant.
struct InkColors {
    let background: Color
    let raised: Color
    let separator: Color
    let text: Color
    let secondary: Color
    let accent: Color
    let onAccent: Color

    init(contrast: ColorSchemeContrast) {
        if contrast == .increased {
            background = Color(hex: 0x0A0D13)
            raised = Color(hex: 0x161B24)
            separator = Color(hex: 0x6A7486)
            text = Color(hex: 0xFFFFFF)
            secondary = Color(hex: 0xD3D6DB)
            accent = Color(hex: 0xF3CA85)
            onAccent = Color(hex: 0x1A1101)
        } else {
            background = Color(hex: 0x11151D)
            raised = Color(hex: 0x1B212C)
            separator = Color(hex: 0x2E3643)
            text = Color(hex: 0xF3F1EA)
            secondary = Color(hex: 0xA9ADB5)
            accent = Color(hex: 0xE6B566)
            onAccent = Color(hex: 0x221702)
        }
    }
}

/// The colors of one Phase's screen.
///
/// Prepare and Cooldown nearly match under color blindness. That's accepted because they're never next to each
/// other, and the Phase name and Cue tell them apart.
struct PhaseColors {
    let background: Color
    let ring: Color
    let track: Color
    let text: Color

    init(kind: Phase.Kind, contrast: ColorSchemeContrast) {
        let hex: (background: UInt32, ring: UInt32, track: UInt32, text: UInt32) =
            switch (kind, contrast == .increased) {
            case (.prepare, false): (0x0F2433, 0x8FCBEF, 0x274A60, 0xEFF8FD)
            case (.work, false): (0x351C17, 0xFFAE8A, 0x59332A, 0xFFF5F0)
            case (.rest, false): (0x0F2A2B, 0x86DCCB, 0x254A48, 0xF0FBF8)
            case (.cooldown, false): (0x18223F, 0xAFC4FF, 0x2F3D66, 0xF3F6FF)
            case (.prepare, true): (0x081A27, 0xB5E0FA, 0x4A748C, 0xFFFFFF)
            case (.work, true): (0x2A120E, 0xFFC6AB, 0x986149, 0xFFFFFF)
            case (.rest, true): (0x071F20, 0xA8EFE1, 0x447E77, 0xFFFFFF)
            case (.cooldown, true): (0x0F1830, 0xC9D7FF, 0x586DAC, 0xFFFFFF)
            }
        background = Color(hex: hex.background)
        ring = Color(hex: hex.ring)
        track = Color(hex: hex.track)
        text = Color(hex: hex.text)
    }
}

/// The Watch's Stop: red on a dark red fill, and solid red with dark text once it asks for a second tap.
struct StopColors {
    let red: Color
    let darkRed: Color
    let onRed: Color

    init(contrast: ColorSchemeContrast) {
        if contrast == .increased {
            red = Color(hex: 0xFF8085)
            darkRed = Color(hex: 0x4D161A)
            onRed = Color(hex: 0x000000)
        } else {
            red = Color(hex: 0xFF5A5F)
            darkRed = Color(hex: 0x40161A)
            onRed = Color(hex: 0x1A0506)
        }
    }
}
