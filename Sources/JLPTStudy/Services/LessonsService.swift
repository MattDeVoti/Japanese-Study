import Foundation

final class LessonsService {
    static let shared = LessonsService()
    private init() {}

    private let decoder = JSONDecoder()
    private(set) var manifest: LessonManifest?

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

    func jlptLevel(for chapterId: String) -> String? {
        manifest?.levels
            .first(where: { $0.chapters.contains(where: { $0.id == chapterId }) })
            .map(\.jlptLevel)
    }
}
