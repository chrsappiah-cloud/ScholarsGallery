import Foundation
import Vapor
import OpenAIConnector

struct ScholarlyDescribeRequest: Content {
    let artworkTitle: String
    let artworkTags: [String]
    let wallLabel: String
    let prompt: String?
}

struct ScholarlyDescribeResponse: Content {
    let scholarlyDescription: String
    let socialMediaCaption: String
    let hashtags: [String]
    let provider: String
}

struct ScholarlyDescriptionService: Sendable {
    enum Provider: String, Sendable { case openai, mock }

    let provider: Provider
    let model: String
    private let openAI: OpenAIChatService?

    init(openAI: OpenAIChatService?, model: String) {
        self.openAI = openAI
        self.model = model
        self.provider = openAI == nil ? .mock : .openai
    }

    func describe(_ input: ScholarlyDescribeRequest) async throws -> ScholarlyDescribeResponse {
        if let openAI {
            return try await openAIDescribe(client: openAI, input: input)
        }
        return Self.mockDescribe(input: input)
    }

    private func openAIDescribe(
        client: OpenAIChatService,
        input: ScholarlyDescribeRequest
    ) async throws -> ScholarlyDescribeResponse {
        let system = """
        You are a distinguished art scholar and museum curator at ScholarsGallery.
        Given an artwork's title, tags, and wall label, produce TWO outputs:

        1. **scholarlyDescription** — A 150-250 word academic analysis written in a scholarly voice.
           Reference art-historical context, compositional techniques, thematic resonances,
           and situate the work within contemporary generative/digital art discourse.
           Use formal register, cite relevant movements or practitioners where fitting.

        2. **socialMediaCaption** — A 40-80 word promotional caption suitable for Instagram,
           Twitter/X, and LinkedIn. Evocative, accessible, uses emojis sparingly.
           Ends with a call-to-action (e.g., "Explore more at ScholarsGallery").

        3. **hashtags** — 5-8 relevant hashtags (without the # symbol).

        Reply ONLY with strict JSON:
        {
          "scholarlyDescription": "...",
          "socialMediaCaption": "...",
          "hashtags": ["...", "..."]
        }
        No markdown fences. No extra keys.
        """

        var userParts: [String] = [
            "Title: \(input.artworkTitle)",
            "Tags: \(input.artworkTags.joined(separator: ", "))",
            "Wall Label: \(input.wallLabel)",
        ]
        if let prompt = input.prompt, !prompt.isEmpty {
            userParts.append("Generation Prompt: \(prompt)")
        }

        let messages: [OpenAIChatMessage] = [
            .init(role: "system", content: system),
            .init(role: "user", content: userParts.joined(separator: "\n")),
        ]

        let raw: String
        do {
            raw = try await client.complete(
                model: model,
                messages: messages,
                temperature: 0.7,
                jsonMode: true
            )
        } catch {
            throw Abort(.badGateway, reason: "Scholar description service is unreachable.")
        }

        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ScholarlyParsed.self, from: data) else {
            return Self.mockDescribe(input: input, provider: "openai-fallback")
        }

        return ScholarlyDescribeResponse(
            scholarlyDescription: parsed.scholarlyDescription,
            socialMediaCaption: parsed.socialMediaCaption,
            hashtags: parsed.hashtags ?? [],
            provider: "openai"
        )
    }

    static func mockDescribe(
        input: ScholarlyDescribeRequest,
        provider: String = "mock"
    ) -> ScholarlyDescribeResponse {
        let scholarly = """
        "\(input.artworkTitle)" occupies a significant position within the contemporary \
        discourse on generative media and computational aesthetics. Drawing upon the \
        lineage of algorithmic art—from Vera Molnár's early plotter works through to \
        the neural-era outputs of Refik Anadol—this piece negotiates the tension between \
        human intentionality and machinic emergence. The compositional logic reveals a \
        deliberate engagement with \(input.artworkTags.first ?? "visual") vocabularies, \
        situating the work at the intersection of curatorial scholarship and digital \
        materiality. As a surface for interpretation, it invites readings through both \
        art-historical and information-theoretic lenses, foregrounding questions of \
        authorship, reproducibility, and the aesthetics of the computed image.
        """

        let social = """
        ✨ Discover "\(input.artworkTitle)" — where art meets algorithm. \
        A luminous exploration of \(input.artworkTags.prefix(2).joined(separator: " & ")) \
        at the frontier of generative media. Explore more at ScholarsGallery.
        """

        let hashtags = ["ScholarsGallery", "GenerativeArt", "DigitalCuration"]
            + input.artworkTags.prefix(3).map { $0.replacingOccurrences(of: " ", with: "") }

        return ScholarlyDescribeResponse(
            scholarlyDescription: scholarly,
            socialMediaCaption: social,
            hashtags: hashtags,
            provider: provider
        )
    }
}

private struct ScholarlyParsed: Decodable {
    let scholarlyDescription: String
    let socialMediaCaption: String
    let hashtags: [String]?
}

private struct ScholarlyDescriptionServiceStorageKey: StorageKey {
    typealias Value = ScholarlyDescriptionService
}

extension Application {
    var scholarlyDescriptionService: ScholarlyDescriptionService? {
        get { storage[ScholarlyDescriptionServiceStorageKey.self] }
        set { storage[ScholarlyDescriptionServiceStorageKey.self] = newValue }
    }
}
