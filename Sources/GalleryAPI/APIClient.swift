import Foundation
import CoreModels

public final class APIClient: @unchecked Sendable {
    public static let shared = APIClient()

    private let session: URLSession
    public var baseURL: URL

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:8081")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchExhibitions() async throws -> [Exhibition] {
        let url = baseURL.appendingPathComponent("api/exhibitions")
        let (data, response) = try await session.data(from: url)
        try Self.validate(response: response)
        return try JSONDecoder.iso8601.decode([Exhibition].self, from: data)
    }

    public func fetchRoomManifest(url: URL) async throws -> RoomManifest {
        let (data, response) = try await session.data(from: url)
        try Self.validate(response: response)
        return try JSONDecoder().decode(RoomManifest.self, from: data)
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
