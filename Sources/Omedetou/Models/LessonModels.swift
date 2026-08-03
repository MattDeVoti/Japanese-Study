import Foundation

struct LessonManifest: Codable {
    let levels: [LessonLevel]
}

struct LessonLevel: Codable, Identifiable {
    var id: String { jlptLevel }
    let jlptLevel: String
    let chapters: [ChapterSummary]
}

struct ChapterSummary: Codable, Identifiable {
    let id: String
    let chapterNumber: Int
    let title: String
    let pointCount: Int
    let chapterType: String?  // "kana" for hiragana/katakana character chapters
}

struct LessonChapter: Codable, Identifiable {
    let id: String
    let chapterNumber: Int
    let title: String
    let points: [GrammarPoint]
    let vocab: [LessonVocabWord]?
    let kanji: [String]?                       // kanji assigned to this chapter (same N-level)
    let chapterPractice: [PracticeQuestion]?  // chapter-level practice (used by kana lessons)
}

struct LessonVocabWord: Codable, Identifiable {
    let id: String
    let partOfSpeech: String
    let kanji: String
    let kana: String
    let romaji: String
    let definition: String
}

struct GrammarPoint: Codable, Identifiable {
    let id: String
    let pointType: String?  // "kana" for hiragana/katakana character cards
    let name: String
    let shortDescription: String
    let formation: String
    let explanation: String
    let rules: [String]
    let examples: [GrammarExample]
    let flashcardHeader: String?
    let flashcardAnswer: String?
    let practice: [PracticeQuestion]?
}

struct PracticeQuestion: Codable, Identifiable {
    let id: String
    let type: String        // "translation" | "fillBlank" | "construct" | "usage"
    let prompt: String
    let japanese: String?
    let choices: [String]   // always 4 options
    let correctIndex: Int
    let explanation: String
}

struct GrammarExample: Codable {
    let japanese: String
    let romaji: String
    let english: String
}
