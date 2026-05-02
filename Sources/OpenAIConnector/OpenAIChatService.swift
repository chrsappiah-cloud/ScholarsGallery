import Foundation

public struct OpenAIChatMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct OpenAIChatRequest: Encodable, Sendable {
    public let model: String
    public let messages: [OpenAIChatMessage]
    public let temperature: Double
    public let response_format: ResponseFormat?

    public struct ResponseFormat: Encodable, Sendable {
        public let type: String
        public init(type: String) { self.type = type }
    }

    public init(
        model: String,
        messages: [OpenAIChatMessage],
        temperature: Double = 0.6,
        responseFormat: ResponseFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.response_format = responseFormat
    }
}

public struct OpenAIChatResponse: Decodable, Sendable {
    public struct Choice: Decodable, Sendable {
        public let message: OpenAIChatMessage
    }

    public let choices: [Choice]
}

/// Minimal chat-completions client used by ScholarsGallery for assistant features
/// (e.g. the **Dola** prompt refiner). Uses the same OpenAI endpoint family as
/// ``OpenAIImageService``; switch model via env (`DOLA_ASSISTANT_MODEL`).
public final class OpenAIChatService: @unchecked Sendable {
    private let apiKey: String
    private let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    /// Performs a single chat completion and returns the first assistant message string.
    /// Throws on non-2xx HTTP, missing data, or decode failures.
    public func complete(
        model: String,
        messages: [OpenAIChatMessage],
        temperature: Double = 0.6,
        jsonMode: Bool = false
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = OpenAIChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            responseFormat: jsonMode ? .init(type: "json_object") : nil
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = payload.choices.first?.message.content else {
            throw URLError(.cannotParseResponse)
        }
        return content
    }
}
