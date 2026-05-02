import SwiftUI

/// "Dola: Smart AI Assistant" — refines a Studio prompt before the user runs
/// `POST /api/artworks/generate`. Talks to the server route
/// `POST /api/dola/assist` (see `Server/Sources/App/DolaAssistantService.swift`).
///
/// The sheet returns its picked prompt to the parent via `onCommit`. The parent
/// (Studio view) is responsible for replacing the textfield prompt and triggering
/// generation.
struct DolaAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var galleryBackendMeta: GalleryBackendMetaModel

    let initialPrompt: String
    let onCommit: (String) -> Void

    @State private var prompt: String
    @State private var mood: DolaMoodChoice = .museum
    @State private var intent: DolaIntentChoice = .scene
    @State private var refined: DolaAssistantPayload?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(initialPrompt: String, onCommit: @escaping (String) -> Void) {
        self.initialPrompt = initialPrompt
        self.onCommit = onCommit
        _prompt = State(initialValue: initialPrompt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    Text(String(localized: "dola.editorTitle"))
                        .font(.headline)
                        .foregroundStyle(GalleryTheme.sapphireDark)
                    TextEditor(text: $prompt)
                        .accessibilityIdentifier("dola.promptEditor")
                        .frame(minHeight: 120)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(GalleryTheme.sapphire.opacity(0.22), lineWidth: 1)
                        )

                    Text(String(localized: "dola.moodTitle"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GalleryTheme.sapphireDark)
                    Picker(String(localized: "dola.moodTitle"), selection: $mood) {
                        ForEach(DolaMoodChoice.allCases, id: \.self) { choice in
                            Text(choice.localizedLabel).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(String(localized: "dola.intentTitle"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GalleryTheme.sapphireDark)
                    Picker(String(localized: "dola.intentTitle"), selection: $intent) {
                        ForEach(DolaIntentChoice.allCases, id: \.self) { choice in
                            Text(choice.localizedLabel).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        Task { await ask() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                        } else {
                            Label(String(localized: "dola.askButton"), systemImage: "wand.and.rays")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(GalleryProminentButtonStyle())
                    .accessibilityIdentifier("dola.askButton")
                    .disabled(
                        isLoading
                            || prompt.trimmingCharacters(in: .whitespacesAndNewlines).count < 6
                            || !(galleryBackendMeta.meta?.effectiveDolaAssistantEnabled ?? true)
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("dola.errorMessage")
                    }

                    if let refined {
                        refinedCard(refined)
                    }
                }
                .padding()
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle(String(localized: "dola.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "dola.cancel")) { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(GalleryTheme.accent)
                Text(String(localized: "dola.headerTitle"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(GalleryTheme.sapphireDark)
            }
            Text(String(localized: "dola.headerSubtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let meta = galleryBackendMeta.meta {
                Text(String(format: String(localized: "dola.providerFootnote"),
                            meta.effectiveDolaAssistantConfigured ? "openai" : "mock"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GalleryTheme.studioBannerGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(GalleryTheme.cardStroke.opacity(0.45), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            SparkleJewelOverlay().padding(10)
        }
    }

    private func refinedCard(_ payload: DolaAssistantPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "dola.refinedTitle"))
                .font(.headline)
                .foregroundStyle(GalleryTheme.sapphireDark)

            Text(payload.refinedPrompt)
                .accessibilityIdentifier("dola.refinedPrompt")
                .font(.callout)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !payload.suggestions.isEmpty {
                Text(String(localized: "dola.suggestionsTitle"))
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(payload.suggestions.enumerated()), id: \.offset) { idx, item in
                    Button {
                        commit(item)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb")
                                .foregroundStyle(GalleryTheme.accent)
                            Text(item)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dola.suggestion.\(idx)")
                }
            }

            if !payload.palette.isEmpty {
                Text(String(localized: "dola.paletteTitle"))
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(Array(payload.palette.enumerated()), id: \.offset) { _, hex in
                        DolaPaletteChip(hex: hex)
                    }
                    Spacer(minLength: 0)
                }
            }

            Button {
                commit(payload.refinedPrompt)
            } label: {
                Label(String(localized: "dola.useThisPrompt"), systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GalleryProminentButtonStyle())
            .accessibilityIdentifier("dola.commitButton")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GalleryTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                )
        )
        .galleryCardShadow()
    }

    private func commit(_ value: String) {
        onCommit(value)
        dismiss()
    }

    private func ask() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let payload = try await DolaAssistantAPI.assist(
                prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                mood: mood.serverValue,
                intent: intent.serverValue
            )
            refined = payload
        } catch DolaAssistantAPIError.policyDisabled {
            refined = nil
            errorMessage = String(localized: "dola.policyDisabled")
        } catch DolaAssistantAPIError.unreachable {
            refined = nil
            errorMessage = String(localized: "dola.unreachable")
        } catch {
            refined = nil
            errorMessage = String(localized: "dola.genericError")
        }
    }
}

// MARK: - Choices

enum DolaMoodChoice: String, CaseIterable {
    case dreamlike, museum, noir, warm, cool

    var localizedLabel: String {
        switch self {
        case .dreamlike: return String(localized: "dola.mood.dreamlike")
        case .museum:    return String(localized: "dola.mood.museum")
        case .noir:      return String(localized: "dola.mood.noir")
        case .warm:      return String(localized: "dola.mood.warm")
        case .cool:      return String(localized: "dola.mood.cool")
        }
    }

    var serverValue: String { rawValue }
}

enum DolaIntentChoice: String, CaseIterable {
    case portrait, scene, abstract

    var localizedLabel: String {
        switch self {
        case .portrait: return String(localized: "dola.intent.portrait")
        case .scene:    return String(localized: "dola.intent.scene")
        case .abstract: return String(localized: "dola.intent.abstract")
        }
    }

    var serverValue: String { rawValue }
}

// MARK: - Palette swatch

private struct DolaPaletteChip: View {
    let hex: String

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: hex) ?? GalleryTheme.sapphire.opacity(0.4))
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                )
            Text(hex.uppercased()).font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hex)
    }
}

private extension Color {
    init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6, let v = UInt64(clean, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >>  8) & 0xFF) / 255.0
        let b = Double( v        & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

// MARK: - Network

struct DolaAssistantPayload: Decodable, Equatable {
    let refinedPrompt: String
    let suggestions: [String]
    let palette: [String]
    let provider: String
}

enum DolaAssistantAPIError: Error {
    case policyDisabled
    case unreachable
    case decodeFailed
}

enum DolaAssistantAPI {
    private struct Request: Encodable {
        let prompt: String
        let mood: String?
        let intent: String?
    }

    static func assist(prompt: String, mood: String?, intent: String?) async throws -> DolaAssistantPayload {
        var request = URLRequest(url: GalleryAPIConfiguration.baseURL.appendingPathComponent("api/dola/assist"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = Request(prompt: prompt, mood: mood, intent: intent)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DolaAssistantAPIError.unreachable
        }
        if http.statusCode == 403 {
            throw DolaAssistantAPIError.policyDisabled
        }
        guard (200...299).contains(http.statusCode) else {
            throw DolaAssistantAPIError.unreachable
        }
        do {
            return try JSONDecoder().decode(DolaAssistantPayload.self, from: data)
        } catch {
            throw DolaAssistantAPIError.decodeFailed
        }
    }
}
