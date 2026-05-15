import Foundation

public protocol URLSessioning: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessioning {}

public final class APIClient: Sendable {
    public let baseURL: URL
    private let session: URLSessioning

    public init(baseURL: URL, session: URLSessioning = URLSession.shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        var components = URLComponents(url: baseURL.appendingPathComponent("quotes"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "symbols", value: symbols.joined(separator: ","))]
        let (data, _) = try await session.data(from: components.url!)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Quote].self, from: data)
    }

    public func fetchSignal(symbol: String, features: [String: Double], mode: TradingMode) async throws -> Signal {
        let url = baseURL.appendingPathComponent("signal")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SignalRequest(symbol: symbol, mode: mode.rawValue, features: features))
        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Signal.self, from: data)
    }

    public func fetchDashboardSnapshot() async throws -> DashboardSnapshot {
        let url = baseURL.appendingPathComponent("dashboard")
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DashboardSnapshot.self, from: data)
    }

    // MARK: - Portfolio & Risk

    public func fetchPositions() async throws -> [UnifiedAssetPosition] {
        try await get("positions")
    }

    public func fetchRiskSnapshot() async throws -> RiskSnapshot {
        try await get("snapshot")
    }

    // MARK: - Blockchain & Wallet

    public func fetchChainAccounts() async throws -> [ChainAccount] {
        try await get("accounts")
    }

    public func fetchTokenHoldings() async throws -> [TokenHolding] {
        try await get("holdings")
    }

    public func fetchContractEvents() async throws -> [SmartContractEvent] {
        try await get("events")
    }

    public func fetchOnChainAlerts() async throws -> [OnChainAlert] {
        try await get("alerts")
    }

    public func fetchTokenizedAssets() async throws -> [TokenizedAsset] {
        try await get("tokenized-assets")
    }

    // MARK: - Compliance & Social

    public func fetchComplianceProfile() async throws -> ComplianceProfile {
        try await get("profile")
    }

    public func fetchAnalystNotes(symbol: String? = nil) async throws -> [AnalystNote] {
        var components = URLComponents(url: baseURL.appendingPathComponent("notes"), resolvingAgainstBaseURL: false)!
        if let symbol {
            components.queryItems = [URLQueryItem(name: "symbol", value: symbol)]
        }
        let (data, _) = try await session.data(from: components.url!)
        return try iso8601Decoder().decode([AnalystNote].self, from: data)
    }

    // MARK: - AI Research

    public func fetchBacktests() async throws -> [BacktestRun] {
        try await get("backtests")
    }

    public func runDirectionalChange(prices: [Double], threshold: Double = 0.01) async throws -> [DirectionalChangeEvent] {
        struct Payload: Encodable { let prices: [Double]; let threshold: Double }
        struct Response: Decodable { let events: [DirectionalChangeEvent] }
        let result: Response = try await post("directional-change", body: Payload(prices: prices, threshold: threshold))
        return result.events
    }

    public func runMarkowitz(expectedReturns: [Double], covMatrix: [[Double]], riskAversion: Double = 1.0) async throws -> [Double] {
        struct Payload: Encodable { let expected_returns: [Double]; let covariance_matrix: [[Double]]; let risk_aversion: Double }
        struct Response: Decodable { let weights: [Double] }
        let result: Response = try await post("markowitz", body: Payload(expected_returns: expectedReturns, covariance_matrix: covMatrix, risk_aversion: riskAversion))
        return result.weights
    }

    // MARK: - Helpers

    private func iso8601Decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        let (data, _) = try await session.data(from: url)
        return try iso8601Decoder().decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: request)
        return try iso8601Decoder().decode(T.self, from: data)
    }
}
