import AIFinanceCore
import SwiftUI

public struct StrategiesLabView: View {
    public let backtests: [BacktestRun]

    public init(backtests: [BacktestRun] = DemoData.backtests) {
        self.backtests = backtests
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Research Engines") {
                    NavigationLink {
                        DirectionalChangeView()
                    } label: {
                        Label("Directional Change", systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink {
                        MarkowitzView()
                    } label: {
                        Label("Markowitz Optimizer", systemImage: "chart.pie.fill")
                    }
                    NavigationLink {
                        RLSandboxView()
                    } label: {
                        Label("RL Sandbox (AlphaGo-inspired)", systemImage: "brain.filled.head.profile")
                    }
                }

                Section("Backtests") {
                    ForEach(backtests) { run in
                        BacktestRunRow(run: run)
                    }
                }
            }
            .navigationTitle("Strategies Lab")
        }
    }
}

public struct BacktestRunRow: View {
    public let run: BacktestRun

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(run.strategy)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                StatusBadge(status: run.status)
            }
            Text(run.symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                StatPill(label: "Return", value: run.totalReturn, format: .percent)
                StatPill(label: "Sharpe", value: run.sharpeRatio, format: .decimal)
                StatPill(label: "DD", value: run.maxDrawdown, format: .percent, negative: true)
            }
            Text("\(run.startDate) → \(run.endDate) · \(run.numTrades) trades")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

public struct DirectionalChangeView: View {
    @State private var threshold: Double = 0.01
    @State private var eventCount = 0
    @State private var upturnCount = 0
    @State private var downturnCount = 0

    private let samplePrices: [Double] = [
        100, 101.5, 103.2, 102.1, 100.8, 99.2, 97.5, 99.8, 102.4, 104.1,
        103.3, 101.7, 100.2, 98.9, 97.1, 99.5, 101.8, 103.6, 105.2, 104.0
    ]

    public init() {}

    public var body: some View {
        List {
            Section("Parameters") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Threshold")
                        Spacer()
                        Text("\(threshold * 100, specifier: "%.1f")%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(PearlTheme.diamond)
                    }
                    Slider(value: $threshold, in: 0.005...0.05, step: 0.005)
                        .tint(PearlTheme.diamond)
                        .onChange(of: threshold) { _, _ in compute() }
                }
            }

            Section("Results (sample series)") {
                LabeledContent("Total events", value: "\(eventCount)")
                LabeledContent("Upturns") {
                    Text("\(upturnCount)")
                        .foregroundStyle(.green)
                }
                LabeledContent("Downturns") {
                    Text("\(downturnCount)")
                        .foregroundStyle(.red)
                }
            }

            Section("Input Series") {
                Text(samplePrices.map { String(format: "%.1f", $0) }.joined(separator: ", "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Directional Change")
        .onAppear { compute() }
    }

    private func compute() {
        var events = 0
        var ups = 0
        var downs = 0
        var lastExtreme = samplePrices[0]
        var direction: String? = nil
        for price in samplePrices.dropFirst() {
            if direction == nil || direction == "down", price >= lastExtreme * (1 + threshold) {
                direction = "up"; lastExtreme = price; events += 1; ups += 1
            } else if direction == nil || direction == "up", price <= lastExtreme * (1 - threshold) {
                direction = "down"; lastExtreme = price; events += 1; downs += 1
            } else {
                if direction == "up", price > lastExtreme { lastExtreme = price }
                else if direction == "down", price < lastExtreme { lastExtreme = price }
            }
        }
        eventCount = events; upturnCount = ups; downturnCount = downs
    }
}

public struct MarkowitzView: View {
    @State private var riskAversion: Double = 1.0

    private let assets = ["SPY", "QQQ", "ETH", "BTC", "ENGY-RWA"]
    private let expectedReturns = [0.12, 0.15, 0.28, 0.35, 0.09]
    private var weights: [Double] {
        let mu = expectedReturns.map { $0 / max(riskAversion, 0.01) }
        let total = mu.reduce(0, +)
        guard total > 0 else { return [Double](repeating: 1.0 / Double(assets.count), count: assets.count) }
        return mu.map { max($0, 0) / total }
    }

    public init() {}

    public var body: some View {
        List {
            Section("Parameters") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Risk Aversion λ")
                        Spacer()
                        Text("\(riskAversion, specifier: "%.2f")")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(PearlTheme.gold)
                    }
                    Slider(value: $riskAversion, in: 0.1...5.0, step: 0.1)
                        .tint(PearlTheme.gold)
                }
            }

            Section("Optimal Weights") {
                ForEach(Array(zip(assets, weights)), id: \.0) { asset, weight in
                    HStack {
                        Text(asset)
                            .font(.subheadline)
                        Spacer()
                        ProgressView(value: weight)
                            .tint(PearlTheme.gold)
                            .frame(width: 80)
                        Text("\(Int(weight * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            Section("Expected Returns Input") {
                ForEach(Array(zip(assets, expectedReturns)), id: \.0) { asset, ret in
                    LabeledContent(asset, value: "\(Int(ret * 100))%")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Markowitz Optimizer")
    }
}

public struct RLSandboxView: View {
    @State private var stepCount = 0
    @State private var cumulativeReward: Double = 0
    @State private var lastAction = "hold"
    @State private var lastReward: Double = 0
    @State private var isRunning = false

    public init() {}

    public var body: some View {
        List {
            Section("Agent State") {
                LabeledContent("Steps taken", value: "\(stepCount)")
                LabeledContent("Cumulative reward") {
                    Text("\(cumulativeReward, specifier: "%.4f")")
                        .foregroundStyle(cumulativeReward >= 0 ? .green : .red)
                        .font(.caption.monospacedDigit())
                }
                LabeledContent("Last action") {
                    Text(lastAction.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(actionColor)
                }
                LabeledContent("Last reward") {
                    Text("\(lastReward, specifier: "%.4f")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(lastReward >= 0 ? .green : .red)
                }
            }

            Section("Actions") {
                HStack(spacing: 12) {
                    ForEach(["sell", "hold", "buy"], id: \.self) { action in
                        Button {
                            step(action: action)
                        } label: {
                            Text(action.uppercased())
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(actionBg(action), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button("Reset Environment") {
                    stepCount = 0; cumulativeReward = 0; lastAction = "hold"; lastReward = 0
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("RL Sandbox")
    }

    private func step(action: String) {
        let actions = ["sell": 0, "hold": 1, "buy": 2]
        let _ = actions[action] ?? 1
        let reward = Double.random(in: -0.02...0.02)
        lastReward = reward
        cumulativeReward += reward
        lastAction = action
        stepCount += 1
    }

    private var actionColor: Color {
        switch lastAction {
        case "buy": return .green
        case "sell": return .red
        default: return .secondary
        }
    }

    private func actionBg(_ action: String) -> Color {
        switch action {
        case "buy": return .green.opacity(0.15)
        case "sell": return .red.opacity(0.15)
        default: return PearlTheme.silver
        }
    }
}

public struct BacktestsView: View {
    public let runs: [BacktestRun]

    public init(runs: [BacktestRun] = DemoData.backtests) {
        self.runs = runs
    }

    public var body: some View {
        NavigationStack {
            List(runs) { run in
                BacktestRunRow(run: run)
            }
            .navigationTitle("Backtests")
        }
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        switch status {
        case "complete": return .green
        case "running": return PearlTheme.diamond
        case "failed": return .red
        default: return .secondary
        }
    }
}

struct StatPill: View {
    let label: String
    let value: Double
    let format: StatFormat
    var negative: Bool = false

    enum StatFormat { case percent, decimal }

    var body: some View {
        VStack(spacing: 1) {
            Text(formattedValue)
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }

    private var formattedValue: String {
        switch format {
        case .percent: return "\(negative ? "-" : "+")\(Int(value * 100))%"
        case .decimal: return String(format: "%.2f", value)
        }
    }

    private var color: Color {
        if negative { return .red }
        return value > 0 ? .green : .secondary
    }
}
