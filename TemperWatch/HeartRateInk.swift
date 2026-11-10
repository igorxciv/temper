import SwiftUI

/// The heart-rate colors, which only the Watch shows.
enum HeartRateInk {
    /// The red of the heart beside a bpm.
    static let heart = Color(hex: 0xFF5A5F)

    /// A Zone's color, from cool in Zone 1 to hot in Zone 5, where it meets the heart's red.
    static func zone(_ zone: Int) -> Color {
        switch zone {
        case ...1: Color(hex: 0x9DB4D3)
        case 2: Color(hex: 0x7FD6A0)
        case 3: Color(hex: 0xF5D76E)
        case 4: Color(hex: 0xFFA35C)
        default: heart
        }
    }
}
