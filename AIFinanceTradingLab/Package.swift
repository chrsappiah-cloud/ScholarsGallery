// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AIFinanceTradingLab",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AIFinanceCore", targets: ["AIFinanceCore"]),
        .library(name: "AIFinanceUI", targets: ["AIFinanceUI"]),
        .executable(name: "AIFinanceTradingLab", targets: ["AIFinanceTradingLab"])
    ],
    targets: [
        .target(
            name: "AIFinanceCore"
        ),
        .target(
            name: "AIFinanceUI",
            dependencies: ["AIFinanceCore"]
        ),
        .executableTarget(
            name: "AIFinanceTradingLab",
            dependencies: ["AIFinanceCore", "AIFinanceUI"]
        ),
        .testTarget(
            name: "AIFinanceCoreTests",
            dependencies: ["AIFinanceCore"]
        )
    ]
)
