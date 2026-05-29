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
        #expect(
            url.absoluteString.contains("127.0.0.1")
                || url.absoluteString.contains("scholarsgallery")
                || url.absoluteString.contains("192.168.")
        )
    }

    @Test func galleryAPIConfigurationResolvesAbsoluteRemoteAssetURL() {
        let raw = "https://cdn.example.com/generated/image%20one.png"
        let resolved = GalleryAPIConfiguration.remoteAssetURL(from: raw)

        #expect(resolved?.absoluteString == raw)
    }

    @Test func galleryAPIConfigurationResolvesRelativeRemoteAssetURLAgainstBaseURL() {
        let resolved = GalleryAPIConfiguration.remoteAssetURL(from: "/media/generated/example.png")

        #expect(resolved?.host == GalleryAPIConfiguration.baseURL.host)
        #expect(resolved?.path == "/media/generated/example.png")
    }

    // MARK: - CloudBackupError

    @Test func cloudBackupErrorHasLocalizedDescription() {
        let error = CloudBackupError.iCloudUnavailable
        #expect(error.errorDescription != nil)
    }

    // MARK: - Study Coach Prompt Grounding

    @Test func studyCoachSuggestedResourcesMatchTraumaAwareTopic() {
        let suggested = ScholarCoachResourceCatalog.suggested(for: "trauma-aware communication in aged care")

        #expect(!suggested.isEmpty)
        #expect(suggested.count <= 3)
        #expect(suggested.first?.id == "trauma-aware")
        #expect(suggested.map(\.id).contains("trauma-aware"))
    }

    @Test func studyCoachFlashcardPromptIncludesGroundingNotes() {
        let notes = ScholarCoachResourceCatalog.suggested(for: "disability dignity in care")
        let prompt = ScholarCoachPromptBuilder.generationPrompt(
            topic: "disability dignity in care",
            mode: .flashcards,
            groundingNotes: notes
        )

        #expect(prompt.contains("Create exactly 5 flashcards"))
        #expect(prompt.contains("Grounding notes:"))
        #expect(prompt.contains("Center dignity, consent, and autonomy."))
    }

    @Test func studyCoachFollowUpPromptCarriesModeAndTopic() {
        let prompt = ScholarCoachPromptBuilder.followUpPrompt(
            question: "Adapt this for first-year nursing students",
            topic: "trauma-aware communication",
            mode: .lessonPlan
        )

        #expect(prompt.contains("continuing a lesson session"))
        #expect(prompt.contains("\"trauma-aware communication\""))
        #expect(prompt.contains("Adapt this for first-year nursing students"))
    }

    @Test func studyCoachQuickStartUsesDefaultTopicWhenLastTopicMissing() {
        #expect(!ScholarCoachQuickStart.topics.isEmpty)
        #expect(
            ScholarCoachQuickStart.initialTopic(lastTopic: "   ")
            == ScholarCoachQuickStart.topics[0]
        )
    }

    @Test func studyCoachQuickStartPreservesTrimmedLastTopic() {
        #expect(
            ScholarCoachQuickStart.initialTopic(lastTopic: "  reflective dementia care  ")
            == "reflective dementia care"
        )
    }
}

// MARK: - AccessCheckResponse Decoding

private struct AccessCheckResponseTest: Decodable {
    var granted: Bool
    var expiresAt: Date?
}

@Suite("AccessCheckResponse Decoding")
struct AccessCheckResponseTests {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test func decodes_granted_true() throws {
        let json = #"{"granted":true}"#.data(using: .utf8)!
        let response = try decoder.decode(AccessCheckResponseTest.self, from: json)
        #expect(response.granted == true)
        #expect(response.expiresAt == nil)
    }

    @Test func decodes_granted_false() throws {
        let json = #"{"granted":false}"#.data(using: .utf8)!
        let response = try decoder.decode(AccessCheckResponseTest.self, from: json)
        #expect(response.granted == false)
    }

    @Test func decodes_with_expiry_date() throws {
        let json = #"{"granted":true,"expiresAt":"2026-12-31T00:00:00Z"}"#.data(using: .utf8)!
        let response = try decoder.decode(AccessCheckResponseTest.self, from: json)
        #expect(response.granted == true)
        #expect(response.expiresAt != nil)
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day], from: response.expiresAt!)
        #expect(components.year == 2026)
        #expect(components.month == 12)
        #expect(components.day == 31)
    }
}

// MARK: - AdminAccessGrant Codable

private struct AdminAccessGrantTest: Codable, Identifiable {
    var id: String { deviceID }
    var deviceID: String
    var grantedAt: Date
    var expiresAt: Date?
    var reason: String?
}

@Suite("AdminAccessGrant Codable")
struct AdminAccessGrantTests {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test func roundTrip_allFields() throws {
        let original = AdminAccessGrantTest(
            deviceID: "ABCD1234",
            grantedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            reason: "Test grant"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AdminAccessGrantTest.self, from: data)
        #expect(decoded.deviceID == original.deviceID)
        #expect(decoded.reason == original.reason)
        #expect(decoded.expiresAt != nil)
    }

    @Test func roundTrip_optionalsNil() throws {
        let original = AdminAccessGrantTest(
            deviceID: "TESTDEVICE",
            grantedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: nil,
            reason: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AdminAccessGrantTest.self, from: data)
        #expect(decoded.deviceID == "TESTDEVICE")
        #expect(decoded.expiresAt == nil)
        #expect(decoded.reason == nil)
    }
}

// MARK: - Device Access Code Extraction

@Suite("Device Access Code")
struct DeviceAccessCodeTests {
    @Test func extractsLast8Chars() {
        let uuidString = "AABBCCDD-1111-2222-3333-EEFF00112233"
        let code = String(uuidString.suffix(8)).uppercased()
        #expect(code == "00112233")
    }

    @Test func last8CharsAreUppercased() {
        let uuidString = "aabbccdd-1111-2222-3333-eeff00aabbcc"
        let code = String(uuidString.suffix(8)).uppercased()
        #expect(code == code.uppercased())
        #expect(code.count == 8)
    }

    @Test func fallbackForUnknown() {
        let full = "UNKNOWN"
        let code = String(full.suffix(8)).uppercased()
        #expect(code == "UNKNOWN")
    }
}
