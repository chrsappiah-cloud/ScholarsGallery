import SwiftUI
import FoundationModels

// MARK: - Guided generation types (on-device Apple Intelligence)

@Generable
struct ScholarFlashcard: Equatable {
    @Guide(description: "A concise question suitable for spaced repetition.")
    var question: String
    @Guide(description: "A clear, respectful answer centering dignity and lived experience.")
    var answer: String
}

@Generable
struct ScholarFlashcardSet: Equatable {
    @Guide(description: "Short theme title for the card set.")
    var theme: String
    @Guide(description: "Equity-focused flashcards for scholars and carers.")
    var cards: [ScholarFlashcard]
}

/// On-device study coach using Apple Intelligence (`FoundationModels`).
/// Requires a supported device, Apple Intelligence enabled, and the system model ready (Wi‑Fi / power helps downloads).
struct OnDeviceScholarStudyCoachView: View {
    @AppStorage("scholarCoach.lastTopic") private var lastTopic = ""
    @State private var topic = ""
    @State private var session: LanguageModelSession?
    @State private var flashcards: ScholarFlashcardSet?
    @State private var isGenerating = false
    @State private var errorText: String?

    private let coachInstructions = """
    You support World Class Scholars and humane aged-care learning. \
    Center human rights, co-design, dignity, and lived experience. \
    Use plain, accessible language suitable for micro-credentials and training workshops.
    """

    var body: some View {
        Group {
            switch SystemLanguageModel.default.availability {
            case .available:
                availableContent
            case .unavailable(let reason):
                unavailableContent(reason: reason)
            }
        }
        .navigationTitle("Study Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if topic.isEmpty { topic = lastTopic }
            session = LanguageModelSession(instructions: coachInstructions)
            session?.prewarm()
        }
    }

    @ViewBuilder
    private func unavailableContent(reason: SystemLanguageModel.Availability.UnavailableReason) -> some View {
        let (title, detail) = unavailableCopy(for: reason)
        ContentUnavailableView(
            title,
            systemImage: "brain.head.profile",
            description: Text(detail)
        )
    }

    private func unavailableCopy(for reason: SystemLanguageModel.Availability.UnavailableReason) -> (String, String) {
        switch reason {
        case .deviceNotEligible:
            return ("Apple Intelligence unavailable", "This device needs a supported chip (for example A17 Pro or later on iPhone, or M-series on iPad).")
        case .appleIntelligenceNotEnabled:
            return ("Enable Apple Intelligence", "Turn on Apple Intelligence in Settings. It needs free storage (about 7 GB) and usually Wi‑Fi for the model download.")
        case .modelNotReady:
            return ("Model not ready", "The on-device model is still downloading or preparing. Keep the device on Wi‑Fi and power until setup completes.")
        @unknown default:
            return ("Apple Intelligence unavailable", String(describing: reason))
        }
    }

    private var availableContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Generate inclusive flashcards entirely on device—ideal for equity-focused lessons and care training.")
                    .font(.subheadline)
                    .foregroundStyle(GalleryTheme.textSecondary)

                TextField("Topic (e.g. trauma-aware communication in aged care)", text: $topic, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .tint(GalleryTheme.accent)

                Button {
                    Task { await generateFlashcards() }
                } label: {
                    if isGenerating {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Generate flashcards", systemImage: "rectangle.stack.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(GalleryProminentButtonStyle())
                .disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(GalleryTheme.rose)
                }

                if let flashcards {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(flashcards.theme)
                            .font(.headline)
                            .foregroundStyle(GalleryTheme.textPrimary)

                        ForEach(Array(flashcards.cards.enumerated()), id: \.offset) { _, card in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.question)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(GalleryTheme.textPrimary)
                                Text(card.answer)
                                    .font(.caption)
                                    .foregroundStyle(GalleryTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(GalleryAppBackground().ignoresSafeArea())
    }

    private func generateFlashcards() async {
        errorText = nil
        flashcards = nil
        isGenerating = true
        lastTopic = topic
        defer { isGenerating = false }

        guard let session else {
            errorText = "Session not ready."
            return
        }

        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptText = """
        Create exactly 5 flashcards for teaching and discussion. Topic: \(trimmed). \
        Center equity, dignity, and practical scenarios suitable for educators and carers.
        """

        let options = GenerationOptions(temperature: 0.65)

        do {
            let response = try await session.respond(
                to: promptText,
                generating: ScholarFlashcardSet.self,
                options: options
            )
            flashcards = response.content
        } catch let error as LanguageModelSession.GenerationError {
            errorText = error.recoverySuggestion ?? error.localizedDescription
        } catch {
            errorText = error.localizedDescription
        }
    }
}
