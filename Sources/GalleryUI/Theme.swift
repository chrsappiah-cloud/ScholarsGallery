import SwiftUI

public enum GalleryPalette {
    public static let void        = Color(red: 0.09, green: 0.10, blue: 0.14)
    public static let ink         = Color(red: 0.12, green: 0.13, blue: 0.18)
    public static let surface     = Color(red: 0.16, green: 0.17, blue: 0.23)
    public static let elevated    = Color(red: 0.20, green: 0.21, blue: 0.28)

    public static let accent      = Color(red: 0.11, green: 0.62, blue: 0.52)
    public static let accentDeep  = Color(red: 0.04, green: 0.42, blue: 0.38)
    public static let sapphire    = Color(red: 0.22, green: 0.42, blue: 0.82)
    public static let sapphireDark = Color(red: 0.08, green: 0.16, blue: 0.42)
    public static let rose        = Color(red: 0.93, green: 0.32, blue: 0.55)
    public static let roseSoft    = Color(red: 0.98, green: 0.78, blue: 0.88)
    public static let gold        = Color(red: 0.85, green: 0.72, blue: 0.42)

    public static let textPrimary   = Color.white
    public static let textSecondary = Color.white.opacity(0.82)
    public static let textTertiary  = Color.white.opacity(0.64)

    public static let glass       = Color.white.opacity(0.10)
    public static let glassStroke = Color.white.opacity(0.18)
    public static let glassBright = Color.white.opacity(0.24)
}

public enum GalleryGradients {
    public static let hero = LinearGradient(
        colors: [GalleryPalette.ink, GalleryPalette.sapphireDark.opacity(0.50), GalleryPalette.void],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let heroCard = LinearGradient(
        colors: [GalleryPalette.sapphireDark, GalleryPalette.sapphire.opacity(0.55), GalleryPalette.accentDeep.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let primaryButton = LinearGradient(
        colors: [GalleryPalette.accent, Color(red: 0.12, green: 0.52, blue: 0.68)],
        startPoint: .leading,
        endPoint: .trailing
    )

    public static let fadeToBlack = LinearGradient(
        colors: [.clear, GalleryPalette.void.opacity(0.45), GalleryPalette.ink.opacity(0.82)],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let fadeFromBlack = LinearGradient(
        colors: [GalleryPalette.ink.opacity(0.72), .clear],
        startPoint: .top,
        endPoint: .bottom
    )
}
