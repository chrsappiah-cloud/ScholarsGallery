import AIFinanceCore
import AIFinanceUI
import SwiftData
import SwiftUI

@main
struct AIFinanceTradingLabApp: App {
    @State private var state = AppState()

    private let modelContainer: ModelContainer = {
        let inUITests = ProcessInfo.processInfo.arguments.contains("-uitesting")
        let config = ModelConfiguration(isStoredInMemoryOnly: inUITests)
        do {
            return try ModelContainer(for: LabJournalNote.self, configurations: config)
        } catch {
            fatalError("SwiftData ModelContainer failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView(
                snapshot: state.snapshot,
                quotes: state.quotes,
                chainAccounts: state.chainAccounts,
                tokenHoldings: state.tokenHoldings,
                contractEvents: state.contractEvents,
                onChainAlerts: state.onChainAlerts,
                analystNotes: state.analystNotes,
                complianceProfile: state.complianceProfile,
                tokenizedAssets: state.tokenizedAssets,
                backtests: state.backtests,
                pinnedSymbols: $state.pinnedSymbols,
                mode: $state.mode,
                apiBaseURLString: $state.apiBaseURLString,
                labTabRoot: AnyView(LabJournalView())
            )
            .modelContainer(modelContainer)
            .onChange(of: state.mode) { _, newMode in
                guard state.snapshot.mode != newMode else { return }
                state.snapshot = DashboardSnapshot(
                    mode: newMode,
                    headline: state.snapshot.headline,
                    subheadline: state.snapshot.subheadline,
                    panels: state.snapshot.panels,
                    risk: state.snapshot.risk,
                    topSignals: state.snapshot.topSignals,
                    unifiedPositions: state.snapshot.unifiedPositions
                )
            }
        }
    }
}
