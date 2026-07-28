import Foundation

// MARK: - Model

/// A grammar point referenced by the chapter + point it lives in (same key
/// scheme the Favorites store uses).
struct CustomGrammarRef: Codable, Hashable {
    let chapterId: String
    let pointId: String
}

/// A user-built lesson: any mix of grammar points, vocab words, and kanji the
/// user has gathered from anywhere in the app.
struct CustomLesson: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var grammar: [CustomGrammarRef]
    var vocabIds: [String]      // LessonVocabWord.id (globally unique)
    var kanji: [String]         // kanji characters
    let createdAt: Date

    var itemCount: Int { grammar.count + vocabIds.count + kanji.count }
}

/// Which of a lesson's three ordered buckets an item belongs to. Reordering is
/// confined to one bucket, so vocab can never be dragged among grammar points.
enum CustomCategory {
    case grammar, vocab, kanji
}

/// One thing the user can drop into a custom lesson. Carries a display title so
/// the "add" sheet can label what's being added without re-resolving it.
enum CustomItem: Identifiable, Hashable {
    case grammar(chapterId: String, pointId: String, title: String)
    case vocab(id: String, title: String)
    case kanji(char: String)

    var id: String {
        switch self {
        case let .grammar(chapterId, pointId, _): return "g:\(chapterId)/\(pointId)"
        case let .vocab(wordId, _):               return "v:\(wordId)"
        case let .kanji(char):                    return "k:\(char)"
        }
    }

    var typeLabel: String {
        switch self {
        case .grammar: return "Grammar"
        case .vocab:   return "Vocab"
        case .kanji:   return "Kanji"
        }
    }

    var displayTitle: String {
        switch self {
        case let .grammar(_, _, title): return title
        case let .vocab(_, title):      return title
        case let .kanji(char):          return char
        }
    }

    var category: CustomCategory {
        switch self {
        case .grammar: return .grammar
        case .vocab:   return .vocab
        case .kanji:   return .kanji
        }
    }
}

// MARK: - Store

final class CustomLessonsStore: ObservableObject {
    static let shared = CustomLessonsStore()

    @Published private(set) var lessons: [CustomLesson] = []

    private let storageKey = "CustomLessonsData"
    private let seededKey = "CustomLessonsDidSeedPresets"
    private var didLoad = false

    private init() {
        load()
        didLoad = true
        seedPresetsIfNeeded()
    }

    /// Adds the ready-made lessons the first time the app runs. The flag is set
    /// regardless of outcome, so a preset the user deletes stays deleted.
    private func seedPresetsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)

        let now = Date()
        lessons += CustomLessonPresets.all.map { preset in
            CustomLesson(
                id: UUID().uuidString,
                name: preset.name,
                grammar: preset.grammar.map { CustomGrammarRef(chapterId: $0.chapter, pointId: $0.point) },
                vocabIds: preset.vocabIds,
                kanji: preset.kanji,
                createdAt: now)
        }
        persist()
    }

    // MARK: Queries

    func lesson(id: String) -> CustomLesson? { lessons.first { $0.id == id } }

    func contains(_ item: CustomItem, in lessonId: String) -> Bool {
        guard let l = lessons.first(where: { $0.id == lessonId }) else { return false }
        switch item {
        case let .grammar(chapterId, pointId, _):
            return l.grammar.contains(CustomGrammarRef(chapterId: chapterId, pointId: pointId))
        case let .vocab(wordId, _):
            return l.vocabIds.contains(wordId)
        case let .kanji(char):
            return l.kanji.contains(char)
        }
    }

    // MARK: Lesson mutations

    /// Creates a lesson and returns its id. Names are trimmed; a blank name gets
    /// a sensible default so a lesson always has a label.
    @discardableResult
    func create(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Custom Lesson \(lessons.count + 1)" : trimmed
        let lesson = CustomLesson(id: UUID().uuidString, name: finalName,
                                  grammar: [], vocabIds: [], kanji: [], createdAt: Date())
        lessons.append(lesson)
        persist()
        return lesson.id
    }

    func rename(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = lessons.firstIndex(where: { $0.id == id }) else { return }
        lessons[i].name = trimmed
        persist()
    }

    func delete(id: String) {
        lessons.removeAll { $0.id == id }
        persist()
    }

    /// Deletes a lesson only if it is still empty. Used to clean up a lesson the
    /// user created from the "+" bubble and then abandoned without adding
    /// anything — deliberately narrow, so a lesson someone emptied on purpose
    /// while curating it is left alone.
    func deleteIfEmpty(id: String) {
        guard let lesson = lesson(id: id), lesson.itemCount == 0 else { return }
        delete(id: id)
    }

    // MARK: Item mutations

    func add(_ item: CustomItem, to lessonId: String) {
        guard let i = lessons.firstIndex(where: { $0.id == lessonId }) else { return }
        append(item, at: i)
        persist()
    }

    /// Bulk add (the "Add" picker commits a whole multi-selection at once).
    func add(_ items: [CustomItem], to lessonId: String) {
        guard !items.isEmpty, let i = lessons.firstIndex(where: { $0.id == lessonId }) else { return }
        for item in items { append(item, at: i) }
        persist()
    }

    private func append(_ item: CustomItem, at i: Int) {
        switch item {
        case let .grammar(chapterId, pointId, _):
            let ref = CustomGrammarRef(chapterId: chapterId, pointId: pointId)
            if !lessons[i].grammar.contains(ref) { lessons[i].grammar.append(ref) }
        case let .vocab(wordId, _):
            if !lessons[i].vocabIds.contains(wordId) { lessons[i].vocabIds.append(wordId) }
        case let .kanji(char):
            if !lessons[i].kanji.contains(char) { lessons[i].kanji.append(char) }
        }
    }

    // MARK: Ordering (drag-to-reorder, one bucket at a time)

    func setGrammarOrder(_ refs: [CustomGrammarRef], in lessonId: String) {
        guard let i = lessons.firstIndex(where: { $0.id == lessonId }),
              lessons[i].grammar != refs else { return }
        lessons[i].grammar = refs
        persist()
    }

    func setVocabOrder(_ ids: [String], in lessonId: String) {
        guard let i = lessons.firstIndex(where: { $0.id == lessonId }),
              lessons[i].vocabIds != ids else { return }
        lessons[i].vocabIds = ids
        persist()
    }

    func setKanjiOrder(_ chars: [String], in lessonId: String) {
        guard let i = lessons.firstIndex(where: { $0.id == lessonId }),
              lessons[i].kanji != chars else { return }
        lessons[i].kanji = chars
        persist()
    }

    func remove(_ item: CustomItem, from lessonId: String) {
        guard let i = lessons.firstIndex(where: { $0.id == lessonId }) else { return }
        switch item {
        case let .grammar(chapterId, pointId, _):
            lessons[i].grammar.removeAll { $0 == CustomGrammarRef(chapterId: chapterId, pointId: pointId) }
        case let .vocab(wordId, _):
            lessons[i].vocabIds.removeAll { $0 == wordId }
        case let .kanji(char):
            lessons[i].kanji.removeAll { $0 == char }
        }
        persist()
    }

    /// Toggles membership; returns whether the item is now in the lesson.
    @discardableResult
    func toggle(_ item: CustomItem, in lessonId: String) -> Bool {
        if contains(item, in: lessonId) { remove(item, from: lessonId); return false }
        else { add(item, to: lessonId); return true }
    }

    // MARK: Persistence

    private func load() {
        if let decoded = UserDefaults.standard.decode([CustomLesson].self, forKey: storageKey) {
            lessons = decoded
        }
    }

    private func persist() {
        guard didLoad else { return }
        UserDefaults.standard.encode(lessons, forKey: storageKey)
    }
}
