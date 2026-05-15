import Foundation

public struct MarketDataService: Sendable {
    private let client: APIClient

    public init(client: APIClient) { self.client = client }

    public func quotes(for symbols: [String]) async throws -> [Quote] {
        try await client.fetchQuotes(symbols: symbols)
    }
}

public struct StrategyService: Sendable {
    private let client: APIClient

    public init(client: APIClient) { self.client = client }

    public func signal(for symbol: String, features: [String: Double], mode: TradingMode) async throws -> Signal {
        try await client.fetchSignal(symbol: symbol, features: features, mode: mode)
    }
}

public struct PortfolioService: Sendable {
    public init() {}

    public func unifiedPositions() -> [UnifiedAssetPosition] {
        DemoData.snapshot.unifiedPositions
    }
}

public struct BlockchainService: Sendable {
    public init() {}

    public func chainAccounts() -> [ChainAccount] {
        [
            ChainAccount(id: "eth-primary", chain: "Ethereum", address: "0xABCD...1234", label: "Primary Vault", balanceUSD: 19_800, lastSyncedAt: .now),
            ChainAccount(id: "base-watch", chain: "Base", address: "0x9988...F0AA", label: "Watch Wallet", balanceUSD: 8_150, lastSyncedAt: .now)
        ]
    }
}

public struct WalletService: Sendable {
    public init() {}

    public func holdings() -> [TokenHolding] {
        [
            TokenHolding(id: "eth", contractAddress: "native", symbol: "ETH", name: "Ethereum", quantity: 6.5, priceUSD: 3_046, valueUSD: 19_799, chain: "Ethereum"),
            TokenHolding(id: "usdc", contractAddress: "0xa0b8...", symbol: "USDC", name: "USD Coin", quantity: 12_500, priceUSD: 1, valueUSD: 12_500, chain: "Base")
        ]
    }
}

public struct ComplianceService: Sendable {
    public init() {}

    public func activeProfile() -> ComplianceProfile {
        ComplianceProfile(kycStatus: "approved", amlRiskScore: 0.14, jurisdiction: "AU", accreditedInvestor: true)
    }
}

public struct SmartContractService: Sendable {
    public init() {}

    public func recentEvents(limit: Int = 20) -> [SmartContractEvent] {
        Array(DemoData.contractEvents.prefix(limit))
    }

    public func alerts() -> [OnChainAlert] {
        DemoData.onChainAlerts
    }
}

public struct SocialIntelService: Sendable {
    public init() {}

    public func analystNotes(symbol: String? = nil) -> [AnalystNote] {
        guard let symbol else { return DemoData.analystNotes }
        return DemoData.analystNotes.filter { $0.symbol == symbol }
    }
}

public struct TokenizedAssetService: Sendable {
    public init() {}

    public func availableAssets() -> [TokenizedAsset] {
        DemoData.tokenizedAssets
    }
}
