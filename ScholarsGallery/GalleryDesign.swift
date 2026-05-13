import SwiftUI
@_exported import GalleryUI

// MARK: - Legacy Aliases (bridge to GalleryUI module)

typealias GalleryTheme = GalleryPalette

extension GalleryPalette {
    static let background = void
    static let backgroundMist = surface
    static let card = elevated
    static let cardStroke = glassStroke

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

    static let primaryButtonGradient = GalleryGradients.primaryButton

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

struct SparkleJewelOverlay: View {
    var body: some View {
        ZStack {
            Image(systemName: "diamond.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(GalleryTheme.glassBright.opacity(0.55))
                .offset(x: -38, y: -30)

            Image(systemName: "sparkle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GalleryTheme.accent.opacity(0.50))
                .offset(x: 44, y: -20)

            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(GalleryTheme.sapphire.opacity(0.45))
                .offset(x: 50, y: 22)

            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(GalleryTheme.roseSoft.opacity(0.35))
                .offset(x: -50, y: 34)

            Image(systemName: "waveform.path")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(GalleryTheme.sapphire.opacity(0.30))
                .offset(x: -20, y: -45)

            Image(systemName: "diamond")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(GalleryTheme.glassBright.opacity(0.60))
                .offset(x: 30, y: -42)
        }
        .allowsHitTesting(false)
    }
}

struct GalleryProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background {
                if isEnabled {
                    GalleryTheme.primaryButtonGradient
                } else {
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.30),
                            Color.gray.opacity(0.20)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                GalleryTheme.glassBright.opacity(isEnabled ? 0.30 : 0),
                                GalleryTheme.accent.opacity(isEnabled ? 0.20 : 0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: GalleryTheme.accent.opacity(isEnabled ? 0.30 : 0), radius: 12, y: 5)
            .shadow(color: GalleryTheme.sapphire.opacity(isEnabled ? 0.15 : 0), radius: 20, y: 10)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
