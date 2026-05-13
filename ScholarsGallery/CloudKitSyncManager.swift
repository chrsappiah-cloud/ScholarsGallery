import Foundation
import CloudKit
import SwiftData
import os

actor CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScholarsGallery",
                                 category: "CloudKitSync")

    private let collectionRecordType = "CollectionRecord"
    private let favoriteRecordType = "FavoriteArtwork"
    private let generatedArtworkRecordType = "GeneratedArtwork"
    private let backupRecordType = "UserBackup"
    private let backupRecordName = "primary"

    private init() {}

    private var isCloudKitConfigured: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private func makeContainer() -> CKContainer { CKContainer.default() }
    private func makeDatabase() -> CKDatabase { CKContainer.default().privateCloudDatabase }

    // MARK: - Account Check

    func isAvailable() async -> Bool {
        guard isCloudKitConfigured else { return false }
        do {
            let status = try await makeContainer().accountStatus()
            return status == .available
        } catch {
            logger.warning("CloudKit account check failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Collection Records Sync

    func syncCollectionRecords(_ records: [PersistedCollectionRecord]) async {
        guard await isAvailable() else { return }

        for record in records where !record.syncedToCloud {
            let ckRecordID = CKRecord.ID(recordName: "collection-\(record.artworkID)")
            let ckRecord = CKRecord(recordType: collectionRecordType, recordID: ckRecordID)
            ckRecord["artworkID"] = record.artworkID as CKRecordValue
            ckRecord["acquiredAt"] = record.acquiredAt as CKRecordValue
            ckRecord["certificateID"] = record.certificateID as CKRecordValue

            do {
                _ = try await makeDatabase().save(ckRecord)
                logger.info("Synced collection record: \(record.artworkID)")
            } catch let error as CKError where error.code == .serverRecordChanged {
                logger.info("Collection record already exists in cloud: \(record.artworkID)")
            } catch {
                logger.error("Failed to sync collection record: \(error.localizedDescription)")
            }
        }
    }

    func fetchCloudCollectionRecords() async -> [(artworkID: String, acquiredAt: Date, certificateID: String)] {
        guard await isAvailable() else { return [] }

        let query = CKQuery(recordType: collectionRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "acquiredAt", ascending: false)]

        do {
            let (results, _) = try await makeDatabase().records(matching: query, resultsLimit: 200)
            return results.compactMap { _, result in
                guard let record = try? result.get(),
                      let artworkID = record["artworkID"] as? String,
                      let acquiredAt = record["acquiredAt"] as? Date,
                      let certificateID = record["certificateID"] as? String
                else { return nil }
                return (artworkID, acquiredAt, certificateID)
            }
        } catch {
            logger.error("Failed to fetch cloud collection records: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Favorites Sync

    func syncFavorites(_ artworkIDs: Set<String>) async {
        guard await isAvailable() else { return }

        let ckRecordID = CKRecord.ID(recordName: "favorites-manifest")
        let ckRecord = CKRecord(recordType: favoriteRecordType, recordID: ckRecordID)
        ckRecord["artworkIDs"] = artworkIDs.sorted().joined(separator: ",") as CKRecordValue
        ckRecord["modifiedAt"] = Date() as CKRecordValue

        do {
            _ = try await makeDatabase().save(ckRecord)
            logger.info("Synced \(artworkIDs.count) favorites to cloud")
        } catch {
            logger.error("Failed to sync favorites: \(error.localizedDescription)")
        }
    }

    func fetchCloudFavorites() async -> Set<String> {
        guard await isAvailable() else { return [] }

        let recordID = CKRecord.ID(recordName: "favorites-manifest")
        do {
            let record = try await makeDatabase().record(for: recordID)
            guard let raw = record["artworkIDs"] as? String else { return [] }
            return Set(raw.split(separator: ",").map(String.init))
        } catch {
            logger.info("No cloud favorites found: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Generated Artworks Sync

    func syncGeneratedArtwork(id: String, status: String, imageURL: String,
                               prompt: String, provider: String, createdAt: Date) async {
        guard await isAvailable() else { return }

        let ckRecordID = CKRecord.ID(recordName: "gen-\(id)")
        let ckRecord = CKRecord(recordType: generatedArtworkRecordType, recordID: ckRecordID)
        ckRecord["generationID"] = id as CKRecordValue
        ckRecord["status"] = status as CKRecordValue
        ckRecord["imageURL"] = imageURL as CKRecordValue
        ckRecord["prompt"] = prompt as CKRecordValue
        ckRecord["provider"] = provider as CKRecordValue
        ckRecord["createdAt"] = createdAt as CKRecordValue

        do {
            _ = try await makeDatabase().save(ckRecord)
            logger.info("Synced generated artwork: \(id)")
        } catch {
            logger.error("Failed to sync generated artwork: \(error.localizedDescription)")
        }
    }

    func fetchCloudGeneratedArtworks() async -> [(id: String, status: String, imageURL: String,
                                                    prompt: String, provider: String, createdAt: Date)] {
        guard await isAvailable() else { return [] }

        let query = CKQuery(recordType: generatedArtworkRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await makeDatabase().records(matching: query, resultsLimit: 100)
            return results.compactMap { _, result in
                guard let record = try? result.get(),
                      let id = record["generationID"] as? String,
                      let status = record["status"] as? String,
                      let imageURL = record["imageURL"] as? String,
                      let prompt = record["prompt"] as? String,
                      let provider = record["provider"] as? String,
                      let createdAt = record["createdAt"] as? Date
                else { return nil }
                return (id, status, imageURL, prompt, provider, createdAt)
            }
        } catch {
            logger.error("Failed to fetch cloud generated artworks: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Legacy Blob Backup (kept for migration)

    func uploadLegacyBackup(collectionRaw: String, favoritesRaw: String) async {
        guard await isAvailable() else { return }

        let recordID = CKRecord.ID(recordName: backupRecordName)
        let record = CKRecord(recordType: backupRecordType, recordID: recordID)
        record["collectionRaw"] = collectionRaw as CKRecordValue
        record["favoritesRaw"] = favoritesRaw as CKRecordValue
        record["modifiedAt"] = Date() as CKRecordValue

        do {
            _ = try await makeDatabase().save(record)
            logger.info("Legacy blob backup uploaded")
        } catch {
            logger.error("Legacy backup failed: \(error.localizedDescription)")
        }
    }

    func fetchLegacyBackup() async -> (collectionRaw: String, favoritesRaw: String)? {
        guard await isAvailable() else { return nil }

        let recordID = CKRecord.ID(recordName: backupRecordName)
        do {
            let record = try await makeDatabase().record(for: recordID)
            guard let collectionRaw = record["collectionRaw"] as? String,
                  let favoritesRaw = record["favoritesRaw"] as? String
            else { return nil }
            return (collectionRaw, favoritesRaw)
        } catch {
            return nil
        }
    }

    // MARK: - Full Restore into SwiftData

    @MainActor
    func restoreIntoSwiftData(context: ModelContext) async {
        let cloudRecords = await fetchCloudCollectionRecords()
        for cr in cloudRecords {
            let artID = cr.artworkID
            let descriptor = FetchDescriptor<PersistedCollectionRecord>(
                predicate: #Predicate { $0.artworkID == artID }
            )
            let existing = (try? context.fetch(descriptor))?.first
            if existing == nil {
                context.insert(PersistedCollectionRecord(
                    artworkID: cr.artworkID,
                    acquiredAt: cr.acquiredAt,
                    certificateID: cr.certificateID,
                    syncedToCloud: true
                ))
            }
        }

        let cloudFavorites = await fetchCloudFavorites()
        for fav in cloudFavorites {
            let favID = fav
            let descriptor = FetchDescriptor<PersistedFavorite>(
                predicate: #Predicate { $0.artworkID == favID }
            )
            let existing = (try? context.fetch(descriptor))?.first
            if existing == nil {
                context.insert(PersistedFavorite(artworkID: fav))
            }
        }

        let cloudGenerated = await fetchCloudGeneratedArtworks()
        for gen in cloudGenerated {
            let genID = gen.id
            let descriptor = FetchDescriptor<PersistedGeneratedArtwork>(
                predicate: #Predicate { $0.generationID == genID }
            )
            let existing = (try? context.fetch(descriptor))?.first
            if existing == nil {
                context.insert(PersistedGeneratedArtwork(
                    generationID: gen.id,
                    status: gen.status,
                    imageURLString: gen.imageURL,
                    prompt: gen.prompt,
                    provider: gen.provider,
                    createdAt: gen.createdAt
                ))
            }
        }

        try? context.save()
    }
}
