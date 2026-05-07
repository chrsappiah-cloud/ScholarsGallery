import SwiftUI
@_exported import GalleryUI

// MARK: - Legacy Aliases (bridge to GalleryUI module)

typealias GalleryTheme = GalleryPalette

extension GalleryPalette {
    static let background    = void
    static let backgroundMist = surface
    static let card          = elevated
    static let cardStroke    = glassStroke

    static let heroGradient = LinearGradient(
        colors: [void, sapphireDark.opacity(0.55), void],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroCardGradient = LinearGradient(
        colors: [sapphireDark, sapphire.opacity(0.55), accentDeep.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerGradient = LinearGradient(
        colors: [void, sapphireDark.opacity(0.65), sapphire.opacity(0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let studioBannerGradient = LinearGradient(
        colors: [accent.opacity(0.25), sapphire.opacity(0.18), rose.opacity(0.12)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let primaryButtonGradient = LinearGradient(
        colors: [accent, Color(red: 0.12, green: 0.52, blue: 0.68)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let roomCarouselGradient = LinearGradient(
        colors: [void.opacity(0.92), sapphireDark.opacity(0.88)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let fadeToBlack = LinearGradient(
        colors: [.clear, void.opacity(0.6), void.opacity(0.95)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let fadeFromBlack = LinearGradient(
        colors: [void.opacity(0.85), .clear],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - App Background (delegates to GalleryUI.GalleryBackground)

typealias GalleryAppBackground = GalleryBackground
