import Foundation

final class LessonsService {
    static let shared = LessonsService()
    private init() {}

    private(set) var manifest: LessonManifest?
    private var pointIdsCache: [String: [String]] = [:]
    private var chapterCache: [String: LessonChapter] = [:]
    private var vocabIndex: [String: LessonVocabWord]?
    private var kanjiIndex: [String: ChapterKanji]?
    private var kanjiWordIndex: [String: (word: ChapterKanjiWord, chapterId: String)]?

    func loadIfNeeded() {
        guard manifest == nil else { return }
        manifest = Bundle.main.decodeJSON(LessonManifest.self, resource: "lessons")
    }

    /// Every chapter kanji entry in the course — the distractor pool for kanji
    /// questions, so wrong answers are also things the learner has been taught.
    func allKanjiEntries() -> [ChapterKanji] {
        Array(kanjiIndexBuildingIfNeeded().values)
    }

    /// How a chapter teaches this character, wherever it was assigned.
    ///
    /// Every kanji belongs to exactly one chapter, so this is unambiguous. Used
    /// by reviews and tests, which know a character but not where it came from.
    func kanjiEntry(_ char: String) -> ChapterKanji? {
        kanjiIndexBuildingIfNeeded()[char]
    }

    /// Character → how its chapter teaches it, built once on first use.
    ///
    /// Building it means decoding every chapter, so it is deliberately lazy
    /// rather than done at launch — most sessions never ask.
    @discardableResult
    private func kanjiIndexBuildingIfNeeded() -> [String: ChapterKanji] {
        if let kanjiIndex { return kanjiIndex }
        loadIfNeeded()
        var index: [String: ChapterKanji] = [:]
        for level in manifest?.levels ?? [] {
            for summary in level.chapters {
                for entry in loadChapter(summary.id)?.kanji ?? [] {
                    index[entry.char] = entry
                }
            }
        }
        kanjiIndex = index
        return index
    }

    /// Every kanji word every chapter teaches, tagged with its chapter — the
    /// exam builder's distractor pool, so wrong answers are always drawn from
    /// words the course actually teaches.
    func allKanjiWords() -> [(word: ChapterKanjiWord, chapterId: String)] {
        Array(kanjiWordIndexBuildingIfNeeded().values)
    }

    /// Resolves a kanji-word id ("kw:word|kana") to the entry and its chapter.
    /// Reviews use this the way vocab reviews use `vocabWord(id:)`.
    func kanjiWord(id: String) -> (word: ChapterKanjiWord, chapterId: String)? {
        kanjiWordIndexBuildingIfNeeded()[id]
    }

    /// The word a character's home chapter teaches it in, as a word entry —
    /// how a custom lesson's bare kanji become word flashcards.
    func primaryWord(for char: String) -> ChapterKanjiWord? {
        guard let entry = kanjiEntry(char) else { return nil }
        return kanjiWord(id: "kw:\(entry.word)|\(entry.reading)")?.word
    }

    /// The words a chapter teaches its kanji in. Cached via `loadChapter`.
    func kanjiWords(for chapterId: String) -> [ChapterKanjiWord] {
        loadChapter(chapterId)?.kanjiWords ?? []
    }

    @discardableResult
    private func kanjiWordIndexBuildingIfNeeded() -> [String: (word: ChapterKanjiWord, chapterId: String)] {
        if let kanjiWordIndex { return kanjiWordIndex }
        loadIfNeeded()
        var index: [String: (word: ChapterKanjiWord, chapterId: String)] = [:]
        for level in manifest?.levels ?? [] {
            for summary in level.chapters {
                for entry in loadChapter(summary.id)?.kanjiWords ?? [] {
                    index[entry.id] = (entry, summary.id)
                }
            }
        }
        kanjiWordIndex = index
        return index
    }

    /// Chapters are static bundled data, so each is decoded at most once.
    func loadChapter(_ id: String) -> LessonChapter? {
        if let cached = chapterCache[id] { return cached }
        guard let chapter = Bundle.main.decodeJSON(LessonChapter.self, resource: id) else { return nil }
        chapterCache[id] = chapter
        return chapter
    }

    /// Loads a standalone practice-question bank (a JSON array of PracticeQuestion),
    /// used by the Hiragana / Katakana pronunciation drills.
    func loadQuestionBank(_ name: String) -> [PracticeQuestion] {
        Bundle.main.decodeJSON([PracticeQuestion].self, resource: name) ?? []
    }

    /// The manifest entry for a chapter — lets a search hit navigate to its chapter.
    func chapterSummary(for chapterId: String) -> ChapterSummary? {
        manifest?.levels.flatMap(\.chapters).first { $0.id == chapterId }
    }

    func levelId(for chapterId: String) -> String? {
        manifest?.levels
            .first(where: { $0.chapters.contains(where: { $0.id == chapterId }) })
            .map(\.levelId)
    }

    /// The ids of every point in a chapter, read straight from the chapter file so
    /// they stay correct whenever a chapter is edited. Used to count total points
    /// and to filter progress to points that currently exist. Cached after first read.
    func pointIds(for chapterId: String) -> [String] {
        if let cached = pointIdsCache[chapterId] { return cached }
        let ids = decodedPointIds(chapterId) ?? []
        pointIdsCache[chapterId] = ids
        return ids
    }

    /// Number of points in a chapter — grammar points, or kana characters —
    /// computed dynamically from the chapter file (never a hardcoded total). Falls
    /// back to the manifest's `pointCount` only if the chapter file can't be read.
    func pointCount(for chapterId: String) -> Int {
        let ids = pointIds(for: chapterId)
        if !ids.isEmpty { return ids.count }
        return manifest?.levels.flatMap(\.chapters).first { $0.id == chapterId }?.pointCount ?? 0
    }

    /// How many actual characters a kana chapter teaches.
    ///
    /// Separate from `pointCount` because a kana chapter may also carry points
    /// that aren't characters — the writing-system introduction in kana_h01, for
    /// one. Counting those would have the chapter list advertise "6 characters"
    /// for the five vowels. `loadChapter` is cached, so this costs one decode per
    /// chapter however many rows ask for it.
    func characterCount(for chapterId: String) -> Int {
        guard let chapter = loadChapter(chapterId) else { return pointCount(for: chapterId) }
        let characters = chapter.points.filter(\.isKanaCharacter).count
        return characters > 0 ? characters : chapter.points.count
    }

    /// Resolves a vocab word by its (global) id, building a one-time index over
    /// every chapter's vocab on first use. Custom lessons store only word ids, so
    /// they lean on this to render and study the actual words.
    func vocabWord(id: String) -> LessonVocabWord? {
        if vocabIndex == nil { buildVocabIndex() }
        return vocabIndex?[id]
    }

    private func buildVocabIndex() {
        loadIfNeeded()
        var index: [String: LessonVocabWord] = [:]
        for level in manifest?.levels ?? [] {
            for summary in level.chapters {
                guard let chapter = loadChapter(summary.id), let vocab = chapter.vocab else { continue }
                for word in vocab { index[word.id] = word }
            }
        }
        vocabIndex = index
    }

    /// Point ids for a chapter. Reuses the cached chapter decode (chapters are
    /// static, so the first read warms the cache for everything else).
    private func decodedPointIds(_ id: String) -> [String]? {
        loadChapter(id).map { $0.points.map(\.id) }
    }
}
