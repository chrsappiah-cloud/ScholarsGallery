import AIFinanceCore
import Foundation
import Observation

@Observable
final class AppState {
    var mode: TradingMode = .simulation
    var snapshot: DashboardSnapshot = DemoData.snapshot
    var quotes: [Quote] = DemoData.quotes
    var chainAccounts: [ChainAccount] = DemoData.chainAccounts
    var tokenHoldings: [TokenHolding] = DemoData.tokenHoldings
    var contractEvents: [SmartContractEvent] = DemoData.contractEvents
    var onChainAlerts: [OnChainAlert] = DemoData.onChainAlerts
    var analystNotes: [AnalystNote] = DemoData.analystNotes
    var tokenizedAssets: [TokenizedAsset] = DemoData.tokenizedAssets
    var backtests: [BacktestRun] = DemoData.backtests
    var complianceProfile: ComplianceProfile = ComplianceProfile(kycStatus: "approved", amlRiskScore: 0.14, jurisdiction: "AU", accreditedInvestor: true)
    var pinnedSymbols: [String] = ["AAPL", "MSFT", "NVDA", "TSLA", "BTC-USD", "ETH-USD"]
    var apiBaseURLString: String = "http://127.0.0.1:8000"
    var apiBaseURL: URL { URL(string: apiBaseURLString) ?? URL(string: "http://127.0.0.1:8000")! }

    var isRefreshing: Bool = false
    var lastRefreshError: String? = nil

    func toggleMode() {
        switch mode {
        case .simulation: mode = .paper
        case .paper: mode = .live
        case .live: mode = .simulation
        }
        snapshot = DashboardSnapshot(
            mode: mode,
            headline: snapshot.headline,
            subheadline: snapshot.subheadline,
            panels: snapshot.panels,
            risk: snapshot.risk,
            topSignals: snapshot.topSignals,
            unifiedPositions: snapshot.unifiedPositions
        )
    }

    /// Fetches live data from the backend gateway. Falls back to existing data on error.
    @MainActor
    func refreshFromAPI() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastRefreshError = nil
        let client = APIClient(baseURL: apiBaseURL)
        do {
            async let quotesTask     = client.fetchQuotes(symbols: pinnedSymbols)
            async let backtestsTask  = client.fetchBacktests()
            async let positionsTask  = client.fetchPositions()
            async let riskTask       = client.fetchRiskSnapshot()
            async let holdingsTask   = client.fetchTokenHoldings()
            async let alertsTask     = client.fetchOnChainAlerts()
            async let notesTask      = client.fetchAnalystNotes()

            let (liveQuotes, liveBacktests, livePositions, liveRisk, liveHoldings, liveAlerts, liveNotes) =
                try await (quotesTask, backtestsTask, positionsTask, riskTask, holdingsTask, alertsTask, notesTask)

            quotes           = liveQuotes
            backtests        = liveBacktests
            tokenHoldings    = liveHoldings
            onChainAlerts    = liveAlerts
            analystNotes     = liveNotes
            snapshot = DashboardSnapshot(
                mode: mode,
                headline: "Portfolio \(mode.rawValue.capitalized)",
                subheadline: "Updated \(Date().formatted(.dateTime.hour().minute()))",
                panels: snapshot.panels,
                risk: liveRisk,
                topSignals: snapshot.topSignals,
                unifiedPositions: livePositions
            )
        } catch {
            lastRefreshError = error.localizedDescription
        }
        isRefreshing = false
    }
}
