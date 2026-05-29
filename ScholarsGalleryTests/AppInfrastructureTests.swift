import Foundation
import Testing
@testable import ScholarsGallery

@Suite("AppAPIErrorMapper")
struct AppAPIErrorMapperTests {
    @Test func mapsDecodingErrorToDecodingFailed() {
        let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "test"))
        #expect(AppAPIErrorMapper.map(decodingError) == .decodingFailed)
    }

    @Test func mapsNotConnectedToInternetToNetworkCached() {
        let error = URLError(.notConnectedToInternet)
        #expect(AppAPIErrorMapper.map(error) == .networkCached)
    }

    @Test func mapsTimedOutToNetworkCached() {
        let error = URLError(.timedOut)
        #expect(AppAPIErrorMapper.map(error) == .networkCached)
    }

    @Test func mapsNetworkConnectionLostToNetworkCached() {
        let error = URLError(.networkConnectionLost)
        #expect(AppAPIErrorMapper.map(error) == .networkCached)
    }

    @Test func mapsDNSFailureToNetworkConnect() {
        let error = URLError(.dnsLookupFailed)
        #expect(AppAPIErrorMapper.map(error) == .networkConnect)
    }

    @Test func mapsCannotFindHostToNetworkConnect() {
        let error = URLError(.cannotFindHost)
        #expect(AppAPIErrorMapper.map(error) == .networkConnect)
    }

    @Test func mapsCannotConnectToHostToNetworkConnect() {
        let error = URLError(.cannotConnectToHost)
        #expect(AppAPIErrorMapper.map(error) == .networkConnect)
    }

    @Test func passesThroughExistingAppAPIError() {
        #expect(AppAPIErrorMapper.map(AppAPIError.networkCached) == .networkCached)
        #expect(AppAPIErrorMapper.map(AppAPIError.decodingFailed) == .decodingFailed)
        #expect(AppAPIErrorMapper.map(AppAPIError.networkConnect) == .networkConnect)
        #expect(AppAPIErrorMapper.map(AppAPIError.unexpected) == .unexpected)
    }

    @Test func mapsUnknownErrorToUnexpected() {
        struct Unknown: Error {}
        #expect(AppAPIErrorMapper.map(Unknown()) == .unexpected)
    }
}

@Suite("AppAPIError")
struct AppAPIErrorTests {
    @Test func allCasesHaveNonEmptyDescriptions() {
        for error in [AppAPIError.networkCached, AppAPIError.networkConnect, AppAPIError.decodingFailed, AppAPIError.unexpected] {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }

    @Test func equalityMatchesSameCase() {
        #expect(AppAPIError.networkCached == AppAPIError.networkCached)
        #expect(AppAPIError.networkCached != AppAPIError.networkConnect)
    }
}

@Suite("AppJSONCache")
struct AppJSONCacheTests {
    @Test func roundTripString() {
        let suite = UserDefaults(suiteName: "AppInfrastructureTests.cache.str")!
        suite.removePersistentDomain(forName: "AppInfrastructureTests.cache.str")
        let cache = AppJSONCache(defaults: suite)
        cache.save("hello", for: "test.key")
        let loaded: String? = cache.load(String.self, for: "test.key")
        #expect(loaded == "hello")
    }

    @Test func roundTripInteger() {
        let suite = UserDefaults(suiteName: "AppInfrastructureTests.cache.int")!
        suite.removePersistentDomain(forName: "AppInfrastructureTests.cache.int")
        let cache = AppJSONCache(defaults: suite)
        cache.save(42, for: "number")
        let loaded: Int? = cache.load(Int.self, for: "number")
        #expect(loaded == 42)
    }

    @Test func returnsNilForMissingKey() {
        let suite = UserDefaults(suiteName: "AppInfrastructureTests.cache.miss")!
        suite.removePersistentDomain(forName: "AppInfrastructureTests.cache.miss")
        let cache = AppJSONCache(defaults: suite)
        let loaded: String? = cache.load(String.self, for: "missing.key")
        #expect(loaded == nil)
    }

    @Test func overwritesPreviousValue() {
        let suite = UserDefaults(suiteName: "AppInfrastructureTests.cache.ovr")!
        suite.removePersistentDomain(forName: "AppInfrastructureTests.cache.ovr")
        let cache = AppJSONCache(defaults: suite)
        cache.save("first", for: "key")
        cache.save("second", for: "key")
        let loaded: String? = cache.load(String.self, for: "key")
        #expect(loaded == "second")
    }

    @Test func saveTypeMismatchReturnsNil() {
        let suite = UserDefaults(suiteName: "AppInfrastructureTests.cache.type")!
        suite.removePersistentDomain(forName: "AppInfrastructureTests.cache.type")
        let cache = AppJSONCache(defaults: suite)
        cache.save(99, for: "key")
        let loaded: String? = cache.load(String.self, for: "key")
        #expect(loaded == nil)
    }
}

@Suite("CollectionRecordCodec")
struct CollectionRecordCodecEdgeCaseTests {
    @Test func encodeEmptyArrayReturnsEmptyString() {
        let raw = CollectionRecordCodec.encode([])
        #expect(raw == "[]")
    }

    @Test func decodeMalformedJSONReturnsEmptyArray() {
        #expect(CollectionRecordCodec.decode("not json").isEmpty)
    }

    @Test func decodeEmptyStringReturnsEmptyArray() {
        #expect(CollectionRecordCodec.decode("").isEmpty)
    }

    @Test func roundTripsSingleRecord() {
        let record = CollectionRecord(
            artworkID: "art-001",
            acquiredAt: Date(timeIntervalSince1970: 1_700_000_000),
            certificateID: "CERT-001"
        )
        let raw = CollectionRecordCodec.encode([record])
        let decoded = CollectionRecordCodec.decode(raw)
        #expect(decoded.count == 1)
        #expect(decoded[0].artworkID == "art-001")
        #expect(decoded[0].certificateID == "CERT-001")
    }

    @Test func roundTripsMultipleRecords() {
        let records = (1...5).map { i in
            CollectionRecord(
                artworkID: "art-\(i)",
                acquiredAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + i)),
                certificateID: "CERT-\(String(format: "%03d", i))"
            )
        }
        let raw = CollectionRecordCodec.encode(records)
        let decoded = CollectionRecordCodec.decode(raw)
        #expect(decoded.count == 5)
        #expect(decoded[4].artworkID == "art-5")
    }
}

@Suite("GeneratedArtworkHistoryCache")
struct GeneratedArtworkHistoryCacheEdgeCaseTests {
    @Test func mergeWithEmptyExistingReturnsOnlyNew() {
        let cache = GeneratedArtworkHistoryCache()
        let artwork = GeneratedArtwork(
            id: UUID(),
            status: "completed",
            imageURL: "https://example.com/img.jpg",
            prompt: "New artwork",
            provider: "mock",
            createdAt: Date()
        )
        let merged = cache.merge(artwork, into: [], limit: 10)
        #expect(merged.count == 1)
        #expect(merged[0].prompt == "New artwork")
    }

    @Test func mergeDeduplicatesById() {
        let cache = GeneratedArtworkHistoryCache()
        let id = UUID()
        let newer = GeneratedArtwork(
            id: id,
            status: "completed",
            imageURL: "https://example.com/new.jpg",
            prompt: "Newer",
            provider: "mock",
            createdAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let older = GeneratedArtwork(
            id: id,
            status: "completed",
            imageURL: "https://example.com/old.jpg",
            prompt: "Older",
            provider: "mock",
            createdAt: Date(timeIntervalSince1970: 1_000_000_000)
        )
        let merged = cache.merge(newer, into: [older], limit: 10)
        #expect(merged.count == 1)
        #expect(merged[0].prompt == "Newer")
    }

    @Test func mergeRespectsLimit() {
        let cache = GeneratedArtworkHistoryCache()
        let existing = (0..<5).map { i in
            GeneratedArtwork(
                id: UUID(),
                status: "completed",
                imageURL: "https://example.com/\(i).jpg",
                prompt: "Existing \(i)",
                provider: "mock",
                createdAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + i))
            )
        }
        let new = GeneratedArtwork(
            id: UUID(),
            status: "completed",
            imageURL: "https://example.com/new.jpg",
            prompt: "New item",
            provider: "mock",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let merged = cache.merge(new, into: existing, limit: 3)
        #expect(merged.count == 3)
        #expect(merged[0].prompt == "New item")
    }

    @Test func mergeClampsLimitBetween1And100() {
        let cache = GeneratedArtworkHistoryCache()
        let new = GeneratedArtwork(id: UUID(), status: "completed", imageURL: "https://e.com/i.jpg", prompt: "Only one", provider: "mock", createdAt: Date())
        let zero = cache.merge(new, into: [], limit: 0)
        #expect(zero.count == 1)
        let capped = cache.merge(new, into: [], limit: 200)
        #expect(capped.count == 1)
    }

    @Test func mergeOrdersNewestFirst() {
        let cache = GeneratedArtworkHistoryCache()
        let id1 = UUID(), id2 = UUID(), id3 = UUID()
        let veryNew = GeneratedArtwork(id: id1, status: "completed", imageURL: "https://e.com/vn.jpg", prompt: "Very new", provider: "mock", createdAt: Date(timeIntervalSince1970: 3_000_000_000))
        let mid = GeneratedArtwork(id: id2, status: "completed", imageURL: "https://e.com/mid.jpg", prompt: "Mid", provider: "mock", createdAt: Date(timeIntervalSince1970: 2_000_000_000))
        let old = GeneratedArtwork(id: id3, status: "completed", imageURL: "https://e.com/old.jpg", prompt: "Oldest", provider: "mock", createdAt: Date(timeIntervalSince1970: 1_000_000_000))
        let merged = cache.merge(veryNew, into: [old, mid], limit: 10)
        #expect(merged.count == 3)
        #expect(merged[0].prompt == "Very new")
        #expect(merged[1].prompt == "Oldest")
        #expect(merged[2].prompt == "Mid")
    }
}

@Suite("BackupSnapshot")
struct BackupSnapshotInitTests {
    @Test func storesAllFields() {
        let now = Date()
        let snap = BackupSnapshot(collectionRaw: "[]", favoritesRaw: "", modifiedAt: now)
        #expect(snap.collectionRaw == "[]")
        #expect(snap.favoritesRaw == "")
        #expect(snap.modifiedAt == now)
    }

    @Test func emptyFavoritesRaw() {
        let snap = BackupSnapshot(collectionRaw: "[{}]", favoritesRaw: "", modifiedAt: .distantPast)
        #expect(snap.favoritesRaw.isEmpty)
    }
}
