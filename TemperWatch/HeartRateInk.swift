import SwiftUI

/// The heart-rate colors, which only the Watch shows.
enum HeartRateInk {
    /// The red of the heart beside a bpm.
    static let heart = color(0xFF5A5F)

    /// A Zone's color, from cool in Zone 1 to hot in Zone 5.
    static func zone(_ zone: Int) -> Color {
        switch zone {
        case ...1: color(0x9DB4D3)
        case 2: color(0x7FD6A0)
        case 3: color(0xF5D76E)
        case 4: color(0xFFA35C)
        default: color(0xFF5A5F)
        }
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(
            red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
