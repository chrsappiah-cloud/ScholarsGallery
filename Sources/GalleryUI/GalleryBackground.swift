import SwiftUI

public struct GalleryBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [GalleryPalette.ink, GalleryPalette.void, GalleryPalette.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [Color.white.opacity(0.03), .clear, GalleryPalette.accent.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [GalleryPalette.sapphire.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 80,
                endRadius: 520
            )
            RadialGradient(
                colors: [GalleryPalette.accent.opacity(0.16), .clear],
                center: .bottomLeading,
                startRadius: 60,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 300
            )
        }
    }
}
