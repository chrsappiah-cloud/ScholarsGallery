import SwiftUI

public struct CinematicImagePlaceholder: View {
    public var height: CGFloat
    public var cornerRadius: CGFloat

    public init(height: CGFloat = 220, cornerRadius: CGFloat = 16) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(GalleryPalette.surface)
            .frame(maxWidth: .infinity, minHeight: height)
            .overlay(
                ProgressView()
                    .tint(GalleryPalette.textTertiary)
            )
    }
}
