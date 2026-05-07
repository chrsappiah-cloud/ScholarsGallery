import SwiftUI

public struct GalleryBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            GalleryPalette.void
            RadialGradient(
                colors: [GalleryPalette.sapphireDark.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 80,
                endRadius: 480
            )
            RadialGradient(
                colors: [GalleryPalette.accentDeep.opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 60,
                endRadius: 400
            )
        }
    }
}
