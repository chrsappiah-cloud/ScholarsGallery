import SwiftUI

public struct GallerySectionHeader: View {
    public let title: String
    public var subtitle: String?

    public init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(GalleryPalette.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(GalleryPalette.textTertiary)
                    .tracking(0.3)
            }
        }
    }
}
