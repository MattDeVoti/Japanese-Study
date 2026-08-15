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
    /// Raw value from the JSON. Read it through `isKanaChapter` — see `LessonKind`.
    let chapterType: String?
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
    /// Raw value from the JSON. Read it through `isKanaCharacter` — see `LessonKind`.
    let pointType: String?
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

// MARK: - What a lesson or point actually is

/// Whether a chapter or point teaches a single kana character or a grammar
/// pattern. The two render, search, review and get counted differently.
///
/// The JSON stores this as a bare string, and comparing against `"kana"` was
/// spread across seven files — one typo away from a card silently rendering as
/// the wrong kind, with nothing to catch it. Decoding stays string-based so the
/// bundled lessons are untouched; every reader goes through the accessors below.
enum LessonKind: String {
    /// A single character — あ, シ — taught as a character, not a pattern.
    case kana
    /// An ordinary grammar point or chapter.
    case grammar

    /// Anything unrecognised is ordinary grammar: a new kind in the data should
    /// render as a normal point rather than vanish.
    init(raw: String?) {
        self = LessonKind(rawValue: raw ?? "") ?? .grammar
    }
}

extension GrammarPoint {
    var kind: LessonKind { LessonKind(raw: pointType) }
    /// True for the single-character kana cards.
    var isKanaCharacter: Bool { kind == .kana }
}

extension ChapterSummary {
    var kind: LessonKind { LessonKind(raw: chapterType) }
    /// True for the hiragana and katakana chapters.
    var isKanaChapter: Bool { kind == .kana }
}
