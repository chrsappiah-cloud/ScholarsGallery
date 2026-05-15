import Foundation

public enum TradingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case simulation
    case paper
    case live

    public var id: String { rawValue }
}

public struct Quote: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let symbol: String
    public let bid: Double
    public let ask: Double
    public let last: Double
    public let timestamp: Date

    public init(id: UUID = UUID(), symbol: String, bid: Double, ask: Double, last: Double, timestamp: Date) {
        self.id = id
        self.symbol = symbol
        self.bid = bid
        self.ask = ask
        self.last = last
        self.timestamp = timestamp
    }
}

public struct Signal: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let symbol: String
    public let action: String
    public let confidence: Double
    public let engine: String
    public let explanation: String?

    public init(id: UUID = UUID(), symbol: String, action: String, confidence: Double, engine: String, explanation: String? = nil) {
        self.id = id
        self.symbol = symbol
        self.action = action
        self.confidence = confidence
        self.engine = engine
        self.explanation = explanation
    }
}

public struct Position: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let symbol: String
    public let quantity: Double
    public let averagePrice: Double
    public let marketValue: Double
    public let unrealizedPnL: Double

    public init(id: UUID = UUID(), symbol: String, quantity: Double, averagePrice: Double, marketValue: Double, unrealizedPnL: Double) {
        self.id = id
        self.symbol = symbol
        self.quantity = quantity
        self.averagePrice = averagePrice
        self.marketValue = marketValue
        self.unrealizedPnL = unrealizedPnL
    }
}

public struct RiskSnapshot: Codable, Hashable, Sendable {
    public let grossExposure: Double
    public let netExposure: Double
    public let maxDrawdown: Double
    public let valueAtRisk95: Double
    public let expectedShortfall95: Double

    public init(grossExposure: Double, netExposure: Double, maxDrawdown: Double, valueAtRisk95: Double, expectedShortfall95: Double) {
        self.grossExposure = grossExposure
        self.netExposure = netExposure
        self.maxDrawdown = maxDrawdown
        self.valueAtRisk95 = valueAtRisk95
        self.expectedShortfall95 = expectedShortfall95
    }
}

public struct ChainAccount: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let chain: String
    public let address: String
    public let label: String?
    public let balanceUSD: Double
    public let lastSyncedAt: Date
}

public struct TokenHolding: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let contractAddress: String
    public let symbol: String
    public let name: String
    public let quantity: Double
    public let priceUSD: Double
    public let valueUSD: Double
    public let chain: String
}

public struct SmartContractEvent: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let chain: String
    public let contractAddress: String
    public let eventName: String
    public let txHash: String
    public let blockNumber: Int
    public let timestamp: Date
    public let summary: String
}

public struct ComplianceProfile: Codable, Hashable, Sendable {
    public let kycStatus: String
    public let amlRiskScore: Double
    public let jurisdiction: String
    public let accreditedInvestor: Bool

    public init(kycStatus: String, amlRiskScore: Double, jurisdiction: String, accreditedInvestor: Bool) {
        self.kycStatus = kycStatus
        self.amlRiskScore = amlRiskScore
        self.jurisdiction = jurisdiction
        self.accreditedInvestor = accreditedInvestor
    }
}

public enum AssetDomain: String, Codable, CaseIterable, Sendable {
    case traditional
    case crypto
    case tokenized
}

public struct UnifiedAssetPosition: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let domain: AssetDomain
    public let symbol: String
    public let displayName: String
    public let quantity: Double
    public let marketValueUSD: Double
    public let venue: String
    public let riskLabel: String
}

public struct OnChainAlert: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let chain: String
    public let severity: AlertSeverity
    public let title: String
    public let detail: String
    public let txHash: String?
    public let timestamp: Date

    public enum AlertSeverity: String, Codable, Sendable {
        case info, warning, critical
    }
}

public struct AnalystNote: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let authorHandle: String
    public let reputationScore: Double
    public let symbol: String
    public let sentiment: String
    public let body: String
    public let provenanceHash: String?
    public let publishedAt: Date
    public let verifiedOnChain: Bool
}

public struct ReputationScore: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let handle: String
    public let overallScore: Double
    public let signalAccuracy: Double
    public let totalCalls: Int
    public let correctCalls: Int
    public let domain: String
}

public struct TokenizedAsset: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let symbol: String
    public let displayName: String
    public let assetClass: String
    public let contractAddress: String
    public let chain: String
    public let bidUSD: Double?
    public let askUSD: Double?
    public let lastPriceUSD: Double
    public let settlementState: SettlementState
    public let eligibilityRequired: Bool

    public enum SettlementState: String, Codable, Sendable {
        case open, pending, settled, failed
    }
}

public struct DirectionalChangeEvent: Codable, Hashable, Sendable {
    public let index: Int
    public let type: String
    public let price: Double
}

public struct BacktestRun: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let strategy: String
    public let symbol: String
    public let startDate: String
    public let endDate: String
    public let totalReturn: Double
    public let sharpeRatio: Double
    public let maxDrawdown: Double
    public let numTrades: Int
    public let status: String

    public enum CodingKeys: String, CodingKey {
        case id, strategy, symbol, status
        case startDate = "start_date"
        case endDate = "end_date"
        case totalReturn = "total_return"
        case sharpeRatio = "sharpe_ratio"
        case maxDrawdown = "max_drawdown"
        case numTrades = "num_trades"
    }
}

public struct SignalRequest: Codable, Equatable, Sendable {
    public let symbol: String
    public let mode: String
    public let features: [String: Double]

    public init(symbol: String, mode: String, features: [String: Double]) {
        self.symbol = symbol
        self.mode = mode
        self.features = features
    }
}

public struct DashboardPanel: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let caption: String

    public init(id: UUID = UUID(), title: String, detail: String, caption: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.caption = caption
    }
}

public struct DashboardSnapshot: Codable, Hashable, Sendable {
    public let mode: TradingMode
    public let headline: String
    public let subheadline: String
    public let panels: [DashboardPanel]
    public let risk: RiskSnapshot
    public let topSignals: [Signal]
    public let unifiedPositions: [UnifiedAssetPosition]

    public init(mode: TradingMode, headline: String, subheadline: String, panels: [DashboardPanel], risk: RiskSnapshot, topSignals: [Signal], unifiedPositions: [UnifiedAssetPosition]) {
        self.mode = mode
        self.headline = headline
        self.subheadline = subheadline
        self.panels = panels
        self.risk = risk
        self.topSignals = topSignals
        self.unifiedPositions = unifiedPositions
    }
}

public enum DemoData {
    public static let snapshot = DashboardSnapshot(
        mode: .simulation,
        headline: "AIF Scholars Board",
        subheadline: "Multi-asset • AI-assisted • On-chain aware",
        panels: [
            DashboardPanel(title: "Market Regime", detail: "Calm with local turbulence in tech & L2 chains", caption: "Regime: Mean-reverting"),
            DashboardPanel(title: "Portfolio Health", detail: "+4.2% YTD · VaR(95) 3.1%", caption: "Risk budget aligned"),
            DashboardPanel(title: "On-Chain Signals", detail: "3 contracts with unusual flow", caption: "View anomalies ->"),
            DashboardPanel(title: "Research Atelier", detail: "7 new backtests and 2 RL experiments", caption: "Model-simulate-learn loop")
        ],
        risk: RiskSnapshot(grossExposure: 0.74, netExposure: 0.42, maxDrawdown: 0.061, valueAtRisk95: 0.031, expectedShortfall95: 0.046),
        topSignals: [
            Signal(symbol: "NVDA", action: "buy", confidence: 0.81, engine: "Directional Change + LSTM", explanation: "Momentum recovery after event-based downturn reset"),
            Signal(symbol: "ETH-USD", action: "hold", confidence: 0.67, engine: "On-chain anomaly monitor", explanation: "Smart-contract flow elevated but not yet directional")
        ],
        unifiedPositions: [
            UnifiedAssetPosition(id: "eq-spy", domain: .traditional, symbol: "SPY", displayName: "SPDR S&P 500 ETF", quantity: 42, marketValueUSD: 22050, venue: "Brokerage", riskLabel: "Core"),
            UnifiedAssetPosition(id: "cr-eth", domain: .crypto, symbol: "ETH", displayName: "Ethereum", quantity: 6.5, marketValueUSD: 19800, venue: "Wallet", riskLabel: "Elevated"),
            UnifiedAssetPosition(id: "tk-energy", domain: .tokenized, symbol: "ENGY-RWA", displayName: "Tokenized Energy Basket", quantity: 120, marketValueUSD: 12400, venue: "Smart Contract", riskLabel: "Structured")
        ]
    )

    public static let quotes = [
        Quote(symbol: "AAPL", bid: 212.1, ask: 212.3, last: 212.2, timestamp: .now),
        Quote(symbol: "BTC-USD", bid: 102_200, ask: 102_260, last: 102_240, timestamp: .now)
    ]

    public static let chainAccounts = [
        ChainAccount(id: "eth-primary", chain: "Ethereum", address: "0xABCD...1234", label: "Primary Vault", balanceUSD: 19_800, lastSyncedAt: .now),
        ChainAccount(id: "base-watch", chain: "Base", address: "0x9988...F0AA", label: "Watch Wallet", balanceUSD: 8_150, lastSyncedAt: .now)
    ]

    public static let tokenHoldings = [
        TokenHolding(id: "eth", contractAddress: "native", symbol: "ETH", name: "Ethereum", quantity: 6.5, priceUSD: 3_046, valueUSD: 19_799, chain: "Ethereum"),
        TokenHolding(id: "usdc", contractAddress: "0xa0b8...", symbol: "USDC", name: "USD Coin", quantity: 12_500, priceUSD: 1, valueUSD: 12_500, chain: "Base"),
        TokenHolding(id: "wbtc", contractAddress: "0x2260...", symbol: "WBTC", name: "Wrapped Bitcoin", quantity: 0.12, priceUSD: 102_240, valueUSD: 12_269, chain: "Ethereum")
    ]

    public static let contractEvents = [
        SmartContractEvent(id: "evt-1", chain: "Ethereum", contractAddress: "0xVault...AA", eventName: "Deposit", txHash: "0xabc...123", blockNumber: 21_540_110, timestamp: .now.addingTimeInterval(-300), summary: "Deposit of 5.0 ETH into strategy vault"),
        SmartContractEvent(id: "evt-2", chain: "Base", contractAddress: "0xPool...BB", eventName: "Swap", txHash: "0xdef...456", blockNumber: 14_902_000, timestamp: .now.addingTimeInterval(-900), summary: "Swap 12,500 USDC → 4.1 ETH at pool price"),
        SmartContractEvent(id: "evt-3", chain: "Ethereum", contractAddress: "0xStake...CC", eventName: "RewardClaimed", txHash: "0x789...abc", blockNumber: 21_540_050, timestamp: .now.addingTimeInterval(-1800), summary: "Claimed 0.08 ETH staking reward")
    ]

    public static let onChainAlerts = [
        OnChainAlert(id: "al-1", chain: "Ethereum", severity: .warning, title: "Unusual contract flow", detail: "0xVault...AA received 3× normal deposit volume in 1 hour", txHash: nil, timestamp: .now.addingTimeInterval(-120)),
        OnChainAlert(id: "al-2", chain: "Base", severity: .info, title: "Gas spike detected", detail: "Base gas fees elevated: 42 gwei (normal < 15)", txHash: nil, timestamp: .now.addingTimeInterval(-600))
    ]

    public static let analystNotes = [
        AnalystNote(id: "note-1", authorHandle: "@quant_atlas", reputationScore: 0.87, symbol: "ETH", sentiment: "bullish", body: "L2 fee compression is driving ETH accumulation by DeFi protocols. On-chain net flow from CEX to self-custody up 18% WoW.", provenanceHash: "QmXf...9kLm", publishedAt: .now.addingTimeInterval(-3600), verifiedOnChain: true),
        AnalystNote(id: "note-2", authorHandle: "@macro_drift", reputationScore: 0.74, symbol: "BTC-USD", sentiment: "neutral", body: "BTC holding $100k range but open interest distribution suggests large positioning above $108k. Watch for liquidation cascade.", provenanceHash: nil, publishedAt: .now.addingTimeInterval(-7200), verifiedOnChain: false),
        AnalystNote(id: "note-3", authorHandle: "@onchain_lens", reputationScore: 0.91, symbol: "NVDA", sentiment: "bullish", body: "AI compute demand still compounding. Supply constraint signals in Taiwan fab data corroborated by on-chain GPU futures.", provenanceHash: "QmRa...3pQw", publishedAt: .now.addingTimeInterval(-14400), verifiedOnChain: true)
    ]

    public static let backtests = [
        BacktestRun(id: "bt-1", strategy: "Directional Change + LSTM", symbol: "NVDA", startDate: "2024-01-01", endDate: "2024-12-31", totalReturn: 0.412, sharpeRatio: 1.84, maxDrawdown: 0.092, numTrades: 143, status: "complete"),
        BacktestRun(id: "bt-2", strategy: "Markowitz Rebalance (Monthly)", symbol: "SPY/QQQ/ETH", startDate: "2024-01-01", endDate: "2024-12-31", totalReturn: 0.211, sharpeRatio: 1.31, maxDrawdown: 0.068, numTrades: 12, status: "complete"),
        BacktestRun(id: "bt-3", strategy: "RL Agent (PPO)", symbol: "BTC-USD", startDate: "2024-06-01", endDate: "2024-12-31", totalReturn: 0.187, sharpeRatio: 0.97, maxDrawdown: 0.143, numTrades: 291, status: "complete"),
        BacktestRun(id: "bt-4", strategy: "On-chain Anomaly + Mean Reversion", symbol: "ETH-USD", startDate: "2025-01-01", endDate: "2025-04-30", totalReturn: 0.063, sharpeRatio: 1.12, maxDrawdown: 0.041, numTrades: 58, status: "running")
    ]

    public static let tokenizedAssets = [
        TokenizedAsset(id: "rwa-energy", symbol: "ENGY-RWA", displayName: "Tokenized Energy Basket", assetClass: "Real World Asset", contractAddress: "0xENGY...01", chain: "Ethereum", bidUSD: 103.2, askUSD: 103.6, lastPriceUSD: 103.4, settlementState: .open, eligibilityRequired: true),
        TokenizedAsset(id: "rwa-re", symbol: "PROP-AUS", displayName: "AU Commercial Property Token", assetClass: "Real Estate", contractAddress: "0xPROP...02", chain: "Base", bidUSD: 212.0, askUSD: 213.5, lastPriceUSD: 212.8, settlementState: .open, eligibilityRequired: true),
        TokenizedAsset(id: "rwa-tbill", symbol: "TBILL-3M", displayName: "3-Month T-Bill Token", assetClass: "Fixed Income", contractAddress: "0xTBIL...03", chain: "Ethereum", bidUSD: 99.87, askUSD: 99.91, lastPriceUSD: 99.89, settlementState: .settled, eligibilityRequired: false)
    ]
}

// MARK: - Dashboard hero validation (contract / QA score)

/// Aggregates boolean checks on the dashboard “hero” snapshot so tests can require a minimum quality ratio (e.g. 95%).
public enum DashboardHeroValidator: Sendable {
    public struct HeroValidationResult: Sendable, Equatable {
        public let passedChecks: Int
        public let totalChecks: Int
        /// Fraction of checks that passed, in `0...1`.
        public var qualityRatio: Double {
            guard totalChecks > 0 else { return 0 }
            return Double(passedChecks) / Double(totalChecks)
        }
    }

    public static func validateHeroSnapshot(_ snapshot: DashboardSnapshot) -> HeroValidationResult {
        var passed = 0
        var total = 0
        func ck(_ ok: Bool) {
            total += 1
            if ok { passed += 1 }
        }

        ck(!snapshot.headline.isEmpty)
        ck(!snapshot.subheadline.isEmpty)
        ck(snapshot.panels.count >= 3)
        for panel in snapshot.panels {
            ck(!panel.title.isEmpty)
            ck(!panel.detail.isEmpty)
            ck(!panel.caption.isEmpty)
        }
        ck(snapshot.risk.grossExposure >= 0 && snapshot.risk.grossExposure <= 3)
        ck(snapshot.risk.netExposure >= -1 && snapshot.risk.netExposure <= 1)
        ck(snapshot.risk.maxDrawdown >= 0 && snapshot.risk.maxDrawdown <= 1)
        ck(snapshot.risk.valueAtRisk95 >= 0)
        ck(snapshot.risk.expectedShortfall95 >= snapshot.risk.valueAtRisk95)
        ck(!snapshot.topSignals.isEmpty)
        for signal in snapshot.topSignals {
            ck(signal.confidence >= 0 && signal.confidence <= 1)
            ck(!signal.symbol.isEmpty)
            ck(!signal.action.isEmpty)
        }
        ck(!snapshot.unifiedPositions.isEmpty)
        for position in snapshot.unifiedPositions {
            ck(position.marketValueUSD > 0)
            ck(!position.displayName.isEmpty)
            ck(!position.symbol.isEmpty)
        }

        return HeroValidationResult(passedChecks: passed, totalChecks: total)
    }
}
