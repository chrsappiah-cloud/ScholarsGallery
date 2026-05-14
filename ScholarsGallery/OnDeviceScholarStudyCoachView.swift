import SwiftUI
import FoundationModels

// MARK: - Guided generation types

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

@Generable
struct ScholarLessonPlan: Equatable {
    @Guide(description: "A short title for the learning experience.")
    var title: String
    @Guide(description: "The intended learner group or audience.")
    var audience: String
    @Guide(description: "Clear learning objectives written in plain language.")
    var objectives: [String]
    @Guide(description: "Practical, humane activities for the workshop or module.")
    var activities: [ScholarLessonActivity]
    @Guide(description: "One reflective closing question for learners.")
    var reflectionPrompt: String
}

@Generable
struct ScholarLessonActivity: Equatable {
    @Guide(description: "Short activity title.")
    var title: String
    @Guide(description: "Why the activity matters.")
    var purpose: String
    @Guide(description: "Facilitator steps or learner steps.")
    var steps: [String]
}

@Generable
struct ScholarCoachReply: Equatable {
    @Guide(description: "A direct, practical answer to the follow-up question.")
    var answer: String
    @Guide(description: "One short next step the learner or educator can take.")
    var nextStep: String
}

struct ScholarCoachTranscriptEntry: Identifiable, Equatable {
    enum Role: Equatable {
        case learner
        case coach
    }

    let id = UUID()
    let role: Role
    let text: String
}

enum ScholarCoachMode: String, CaseIterable, Identifiable {
    case flashcards
    case lessonPlan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flashcards: return "Flashcards"
        case .lessonPlan: return "Lesson"
        }
    }

    var systemImage: String {
        switch self {
        case .flashcards: return "rectangle.stack.badge.plus"
        case .lessonPlan: return "list.bullet.rectangle.portrait"
        }
    }

    var actionTitle: String {
        switch self {
        case .flashcards: return "Generate flashcards"
        case .lessonPlan: return "Stream lesson plan"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .flashcards: return "No flashcards yet"
        case .lessonPlan: return "No lesson plan yet"
        }
    }
}

struct ScholarCoachResource: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let note: String
    let keywords: [String]
}

enum ScholarCoachResourceCatalog {
    static let all: [ScholarCoachResource] = [
        ScholarCoachResource(
            id: "dignity",
            title: "Dignity-first care",
            summary: "Use strengths-based language and preserve agency.",
            note: "Center dignity, consent, and autonomy. Avoid deficit framing and include practical choices people can still make.",
            keywords: ["dignity", "autonomy", "consent", "rights", "person-centred", "person-centered"]
        ),
        ScholarCoachResource(
            id: "trauma-aware",
            title: "Trauma-aware communication",
            summary: "Reduce shame, coercion, and avoidable triggers.",
            note: "Use psychologically safe wording, offer predictability, and avoid language that blames, pressures, or retraumatises learners or carers.",
            keywords: ["trauma", "communication", "psychological safety", "trigger", "de-escalation", "trust"]
        ),
        ScholarCoachResource(
            id: "lived-experience",
            title: "Lived experience and co-design",
            summary: "Include families, carers, and people with lived experience.",
            note: "Treat lived experience as expertise. Invite reflection, shared decision-making, and culturally responsive practice.",
            keywords: ["lived experience", "co-design", "family", "carer", "culture", "community", "equity"]
        ),
        ScholarCoachResource(
            id: "dementia",
            title: "Dementia support",
            summary: "Use calm routines, validation, and accessible cues.",
            note: "Prioritise reassurance, plain language, visual cues, and environmental support over correction or confrontation.",
            keywords: ["dementia", "memory", "aged care", "care", "reassurance", "validation"]
        ),
        ScholarCoachResource(
            id: "microcredential",
            title: "Micro-credential design",
            summary: "Keep modules short, measurable, and discussion-ready.",
            note: "Design for short learning bursts, clear objectives, reflective practice, and activities that can work in workshops or asynchronous study.",
            keywords: ["micro-credential", "module", "lesson", "objective", "assessment", "workshop"]
        )
    ]

    static func suggested(for topic: String) -> [ScholarCoachResource] {
        let normalized = topic.lowercased()
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Array(all.prefix(3))
        }

        let scored = all.map { resource in
            let keywordHits = resource.keywords.reduce(into: 0) { result, keyword in
                if normalized.contains(keyword.lowercased()) { result += 2 }
            }
            let titleHit = normalized.contains(resource.title.lowercased()) ? 1 : 0
            return (resource, keywordHits + titleHit)
        }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.title < rhs.0.title
            }
            return lhs.1 > rhs.1
        }

        let matched = scored.filter { $0.1 > 0 }.map(\.0)
        return Array((matched.isEmpty ? all : matched).prefix(3))
    }
}

enum ScholarCoachPromptBuilder {
    static func generationPrompt(
        topic: String,
        mode: ScholarCoachMode,
        groundingNotes: [ScholarCoachResource]
    ) -> String {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let grounding = groundingNotes.isEmpty
            ? ""
            : "\nGrounding notes:\n" + groundingNotes.map { "- \($0.note)" }.joined(separator: "\n")

        switch mode {
        case .flashcards:
            return """
            Create exactly 5 flashcards for teaching and discussion.
            Topic: \(trimmedTopic).
            Keep each answer practical, plain-spoken, and suitable for equity-focused aged-care or scholar training.\(grounding)
            """
        case .lessonPlan:
            return """
            Design a short micro-credential style lesson plan.
            Topic: \(trimmedTopic).
            Include practical objectives, discussion-ready activities, and a reflective close suitable for educators, carers, or scholar cohorts.\(grounding)
            """
        }
    }

    static func followUpPrompt(
        question: String,
        topic: String,
        mode: ScholarCoachMode
    ) -> String {
        """
        We are continuing a \(mode.label.lowercased()) session about "\(topic.trimmingCharacters(in: .whitespacesAndNewlines))".
        Answer the learner's follow-up in a warm, concise way and end with one practical next step.
        Learner question: \(question.trimmingCharacters(in: .whitespacesAndNewlines))
        """
    }
}

/// On-device study coach using Apple Intelligence (`FoundationModels`).
/// Requires a supported device, Apple Intelligence enabled, and the system model ready.
struct OnDeviceScholarStudyCoachView: View {
    @AppStorage("scholarCoach.lastTopic") private var lastTopic = ""
    @AppStorage("scholarCoach.temperature") private var temperature = 0.65

    @State private var topic = ""
    @State private var mode: ScholarCoachMode = .flashcards
    @State private var followUpQuestion = ""
    @State private var useGroundingNotes = true
    @State private var session: LanguageModelSession?
    @State private var flashcards: ScholarFlashcardSet?
    @State private var lessonPlan: ScholarLessonPlan?
    @State private var transcriptEntries: [ScholarCoachTranscriptEntry] = []
    @State private var isGenerating = false
    @State private var isAskingFollowUp = false
    @State private var errorText: String?

    private let coachInstructions = """
    You support World Class Scholars and humane aged-care learning.
    Center human rights, co-design, dignity, and lived experience.
    Use plain, accessible language suitable for micro-credentials, workshops, and care training.
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
            ensureSession()
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
            return ("Apple Intelligence unavailable", "This device needs a supported chip such as A17 Pro or later on iPhone, or an M-series chip on iPad or Mac.")
        case .appleIntelligenceNotEnabled:
            return ("Enable Apple Intelligence", "Turn on Apple Intelligence in Settings. It needs free storage and usually Wi-Fi while the model downloads.")
        case .modelNotReady:
            return ("Model not ready", "The on-device model is still downloading or preparing. Keep the device on Wi-Fi and power until setup completes.")
        @unknown default:
            return ("Apple Intelligence unavailable", String(describing: reason))
        }
    }

    private var availableContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                introCard

                Picker("Coach mode", selection: $mode) {
                    ForEach(ScholarCoachMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("studyCoach.modePicker")

                TextField("Topic (e.g. trauma-aware communication in aged care)", text: $topic, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .tint(GalleryTheme.accent)
                    .accessibilityIdentifier("studyCoach.topicField")

                Toggle(isOn: $useGroundingNotes) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ground with local equity notes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GalleryTheme.textPrimary)
                        Text("Adds dignity, trauma-aware, and lived-experience notes to the prompt for more reliable outputs.")
                            .font(.caption)
                            .foregroundStyle(GalleryTheme.textSecondary)
                    }
                }
                .toggleStyle(.switch)

                if useGroundingNotes {
                    groundingNotesSection
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Creativity")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GalleryTheme.textPrimary)
                        Spacer()
                        Text(String(format: "%.2f", temperature))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(GalleryTheme.textSecondary)
                    }
                    Slider(value: $temperature, in: 0.2...1.0, step: 0.05)
                        .tint(GalleryTheme.accent)
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await generateContent() }
                    } label: {
                        if isGenerating {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label(mode.actionTitle, systemImage: mode.systemImage)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(GalleryProminentButtonStyle())
                    .disabled(trimmedTopic.isEmpty || isGenerating || isAskingFollowUp)
                    .accessibilityIdentifier("studyCoach.generateButton")

                    Button("Reset session") {
                        resetSession(clearTopic: false)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGenerating || isAskingFollowUp)
                    .accessibilityIdentifier("studyCoach.resetButton")
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(GalleryTheme.rose)
                        .accessibilityIdentifier("studyCoach.errorMessage")
                }

                outputSection

                if hasGeneratedContent {
                    transcriptSection
                    followUpSection
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(GalleryAppBackground().ignoresSafeArea())
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create guided, private learning support directly on device.")
                .font(.headline)
                .foregroundStyle(GalleryTheme.textPrimary)
            Text("Use structured generation for flashcards, stream lesson plans, then keep refining with the same on-device session.")
                .font(.subheadline)
                .foregroundStyle(GalleryTheme.textSecondary)

            HStack(spacing: 8) {
                Label("On device", systemImage: "lock.shield")
                Label("Guided output", systemImage: "checklist")
                Label("Session memory", systemImage: "text.bubble")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(GalleryTheme.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GalleryTheme.cardStroke, lineWidth: 1)
        )
    }

    private var groundingNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested grounding notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GalleryTheme.textPrimary)

            ForEach(suggestedResources) { resource in
                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GalleryTheme.textPrimary)
                    Text(resource.summary)
                        .font(.caption)
                        .foregroundStyle(GalleryTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch mode {
        case .flashcards:
            if let flashcards {
                flashcardsSection(flashcards)
            } else {
                emptyStateCard(title: mode.emptyStateTitle, detail: "Generate a grounded set of five cards for quick revision or workshop discussion.")
            }
        case .lessonPlan:
            if let lessonPlan {
                lessonPlanSection(lessonPlan)
            } else if isGenerating {
                emptyStateCard(title: "Streaming lesson plan...", detail: "The session is assembling objectives, activities, and a reflection prompt.")
            } else {
                emptyStateCard(title: mode.emptyStateTitle, detail: "Stream a micro-credential style lesson with objectives, activities, and a reflective close.")
            }
        }
    }

    private func flashcardsSection(_ flashcards: ScholarFlashcardSet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(flashcards.theme)
                .font(.headline)
                .foregroundStyle(GalleryTheme.textPrimary)
                .accessibilityIdentifier("studyCoach.flashcardsTheme")

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

    private func lessonPlanSection(_ lessonPlan: ScholarLessonPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lessonPlan.title)
                .font(.headline)
                .foregroundStyle(GalleryTheme.textPrimary)
                .accessibilityIdentifier("studyCoach.lessonTitle")

            Text(lessonPlan.audience)
                .font(.subheadline)
                .foregroundStyle(GalleryTheme.textSecondary)

            detailBlock(title: "Objectives", items: lessonPlan.objectives)

            VStack(alignment: .leading, spacing: 10) {
                Text("Activities")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GalleryTheme.textPrimary)

                ForEach(Array(lessonPlan.activities.enumerated()), id: \.offset) { _, activity in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(activity.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GalleryTheme.textPrimary)
                        Text(activity.purpose)
                            .font(.caption)
                            .foregroundStyle(GalleryTheme.textSecondary)
                        detailBlock(title: "Steps", items: activity.steps)
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Reflection prompt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GalleryTheme.textPrimary)
                Text(lessonPlan.reflectionPrompt)
                    .font(.caption)
                    .foregroundStyle(GalleryTheme.textSecondary)
            }
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session transcript")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GalleryTheme.textPrimary)

            if transcriptEntries.isEmpty {
                Text("Your generated output is ready. Ask a follow-up to keep building on this session.")
                    .font(.caption)
                    .foregroundStyle(GalleryTheme.textSecondary)
            } else {
                ForEach(transcriptEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.role == .learner ? "You" : "Coach")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(entry.role == .learner ? GalleryTheme.accent : GalleryTheme.textPrimary)
                        Text(entry.text)
                            .font(.caption)
                            .foregroundStyle(GalleryTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Refine with a follow-up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GalleryTheme.textPrimary)

            TextField("Ask for an adaptation, deeper example, or assessment idea", text: $followUpQuestion, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .tint(GalleryTheme.accent)
                .disabled(isGenerating || isAskingFollowUp)
                .accessibilityIdentifier("studyCoach.followUpField")

            Button {
                Task { await askFollowUp() }
            } label: {
                if isAskingFollowUp {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Ask study coach", systemImage: "bubble.left.and.text.bubble.right")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(GalleryProminentButtonStyle())
            .disabled(followUpQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || isAskingFollowUp)
            .accessibilityIdentifier("studyCoach.followUpButton")
        }
    }

    private func emptyStateCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GalleryTheme.textPrimary)
            Text(detail)
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

    private func detailBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GalleryTheme.textPrimary)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text("• \(item)")
                    .font(.caption)
                    .foregroundStyle(GalleryTheme.textSecondary)
            }
        }
    }

    private var trimmedTopic: String {
        topic.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestedResources: [ScholarCoachResource] {
        ScholarCoachResourceCatalog.suggested(for: topic)
    }

    private var selectedResources: [ScholarCoachResource] {
        useGroundingNotes ? suggestedResources : []
    }

    private var hasGeneratedContent: Bool {
        flashcards != nil || lessonPlan != nil
    }

    private var generationOptions: GenerationOptions {
        GenerationOptions(temperature: temperature)
    }

    private func ensureSession() {
        guard session == nil else { return }
        guard SystemLanguageModel.default.isAvailable else { return }
        session = LanguageModelSession(instructions: coachInstructions)
        session?.prewarm()
    }

    private func resetSession(clearTopic: Bool) {
        if clearTopic { topic = "" }
        followUpQuestion = ""
        flashcards = nil
        lessonPlan = nil
        transcriptEntries = []
        errorText = nil
        session = nil
        ensureSession()
    }

    private func generateContent() async {
        ensureSession()
        guard let session else {
            errorText = "Session not ready."
            return
        }

        errorText = nil
        followUpQuestion = ""
        flashcards = nil
        lessonPlan = nil
        transcriptEntries = []
        isGenerating = true
        lastTopic = trimmedTopic
        defer { isGenerating = false }

        let promptText = ScholarCoachPromptBuilder.generationPrompt(
            topic: trimmedTopic,
            mode: mode,
            groundingNotes: selectedResources
        )

        do {
            switch mode {
            case .flashcards:
                let response = try await session.respond(
                    to: promptText,
                    generating: ScholarFlashcardSet.self,
                    options: generationOptions
                )
                flashcards = response.content
                transcriptEntries = [
                    ScholarCoachTranscriptEntry(role: .learner, text: trimmedTopic),
                    ScholarCoachTranscriptEntry(role: .coach, text: "Generated 5 grounded flashcards. Ask for examples, adaptations, or assessment ideas.")
                ]
            case .lessonPlan:
                for try await snapshot in session.streamResponse(
                    to: promptText,
                    generating: ScholarLessonPlan.self,
                    options: generationOptions
                ) {
                    if let streamedLessonPlan = try? ScholarLessonPlan(snapshot.rawContent) {
                        lessonPlan = streamedLessonPlan
                    }
                }
                transcriptEntries = [
                    ScholarCoachTranscriptEntry(role: .learner, text: trimmedTopic),
                    ScholarCoachTranscriptEntry(role: .coach, text: "Lesson plan ready. Ask me to adapt it for a cohort, a shorter session, or a different care setting.")
                ]
            }
        } catch let error as LanguageModelSession.GenerationError {
            errorText = error.recoverySuggestion ?? error.localizedDescription
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func askFollowUp() async {
        ensureSession()
        guard let session else {
            errorText = "Session not ready."
            return
        }

        let trimmedQuestion = followUpQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else { return }

        errorText = nil
        isAskingFollowUp = true
        defer { isAskingFollowUp = false }

        let promptText = ScholarCoachPromptBuilder.followUpPrompt(
            question: trimmedQuestion,
            topic: trimmedTopic,
            mode: mode
        )

        do {
            let response = try await session.respond(
                to: promptText,
                generating: ScholarCoachReply.self,
                options: generationOptions
            )

            transcriptEntries.append(ScholarCoachTranscriptEntry(role: .learner, text: trimmedQuestion))
            transcriptEntries.append(
                ScholarCoachTranscriptEntry(
                    role: .coach,
                    text: "\(response.content.answer)\nNext step: \(response.content.nextStep)"
                )
            )
            followUpQuestion = ""
        } catch let error as LanguageModelSession.GenerationError {
            errorText = error.recoverySuggestion ?? error.localizedDescription
        } catch {
            errorText = error.localizedDescription
        }
    }
}
