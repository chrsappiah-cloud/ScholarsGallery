import Foundation
import Vapor

// MARK: - Model

struct AccessGrant: Codable, Content, Sendable {
    var deviceID: String
    var grantedAt: Date
    var expiresAt: Date?
    var reason: String?
}

// MARK: - Storage key

private struct AccessGrantStoreStorageKey: StorageKey {
    typealias Value = AccessGrantStore
}

extension Application {
    var accessGrantStore: AccessGrantStore? {
        get { storage[AccessGrantStoreStorageKey.self] }
        set { storage[AccessGrantStoreStorageKey.self] = newValue }
    }
}

// MARK: - Actor

actor AccessGrantStore {
    private var grants: [AccessGrant] = []
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        let decoder = JSONCoding.makeDecoder()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([AccessGrant].self, from: data) {
            grants = decoded
        }
    }

    /// Returns `true` if the device has a valid, non-expired grant.
    func isGranted(deviceID: String) -> Bool {
        guard let grant = grants.first(where: { $0.deviceID == deviceID }) else {
            return false
        }
        if let expiry = grant.expiresAt, expiry < Date() {
            return false
        }
        return true
    }

    func activeGrant(for deviceID: String) -> AccessGrant? {
        guard isGranted(deviceID: deviceID) else { return nil }
        return grants.first { $0.deviceID == deviceID }
    }

    @discardableResult
    func grant(deviceID: String, expiresAt: Date?, reason: String?) -> AccessGrant {
        // Replace existing grant for the same device if present.
        grants.removeAll { $0.deviceID == deviceID }
        let g = AccessGrant(deviceID: deviceID, grantedAt: Date(), expiresAt: expiresAt, reason: reason)
        grants.append(g)
        persist()
        return g
    }

    @discardableResult
    func revoke(deviceID: String) -> Bool {
        let before = grants.count
        grants.removeAll { $0.deviceID == deviceID }
        if grants.count < before { persist() }
        return grants.count < before
    }

    func listGrants() -> [AccessGrant] { grants }

    private func persist() {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONCoding.makeEncoder()
        guard let data = try? encoder.encode(grants) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
