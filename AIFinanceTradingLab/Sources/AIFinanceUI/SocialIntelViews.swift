import AIFinanceCore
import SwiftUI

public struct SocialIntelView: View {
    public let notes: [AnalystNote]

    public init(notes: [AnalystNote]) {
        self.notes = notes
    }

    public var body: some View {
        NavigationStack {
            List(notes) { note in
                NavigationLink {
                    AnalystNoteDetailView(note: note)
                } label: {
                    AnalystNoteRow(note: note)
                }
            }
            .navigationTitle("Social Intel")
        }
    }
}

public struct AnalystNoteRow: View {
    public let note: AnalystNote

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.authorHandle)
                    .font(.subheadline.weight(.semibold))
                if note.verifiedOnChain {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(PearlTheme.diamond)
                }
                Spacer()
                ReputationBadge(score: note.reputationScore)
            }
            HStack(spacing: 6) {
                SentimentPill(sentiment: note.sentiment)
                Text(note.symbol)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(note.publishedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(note.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

public struct AnalystNoteDetailView: View {
    public let note: AnalystNote

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(note.authorHandle)
                                .font(.headline)
                            if note.verifiedOnChain {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(PearlTheme.diamond)
                            }
                        }
                        Text(note.publishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ReputationBadge(score: note.reputationScore)
                }

                HStack(spacing: 8) {
                    SentimentPill(sentiment: note.sentiment)
                    Text(note.symbol)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Text(note.body)
                    .font(.body)

                if let hash = note.provenanceHash {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Label("On-chain provenance", systemImage: "link.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PearlTheme.diamond)
                        Text(hash)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Analyst Note")
    }
}

public struct ReputationBadge: View {
    public let score: Double

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 9))
            Text("\(Int(score * 100))")
                .font(.caption2.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(scoreColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(scoreColor.opacity(0.15), in: Capsule())
    }

    private var scoreColor: Color {
        if score >= 0.85 { return .green }
        if score >= 0.65 { return .orange }
        return .red
    }
}

public struct SentimentPill: View {
    public let sentiment: String

    public var body: some View {
        Text(sentiment.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(pillColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pillColor.opacity(0.15), in: Capsule())
    }

    private var pillColor: Color {
        switch sentiment.lowercased() {
        case "bullish": return .green
        case "bearish": return .red
        default: return .secondary
        }
    }
}

public struct ComplianceView: View {
    public let profile: ComplianceProfile

    public init(profile: ComplianceProfile) {
        self.profile = profile
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Identity & KYC") {
                    LabeledContent("KYC Status") {
                        HStack(spacing: 4) {
                            Image(systemName: profile.kycStatus == "approved" ? "checkmark.circle.fill" : "clock.fill")
                                .foregroundStyle(profile.kycStatus == "approved" ? .green : .orange)
                            Text(profile.kycStatus.capitalized)
                                .font(.subheadline)
                        }
                    }
                    LabeledContent("Jurisdiction", value: profile.jurisdiction)
                    LabeledContent("Accredited Investor", value: profile.accreditedInvestor ? "Yes" : "No")
                }

                Section("Risk") {
                    LabeledContent("AML Risk Score") {
                        HStack(spacing: 4) {
                            ProgressView(value: profile.amlRiskScore)
                                .tint(amlColor)
                                .frame(width: 80)
                            Text("\(Int(profile.amlRiskScore * 100))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(amlColor)
                        }
                    }
                }

                Section("Access") {
                    Label("Traditional Markets", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("Crypto & Digital Assets", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label(profile.accreditedInvestor ? "Tokenized Assets (Eligible)" : "Tokenized Assets (Not Eligible)", systemImage: profile.accreditedInvestor ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(profile.accreditedInvestor ? .green : .secondary)
                }
            }
            .navigationTitle("Compliance")
        }
    }

    private var amlColor: Color {
        if profile.amlRiskScore < 0.3 { return .green }
        if profile.amlRiskScore < 0.6 { return .orange }
        return .red
    }
}

public struct TokenizedAssetsView: View {
    public let assets: [TokenizedAsset]

    public init(assets: [TokenizedAsset]) {
        self.assets = assets
    }

    public var body: some View {
        NavigationStack {
            List(assets) { asset in
                TokenizedAssetRow(asset: asset)
            }
            .navigationTitle("Tokenized Assets")
        }
    }
}

public struct TokenizedAssetRow: View {
    public let asset: TokenizedAsset

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(asset.symbol) • \(asset.assetClass)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(asset.lastPriceUSD, format: .currency(code: "USD"))
                        .font(.subheadline.monospacedDigit())
                    SettlementStatePill(state: asset.settlementState)
                }
            }
            HStack(spacing: 6) {
                if let bid = asset.bidUSD, let ask = asset.askUSD {
                    Text("Bid \(bid, format: .number.precision(.fractionLength(2))) · Ask \(ask, format: .number.precision(.fractionLength(2)))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if asset.eligibilityRequired {
                    Label("Accredited", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

public struct SettlementStatePill: View {
    public let state: TokenizedAsset.SettlementState

    public var body: some View {
        Text(state.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(stateColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(stateColor.opacity(0.15), in: Capsule())
    }

    private var stateColor: Color {
        switch state {
        case .open: return PearlTheme.diamond
        case .pending: return .orange
        case .settled: return .green
        case .failed: return .red
        }
    }
}
