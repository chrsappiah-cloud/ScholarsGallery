import Foundation
import os

final class ICloudKeyValueSync: @unchecked Sendable {
    static let shared = ICloudKeyValueSync()

    static let didReceiveExternalChangeNotification = Notification.Name("ICloudKeyValueSync.didReceiveExternalChange")
    static let changedKeysUserInfoKey = "changedKeys"
    static let changeReasonUserInfoKey = "changeReason"

    private let store = NSUbiquitousKeyValueStore.default
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScholarsGallery",
                                 category: "ICloudKV")

    private enum Keys {
        static let adminToken = "pref.adminToken"
        static let lastUsedPrompt = "pref.lastUsedPrompt"
        static let preferredArtistID = "pref.preferredArtistID"
        static let lastBackupDate = "pref.lastBackupDate"
        static let onboardingComplete = "pref.onboardingComplete"
        static let favoriteCountSnapshot = "pref.favoriteCount"
        static let collectionCountSnapshot = "pref.collectionCount"
    }

    private init() {
        store.synchronize()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    @objc private func kvStoreDidChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reason = info[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        else { return }

        let changedKeys = info[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

        switch reason {
        case NSUbiquitousKeyValueStoreServerChange:
            logger.info("iCloud KV: server change received")
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            logger.info("iCloud KV: initial sync completed")
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            logger.warning("iCloud KV: quota exceeded")
        case NSUbiquitousKeyValueStoreAccountChange:
            logger.info("iCloud KV: account changed")
        default:
            break
        }

        NotificationCenter.default.post(
            name: Self.didReceiveExternalChangeNotification,
            object: self,
            userInfo: [
                Self.changedKeysUserInfoKey: changedKeys,
                Self.changeReasonUserInfoKey: reason,
            ]
        )
    }

    func synchronize() {
        store.synchronize()
    }

    // MARK: - Preferences

    var adminToken: String? {
        get { store.string(forKey: Keys.adminToken) }
        set {
            store.set(newValue, forKey: Keys.adminToken)
            store.synchronize()
        }
    }

    var lastUsedPrompt: String? {
        get { store.string(forKey: Keys.lastUsedPrompt) }
        set {
            store.set(newValue, forKey: Keys.lastUsedPrompt)
            store.synchronize()
        }
    }

    var preferredArtistID: String? {
        get { store.string(forKey: Keys.preferredArtistID) }
        set {
            store.set(newValue, forKey: Keys.preferredArtistID)
            store.synchronize()
        }
    }

    var onboardingComplete: Bool {
        get { store.bool(forKey: Keys.onboardingComplete) }
        set {
            store.set(newValue, forKey: Keys.onboardingComplete)
            store.synchronize()
        }
    }

    // MARK: - Snapshots for cross-device awareness

    func updateCountSnapshots(favorites: Int, collection: Int) {
        store.set(Int64(favorites), forKey: Keys.favoriteCountSnapshot)
        store.set(Int64(collection), forKey: Keys.collectionCountSnapshot)
        store.set(Date().timeIntervalSince1970, forKey: Keys.lastBackupDate)
        store.synchronize()
    }

    var favoriteCountSnapshot: Int { Int(store.longLong(forKey: Keys.favoriteCountSnapshot)) }
    var collectionCountSnapshot: Int { Int(store.longLong(forKey: Keys.collectionCountSnapshot)) }

    var lastBackupDate: Date? {
        let ts = store.double(forKey: Keys.lastBackupDate)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
}
