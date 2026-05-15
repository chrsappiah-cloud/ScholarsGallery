import AIFinanceCore
import SwiftUI

public struct CryptoRootView: View {
    public let accounts: [ChainAccount]
    public let holdings: [TokenHolding]
    public let events: [SmartContractEvent]
    public let alerts: [OnChainAlert]

    public init(accounts: [ChainAccount], holdings: [TokenHolding], events: [SmartContractEvent], alerts: [OnChainAlert]) {
        self.accounts = accounts
        self.holdings = holdings
        self.events = events
        self.alerts = alerts
    }

    public var body: some View {
        NavigationStack {
            List {
                if !alerts.isEmpty {
                    Section("On-Chain Alerts") {
                        ForEach(alerts) { alert in
                            OnChainAlertRow(alert: alert)
                        }
                    }
                }

                Section("Wallets") {
                    ForEach(accounts) { account in
                        NavigationLink {
                            WalletDetailView(account: account, holdings: holdings.filter { $0.chain == account.chain })
                        } label: {
                            WalletRow(account: account)
                        }
                    }
                }

                Section("Token Holdings") {
                    ForEach(holdings) { holding in
                        TokenHoldingRow(holding: holding)
                    }
                }

                Section("Contract Events") {
                    NavigationLink("View All Events (\(events.count))") {
                        SmartContractMonitorView(events: events)
                    }
                    ForEach(events.prefix(3)) { event in
                        ContractEventRow(event: event)
                    }
                }
            }
            .navigationTitle("Crypto & On-Chain")
        }
    }
}

public struct WalletRow: View {
    public let account: ChainAccount

    public var body: some View {
        HStack {
            Image(systemName: "wallet.bifold")
                .foregroundStyle(PearlTheme.diamond)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.label ?? account.chain)
                    .font(.subheadline.weight(.semibold))
                Text(account.address)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(account.balanceUSD, format: .currency(code: "USD"))
                    .font(.subheadline.monospacedDigit())
                Text(account.chain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

public struct WalletDetailView: View {
    public let account: ChainAccount
    public let holdings: [TokenHolding]

    public var body: some View {
        List {
            Section {
                LabeledContent("Chain", value: account.chain)
                LabeledContent("Address") {
                    Text(account.address)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                LabeledContent("Balance", value: account.balanceUSD, format: .currency(code: "USD"))
                LabeledContent("Last synced", value: account.lastSyncedAt, format: .relative(presentation: .named))
            } header: {
                Text(account.label ?? account.chain)
            }

            Section("Token Holdings") {
                if holdings.isEmpty {
                    Text("No tokens on \(account.chain)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(holdings) { holding in
                        TokenHoldingRow(holding: holding)
                    }
                }
            }
        }
        .navigationTitle(account.label ?? account.chain)
    }
}

public struct TokenHoldingRow: View {
    public let holding: TokenHolding

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(holding.symbol)
                        .font(.subheadline.weight(.semibold))
                    Text(holding.chain)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Text(holding.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.valueUSD, format: .currency(code: "USD"))
                    .font(.subheadline.monospacedDigit())
                Text("\(holding.quantity, specifier: "%.4f") \(holding.symbol)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

public struct SmartContractMonitorView: View {
    public let events: [SmartContractEvent]

    public init(events: [SmartContractEvent]) {
        self.events = events
    }

    public var body: some View {
        List(events) { event in
            ContractEventRow(event: event)
        }
        .navigationTitle("Contract Events")
    }
}

public struct ContractEventRow: View {
    public let event: SmartContractEvent

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.eventName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(event.timestamp, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(event.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(event.chain)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(PearlTheme.diamond.opacity(0.15), in: Capsule())
                    .foregroundStyle(PearlTheme.diamond)
                Text("Block \(event.blockNumber)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

public struct OnChainAlertRow: View {
    public let alert: OnChainAlert

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: severityIcon)
                .foregroundStyle(severityColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.weight(.semibold))
                Text(alert.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(alert.timestamp, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var severityIcon: String {
        switch alert.severity {
        case .critical: "exclamationmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch alert.severity {
        case .critical: .red
        case .warning: .orange
        case .info: PearlTheme.diamond
        }
    }
}
