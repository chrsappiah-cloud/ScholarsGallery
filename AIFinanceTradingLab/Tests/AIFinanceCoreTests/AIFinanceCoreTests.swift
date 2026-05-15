import Foundation
import Testing
@testable import AIFinanceCore

// MARK: - TradingMode

@Suite("TradingMode")
struct TradingModeTests {
    @Test func identityMatchesRawValue() {
        #expect(TradingMode.simulation.id == "simulation")
        #expect(TradingMode.paper.id == "paper")
        #expect(TradingMode.live.id == "live")
    }

    @Test func allCasesCount() {
        #expect(TradingMode.allCases.count == 3)
    }

    @Test func roundTripsJSON() throws {
        for mode in TradingMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(TradingMode.self, from: data)
            #expect(decoded == mode)
        }
    }
}

// MARK: - Quote

@Suite("Quote")
struct QuoteTests {
    @Test func spreadIsPositive() {
        let q = Quote(symbol: "AAPL", bid: 212.1, ask: 212.3, last: 212.2, timestamp: .now)
        #expect(q.ask > q.bid)
    }

    @Test func defaultUUIDIsUnique() {
        let a = Quote(symbol: "AAPL", bid: 1, ask: 2, last: 1.5, timestamp: .now)
        let b = Quote(symbol: "AAPL", bid: 1, ask: 2, last: 1.5, timestamp: .now)
        #expect(a.id != b.id)
    }

    @Test func roundTripsJSON() throws {
        let q = Quote(symbol: "BTC-USD", bid: 102_200, ask: 102_260, last: 102_240, timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(q)
        let decoded = try JSONDecoder().decode(Quote.self, from: data)
        #expect(decoded.symbol == q.symbol)
        #expect(decoded.bid == q.bid)
        #expect(decoded.ask == q.ask)
        #expect(decoded.last == q.last)
    }
}

// MARK: - Signal

@Suite("Signal")
struct SignalTests {
    @Test func confidenceInRange() {
        let s = Signal(symbol: "NVDA", action: "buy", confidence: 0.81, engine: "test")
        #expect(s.confidence >= 0 && s.confidence <= 1)
    }

    @Test func optionalExplanationNil() {
        let s = Signal(symbol: "X", action: "hold", confidence: 0.5, engine: "e")
        #expect(s.explanation == nil)
    }

    @Test func optionalExplanationSet() {
        let s = Signal(symbol: "X", action: "hold", confidence: 0.5, engine: "e", explanation: "reason")
        #expect(s.explanation == "reason")
    }
}

// MARK: - Position

@Suite("Position")
struct PositionTests {
    @Test func unrealizedPnLPreserved() {
        let p = Position(symbol: "SPY", quantity: 42, averagePrice: 510, marketValue: 22050, unrealizedPnL: 504)
        #expect(p.unrealizedPnL == 504)
    }

    @Test func roundTripsJSON() throws {
        let p = Position(symbol: "ETH", quantity: 6.5, averagePrice: 3000, marketValue: 19800, unrealizedPnL: 300)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Position.self, from: data)
        #expect(decoded.symbol == p.symbol)
        #expect(decoded.quantity == p.quantity)
    }
}

// MARK: - RiskSnapshot

@Suite("RiskSnapshot")
struct RiskSnapshotTests {
    @Test func valuesPreserved() {
        let r = RiskSnapshot(grossExposure: 0.74, netExposure: 0.42, maxDrawdown: 0.061, valueAtRisk95: 0.031, expectedShortfall95: 0.046)
        #expect(r.grossExposure == 0.74)
        #expect(r.netExposure == 0.42)
        #expect(r.maxDrawdown == 0.061)
        #expect(r.valueAtRisk95 == 0.031)
        #expect(r.expectedShortfall95 == 0.046)
    }

    @Test func expectedShortfallExceedsVaR() {
        let r = DemoData.snapshot.risk
        #expect(r.expectedShortfall95 > r.valueAtRisk95)
    }
}

// MARK: - ChainAccount

@Suite("ChainAccount")
struct ChainAccountTests {
    @Test func labelIsOptional() {
        let a = ChainAccount(id: "id", chain: "Ethereum", address: "0x1234", label: nil, balanceUSD: 100, lastSyncedAt: .now)
        #expect(a.label == nil)
    }

    @Test func hashable() {
        let a = ChainAccount(id: "a", chain: "Ethereum", address: "0x1", label: "Vault", balanceUSD: 1000, lastSyncedAt: .now)
        let b = ChainAccount(id: "a", chain: "Ethereum", address: "0x1", label: "Vault", balanceUSD: 1000, lastSyncedAt: a.lastSyncedAt)
        #expect(a == b)
    }

    @Test func demoDataNonEmpty() {
        #expect(!DemoData.chainAccounts.isEmpty)
        #expect(DemoData.chainAccounts.allSatisfy { $0.balanceUSD > 0 })
    }
}

// MARK: - TokenHolding

@Suite("TokenHolding")
struct TokenHoldingTests {
    @Test func valueApproximatelyQuantityTimesPrice() {
        for h in DemoData.tokenHoldings {
            let expected = h.quantity * h.priceUSD
            #expect(abs(h.valueUSD - expected) < 1.0)
        }
    }

    @Test func chainFieldNonEmpty() {
        #expect(DemoData.tokenHoldings.allSatisfy { !$0.chain.isEmpty })
    }
}

// MARK: - SmartContractEvent

@Suite("SmartContractEvent")
struct SmartContractEventTests {
    @Test func demoEventsHaveValidChains() {
        let validChains: Set<String> = ["Ethereum", "Base", "Polygon", "Arbitrum"]
        #expect(DemoData.contractEvents.allSatisfy { validChains.contains($0.chain) })
    }

    @Test func demoEventsHaveNonEmptyTxHash() {
        #expect(DemoData.contractEvents.allSatisfy { !$0.txHash.isEmpty })
    }

    @Test func blockNumbersPositive() {
        #expect(DemoData.contractEvents.allSatisfy { $0.blockNumber > 0 })
    }
}

// MARK: - ComplianceProfile

@Suite("ComplianceProfile")
struct ComplianceProfileTests {
    @Test func memberInit() {
        let p = ComplianceProfile(kycStatus: "approved", amlRiskScore: 0.14, jurisdiction: "AU", accreditedInvestor: true)
        #expect(p.kycStatus == "approved")
        #expect(p.amlRiskScore == 0.14)
        #expect(p.jurisdiction == "AU")
        #expect(p.accreditedInvestor == true)
    }

    @Test func amlRiskScoreInRange() {
        let p = ComplianceProfile(kycStatus: "approved", amlRiskScore: 0.14, jurisdiction: "AU", accreditedInvestor: true)
        #expect(p.amlRiskScore >= 0 && p.amlRiskScore <= 1)
    }

    @Test func roundTripsJSON() throws {
        let p = ComplianceProfile(kycStatus: "pending", amlRiskScore: 0.55, jurisdiction: "US", accreditedInvestor: false)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(ComplianceProfile.self, from: data)
        #expect(decoded == p)
    }
}

// MARK: - UnifiedAssetPosition

@Suite("UnifiedAssetPosition")
struct UnifiedAssetPositionTests {
    @Test func domainsInDemoData() {
        let domains = Set(DemoData.snapshot.unifiedPositions.map(\.domain))
        #expect(domains.contains(.traditional))
        #expect(domains.contains(.crypto))
        #expect(domains.contains(.tokenized))
    }

    @Test func assetDomainRoundTripsJSON() throws {
        for domain in AssetDomain.allCases {
            let data = try JSONEncoder().encode(domain)
            let decoded = try JSONDecoder().decode(AssetDomain.self, from: data)
            #expect(decoded == domain)
        }
    }

    @Test func marketValuePositive() {
        #expect(DemoData.snapshot.unifiedPositions.allSatisfy { $0.marketValueUSD > 0 })
    }
}

// MARK: - OnChainAlert

@Suite("OnChainAlert")
struct OnChainAlertTests {
    @Test func severityRoundTripsJSON() throws {
        for sev in [OnChainAlert.AlertSeverity.info, .warning, .critical] {
            let data = try JSONEncoder().encode(sev)
            let decoded = try JSONDecoder().decode(OnChainAlert.AlertSeverity.self, from: data)
            #expect(decoded == sev)
        }
    }

    @Test func demoAlertsHaveNonEmptyTitles() {
        #expect(DemoData.onChainAlerts.allSatisfy { !$0.title.isEmpty })
    }

    @Test func demoAlertsTxHashOptional() {
        // At least one alert should have nil txHash (system-level alert, no specific tx)
        #expect(DemoData.onChainAlerts.contains { $0.txHash == nil })
    }
}

// MARK: - AnalystNote

@Suite("AnalystNote")
struct AnalystNoteTests {
    @Test func reputationScoreInRange() {
        #expect(DemoData.analystNotes.allSatisfy { $0.reputationScore >= 0 && $0.reputationScore <= 1 })
    }

    @Test func verifiedNotesHaveProvenanceHash() {
        for note in DemoData.analystNotes where note.verifiedOnChain {
            #expect(note.provenanceHash != nil)
        }
    }

    @Test func authorHandlesNonEmpty() {
        #expect(DemoData.analystNotes.allSatisfy { !$0.authorHandle.isEmpty })
    }

    @Test func sentimentsAreValid() {
        let valid: Set<String> = ["bullish", "bearish", "neutral"]
        #expect(DemoData.analystNotes.allSatisfy { valid.contains($0.sentiment) })
    }
}

// MARK: - TokenizedAsset

@Suite("TokenizedAsset")
struct TokenizedAssetTests {
    @Test func demoAssetsHaveValidSettlementStates() {
        let validStates: Set<TokenizedAsset.SettlementState> = [.open, .pending, .settled, .failed]
        #expect(DemoData.tokenizedAssets.allSatisfy { validStates.contains($0.settlementState) })
    }

    @Test func bidBelowAsk() {
        for asset in DemoData.tokenizedAssets {
            if let bid = asset.bidUSD, let ask = asset.askUSD {
                #expect(bid < ask)
            }
        }
    }

    @Test func lastPriceWithinSpread() {
        for asset in DemoData.tokenizedAssets {
            if let bid = asset.bidUSD, let ask = asset.askUSD {
                #expect(asset.lastPriceUSD >= bid && asset.lastPriceUSD <= ask)
            }
        }
    }

    @Test func settlementStateRoundTripsJSON() throws {
        for state in [TokenizedAsset.SettlementState.open, .pending, .settled, .failed] {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(TokenizedAsset.SettlementState.self, from: data)
            #expect(decoded == state)
        }
    }
}

// MARK: - BacktestRun

@Suite("BacktestRun")
struct BacktestRunTests {
    @Test func demoBacktestsHavePositiveSharpe() {
        #expect(DemoData.backtests.allSatisfy { $0.sharpeRatio > 0 })
    }

    @Test func maxDrawdownInRange() {
        #expect(DemoData.backtests.allSatisfy { $0.maxDrawdown >= 0 && $0.maxDrawdown < 1 })
    }

    @Test func numTradesPositive() {
        #expect(DemoData.backtests.allSatisfy { $0.numTrades > 0 })
    }

    @Test func codingKeysMapCorrectly() throws {
        let run = DemoData.backtests[0]
        let data = try JSONEncoder().encode(run)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["total_return"] != nil)
        #expect(json["sharpe_ratio"] != nil)
        #expect(json["max_drawdown"] != nil)
        #expect(json["num_trades"] != nil)
        #expect(json["start_date"] != nil)
        #expect(json["end_date"] != nil)
    }
}

// MARK: - DirectionalChangeEvent

@Suite("DirectionalChangeEvent")
struct DirectionalChangeEventTests {
    @Test func typeIsUpturnOrDownturn() {
        let up = DirectionalChangeEvent(index: 3, type: "upturn", price: 105.0)
        let down = DirectionalChangeEvent(index: 7, type: "downturn", price: 98.0)
        #expect(up.type == "upturn")
        #expect(down.type == "downturn")
    }

    @Test func roundTripsJSON() throws {
        let e = DirectionalChangeEvent(index: 5, type: "upturn", price: 102.5)
        let data = try JSONEncoder().encode(e)
        let decoded = try JSONDecoder().decode(DirectionalChangeEvent.self, from: data)
        #expect(decoded == e)
    }
}

// MARK: - SignalRequest

@Suite("SignalRequest")
struct SignalRequestTests {
    @Test func encodesModeAndFeatures() throws {
        let req = SignalRequest(symbol: "ETH-USD", mode: TradingMode.simulation.rawValue, features: ["dc_count": 4, "volatility": 0.23])
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(SignalRequest.self, from: data)
        #expect(decoded == req)
    }

    @Test func emptyFeaturesAllowed() throws {
        let req = SignalRequest(symbol: "BTC", mode: "paper", features: [:])
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(SignalRequest.self, from: data)
        #expect(decoded.features.isEmpty)
    }
}

// MARK: - DashboardSnapshot

@Suite("DashboardSnapshot")
struct DashboardSnapshotTests {
    @Test func demoSnapshotPanelCount() {
        #expect(DemoData.snapshot.panels.count == 4)
    }

    @Test func demoSnapshotTopSignalsCount() {
        #expect(DemoData.snapshot.topSignals.count == 2)
    }

    @Test func demoSnapshotUnifiedPositionsAllDomains() {
        let domains = Set(DemoData.snapshot.unifiedPositions.map(\.domain))
        #expect(domains.count == 3)
    }

    @Test func demoQuotesNonEmpty() {
        #expect(!DemoData.quotes.isEmpty)
    }

    @Test func demoModeIsSimulation() {
        #expect(DemoData.snapshot.mode == .simulation)
    }
}

// MARK: - ServiceClients

@Suite("ServiceClients")
struct ServiceClientTests {
    @Test func blockchainServiceReturnsTwoAccounts() {
        let svc = BlockchainService()
        let accounts = svc.chainAccounts()
        #expect(accounts.count == 2)
        #expect(accounts.allSatisfy { !$0.chain.isEmpty })
    }

    @Test func walletServiceReturnsHoldings() {
        let svc = WalletService()
        let holdings = svc.holdings()
        #expect(!holdings.isEmpty)
        #expect(holdings.allSatisfy { $0.valueUSD > 0 })
    }

    @Test func complianceServiceApprovedProfile() {
        let svc = ComplianceService()
        let profile = svc.activeProfile()
        #expect(profile.kycStatus == "approved")
        #expect(profile.amlRiskScore < 0.5)
    }

    @Test func smartContractServiceReturnsEvents() {
        let svc = SmartContractService()
        let events = svc.recentEvents()
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { !$0.eventName.isEmpty })
    }

    @Test func smartContractServiceReturnsAlerts() {
        let svc = SmartContractService()
        let alerts = svc.alerts()
        #expect(!alerts.isEmpty)
    }

    @Test func socialIntelServiceReturnsAllNotes() {
        let svc = SocialIntelService()
        let notes = svc.analystNotes()
        #expect(!notes.isEmpty)
    }

    @Test func socialIntelServiceFiltersBySymbol() {
        let svc = SocialIntelService()
        let ethNotes = svc.analystNotes(symbol: "ETH")
        #expect(ethNotes.allSatisfy { $0.symbol == "ETH" })
    }

    @Test func socialIntelServiceUnknownSymbolReturnsEmpty() {
        let svc = SocialIntelService()
        let notes = svc.analystNotes(symbol: "DOESNOTEXIST")
        #expect(notes.isEmpty)
    }

    @Test func tokenizedAssetServiceReturnsAssets() {
        let svc = TokenizedAssetService()
        let assets = svc.availableAssets()
        #expect(!assets.isEmpty)
        #expect(assets.allSatisfy { !$0.symbol.isEmpty })
    }
}

// MARK: - APIClient (mock session)

@Suite("APIClient")
struct APIClientTests {
    final class MockSession: URLSessioning, @unchecked Sendable {
        var responseData: Data = Data()
        var responseURL: URL?

        func data(from url: URL) async throws -> (Data, URLResponse) {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            let url = request.url ?? URL(string: "http://localhost")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }
    }

    @Test func baseURLStoredCorrectly() {
        let url = URL(string: "http://localhost:8000")!
        let client = APIClient(baseURL: url)
        #expect(client.baseURL == url)
    }

    @Test func fetchQuotesDecodesResponse() async throws {
        let session = MockSession()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let quotes = [Quote(symbol: "AAPL", bid: 212.1, ask: 212.3, last: 212.2, timestamp: Date(timeIntervalSince1970: 1_700_000_000))]
        session.responseData = try encoder.encode(quotes)

        let client = APIClient(baseURL: URL(string: "http://localhost:8000")!, session: session)
        let result = try await client.fetchQuotes(symbols: ["AAPL"])
        #expect(result.count == 1)
        #expect(result[0].symbol == "AAPL")
        #expect(result[0].bid == 212.1)
    }

    @Test func fetchSignalDecodesResponse() async throws {
        let session = MockSession()
        let signal = Signal(symbol: "NVDA", action: "buy", confidence: 0.81, engine: "test", explanation: nil)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        session.responseData = try encoder.encode(signal)

        let client = APIClient(baseURL: URL(string: "http://localhost:8000")!, session: session)
        let result = try await client.fetchSignal(symbol: "NVDA", features: ["ma_fast": 210, "ma_slow": 205], mode: .simulation)
        #expect(result.symbol == "NVDA")
        #expect(result.action == "buy")
        #expect(result.confidence == 0.81)
    }

    @Test func fetchPositionsDecodesUnifiedPositions() async throws {
        let session = MockSession()
        let positions = DemoData.snapshot.unifiedPositions
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        session.responseData = try encoder.encode(positions)

        let client = APIClient(baseURL: URL(string: "http://localhost:8000")!, session: session)
        let result = try await client.fetchPositions()
        #expect(result.count == positions.count)
    }

    @Test func fetchChainAccountsDecodes() async throws {
        let session = MockSession()
        let accounts = DemoData.chainAccounts
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        session.responseData = try encoder.encode(accounts)

        let client = APIClient(baseURL: URL(string: "http://localhost:8000")!, session: session)
        let result = try await client.fetchChainAccounts()
        #expect(result.count == accounts.count)
        #expect(result[0].chain == accounts[0].chain)
    }

    @Test func fetchAnalystNotesDecodes() async throws {
        let session = MockSession()
        let notes = DemoData.analystNotes
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        session.responseData = try encoder.encode(notes)

        let client = APIClient(baseURL: URL(string: "http://localhost:8000")!, session: session)
        let result = try await client.fetchAnalystNotes()
        #expect(result.count == notes.count)
    }

    @Test func runMarkowitzDecodesWeights() async throws {
        let session = MockSession()
        struct WeightsResponse: Encodable { let weights: [Double] }
        session.responseData = try JSONEncoder().encode(WeightsResponse(weights: [0.4, 0.35, 0.25]))

        let client = APIClient(baseURL: URL(string: "http://localhost:8000")!, session: session)
        let weights = try await client.runMarkowitz(
            expectedReturns: [0.12, 0.15, 0.28],
            covMatrix: [[0.04, 0, 0], [0, 0.06, 0], [0, 0, 0.10]],
            riskAversion: 1.0
        )
        #expect(weights.count == 3)
        #expect(abs(weights.reduce(0, +) - 1.0) < 0.001)
    }
}

// MARK: - Dashboard hero (Dashboard tab contract)

@Suite("DashboardHeroValidator")
struct DashboardHeroValidatorTests {
    @Test func demoSnapshotQualityAtLeastNinetyFivePercent() {
        let result = DashboardHeroValidator.validateHeroSnapshot(DemoData.snapshot)
        #expect(result.totalChecks > 0)
        #expect(result.qualityRatio >= 0.95)
    }

    @Test func demoSnapshotPassesEveryHeroCheck() {
        let result = DashboardHeroValidator.validateHeroSnapshot(DemoData.snapshot)
        #expect(result.passedChecks == result.totalChecks)
    }

    @Test func brokenSnapshotDropsBelowNinetyFivePercent() {
        let bad = DashboardSnapshot(
            mode: .simulation,
            headline: "",
            subheadline: "x",
            panels: [],
            risk: RiskSnapshot(grossExposure: -1, netExposure: 0, maxDrawdown: 0, valueAtRisk95: 0.05, expectedShortfall95: 0.02),
            topSignals: [],
            unifiedPositions: []
        )
        let result = DashboardHeroValidator.validateHeroSnapshot(bad)
        #expect(result.qualityRatio < 0.95)
    }
}
