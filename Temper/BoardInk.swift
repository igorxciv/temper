import SwiftUI
import TemperCore

/// The whiteboard every screen but the running screen is written on: a gloss white ground, black marker, and each
/// Phase in its own marker ink, the Phase colors of the running screen deepened to read on white.
///
/// Every ink clears 4.5:1 on the ground, so a Phase's name and time can be any size. The ghost, for an Off line,
/// clears 3:1, the floor for the large text it's used at.
struct BoardInk {
    /// The board itself.
    let ground: Color
    /// A slightly darker panel on the board, for a field set into it.
    let panel: Color
    /// A grouped list's row, lifted off the board.
    let row: Color
    /// Black marker: names, numbers, Start.
    let marker: Color
    /// Notes and captions.
    let secondary: Color
    /// A line that won't run, as an Off Prepare, half wiped off the board.
    let ghost: Color
    /// The hairline between lines.
    let rule: Color
    /// Text on black marker, as Start's label.
    let onMarker: Color

    private let increased: Bool

    init(contrast: ColorSchemeContrast) {
        increased = contrast == .increased
        if increased {
            ground = Color(hex: 0xFFFFFF)
            panel = Color(hex: 0xECEEF0)
            row = Color(hex: 0xF1F2F4)
            marker = Color(hex: 0x000000)
            secondary = Color(hex: 0x3F444B)
            ghost = Color(hex: 0x6A7077)
            rule = Color(hex: 0x8A9097)
            onMarker = Color(hex: 0xFFFFFF)
        } else {
            ground = Color(hex: 0xF6F7F5)
            panel = Color(hex: 0xE9EBE8)
            row = Color(hex: 0xFFFFFF)
            marker = Color(hex: 0x1E2126)
            secondary = Color(hex: 0x5E646C)
            ghost = Color(hex: 0x868C93)
            rule = Color(hex: 0xD5D8DB)
            onMarker = Color(hex: 0xF6F7F5)
        }
    }

    /// A Phase's marker ink.
    func ink(_ kind: Phase.Kind) -> Color {
        let hex: UInt32 =
            switch (kind, increased) {
            case (.prepare, false): 0x1F6FB2
            case (.work, false): 0xC63E22
            case (.rest, false): 0x0E7A6C
            case (.cooldown, false): 0x4A55B8
            case (.prepare, true): 0x15568C
            case (.work, true): 0xA3301A
            case (.rest, true): 0x0A5E53
            case (.cooldown, true): 0x353F96
            }
        return Color(hex: hex)
    }
}
