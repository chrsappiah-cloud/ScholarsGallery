import SwiftUI

public enum GalleryPalette {
    public static let void        = Color(red: 0.04, green: 0.04, blue: 0.06)
    public static let ink         = Color(red: 0.06, green: 0.06, blue: 0.10)
    public static let surface     = Color(red: 0.09, green: 0.09, blue: 0.14)
    public static let elevated    = Color(red: 0.12, green: 0.12, blue: 0.18)

    public static let accent      = Color(red: 0.11, green: 0.62, blue: 0.52)
    public static let accentDeep  = Color(red: 0.04, green: 0.42, blue: 0.38)
    public static let sapphire    = Color(red: 0.22, green: 0.42, blue: 0.82)
    public static let sapphireDark = Color(red: 0.08, green: 0.16, blue: 0.42)
    public static let rose        = Color(red: 0.93, green: 0.32, blue: 0.55)
    public static let roseSoft    = Color(red: 0.98, green: 0.78, blue: 0.88)
    public static let gold        = Color(red: 0.85, green: 0.72, blue: 0.42)

    public static let textPrimary   = Color.white
    public static let textSecondary = Color.white.opacity(0.62)
    public static let textTertiary  = Color.white.opacity(0.38)

    public static let glass       = Color.white.opacity(0.06)
    public static let glassStroke = Color.white.opacity(0.10)
    public static let glassBright = Color.white.opacity(0.12)
}

public enum GalleryGradients {
    public static let hero = LinearGradient(
        colors: [GalleryPalette.void, GalleryPalette.sapphireDark.opacity(0.55), GalleryPalette.void],
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
        colors: [.clear, GalleryPalette.void.opacity(0.6), GalleryPalette.void.opacity(0.95)],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let fadeFromBlack = LinearGradient(
        colors: [GalleryPalette.void.opacity(0.85), .clear],
        startPoint: .top,
        endPoint: .bottom
    )
}
