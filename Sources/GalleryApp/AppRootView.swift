import SwiftUI
import GalleryUI

public struct AppRootView: View {
    @StateObject private var router = AppRouter()

    public init() {}

    public var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                GalleryBackground().ignoresSafeArea()
                Text("ScholarsGallery")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(GalleryPalette.textPrimary)
            }
        }
        .environmentObject(router)
        .preferredColorScheme(.dark)
    }
}
