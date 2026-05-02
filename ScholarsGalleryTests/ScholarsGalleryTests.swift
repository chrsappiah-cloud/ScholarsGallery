//
//  ScholarsGalleryTests.swift
//  ScholarsGalleryTests
//
//  Created by Christopher Appiah-Thompson  on 30/4/2026.
//

import Foundation
import Testing
@testable import ScholarsGallery

struct ScholarsGalleryTests {

    // MARK: - Error Mapping (existing)

    @Test func mapsURLErrorToNetworkMessage() {
        let mapped = AppAPIErrorMapper.map(URLError(.notConnectedToInternet))
        #expect(mapped == .networkCached)
    }

    @Test func mapsDecodingErrorToDecodingMessage() {
        let data = Data("not-json".utf8)
        let decodingError: Error
        do {
            _ = try JSONDecoder().decode([String: String].self, from: data)
            decodingError = URLError(.cannotDecodeRawData)
        } catch {
            decodingError = error
        }

        let mapped = AppAPIErrorMapper.map(decodingError)
        #expect(mapped == .decodingFailed)
    }

    @Test func mapsTimeoutToNetworkCached() {
        let mapped = AppAPIErrorMapper.map(URLError(.timedOut))
        #expect(mapped == .networkCached)
    }

    @Test func mapsNetworkConnectionLostToNetworkCached() {
        let mapped = AppAPIErrorMapper.map(URLError(.networkConnectionLost))
        #expect(mapped == .networkCached)
    }

    @Test func mapsOtherURLErrorToNetworkConnect() {
        let mapped = AppAPIErrorMapper.map(URLError(.cannotFindHost))
        #expect(mapped == .networkConnect)
    }

    @Test func mapsUnknownErrorToUnexpected() {
        struct SomeError: Error {}
        let mapped = AppAPIErrorMapper.map(SomeError())
        #expect(mapped == .unexpected)
    }

    @Test func mapsExistingAppAPIErrorPassthrough() {
        let mapped = AppAPIErrorMapper.map(AppAPIError.decodingFailed)
        #expect(mapped == .decodingFailed)
    }

    // MARK: - JSON Cache (existing + new)

    @Test func jsonCacheRoundTrip() {
        let suite = UserDefaults(suiteName: "ScholarsGalleryTests.cache")!
        suite.removePersistentDomain(forName: "ScholarsGalleryTests.cache")
        let cache = AppJSONCache(defaults: suite)

        let payload = ["title": "Worlds Written in Light"]
        cache.save(payload, for: "cache.test")

        let loaded: [String: String]? = cache.load([String: String].self, for: "cache.test")
        #expect(loaded?["title"] == "Worlds Written in Light")
    }

    @Test func jsonCacheReturnsNilForMissingKey() {
        let suite = UserDefaults(suiteName: "ScholarsGalleryTests.cache.miss")!
        suite.removePersistentDomain(forName: "ScholarsGalleryTests.cache.miss")
        let cache = AppJSONCache(defaults: suite)

        let loaded: [String: String]? = cache.load([String: String].self, for: "nonexistent.key")
        #expect(loaded == nil)
    }

    @Test func jsonCacheOverwritesPreviousValue() {
        let suite = UserDefaults(suiteName: "ScholarsGalleryTests.cache.overwrite")!
        suite.removePersistentDomain(forName: "ScholarsGalleryTests.cache.overwrite")
        let cache = AppJSONCache(defaults: suite)

        cache.save(["v": "1"], for: "key")
        cache.save(["v": "2"], for: "key")

        let loaded: [String: String]? = cache.load([String: String].self, for: "key")
        #expect(loaded?["v"] == "2")
    }

    // MARK: - GalleryAPIMeta (existing + new)

    @Test @MainActor func galleryAPIMetaDecodesServerJSON() throws {
        let data = Data(
            """
            {"ok":true,"persistence":"file","catalog":"static","hasOpenAI":false,"version":"1","checkoutEnabled":true,"generationEnabled":true,"announcement":null,"adminPanelConfigured":false}
            """.utf8
        )
        let meta = try JSONDecoder().decode(GalleryAPIMeta.self, from: data)
        #expect(meta.ok)
        #expect(meta.persistence == "file")
        #expect(meta.catalog == "static")
        #expect(meta.hasOpenAI == false)
        #expect(meta.version == "1")
        #expect(meta.effectiveCheckoutEnabled)
        #expect(meta.effectiveGenerationEnabled)
    }

    @Test @MainActor func galleryAPIMetaEffectiveDefaultsWhenNil() throws {
        let data = Data(
            """
            {"ok":true,"persistence":"memory","catalog":"static","hasOpenAI":false,"version":"1"}
            """.utf8
        )
        let meta = try JSONDecoder().decode(GalleryAPIMeta.self, from: data)
        #expect(meta.effectiveCheckoutEnabled == true)
        #expect(meta.effectiveGenerationEnabled == true)
        #expect(meta.effectiveDolaAssistantEnabled == true)
        #expect(meta.effectiveDolaAssistantConfigured == false)
        #expect(meta.checkoutEnabled == nil)
        #expect(meta.generationEnabled == nil)
        #expect(meta.dolaAssistantEnabled == nil)
        #expect(meta.dolaAssistantConfigured == nil)
    }

    @Test @MainActor func galleryAPIMetaDolaFieldsDecode() throws {
        let data = Data(
            """
            {"ok":true,"persistence":"file","catalog":"static","hasOpenAI":true,"version":"1","checkoutEnabled":false,"generationEnabled":false,"dolaAssistantConfigured":true,"dolaAssistantEnabled":false,"adminPanelConfigured":true}
            """.utf8
        )
        let meta = try JSONDecoder().decode(GalleryAPIMeta.self, from: data)
        #expect(meta.effectiveDolaAssistantConfigured == true)
        #expect(meta.effectiveDolaAssistantEnabled == false)
        #expect(meta.effectiveCheckoutEnabled == false)
        #expect(meta.effectiveGenerationEnabled == false)
        #expect(meta.hasOpenAI == true)
    }

    @Test @MainActor func galleryAPIMetaAnnouncementDecodes() throws {
        let data = Data(
            """
            {"ok":true,"persistence":"file","catalog":"static","hasOpenAI":false,"version":"1","announcement":"Gallery closed for maintenance"}
            """.utf8
        )
        let meta = try JSONDecoder().decode(GalleryAPIMeta.self, from: data)
        #expect(meta.announcement == "Gallery closed for maintenance")
    }

    // MARK: - CollectionRecord Codec (existing + new)

    @Test func collectionLedgerCodecRoundTrip() {
        let records = [
            CollectionRecord(
                artworkID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                acquiredAt: Date(timeIntervalSince1970: 1_700_000_000),
                certificateID: "CERT-ABC12345"
            )
        ]

        let raw = CollectionRecordCodec.encode(records)
        let decoded = CollectionRecordCodec.decode(raw)

        #expect(decoded.count == 1)
        #expect(decoded.first?.artworkID == "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
        #expect(decoded.first?.certificateID == "CERT-ABC12345")
    }

    @Test func collectionCodecEmptyArrayRoundTrip() {
        let raw = CollectionRecordCodec.encode([])
        let decoded = CollectionRecordCodec.decode(raw)
        #expect(decoded.isEmpty)
    }

    @Test func collectionCodecDecodeInvalidJSONReturnsEmpty() {
        let decoded = CollectionRecordCodec.decode("not valid json {{{")
        #expect(decoded.isEmpty)
    }

    @Test func collectionCodecDecodeEmptyStringReturnsEmpty() {
        let decoded = CollectionRecordCodec.decode("")
        #expect(decoded.isEmpty)
    }

    @Test func collectionCodecMultipleRecords() {
        let records = [
            CollectionRecord(
                artworkID: "id-1",
                acquiredAt: Date(timeIntervalSince1970: 1_700_000_000),
                certificateID: "CERT-001"
            ),
            CollectionRecord(
                artworkID: "id-2",
                acquiredAt: Date(timeIntervalSince1970: 1_700_001_000),
                certificateID: "CERT-002"
            ),
            CollectionRecord(
                artworkID: "id-3",
                acquiredAt: Date(timeIntervalSince1970: 1_700_002_000),
                certificateID: "CERT-003"
            )
        ]

        let raw = CollectionRecordCodec.encode(records)
        let decoded = CollectionRecordCodec.decode(raw)

        #expect(decoded.count == 3)
        #expect(decoded[0].artworkID == "id-1")
        #expect(decoded[1].artworkID == "id-2")
        #expect(decoded[2].artworkID == "id-3")
    }

    // MARK: - Dola Models

    @Test @MainActor func dolaAssistantPayloadDecoding() throws {
        let data = Data(
            """
            {
                "refinedPrompt": "A luminous gallery in twilight",
                "suggestions": ["Add golden hour lighting", "Include marble textures"],
                "palette": ["#1A2B3C", "#FF6B9D", "#2ECC71"],
                "provider": "openai"
            }
            """.utf8
        )
        let payload = try JSONDecoder().decode(DolaAssistantPayload.self, from: data)
        #expect(payload.refinedPrompt == "A luminous gallery in twilight")
        #expect(payload.suggestions.count == 2)
        #expect(payload.suggestions[0] == "Add golden hour lighting")
        #expect(payload.palette.count == 3)
        #expect(payload.palette[0] == "#1A2B3C")
        #expect(payload.provider == "openai")
    }

    @Test @MainActor func dolaAssistantPayloadDecodesEmptyArrays() throws {
        let data = Data(
            """
            {"refinedPrompt":"test","suggestions":[],"palette":[],"provider":"mock"}
            """.utf8
        )
        let payload = try JSONDecoder().decode(DolaAssistantPayload.self, from: data)
        #expect(payload.suggestions.isEmpty)
        #expect(payload.palette.isEmpty)
        #expect(payload.provider == "mock")
    }

    @Test func dolaMoodChoiceAllCasesHaveServerValues() {
        for mood in DolaMoodChoice.allCases {
            #expect(!mood.serverValue.isEmpty)
            #expect(mood.serverValue == mood.rawValue)
        }
        #expect(DolaMoodChoice.allCases.count == 5)
    }

    @Test func dolaIntentChoiceAllCasesHaveServerValues() {
        for intent in DolaIntentChoice.allCases {
            #expect(!intent.serverValue.isEmpty)
            #expect(intent.serverValue == intent.rawValue)
        }
        #expect(DolaIntentChoice.allCases.count == 3)
    }

    @Test func dolaMoodChoiceLocalizedLabelsAreNonEmpty() {
        for mood in DolaMoodChoice.allCases {
            #expect(!mood.localizedLabel.isEmpty)
        }
    }

    @Test func dolaIntentChoiceLocalizedLabelsAreNonEmpty() {
        for intent in DolaIntentChoice.allCases {
            #expect(!intent.localizedLabel.isEmpty)
        }
    }

    // MARK: - BackupSnapshot

    @Test func backupSnapshotStoresFields() {
        let now = Date()
        let snapshot = BackupSnapshot(
            collectionRaw: "[{\"artworkID\":\"abc\"}]",
            favoritesRaw: "id1,id2,id3",
            modifiedAt: now
        )
        #expect(snapshot.collectionRaw == "[{\"artworkID\":\"abc\"}]")
        #expect(snapshot.favoritesRaw == "id1,id2,id3")
        #expect(snapshot.modifiedAt == now)
    }

    // MARK: - AppAPIError

    @Test func appAPIErrorHasLocalizedDescriptions() {
        let cases: [AppAPIError] = [.networkCached, .networkConnect, .decodingFailed, .unexpected]
        for apiError in cases {
            #expect(apiError.errorDescription != nil)
            #expect(!apiError.errorDescription!.isEmpty)
        }
    }

    @Test func appAPIErrorEquality() {
        #expect(AppAPIError.networkCached == AppAPIError.networkCached)
        #expect(AppAPIError.networkCached != AppAPIError.decodingFailed)
        #expect(AppAPIError.unexpected != AppAPIError.networkConnect)
    }

    // MARK: - GalleryAPIConfiguration

    @Test func galleryAPIConfigurationProvidesDefaultURL() {
        let url = GalleryAPIConfiguration.baseURL
        #expect(url.absoluteString.contains("127.0.0.1") || url.absoluteString.contains("scholarsgallery"))
    }

    // MARK: - CloudBackupError

    @Test func cloudBackupErrorHasLocalizedDescription() {
        let error = CloudBackupError.iCloudUnavailable
        #expect(error.errorDescription != nil)
    }
}

