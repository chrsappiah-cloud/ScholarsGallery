// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ScholarsGallery",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"]),
        .library(name: "GalleryAPI", targets: ["GalleryAPI"]),
        .library(name: "ScholarKit", targets: ["ScholarKit"]),
        .library(name: "CommerceKit", targets: ["CommerceKit"]),
        .library(name: "ExhibitionEngine", targets: ["ExhibitionEngine"]),
        .library(name: "OpenAIConnector", targets: ["OpenAIConnector"]),
        .executable(name: "ScholarsGalleryServer", targets: ["ScholarsGalleryServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.103.0")
    ],
    targets: [
        .target(
            name: "CoreModels"
        ),
        .target(
            name: "GalleryAPI",
            dependencies: ["CoreModels"]
        ),
        .target(
            name: "ScholarKit",
            dependencies: ["CoreModels"]
        ),
        .target(
            name: "CommerceKit",
            dependencies: ["CoreModels"]
        ),
        .target(
            name: "ExhibitionEngine",
            dependencies: ["CoreModels"]
        ),
        .target(
            name: "OpenAIConnector"
        ),
        .executableTarget(
            name: "ScholarsGalleryServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "CoreModels",
                "ScholarKit",
                "CommerceKit",
                "OpenAIConnector"
            ],
            path: "Server/Sources/App"
        ),
        .testTarget(
            name: "ScholarsGalleryServerTests",
            dependencies: [
                "ScholarsGalleryServer",
                .product(name: "XCTVapor", package: "vapor")
            ],
            path: "Server/Tests/ScholarsGalleryServerTests"
        )
    ]
)
