import Foundation
import Testing
@testable import ScholarsGallery

@Suite("CachedArtwork — Tags Parsing")
struct CachedArtworkTagsParsingTests {
    @Test func singleTagParsesCorrectly() {
        let artwork = CachedArtwork(
            artworkID: "art-001",
            title: "Test",
            tags: ["abstract"],
            heroAssetURLString: "https://example.com/hero.jpg",
            thumbnailURLString: "https://example.com/thumb.jpg",
            wallLabelMarkdown: "A test artwork",
            editionNumber: nil,
            editionTotal: nil,
            exhibitionSlug: "test-exhibition"
        )
        #expect(artwork.tags == ["abstract"])
    }

    @Test func multipleTagsSeparatedByPipe() {
        let artwork = CachedArtwork(
            artworkID: "art-002",
            title: "Multi-tag",
            tags: ["abstract", "digital", "generative"],
            heroAssetURLString: "https://example.com/hero.jpg",
            thumbnailURLString: "https://example.com/thumb.jpg",
            wallLabelMarkdown: "Multi-tag artwork",
            editionNumber: nil,
            editionTotal: nil,
            exhibitionSlug: "test-exhibition"
        )
        #expect(artwork.tags == ["abstract", "digital", "generative"])
    }

    @Test func emptyTagsList() {
        let artwork = CachedArtwork(
            artworkID: "art-003",
            title: "No tags",
            tags: [],
            heroAssetURLString: "https://example.com/hero.jpg",
            thumbnailURLString: "https://example.com/thumb.jpg",
            wallLabelMarkdown: "No tags",
            editionNumber: nil,
            editionTotal: nil,
            exhibitionSlug: "test-exhibition"
        )
        #expect(artwork.tags.isEmpty)
    }

    @Test func tagsWithSpacesArePreserved() {
        let artwork = CachedArtwork(
            artworkID: "art-004",
            title: "Spaced tags",
            tags: ["contemporary art", "mixed media"],
            heroAssetURLString: "https://example.com/hero.jpg",
            thumbnailURLString: "https://example.com/thumb.jpg",
            wallLabelMarkdown: "Spaced tags",
            editionNumber: nil,
            editionTotal: nil,
            exhibitionSlug: "test-exhibition"
        )
        #expect(artwork.tags == ["contemporary art", "mixed media"])
    }

    @Test func editionFieldsPersisted() {
        let artwork = CachedArtwork(
            artworkID: "art-005",
            title: "Edition test",
            tags: ["edition"],
            heroAssetURLString: "https://example.com/hero.jpg",
            thumbnailURLString: "https://example.com/thumb.jpg",
            wallLabelMarkdown: "Edition test",
            editionNumber: 1,
            editionTotal: 10,
            exhibitionSlug: "test-exhibition"
        )
        #expect(artwork.editionNumber == 1)
        #expect(artwork.editionTotal == 10)
    }
}

@Suite("CachedEssay — References Parsing")
struct CachedEssayReferencesParsingTests {
    @Test func emptyReferencesRaw() {
        let essay = CachedEssay(
            essayID: "essay-001",
            title: "Test Essay",
            author: "Author",
            markdownBody: "# Body",
            references: []
        )
        #expect(essay.references.isEmpty)
    }

    @Test func singleReferenceParsesCorrectly() {
        let essay = CachedEssay(
            essayID: "essay-002",
            title: "Single Ref",
            author: "Author",
            markdownBody: "# Body",
            references: ["Ref 1"]
        )
        #expect(essay.references == ["Ref 1"])
    }

    @Test func multipleReferencesSeparatedByTriplePipe() {
        let essay = CachedEssay(
            essayID: "essay-003",
            title: "Multi Ref",
            author: "Author",
            markdownBody: "# Body",
            references: ["Ref 1", "Ref 2", "Ref 3"]
        )
        #expect(essay.references == ["Ref 1", "Ref 2", "Ref 3"])
    }

    @Test func referencesPreserveSpacesAndSpecialChars() {
        let essay = CachedEssay(
            essayID: "essay-004",
            title: "Special Refs",
            author: "Author",
            markdownBody: "# Body",
            references: ["Baudrillard, J. (1981)", "DOI: 10.1000/xyz123"]
        )
        #expect(essay.references == ["Baudrillard, J. (1981)", "DOI: 10.1000/xyz123"])
    }
}

@Suite("CachedExhibition — Initialization")
struct CachedExhibitionInitTests {
    @Test func initWithManifestURL() {
        let exhibition = CachedExhibition(
            exhibitionID: "550E8400-E29B-41D4-A716-446655440001",
            slug: "light-forms",
            title: "Light Forms",
            subtitle: "Radiance and Shadow",
            openingDate: Date(timeIntervalSince1970: 1_735_689_600),
            manifestURLString: "https://example.com/manifest.json"
        )
        #expect(exhibition.exhibitionID == "550E8400-E29B-41D4-A716-446655440001")
        #expect(exhibition.slug == "light-forms")
        #expect(exhibition.title == "Light Forms")
        #expect(exhibition.manifestURLString == "https://example.com/manifest.json")
    }

    @Test func initWithNilManifestURL() {
        let exhibition = CachedExhibition(
            exhibitionID: "id-002",
            slug: "void-garden",
            title: "Void Garden",
            subtitle: "Silence",
            openingDate: Date(timeIntervalSince1970: 1_742_774_400),
            manifestURLString: nil
        )
        #expect(exhibition.manifestURLString == nil)
    }

    @Test func lastSyncedAtDefaultsToNow() {
        let before = Date()
        let exhibition = CachedExhibition(
            exhibitionID: "id-003",
            slug: "default-sync",
            title: "Default Sync",
            subtitle: "Test",
            openingDate: Date(),
            manifestURLString: nil
        )
        let after = Date()
        #expect(exhibition.lastSyncedAt >= before)
        #expect(exhibition.lastSyncedAt <= after)
    }
}
