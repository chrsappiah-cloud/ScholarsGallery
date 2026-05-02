import Foundation
import CloudKit
import os

struct BackupSnapshot {
    let collectionRaw: String
    let favoritesRaw: String
    let modifiedAt: Date
}

enum CloudBackupError: LocalizedError {
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return NSLocalizedString("icloud.unavailable", bundle: .main, comment: "")
        }
    }
}

actor CloudBackupService {
    static let shared = CloudBackupService()

    private let container = CKContainer.default()
    private let database: CKDatabase
    private let recordType = "UserBackup"
    private let recordName = "primary"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScholarsGallery",
                                 category: "CloudBackup")

    private init() {
        database = CKContainer.default().privateCloudDatabase
    }

    func upload(snapshot: BackupSnapshot) async throws {
        guard await isAvailable() else {
            throw CloudBackupError.iCloudUnavailable
        }

        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["collectionRaw"] = snapshot.collectionRaw as CKRecordValue
        record["favoritesRaw"] = snapshot.favoritesRaw as CKRecordValue
        record["modifiedAt"] = snapshot.modifiedAt as CKRecordValue

        _ = try await database.save(record)
        logger.info("Legacy backup uploaded successfully")
    }

    func fetchLatestSnapshot() async throws -> BackupSnapshot? {
        guard await isAvailable() else { return nil }

        let recordID = CKRecord.ID(recordName: recordName)
        do {
            let record = try await database.record(for: recordID)
            guard
                let collectionRaw = record["collectionRaw"] as? String,
                let favoritesRaw = record["favoritesRaw"] as? String,
                let modifiedAt = record["modifiedAt"] as? Date
            else {
                return nil
            }

            return BackupSnapshot(
                collectionRaw: collectionRaw,
                favoritesRaw: favoritesRaw,
                modifiedAt: modifiedAt
            )
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func isAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            logger.warning("CloudKit account check failed: \(error.localizedDescription)")
            return false
        }
    }
}
