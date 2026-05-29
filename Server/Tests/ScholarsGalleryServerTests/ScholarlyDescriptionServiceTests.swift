import Foundation
import Testing
@testable import ScholarsGalleryServer

@Suite("ScholarlyDescriptionService — Mock Provider")
struct ScholarlyDescriptionServiceTests {
    private func makeInput(
        title: String = "Luminous Cathedral",
        tags: [String] = ["abstract", "digital"],
        wallLabel: String = "A luminous exploration of light and space.",
        prompt: String? = nil
    ) -> ScholarlyDescribeRequest {
        ScholarlyDescribeRequest(
            artworkTitle: title,
            artworkTags: tags,
            wallLabel: wallLabel,
            prompt: prompt
        )
    }

    @Test func mockDescribeReturnsValidResponse() {
        let input = makeInput()
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(!response.scholarlyDescription.isEmpty)
        #expect(!response.socialMediaCaption.isEmpty)
        #expect(!response.hashtags.isEmpty)
        #expect(response.provider == "mock")
    }

    @Test func mockDescribeIncludesArtworkTitleInScholarlyDescription() {
        let input = makeInput(title: "Quantum Fields")
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(response.scholarlyDescription.contains("Quantum Fields"))
    }

    @Test func mockDescribeIncludesTagsInHashtags() {
        let input = makeInput(tags: ["abstract", "digital", "generative"])
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(response.hashtags.contains("abstract"))
        #expect(response.hashtags.contains("digital"))
        #expect(response.hashtags.contains("generative"))
    }

    @Test func mockDescribeIncludesDefaultHashtags() {
        let input = makeInput(tags: [])
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(response.hashtags.contains("ScholarsGallery"))
        #expect(response.hashtags.contains("GenerativeArt"))
    }

    @Test func mockDescribeSocialCaptionContainsTitle() {
        let input = makeInput(title: "Neural Bloom")
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(response.socialMediaCaption.contains("Neural Bloom"))
    }

    @Test func mockDescribeSocialCaptionContainsTags() {
        let input = makeInput(tags: ["computational", "aesthetics"])
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(response.socialMediaCaption.contains("computational"))
    }

    @Test func mockDescribeProviderCustomization() {
        let input = makeInput()
        let response = ScholarlyDescriptionService.mockDescribe(input: input, provider: "openai-fallback")
        #expect(response.provider == "openai-fallback")
    }

    @Test func mockDescribeWithGenerationPrompt() {
        let input = makeInput(prompt: "A cathedral interior at dawn")
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(!response.scholarlyDescription.isEmpty)
        #expect(response.hashtags.count >= 3)
    }

    @Test func mockDescribeHandlesSingleTag() {
        let input = makeInput(tags: ["minimal"])
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(response.hashtags.contains("minimal"))
    }

    @Test func mockDescribeWithEmptyWallLabel() {
        let input = makeInput(wallLabel: "")
        let response = ScholarlyDescriptionService.mockDescribe(input: input)
        #expect(!response.scholarlyDescription.isEmpty)
    }

    @Test func providerEnumValues() {
        #expect(ScholarlyDescriptionService.Provider.mock.rawValue == "mock")
        #expect(ScholarlyDescriptionService.Provider.openai.rawValue == "openai")
    }
}
