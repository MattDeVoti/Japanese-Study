import Foundation

final class LessonsService {
    static let shared = LessonsService()
    private init() {}

    private let decoder = JSONDecoder()
    private(set) var manifest: LessonManifest?
    private var pointIdsCache: [String: [String]] = [:]
    private var vocabIndex: [String: LessonVocabWord]?

    func loadIfNeeded() {
        guard manifest == nil else { return }
        guard let url = Bundle.main.url(forResource: "lessons", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        manifest = try? decoder.decode(LessonManifest.self, from: data)
    }

    func loadChapter(_ id: String) -> LessonChapter? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(LessonChapter.self, from: data)
    }

    /// Loads a standalone practice-question bank (a JSON array of PracticeQuestion),
    /// used by the Hiragana / Katakana pronunciation drills.
    func loadQuestionBank(_ name: String) -> [PracticeQuestion] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([PracticeQuestion].self, from: data)) ?? []
    }

    /// The manifest entry for a chapter — lets a search hit navigate to its chapter.
    func chapterSummary(for chapterId: String) -> ChapterSummary? {
        manifest?.levels.flatMap(\.chapters).first { $0.id == chapterId }
    }

    func jlptLevel(for chapterId: String) -> String? {
        manifest?.levels
            .first(where: { $0.chapters.contains(where: { $0.id == chapterId }) })
            .map(\.jlptLevel)
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

    /// Lightweight decode that reads just each point's `id`, without parsing its
    /// full contents (explanations, examples, practice, …).
    private func decodedPointIds(_ id: String) -> [String]? {
        struct Probe: Decodable {
            struct Item: Decodable { let id: String? }
            let points: [Item]
        }
        guard let url = Bundle.main.url(forResource: id, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let probe = try? decoder.decode(Probe.self, from: data) else { return nil }
        return probe.points.compactMap { $0.id }
    }
}
