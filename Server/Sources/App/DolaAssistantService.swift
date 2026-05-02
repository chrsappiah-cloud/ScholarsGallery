import Foundation
import Vapor
import OpenAIConnector

/// Inputs the iOS Studio sends to the **Dola** smart assistant when refining
/// a generation prompt. `mood` and `intent` are optional hints surfaced from
/// the UI (chips, segmented controls, etc.) and folded into the system prompt.
struct DolaAssistRequest: Content {
    let prompt: String
    let mood: String?
    let intent: String?
}

/// What the assistant returns to the iOS Studio. The client may either
/// commit `refinedPrompt` directly into the existing image-generation flow,
/// or surface `suggestions` and `palette` as quick-pick chips for the user.
struct DolaAssistResponse: Content, Equatable {
    let refinedPrompt: String
    let suggestions: [String]
    let palette: [String]
    let provider: String
}

/// Persisted across the application; exposed via `Application.dolaAssistantService`.
/// Falls back to a deterministic `mock` provider when no OpenAI key is set so
/// that tests, CI, and local first-runs always return a usable refinement.
struct DolaAssistantService: Sendable {
    enum Provider: String, Sendable { case openai, mock }

    let provider: Provider
    let model: String
    private let openAI: OpenAIChatService?

    init(openAI: OpenAIChatService?, model: String) {
        self.openAI = openAI
        self.model = model
        self.provider = openAI == nil ? .mock : .openai
    }

    func assist(_ input: DolaAssistRequest) async throws -> DolaAssistResponse {
        let trimmed = input.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else {
            throw Abort(.badRequest, reason: "Dola needs at least a few words to work with.")
        }

        if let openAI {
            return try await openAIAssist(client: openAI, base: trimmed, mood: input.mood, intent: input.intent)
        }
        return Self.mockAssist(base: trimmed, mood: input.mood, intent: input.intent)
    }

    // MARK: - OpenAI path

    private func openAIAssist(
        client: OpenAIChatService,
        base: String,
        mood: String?,
        intent: String?
    ) async throws -> DolaAssistResponse {
        let system = """
        You are Dola, ScholarsGallery's Smart AI Assistant for image generation.
        Refine the user's idea into a vivid, specific prompt for an image model
        (gpt-image-1 / SDXL-class). Always reply with strict JSON of shape:
        {
          "refinedPrompt": String,
          "suggestions": [String],   // 3 short style/composition variations the user can try
          "palette":     [String]    // 3 to 5 hex color codes that fit the mood
        }
        Keep refinedPrompt under 480 characters. Do not include markdown.
        """

        var userParts: [String] = ["Idea: \(base)"]
        if let mood, !mood.isEmpty { userParts.append("Mood: \(mood)") }
        if let intent, !intent.isEmpty { userParts.append("Intent: \(intent)") }

        let messages: [OpenAIChatMessage] = [
            .init(role: "system", content: system),
            .init(role: "user", content: userParts.joined(separator: "\n")),
        ]

        let raw: String
        do {
            raw = try await client.complete(
                model: model,
                messages: messages,
                temperature: 0.65,
                jsonMode: true
            )
        } catch {
            throw Abort(.badGateway, reason: "Dola assistant is unreachable right now.")
        }

        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(DolaAssistantParsed.self, from: data) else {
            // Fall back to mock-style structuring so the iOS UI never sees a 5xx.
            return Self.mockAssist(base: base, mood: mood, intent: intent, provider: "openai-fallback")
        }
        return DolaAssistResponse(
            refinedPrompt: parsed.refinedPrompt.isEmpty ? base : parsed.refinedPrompt,
            suggestions: parsed.suggestions ?? [],
            palette: parsed.palette ?? [],
            provider: "openai"
        )
    }

    // MARK: - Mock path

    static func mockAssist(
        base: String,
        mood: String?,
        intent: String?,
        provider: String = "mock"
    ) -> DolaAssistResponse {
        let moodHint: String
        switch (mood ?? "").lowercased() {
        case let m where m.contains("dream"):  moodHint = "dreamlike, soft chromatic bloom"
        case let m where m.contains("noir"):   moodHint = "high-contrast noir, deep shadow play"
        case let m where m.contains("warm"):   moodHint = "golden-hour warmth, gentle film grain"
        case let m where m.contains("cool"):   moodHint = "cool tonal palette, glacial reflections"
        default:                                moodHint = "museum-quality lighting, painterly atmosphere"
        }

        let intentHint: String
        switch (intent ?? "").lowercased() {
        case let i where i.contains("portrait"): intentHint = "centered portrait composition"
        case let i where i.contains("scene"):    intentHint = "wide cinematic establishing shot"
        case let i where i.contains("abstract"): intentHint = "abstract geometric arrangement"
        default:                                  intentHint = "balanced rule-of-thirds composition"
        }

        let refined = "\(base.trimmingCharacters(in: .whitespacesAndNewlines)). " +
            "\(moodHint), \(intentHint). " +
            "Volumetric light, fine surface detail, gallery print suitable for a curated exhibition wall."

        let suggestions = [
            "Restage as a triptych of three moments in time",
            "Re-render in a high-contrast cyanotype style",
            "Add a single human silhouette to anchor the scale",
        ]

        let palette = ["#0F1B2D", "#1F4068", "#E8C547", "#C5283D", "#F4F1DE"]

        return DolaAssistResponse(
            refinedPrompt: refined,
            suggestions: suggestions,
            palette: palette,
            provider: provider
        )
    }
}

private struct DolaAssistantParsed: Decodable {
    let refinedPrompt: String
    let suggestions: [String]?
    let palette: [String]?
}

// MARK: - Application storage

private struct DolaAssistantServiceStorageKey: StorageKey {
    typealias Value = DolaAssistantService
}

extension Application {
    var dolaAssistantService: DolaAssistantService? {
        get { storage[DolaAssistantServiceStorageKey.self] }
        set { storage[DolaAssistantServiceStorageKey.self] = newValue }
    }
}
