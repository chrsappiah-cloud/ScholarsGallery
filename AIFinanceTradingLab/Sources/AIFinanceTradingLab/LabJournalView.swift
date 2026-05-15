import SwiftData
import SwiftUI

/// SwiftData-backed scratch pad surfaced on the **Lab** tab for persistence smoke + UI tests.
struct LabJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabJournalNote.createdAt, order: .reverse) private var notes: [LabJournalNote]
    @State private var draftTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Saved notes") {
                    if notes.isEmpty {
                        Text("No notes yet")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("lab_empty_state")
                    }
                    ForEach(notes, id: \.persistentModelID) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title)
                                .font(.body)
                            Text(note.createdAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("lab_note_cell_\(note.title)")
                    }
                }

                Section("New note") {
                    TextField("Title", text: $draftTitle)
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                        .accessibilityIdentifier("labNoteTitleField")

                    Button("Save") {
                        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        modelContext.insert(LabJournalNote(title: trimmed))
                        draftTitle = ""
                        try? modelContext.save()
                    }
                    .accessibilityIdentifier("labSaveNoteButton")
                }
            }
            .navigationTitle("Lab")
        }
        .accessibilityIdentifier("lab_journal_root")
    }
}
