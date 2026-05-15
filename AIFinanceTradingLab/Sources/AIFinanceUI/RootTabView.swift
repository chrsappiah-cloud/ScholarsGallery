import AIFinanceCore
import SwiftUI

public struct RootTabView: View {
    public let snapshot: DashboardSnapshot
    public let quotes: [Quote]
    public let chainAccounts: [ChainAccount]
    public let tokenHoldings: [TokenHolding]
    public let contractEvents: [SmartContractEvent]
    public let onChainAlerts: [OnChainAlert]
    public let analystNotes: [AnalystNote]
    public let complianceProfile: ComplianceProfile
    public let tokenizedAssets: [TokenizedAsset]
    public let backtests: [BacktestRun]
    @Binding public var pinnedSymbols: [String]
    @Binding public var mode: TradingMode
    @Binding public var apiBaseURLString: String
    /// Optional extra tab (e.g. SwiftData **Lab** surface in the app target). Omitted by default.
    private let labTabRoot: AnyView?

    public init(
        snapshot: DashboardSnapshot,
        quotes: [Quote],
        chainAccounts: [ChainAccount] = DemoData.chainAccounts,
        tokenHoldings: [TokenHolding] = DemoData.tokenHoldings,
        contractEvents: [SmartContractEvent] = DemoData.contractEvents,
        onChainAlerts: [OnChainAlert] = DemoData.onChainAlerts,
        analystNotes: [AnalystNote] = DemoData.analystNotes,
        complianceProfile: ComplianceProfile = ComplianceProfile(kycStatus: "approved", amlRiskScore: 0.14, jurisdiction: "AU", accreditedInvestor: true),
        tokenizedAssets: [TokenizedAsset] = DemoData.tokenizedAssets,
        backtests: [BacktestRun] = DemoData.backtests,
        pinnedSymbols: Binding<[String]>,
        mode: Binding<TradingMode>,
        apiBaseURLString: Binding<String>,
        labTabRoot: AnyView? = nil
    ) {
        self.snapshot = snapshot
        self.quotes = quotes
        self.chainAccounts = chainAccounts
        self.tokenHoldings = tokenHoldings
        self.contractEvents = contractEvents
        self.onChainAlerts = onChainAlerts
        self.analystNotes = analystNotes
        self.complianceProfile = complianceProfile
        self.tokenizedAssets = tokenizedAssets
        self.backtests = backtests
        self._pinnedSymbols = pinnedSymbols
        self._mode = mode
        self._apiBaseURLString = apiBaseURLString
        self.labTabRoot = labTabRoot
    }

    public var body: some View {
        TabView {
            ScholarsDashboardView(snapshot: snapshot, mode: $mode)
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            WatchlistView(pinnedSymbols: $pinnedSymbols, quotes: quotes)
                .tabItem { Label("Watchlist", systemImage: "star.fill") }

            CryptoRootView(
                accounts: chainAccounts,
                holdings: tokenHoldings,
                events: contractEvents,
                alerts: onChainAlerts
            )
            .tabItem { Label("On-Chain", systemImage: "hexagon.fill") }

            PortfolioView(positions: snapshot.unifiedPositions)
                .tabItem { Label("Portfolio", systemImage: "briefcase") }

            MoreView(
                analystNotes: analystNotes,
                complianceProfile: complianceProfile,
                tokenizedAssets: tokenizedAssets,
                backtests: backtests,
                mode: $mode,
                apiBaseURLString: $apiBaseURLString,
                pinnedSymbols: $pinnedSymbols,
                labJournalRoot: labTabRoot
            )
            .tabItem { Label("Hub", systemImage: "ellipsis.circle") }
        }
    }
}
