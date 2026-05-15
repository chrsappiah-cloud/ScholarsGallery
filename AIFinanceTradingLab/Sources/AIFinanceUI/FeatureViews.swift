import AIFinanceCore
import SwiftUI

public struct ScholarsDashboardView: View {
    public let snapshot: DashboardSnapshot
    @Binding public var mode: TradingMode

    public init(snapshot: DashboardSnapshot, mode: Binding<TradingMode>) {
        self.snapshot = snapshot
        self._mode = mode
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(Array(snapshot.panels.enumerated()), id: \.element.id) { index, panel in
                            NavigationLink {
                                DashboardPanelDetailView(panel: panel)
                            } label: {
                                PearlCard(title: panel.title, icon: icon(for: index)) {
                                    Text(panel.detail)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                    Text(panel.caption)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(index == 2 ? PearlTheme.diamond : .secondary)
                                    if index == 1 {
                                        ProgressView(value: snapshot.risk.netExposure)
                                            .tint(PearlTheme.gold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dashboard_panel_\(index)")
                        }
                    }

                    PearlCard(title: "Top Signals", icon: "waveform.path.ecg") {
                        ForEach(snapshot.topSignals) { signal in
                            NavigationLink {
                                DashboardSignalDetailView(signal: signal)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(signal.symbol) • \(signal.action.uppercased())")
                                            .font(.caption.weight(.semibold))
                                        Text(signal.engine)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(signal.confidence * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(PearlTheme.gold)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dashboard_signal_\(signal.id.uuidString)")
                        }
                    }

                    PearlCard(title: "Unified Holdings", icon: "tray.full") {
                        ForEach(snapshot.unifiedPositions.prefix(3)) { position in
                            NavigationLink {
                                DashboardPositionDetailView(position: position)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(position.displayName)
                                            .font(.caption.weight(.semibold))
                                        Text("\(position.domain.rawValue.capitalized) • \(position.venue)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(position.marketValueUSD, format: .currency(code: "USD"))
                                        .font(.caption.monospacedDigit())
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dashboard_holding_row_\(position.id)")
                        }
                        NavigationLink {
                            UnifiedHoldingsListView(positions: snapshot.unifiedPositions)
                        } label: {
                            Label("View all holdings", systemImage: "chevron.right.circle")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("dashboard_holdings_see_all")
                    }
                }
                .padding(16)
            }
            .background(PearlTheme.boardGradient.ignoresSafeArea())
            .navigationTitle("Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .accessibilityIdentifier("dashboard_hero_root")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.headline)
                    .font(.title2.bold())
                Text(snapshot.subheadline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(TradingMode.allCases) { m in
                    Button {
                        mode = m
                    } label: {
                        if mode == m {
                            Label(m.rawValue.capitalized, systemImage: "checkmark.circle.fill")
                        } else {
                            Text(m.rawValue.capitalized)
                        }
                    }
                }
            } label: {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        HStack(spacing: 4) {
                            Circle().fill(PearlTheme.diamond).frame(width: 6, height: 6)
                            Text(mode.rawValue.capitalized)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                    )
                    .frame(height: 24)
            }
            .accessibilityIdentifier("dashboard_mode_picker")
        }
    }

    private func icon(for index: Int) -> String {
        switch index {
        case 0: "eye.trianglebadge.exclamationmark"
        case 1: "shield.lefthalf.filled"
        case 2: "hexagon.fill"
        default: "books.vertical"
        }
    }
}

// MARK: - Dashboard hero drill-downs

public struct DashboardPanelDetailView: View {
    public let panel: DashboardPanel

    public init(panel: DashboardPanel) {
        self.panel = panel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(panel.detail)
                    .font(.body)
                Text(panel.caption)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(panel.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("dashboard_panel_detail")
    }
}

public struct DashboardSignalDetailView: View {
    public let signal: Signal

    public init(signal: Signal) {
        self.signal = signal
    }

    public var body: some View {
        List {
            Section("Signal") {
                LabeledContent("Symbol", value: signal.symbol)
                LabeledContent("Action", value: signal.action.uppercased())
                LabeledContent("Confidence", value: "\(Int(signal.confidence * 100))%")
                LabeledContent("Engine", value: signal.engine)
            }
            if let explanation = signal.explanation, !explanation.isEmpty {
                Section("Rationale") {
                    Text(explanation)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(signal.symbol)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("dashboard_signal_detail")
    }
}

public struct DashboardPositionDetailView: View {
    public let position: UnifiedAssetPosition

    public init(position: UnifiedAssetPosition) {
        self.position = position
    }

    public var body: some View {
        List {
            Section("Position") {
                LabeledContent("Name", value: position.displayName)
                LabeledContent("Symbol", value: position.symbol)
                LabeledContent("Domain", value: position.domain.rawValue.capitalized)
                LabeledContent("Venue", value: position.venue)
                LabeledContent("Risk", value: position.riskLabel)
                LabeledContent("Quantity", value: String(format: "%.4f", position.quantity))
                LabeledContent("Market value", value: position.marketValueUSD.formatted(.currency(code: "USD")))
            }
        }
        .navigationTitle(position.symbol)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("dashboard_position_detail")
    }
}

public struct UnifiedHoldingsListView: View {
    public let positions: [UnifiedAssetPosition]

    public init(positions: [UnifiedAssetPosition]) {
        self.positions = positions
    }

    public var body: some View {
        List(positions) { position in
            NavigationLink {
                DashboardPositionDetailView(position: position)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(position.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(position.symbol) • \(position.venue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("dashboard_holdings_list_row_\(position.id)")
        }
        .navigationTitle("All holdings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("dashboard_holdings_list")
    }
}

public struct MarketsView: View {
    public let quotes: [Quote]

    public init(quotes: [Quote]) {
        self.quotes = quotes
    }

    public var body: some View {
        NavigationStack {
            List(quotes) { quote in
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.symbol)
                        .font(.headline)
                    Text("Bid \(quote.bid, format: .number.precision(.fractionLength(2))) • Ask \(quote.ask, format: .number.precision(.fractionLength(2))) • Last \(quote.last, format: .number.precision(.fractionLength(2)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Markets")
        }
    }
}


public struct PortfolioView: View {
    public let positions: [UnifiedAssetPosition]

    public init(positions: [UnifiedAssetPosition]) {
        self.positions = positions
    }

    public var body: some View {
        NavigationStack {
            List(positions) { position in
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.displayName)
                        .font(.headline)
                    Text("\(position.symbol) • \(position.riskLabel) • \(position.venue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(position.marketValueUSD, format: .currency(code: "USD"))
                        .font(.caption.monospacedDigit())
                }
            }
            .navigationTitle("Portfolio")
        }
    }
}

public struct MoreView: View {
    public let analystNotes: [AnalystNote]
    public let complianceProfile: ComplianceProfile
    public let tokenizedAssets: [TokenizedAsset]
    public let backtests: [BacktestRun]
    @Binding public var mode: TradingMode
    @Binding public var apiBaseURLString: String
    @Binding public var pinnedSymbols: [String]
    private let labJournalRoot: AnyView?

    public init(
        analystNotes: [AnalystNote],
        complianceProfile: ComplianceProfile,
        tokenizedAssets: [TokenizedAsset],
        backtests: [BacktestRun] = DemoData.backtests,
        mode: Binding<TradingMode>,
        apiBaseURLString: Binding<String>,
        pinnedSymbols: Binding<[String]>,
        labJournalRoot: AnyView? = nil
    ) {
        self.analystNotes = analystNotes
        self.complianceProfile = complianceProfile
        self.tokenizedAssets = tokenizedAssets
        self.backtests = backtests
        self._mode = mode
        self._apiBaseURLString = apiBaseURLString
        self._pinnedSymbols = pinnedSymbols
        self.labJournalRoot = labJournalRoot
    }

    public var body: some View {
        NavigationStack {
            List {
                if let labJournalRoot {
                    Section("Lab") {
                        NavigationLink {
                            labJournalRoot
                        } label: {
                            Label("Lab journal", systemImage: "testtube.2")
                        }
                        .accessibilityIdentifier("hub_lab_journal_link")
                    }
                }

                Section("Research & Intelligence") {
                    NavigationLink {
                        SocialIntelView(notes: analystNotes)
                    } label: {
                        Label("Social Intel", systemImage: "person.3.sequence.fill")
                    }
                    NavigationLink {
                        StrategiesLabView(backtests: backtests)
                    } label: {
                        Label("Strategies Lab", systemImage: "brain.head.profile")
                    }
                    NavigationLink {
                        BacktestsView(runs: backtests)
                    } label: {
                        Label("Backtests", systemImage: "clock.arrow.2.circlepath")
                    }
                }

                Section("Asset Markets") {
                    NavigationLink {
                        TokenizedAssetsView(assets: tokenizedAssets)
                    } label: {
                        Label("Tokenized Assets", systemImage: "doc.richtext")
                    }
                }

                Section("Account") {
                    NavigationLink {
                        ComplianceView(profile: complianceProfile)
                    } label: {
                        Label("Compliance & KYC", systemImage: "checkmark.shield.fill")
                    }
                    NavigationLink {
                        SettingsView(mode: $mode, apiBaseURL: $apiBaseURLString, pinnedSymbols: $pinnedSymbols)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Hub")
        }
    }
}
