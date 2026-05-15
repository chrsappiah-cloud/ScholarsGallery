import AIFinanceCore
import SwiftUI

// MARK: - Watchlist

public struct WatchlistView: View {
    @Binding public var pinnedSymbols: [String]
    public let quotes: [Quote]

    @State private var searchText = ""
    @State private var showAddSheet = false

    private let suggestedSymbols = ["AAPL", "MSFT", "NVDA", "TSLA", "GOOGL", "AMZN", "META", "SPY", "QQQ", "BTC-USD", "ETH-USD", "ENGY-RWA"]

    public init(pinnedSymbols: Binding<[String]>, quotes: [Quote]) {
        self._pinnedSymbols = pinnedSymbols
        self.quotes = quotes
    }

    public var body: some View {
        NavigationStack {
            List {
                if !pinnedSymbols.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedSymbols, id: \.self) { symbol in
                            WatchlistRow(symbol: symbol, quote: quotes.first { $0.symbol == symbol })
                        }
                        .onDelete { idx in pinnedSymbols.remove(atOffsets: idx) }
                        .onMove { from, to in pinnedSymbols.move(fromOffsets: from, toOffset: to) }
                    }
                }

                Section("Suggested") {
                    ForEach(filtered(suggestedSymbols), id: \.self) { symbol in
                        HStack {
                            Text(symbol)
                                .font(.subheadline)
                            Spacer()
                            if pinnedSymbols.contains(symbol) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button {
                                    pinnedSymbols.append(symbol)
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(PearlTheme.diamond)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search symbols")
            .navigationTitle("Watchlist")
            #if os(iOS)
            .toolbar { EditButton() }
            #endif
        }
    }

    private func filtered(_ symbols: [String]) -> [String] {
        guard !searchText.isEmpty else { return symbols }
        return symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
}

public struct WatchlistRow: View {
    public let symbol: String
    public let quote: Quote?

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.subheadline.weight(.semibold))
                if let q = quote {
                    Text("Bid \(q.bid, format: .number.precision(.fractionLength(2))) · Ask \(q.ask, format: .number.precision(.fractionLength(2)))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let q = quote {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(q.last, format: .number.precision(.fractionLength(2)))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                    Text(q.timestamp, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("—")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Settings

public struct SettingsView: View {
    @Binding public var mode: TradingMode
    @Binding public var apiBaseURL: String
    @Binding public var pinnedSymbols: [String]

    public init(mode: Binding<TradingMode>, apiBaseURL: Binding<String>, pinnedSymbols: Binding<[String]>) {
        self._mode = mode
        self._apiBaseURL = apiBaseURL
        self._pinnedSymbols = pinnedSymbols
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Trading Mode") {
                    Picker("Mode", selection: $mode) {
                        ForEach(TradingMode.allCases) { m in
                            Text(m.rawValue.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    modeDescription
                }

                Section("API Endpoint") {
                    TextField("Base URL", text: $apiBaseURL)
                        .font(.caption.monospaced())
                        .autocorrectionDisabled()
                    Text("All broker credentials are stored server-side. This URL points to the backend gateway only.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Watchlist Symbols") {
                    ForEach(pinnedSymbols, id: \.self) { symbol in
                        Label(symbol, systemImage: "star.fill")
                            .font(.subheadline)
                    }
                    .onDelete { idx in pinnedSymbols.remove(atOffsets: idx) }
                    if pinnedSymbols.isEmpty {
                        Text("No pinned symbols. Add from the Watchlist tab.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    LabeledContent("Platform", value: "AI Finance Trading Lab")
                    LabeledContent("Version", value: "0.1.0-alpha")
                    LabeledContent("Build", value: "Phase 1 — AI Finance Core")
                    LabeledContent("Broker support", value: "Alpaca · IBKR (simulation)")
                }

                Section {
                    Label("Simulation: historical/synthetic data, no real orders", systemImage: "doc.text")
                    Label("Paper: real market data, simulated orders only", systemImage: "doc.badge.clock")
                    Label("Live: requires compliance approval and risk limits", systemImage: "lock.shield")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
        }
    }

    private var modeDescription: some View {
        HStack(spacing: 6) {
            Image(systemName: modeIcon)
                .foregroundStyle(modeColor)
            Text(modeText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modeIcon: String {
        switch mode {
        case .simulation: return "clock.arrow.2.circlepath"
        case .paper: return "doc.badge.clock"
        case .live: return "exclamationmark.triangle.fill"
        }
    }

    private var modeColor: Color {
        switch mode {
        case .simulation: return PearlTheme.diamond
        case .paper: return .orange
        case .live: return .red
        }
    }

    private var modeText: String {
        switch mode {
        case .simulation: return "Safe to experiment — no real capital at risk."
        case .paper: return "Real prices, simulated execution. No real capital."
        case .live: return "Real capital. Requires compliance sign-off."
        }
    }
}
