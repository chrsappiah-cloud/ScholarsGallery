import Foundation

public struct OpenAIImageRequest: Encodable, Sendable {
    public let model: String
    public let prompt: String
    public let size: String
}

public struct OpenAIImageResponse: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let url: String?
    }

    public let data: [Item]
}

public final class OpenAIImageService: @unchecked Sendable {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func generate(prompt: String, model: String = "gpt-image-1", size: String = "1536x1024") async throws -> URL {
        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OpenAIImageRequest(model: model, prompt: prompt, size: size))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
        guard let rawURL = payload.data.first?.url, let imageURL = URL(string: rawURL) else {
            throw URLError(.cannotParseResponse)
        }
        return imageURL
    }
}
