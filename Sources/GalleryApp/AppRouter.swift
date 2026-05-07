import SwiftUI

public enum GalleryRoute: Hashable {
    case home
    case artworkDetail(id: String)
    case artistProfile(id: String)
    case savedWorks
    case studio
    case scholarship
    case collection
}

@MainActor
public final class AppRouter: ObservableObject {
    @Published public var path = NavigationPath()

    public init() {}

    public func push(_ route: GalleryRoute) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path = NavigationPath()
    }
}
