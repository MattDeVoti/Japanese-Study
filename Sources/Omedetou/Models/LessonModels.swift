import Foundation

struct LessonManifest: Codable {
    let levels: [LessonLevel]
}

struct LessonLevel: Codable, Identifiable {
    var id: String { levelId }
    let levelId: String
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
    let kanji: [ChapterKanji]?                 // kanji assigned to this chapter (same N-level)
    let chapterPractice: [PracticeQuestion]?  // chapter-level practice (used by kana lessons)

    /// Just the characters, for the several places that only need the list.
    var kanjiChars: [String] { (kanji ?? []).map(\.char) }
}

/// A kanji as a chapter teaches it.
///
/// The card in the kanji deck carries everything a character can mean and every
/// way it can be read; a chapter teaches exactly one of each. 分 in Telling Time
/// is ふん, "minute" — not 分ける, which is true of the character and useless to
/// someone who has just learned to read a clock. Tests and reviews ask from
/// here so that what they ask is what was taught.
struct ChapterKanji: Codable, Hashable, Identifiable {
    let char: String
    /// The form the learner meets it in — 高い rather than a bare 高.
    let word: String
    /// Reading of `word`.
    let reading: String
    let meaning: String

    var id: String { char }
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
