import SwiftUI
import UniformTypeIdentifiers

// The signature hue for everything "custom" — indigo, distinct from the level
// level colors and the gold used by Favorites.
var customAccent: Color { .themeTile(7) }

/// Strips furigana markup (`漢字[かんじ]` → `漢字`) for short plain-text labels.
func strippedFurigana(_ text: String) -> String {
    guard text.contains("[") else { return text }
    var out = ""
    var skipping = false
    for ch in text {
        if ch == "[" { skipping = true; continue }
        if ch == "]" { skipping = false; continue }
        if !skipping { out.append(ch) }
    }
    return out
}

func itemsLabel(_ n: Int) -> String { "\(n) item\(n == 1 ? "" : "s")" }

// MARK: - Textbook bubble

struct CustomLessonCircleButton: View {
    let lesson: CustomLesson

    var body: some View {
        AestheticTile(title: lesson.name, subtitle: itemsLabel(lesson.itemCount),
                      glyph: "組", icon: "square.stack.3d.up.fill",
                      color: customAccent, aspect: nil, titleSize: 17)
            .frame(height: LessonsView.barHeight)
    }
}

// MARK: - "New lesson" bubble (always first in the Custom section)

/// Wrapper so a freshly created lesson id can drive `.sheet(item:)`.
private struct CreatedLesson: Identifiable { let id: String }

/// The dashed "+" bubble: name a new lesson, then go straight into picking
/// what to put in it.
struct NewCustomLessonBubble: View {
    @ObservedObject private var store = CustomLessonsStore.shared
    @State private var showNameAlert = false
    @State private var name = ""
    @State private var created: CreatedLesson?
    /// Held separately from `created` so it survives the sheet's dismissal.
    @State private var lastCreatedId: String?

    var body: some View {
        Button {
            showNameAlert = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(customAccent.opacity(0.55),
                                  style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                    Text("New Lesson")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(customAccent)
                .padding(.horizontal, 18)
            }
            .frame(height: LessonsView.barHeight)
        }
        .buttonStyle(.plain)
        .alert("New Custom Lesson", isPresented: $showNameAlert) {
            TextField("Lesson name", text: $name)
            Button("Create", action: createAndPick)
            Button("Cancel", role: .cancel) { name = "" }
        } message: {
            Text("Name it, then pick the grammar, vocab, and kanji to put inside.")
        }
        .sheet(item: $created, onDismiss: discardIfAbandoned) {
            CustomLessonAddView(lessonId: $0.id)
        }
    }

    private func createAndPick() {
        let id = store.create(name: name)
        name = ""
        lastCreatedId = id
        // Let the alert finish dismissing before the picker slides up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            created = CreatedLesson(id: id)
        }
    }

    /// Backing out of the picker without adding anything leaves an empty lesson
    /// behind, so drop it again.
    private func discardIfAbandoned() {
        guard let id = lastCreatedId else { return }
        lastCreatedId = nil
        store.deleteIfEmpty(id: id)
    }
}

// MARK: - Long-press "add" (used from chapters and Favorites)

private struct AddToCustomLessonModifier: ViewModifier {
    let item: CustomItem
    @State private var showSheet = false

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    showSheet = true
                } label: {
                    Label("Add to custom lesson", systemImage: "folder.badge.plus")
                }
            }
            .sheet(isPresented: $showSheet) {
                AddToCustomLessonSheet(item: item)
            }
    }
}

extension View {
    /// Long-press → "Add to custom lesson" → create/pick sheet.
    func addToCustomLesson(_ item: CustomItem) -> some View {
        modifier(AddToCustomLessonModifier(item: item))
    }
}

// MARK: - Add-to-lesson sheet (single item)

struct AddToCustomLessonSheet: View {
    let item: CustomItem

    @ObservedObject private var store = CustomLessonsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(customAccent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(strippedFurigana(item.displayTitle))
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Text(item.typeLabel)
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("New lesson name", text: $newName)
                            .submitLabel(.done)
                            .onSubmit(createAndAdd)
                        Button("Create", action: createAndAdd)
                            .fontWeight(.semibold)
                    }
                } header: {
                    Text("New custom lesson")
                }

                if !store.lessons.isEmpty {
                    Section {
                        ForEach(store.lessons) { lesson in
                            Button {
                                store.toggle(item, in: lesson.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(lesson.name)
                                            .foregroundColor(.primary)
                                        Text(itemsLabel(lesson.itemCount))
                                            .font(.caption)
                                            .foregroundColor(.appTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: store.contains(item, in: lesson.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(store.contains(item, in: lesson.id) ? .green : Color.secondary.opacity(0.4))
                                }
                            }
                        }
                    } header: {
                        Text("Add to existing")
                    }
                }
            }
            .navigationTitle("Add to Custom Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private var icon: String {
        switch item {
        case .grammar: return "text.book.closed.fill"
        case .vocab:   return "character.book.closed.fill"
        case .kanji:   return "character.textbox"
        }
    }

    private func createAndAdd() {
        let id = store.create(name: newName)
        store.add(item, to: id)
        newName = ""
    }
}

// MARK: - Custom lesson detail

struct CustomLessonDetailView: View {
    let lessonId: String

    @ObservedObject private var store = CustomLessonsStore.shared
    @EnvironmentObject private var cardStore: CardStore
    @Environment(\.dismiss) private var dismiss

    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var showAddPicker = false
    @State private var isRemoving = false

    // Local mirrors of the lesson's three buckets so a drag reorders smoothly;
    // committed back to the store when the drop lands.
    @State private var grammarOrder: [CustomGrammarRef] = []
    @State private var vocabOrder: [String] = []
    @State private var kanjiOrder: [String] = []
    @State private var dragging: CustomItem?

    // Resolution caches, rebuilt whenever the lesson changes, so a drag doesn't
    // re-decode chapter JSON on every frame.
    @State private var grammarCache: [CustomGrammarRef: GrammarPoint] = [:]
    @State private var kanjiCache: [String: KanjiCard] = [:]

    private var lesson: CustomLesson? { store.lesson(id: lessonId) }

    var body: some View {
        ZStack {
            AppBackground()
            if let lesson = lesson {
                if lesson.itemCount == 0 { emptyState } else { content }
            }
        }
        .standardNavBar(lesson?.name ?? "Custom Lesson")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isRemoving {
                    Button("Done") { isRemoving = false }
                        .fontWeight(.semibold)
                        .foregroundColor(.appNavBarText)
                } else {
                    Menu {
                        Button { showAddPicker = true } label: { Label("Add", systemImage: "plus") }
                        Button { isRemoving = true } label: { Label("Remove", systemImage: "minus.circle") }
                        Divider()
                        Button {
                            renameText = lesson?.name ?? ""
                            showRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Lesson", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.appNavBarText)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPicker) {
            CustomLessonAddView(lessonId: lessonId)
        }
        .alert("Rename Lesson", isPresented: $showRename) {
            TextField("Lesson name", text: $renameText)
            Button("Save") { store.rename(id: lessonId, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this custom lesson?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.delete(id: lessonId)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The lesson is removed. The grammar, vocab, and kanji themselves are not affected.")
        }
        .onAppear(perform: sync)
        .onChange(of: store.lessons) { _ in sync() }
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isRemoving {
                    Text("Tap a red ✕ to remove an item from this lesson.")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                        .padding(.top, 4)
                }
                grammarSection
                vocabSection
                kanjiSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private var grammarSection: some View {
        if !grammarOrder.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Grammar", icon: "text.book.closed")
                ForEach(Array(grammarOrder.enumerated()), id: \.element) { idx, ref in
                    if let point = grammarCache[ref] {
                        let item = CustomItem.grammar(chapterId: ref.chapterId, pointId: ref.pointId, title: point.name)
                        HStack(spacing: 10) {
                            if isRemoving { removeButton(item) }
                            GrammarPointCard(point: point, chapterId: ref.chapterId, accentColor: customAccent)
                        }
                        .reorderable(item: item, index: idx, dragging: $dragging,
                                     move: moveGrammar, commit: commitOrders, enabled: !isRemoving)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var vocabSection: some View {
        if !vocabOrder.isEmpty {
            let words = vocabOrder.compactMap { LessonsService.shared.vocabWord(id: $0) }
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Vocabulary", icon: "character.book.closed")
                ForEach(Array(words.enumerated()), id: \.element.id) { idx, word in
                    let item = CustomItem.vocab(id: word.id, title: word.kanji)
                    HStack(spacing: 10) {
                        if isRemoving { removeButton(item) }
                        VocabWordRow(word: word, accentColor: customAccent)
                    }
                    .reorderable(item: item, index: idx, dragging: $dragging,
                                 move: moveVocab, commit: commitOrders, enabled: !isRemoving)
                }
                NavigationLink {
                    VocabFlashcardsView(
                        lockedChapter: LockedVocabChapter(id: lessonId, number: 0,
                                                          title: lesson?.name ?? "Custom", accent: customAccent),
                        lockedWords: words)
                } label: {
                    StudyButtonLabel(title: "Study Vocab", accent: customAccent)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var kanjiSection: some View {
        if !kanjiOrder.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Kanji", icon: "character.textbox")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)],
                          alignment: .leading, spacing: 8) {
                    ForEach(Array(kanjiOrder.enumerated()), id: \.element) { idx, char in
                        if let card = kanjiCache[char] {
                            kanjiCell(card: card, char: char, index: idx)
                        }
                    }
                }
                NavigationLink {
                    KanjiStudyView(lockedChapter: LockedKanjiChapter(title: lesson?.name ?? "Custom", kanji: kanjiOrder))
                } label: {
                    StudyButtonLabel(title: "Study Kanji", accent: customAccent)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private func kanjiCell(card: KanjiCard, char: String, index: Int) -> some View {
        let item = CustomItem.kanji(char: char)
        return KanjiExcludeCell(card: card)
            .overlay(alignment: .topLeading) {
                if isRemoving { removeButton(item).padding(4) }
            }
            .reorderable(item: item, index: index, dragging: $dragging,
                         move: moveKanji, commit: commitOrders, enabled: !isRemoving)
    }

    private func removeButton(_ item: CustomItem) -> some View {
        Button {
            withAnimation { store.remove(item, from: lessonId) }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.red)
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        SectionHeading(title).padding(.top, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("This lesson is empty")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.appTextSecondary)
            Text("Use “Add” in the menu, or long-press a grammar point, vocab word, or kanji anywhere in the app.")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: Sync + reordering

    private func sync() {
        guard let l = lesson else { return }
        grammarOrder = l.grammar
        vocabOrder = l.vocabIds
        kanjiOrder = l.kanji

        var gc: [CustomGrammarRef: GrammarPoint] = [:]
        for ref in l.grammar where gc[ref] == nil {
            if let p = LessonsService.shared.loadChapter(ref.chapterId)?
                .points.first(where: { $0.id == ref.pointId }) {
                gc[ref] = p
            }
        }
        grammarCache = gc

        var kc: [String: KanjiCard] = [:]
        for ch in l.kanji where kc[ch] == nil {
            if let card = cardStore.kanjiCard(for: ch) { kc[ch] = card }
        }
        kanjiCache = kc
    }

    private func moveGrammar(to target: Int) {
        guard case let .grammar(chapterId, pointId, _) = dragging else { return }
        let ref = CustomGrammarRef(chapterId: chapterId, pointId: pointId)
        guard let from = grammarOrder.firstIndex(of: ref), from != target else { return }
        withAnimation {
            grammarOrder.remove(at: from)
            grammarOrder.insert(ref, at: min(target, grammarOrder.count))
        }
    }

    private func moveVocab(to target: Int) {
        guard case let .vocab(id, _) = dragging else { return }
        guard let from = vocabOrder.firstIndex(of: id), from != target else { return }
        withAnimation {
            vocabOrder.remove(at: from)
            vocabOrder.insert(id, at: min(target, vocabOrder.count))
        }
    }

    private func moveKanji(to target: Int) {
        guard case let .kanji(char) = dragging else { return }
        guard let from = kanjiOrder.firstIndex(of: char), from != target else { return }
        withAnimation {
            kanjiOrder.remove(at: from)
            kanjiOrder.insert(char, at: min(target, kanjiOrder.count))
        }
    }

    private func commitOrders() {
        store.setGrammarOrder(grammarOrder, in: lessonId)
        store.setVocabOrder(vocabOrder, in: lessonId)
        store.setKanjiOrder(kanjiOrder, in: lessonId)
    }
}

// MARK: - Drag-to-reorder (confined to one category)

private struct ReorderModifier: ViewModifier {
    let item: CustomItem
    let index: Int
    @Binding var dragging: CustomItem?
    let move: (Int) -> Void
    let commit: () -> Void
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .opacity(dragging == item ? 0.4 : 1)
                .onDrag {
                    dragging = item
                    return NSItemProvider(object: item.id as NSString)
                }
                .onDrop(of: [.text], delegate: ReorderDropDelegate(
                    index: index, category: item.category,
                    dragging: $dragging, move: move, commit: commit))
        } else {
            content
        }
    }
}

/// Only accepts a drop when the dragged item belongs to the same bucket, so
/// vocab can never be dropped among grammar points (or kanji).
private struct ReorderDropDelegate: DropDelegate {
    let index: Int
    let category: CustomCategory
    @Binding var dragging: CustomItem?
    let move: (Int) -> Void
    let commit: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        dragging?.category == category
    }

    func dropEntered(info: DropInfo) {
        guard dragging?.category == category else { return }
        move(index)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: dragging?.category == category ? .move : .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard dragging?.category == category else { dragging = nil; return false }
        dragging = nil
        commit()
        return true
    }
}

private extension View {
    func reorderable(item: CustomItem, index: Int, dragging: Binding<CustomItem?>,
                     move: @escaping (Int) -> Void, commit: @escaping () -> Void,
                     enabled: Bool) -> some View {
        modifier(ReorderModifier(item: item, index: index, dragging: dragging,
                                 move: move, commit: commit, enabled: enabled))
    }
}
