import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255
        )
    }
}

enum PokerTheme {
    /// Near-black app chrome
    static let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.1)
    /// Dark felt on the oval table

    static let tableRail = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let tableRailHighlight = Color.white.opacity(0.08)

    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.45)

    static let fold = Color(red: 0.55, green: 0.18, blue: 0.18)
    static let call = Color(red: 0.14, green: 0.42, blue: 0.28)
    static let raise = Color(red: 0.5, green: 0.38, blue: 0.12)

    /// Capsule fills / text (bottom action bar)
    static let foldFill  = Color(hex: 0x1D1D1E)
    static let foldText  = Color(hex: 0xC63F3F)
    
    static let raiseFill = Color(hex: 0x1D1D1E)
    static let raiseText = Color(hex: 0xE9E3D6)
    
    static let callFill  = Color(hex: 0x1D1D1E)
    static let callText  = Color(hex: 0xC6953F)

    /// Dark card faces for full dark theme
    static let cardFace = Color(red: 0.14, green: 0.14, blue: 0.15)
    static let cardBack = Color(red: 0.1, green: 0.12, blue: 0.16)
    static let cardStroke = Color.white.opacity(0.12)
    /// Winning-hand highlights at end of showdown
    static let winningCardStroke = Color(hex: 0xE8C84A)
    /// Softer outline for supporting board cards in the made hand
    static let winningCardStrokeSoft = Color(hex: 0xE8C84A).opacity(0.45)
    static let cardText = Color.white.opacity(0.9)
    static let cardTextRed = Color(red: 0.95, green: 0.4, blue: 0.4)

    static let accent = Color.white.opacity(0.06)
    static let dealerBadge = Color(red: 0.55, green: 0.52, blue: 0.22)
    static let turnGlow = Color(hex: 0x0070FC)
    
    static let tableFelt      = Color(hex: 0x12284A) // dark navy
    static let tableFeltLight = Color(hex: 0x1D3C69) // slightly lighter navy for the center glow

    // MARK: - Brand

    /// Vibrant azure from the Pokimate wordmark ("mate")
    static let brandBlue = Color(hex: 0x2F7BFF)
    static let brandBlueDeep = Color(hex: 0x1A5AE0)
    static let brandBlueGlow = Color(hex: 0x5CA0FF)
}
