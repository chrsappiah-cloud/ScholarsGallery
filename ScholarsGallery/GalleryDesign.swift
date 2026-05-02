import SwiftUI

/// Visual language: emerald + sapphire + rose, with subtle sparkle / jewel motifs (matches app icon / marketing direction).
enum GalleryTheme {
    static let accent = Color(red: 0.11, green: 0.62, blue: 0.52)
    static let accentDeep = Color(red: 0.04, green: 0.42, blue: 0.38)
    static let sapphire = Color(red: 0.22, green: 0.42, blue: 0.82)
    static let sapphireDark = Color(red: 0.08, green: 0.16, blue: 0.42)
    static let rose = Color(red: 0.93, green: 0.32, blue: 0.55)
    static let roseSoft = Color(red: 0.98, green: 0.78, blue: 0.88)

    static let background = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let backgroundMist = Color(red: 0.88, green: 0.93, blue: 0.97)

    static let surface = Color(red: 0.10, green: 0.14, blue: 0.22)
    static let ink = Color(red: 0.06, green: 0.08, blue: 0.12)
    static let card = Color.white.opacity(0.94)
    static let cardStroke = Color.white.opacity(0.65)

    static let heroCardGradient = LinearGradient(
        colors: [sapphireDark, sapphire.opacity(0.88), accentDeep.opacity(0.92)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerGradient = LinearGradient(
        colors: [ink, sapphireDark.opacity(0.95), sapphire.opacity(0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let studioBannerGradient = LinearGradient(
        colors: [accent.opacity(0.42), sapphire.opacity(0.32), rose.opacity(0.28)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let primaryButtonGradient = LinearGradient(
        colors: [accent, Color(red: 0.12, green: 0.52, blue: 0.68)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let roomCarouselGradient = LinearGradient(
        colors: [ink.opacity(0.92), sapphireDark.opacity(0.88)],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct GalleryAppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                GalleryTheme.background,
                GalleryTheme.backgroundMist.opacity(0.85),
                GalleryTheme.roseSoft.opacity(0.18),
                GalleryTheme.background,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Decorative sparkles / jewel hints for hero surfaces (non-interactive).
struct SparkleJewelOverlay: View {
    var body: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
                .offset(x: -36, y: -28)
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(GalleryTheme.roseSoft.opacity(0.55))
                .offset(x: 48, y: 18)
            Image(systemName: "diamond.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(GalleryTheme.accent.opacity(0.55))
                .offset(x: 32, y: -42)
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.white.opacity(0.22))
                .offset(x: -52, y: 36)
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
                        colors: [Color.gray.opacity(0.45), Color.gray.opacity(0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: GalleryTheme.accent.opacity(isEnabled ? 0.35 : 0), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func galleryCardShadow() -> some View {
        shadow(color: GalleryTheme.sapphire.opacity(0.14), radius: 14, x: 0, y: 8)
    }
}
