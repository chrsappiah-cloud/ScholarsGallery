import SwiftUI

public struct ArtworkGridRow: View {
    public let artworkURLs: [(id: String, title: String, url: URL)]

    public init(artworkURLs: [(id: String, title: String, url: URL)]) {
        self.artworkURLs = artworkURLs
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(artworkURLs, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        AsyncImage(url: item.url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFill()
                                    .frame(width: 140, height: 180)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(GalleryPalette.surface)
                                    .frame(width: 140, height: 180)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundStyle(GalleryPalette.textTertiary)
                                    )
                            default:
                                CinematicImagePlaceholder(height: 180, cornerRadius: 12)
                                    .frame(width: 140)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Text(item.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(GalleryPalette.textSecondary)
                            .lineLimit(1)
                            .frame(width: 140, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
