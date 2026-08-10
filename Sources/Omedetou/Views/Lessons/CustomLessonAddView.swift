import SwiftUI

/// Running multi-selection for the "Add" picker. Held by the sheet root so it
/// survives pushes into levels → chapters → items.
final class AddSelection: ObservableObject {
    @Published private(set) var items: [CustomItem] = []

    var count: Int { items.count }
    func contains(_ item: CustomItem) -> Bool { items.contains(item) }
    func toggle(_ item: CustomItem) {
        if let i = items.firstIndex(of: item) { items.remove(at: i) } else { items.append(item) }
    }
}

/// Browse the whole textbook and tick any number of grammar points, vocab words,
/// and kanji; "Add" commits the entire selection to the custom lesson at once.
struct CustomLessonAddView: View {
    let lessonId: String

    @StateObject private var selection = AddSelection()
    @Environment(\.dismiss) private var dismiss
    @State private var levels: [LessonLevel] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(levels) { level in
                    NavigationLink {
                        AddChapterList(level: level, lessonId: lessonId, selection: selection,
                                       onDone: commit, onCancel: { dismiss() })
                    } label: {
                        HStack {
                            Text(levelName(jlpt: level.levelId))
                            Spacer()
                            Text("\(level.chapters.count) ch")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .addPickerDoneButton(selection: selection, onDone: commit)
        }
        .onAppear {
            LessonsService.shared.loadIfNeeded()
            // Kana levels hold no grammar/vocab/kanji, so they're not offered here.
            levels = (LessonsService.shared.manifest?.levels ?? [])
                .filter { $0.levelId.hasPrefix("N") || $0.levelId == SlangContent.levelId }
        }
    }

    private func commit() {
        CustomLessonsStore.shared.add(selection.items, to: lessonId)
        dismiss()
    }
}

// MARK: - Chapters within a level

private struct AddChapterList: View {
    let level: LessonLevel
    let lessonId: String
    @ObservedObject var selection: AddSelection
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        List {
            ForEach(level.chapters) { summary in
                NavigationLink {
                    AddItemPicker(summary: summary, lessonId: lessonId, selection: selection,
                                  onDone: onDone, onCancel: onCancel)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chapter \(summary.chapterNumber)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(summary.title)
                    }
                }
            }
        }
        .navigationTitle(levelName(jlpt: level.levelId))
        .navigationBarTitleDisplayMode(.inline)
        .addPickerDoneButton(selection: selection, onDone: onDone)
    }
}

// MARK: - Selectable items in one chapter

private struct AddItemPicker: View {
    let summary: ChapterSummary
    let lessonId: String
    @ObservedObject var selection: AddSelection
    let onDone: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var cardStore: CardStore
    @ObservedObject private var store = CustomLessonsStore.shared
    @State private var chapter: LessonChapter?

    var body: some View {
        List {
            if let chapter = chapter {
                let points = chapter.points.filter { $0.pointType != "kana" }
                if !points.isEmpty {
                    Section("Grammar") {
                        ForEach(points) { p in
                            row(.grammar(chapterId: summary.id, pointId: p.id, title: p.name),
                                title: strippedFurigana(p.name),
                                subtitle: p.shortDescription)
                        }
                    }
                }
                if let vocab = chapter.vocab, !vocab.isEmpty {
                    Section("Vocabulary") {
                        ForEach(vocab) { w in
                            row(.vocab(id: w.id, title: w.kanji),
                                title: w.kanji == w.kana ? w.kanji : "\(w.kanji)  \(w.kana)",
                                subtitle: w.definition)
                        }
                    }
                }
                let kanji = chapter.kanjiChars
                if !kanji.isEmpty {
                    Section("Kanji") {
                        ForEach(kanji, id: \.self) { kc in
                            row(.kanji(char: kc),
                                title: kc,
                                subtitle: cardStore.kanjiCard(for: kc)?.definition ?? "")
                        }
                    }
                }
                if points.isEmpty && (chapter.vocab ?? []).isEmpty && chapter.kanjiChars.isEmpty {
                    Text("Nothing to add in this chapter.")
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .addPickerDoneButton(selection: selection, onDone: onDone)
        .onAppear {
            if chapter == nil { chapter = LessonsService.shared.loadChapter(summary.id) }
        }
    }

    private func row(_ item: CustomItem, title: String, subtitle: String) -> some View {
        let already = store.contains(item, in: lessonId)
        let picked = selection.contains(item)
        return Button {
            selection.toggle(item)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(already ? .secondary : .primary)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if already {
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(picked ? .green : Color.secondary.opacity(0.4))
                }
            }
        }
        .disabled(already)
    }
}

// MARK: - Shared "Add (N)" toolbar button

private struct AddPickerDoneButton: ViewModifier {
    @ObservedObject var selection: AddSelection
    let onDone: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(selection.count == 0 ? "Add" : "Add (\(selection.count))", action: onDone)
                    .fontWeight(.semibold)
                    .disabled(selection.count == 0)
            }
        }
    }
}

private extension View {
    func addPickerDoneButton(selection: AddSelection, onDone: @escaping () -> Void) -> some View {
        modifier(AddPickerDoneButton(selection: selection, onDone: onDone))
    }
}
