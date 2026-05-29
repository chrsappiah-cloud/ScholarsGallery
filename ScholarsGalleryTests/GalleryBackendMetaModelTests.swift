import Foundation
import Testing
@testable import ScholarsGallery

@Suite("GalleryBackendMetaModel — Connection Summary")
@MainActor
struct GalleryBackendMetaModelConnectionSummaryTests {
    @Test func whenMetaIsNilAndLocalDevShowsActive() {
        let summary = GalleryBackendMetaModel.makeConnectionSummary(meta: nil, lastRefreshFailed: false)
        #expect(summary != nil)
    }

    @Test func whenRefreshFailsAndProductionConfiguredShowsUnavailable() {
        let meta = GalleryAPIMeta(
            ok: false,
            persistence: "memory",
            catalog: "static",
            hasOpenAI: false,
            version: "1",
            checkoutEnabled: nil,
            generationEnabled: nil,
            announcement: nil,
            adminPanelConfigured: nil,
            dolaAssistantConfigured: nil,
            dolaAssistantEnabled: nil
        )
        let summary = GalleryBackendMetaModel.makeConnectionSummary(meta: meta, lastRefreshFailed: true)
        #expect(summary != nil)
    }

    @Test func withMetaAndProductionIncludesCatalogAndPersistence() {
        let meta = GalleryAPIMeta(
            ok: true,
            persistence: "file",
            catalog: "static",
            hasOpenAI: true,
            version: "1",
            checkoutEnabled: true,
            generationEnabled: true,
            announcement: nil,
            adminPanelConfigured: true,
            dolaAssistantConfigured: true,
            dolaAssistantEnabled: true
        )
        let summary = GalleryBackendMetaModel.makeConnectionSummary(meta: meta, lastRefreshFailed: false)
        #expect(summary != nil)
        #expect(summary?.contains("File") == true)
        #expect(summary?.contains("Static") == true)
    }
}
