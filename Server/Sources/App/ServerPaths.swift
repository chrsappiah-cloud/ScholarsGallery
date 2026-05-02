import Foundation
import Vapor

/// Resolves `Server/Public` and `Server/Data` relative to this source tree so the app works
/// when the process working directory is the repo root, Xcode’s build folder, or another cwd.
enum ServerPaths {
    private static let serverDirectory: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // Server
    }()

    /// Directory for `FileMiddleware` (must end with `/` for Vapor).
    static var publicDirectory: String {
        var path = serverDirectory.appendingPathComponent("Public", isDirectory: true).path
        if !path.hasSuffix("/") {
            path += "/"
        }
        return path
    }

    /// JSON “database” file for persisted generations (override with absolute `GENERATED_ARTWORKS_STORE_PATH`).
    static func generatedArtworksStoreURL() -> URL {
        let raw = Environment.get("GENERATED_ARTWORKS_STORE_PATH") ?? "Data/generated-artworks.json"
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw)
        }
        return serverDirectory.appendingPathComponent(raw)
    }

    static func adminPolicyFileURL() -> URL {
        let raw = Environment.get("ADMIN_POLICY_PATH") ?? "Data/admin-policy.json"
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw)
        }
        return serverDirectory.appendingPathComponent(raw)
    }
}
