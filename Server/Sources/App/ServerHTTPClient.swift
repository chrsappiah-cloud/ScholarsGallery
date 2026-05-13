import Foundation
import Vapor

enum ServerHTTPClient {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    static func perform(_ request: URLRequest, failurePrefix: String) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Abort(.badGateway, reason: "\(failurePrefix): invalid response.")
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: Data(data.prefix(256)), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let messageSuffix: String
            if let snippet, !snippet.isEmpty {
                messageSuffix = " \(snippet)"
            } else {
                messageSuffix = ""
            }
            throw Abort(.badGateway, reason: "\(failurePrefix) failed (HTTP \(http.statusCode)).\(messageSuffix)")
        }
        return data
    }
}
