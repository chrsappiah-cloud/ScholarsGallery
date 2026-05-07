import SwiftUI

public struct GlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var strokeOpacity: Double

    public init(cornerRadius: CGFloat = 20, strokeOpacity: Double = 0.10) {
        self.cornerRadius = cornerRadius
        self.strokeOpacity = strokeOpacity
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.45))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(GalleryPalette.glass)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    func galleryCardShadow() -> some View {
        shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
    }
}
