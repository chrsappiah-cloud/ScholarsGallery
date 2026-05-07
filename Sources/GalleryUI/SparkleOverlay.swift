import SwiftUI

public struct SparkleJewelOverlay: View {
    public init() {}

    public var body: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.25))
                .offset(x: -36, y: -28)
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(GalleryPalette.roseSoft.opacity(0.35))
                .offset(x: 48, y: 18)
            Image(systemName: "diamond.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(GalleryPalette.accent.opacity(0.40))
                .offset(x: 32, y: -42)
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.white.opacity(0.15))
                .offset(x: -52, y: 36)
        }
        .allowsHitTesting(false)
    }
}
