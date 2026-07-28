import Foundation
import Combine

// MARK: - Word cards

/// One of a kanji card's example words, promoted to a flashcard of its own.
/// A handful of words appear under more than one kanji (示唆 sits on both 示 and
/// 唆), so a word remembers every kanji card it came from.
struct KanjiWordCard: Identifiable, Hashable {
    let word: KanjiCommonWord
    /// Kanji card ids this word appears on, in kanji-data order.
    let parentIds: [String]
    /// Level of the easiest kanji it appears under — where a learner meets it first.
    let nLevel: Int

    /// Stable synthetic id. Shares the id space with kanji cards, so study
    /// weights and checkmarks work without a parallel storage system.
    var id: String { KanjiWordCard.id(for: word) }

    static func id(for word: KanjiCommonWord) -> String {
        "kw:\(word.kanji)|\(word.kana)"
    }
}

// MARK: - Unified study item

/// A kanji flashcard is either the kanji itself or one of its example words.
enum KanjiStudyItem: Identifiable, Hashable {
    case kanji(KanjiCard)
    case word(KanjiWordCard)

    var id: String {
        switch self {
        case let .kanji(c): return c.id
        case let .word(w):  return w.id
        }
    }

    var nLevel: Int {
        switch self {
        case let .kanji(c): return c.nLevel
        case let .word(w):  return w.nLevel
        }
    }

    /// What shows on the front of the card.
    var face: String {
        switch self {
        case let .kanji(c): return c.kanji
        case let .word(w):  return w.word.kanji
        }
    }

    var isWord: Bool {
        if case .word = self { return true }
        return false
    }
}

// MARK: - Settings

/// Whether the kanji decks also drill each kanji's example words. Off by default,
/// so the decks stay focused on the kanji themselves until the user opts in.
/// Persisted app-wide, so the Study section and a chapter's Study Kanji stay in sync.
final class KanjiStudySettings: ObservableObject {
    static let shared = KanjiStudySettings()

    private static let key = "KanjiIncludeCommonWords"

    @Published var includeCommonWords: Bool = false {
        didSet { if didLoad { UserDefaults.standard.set(includeCommonWords, forKey: Self.key) } }
    }

    private var didLoad = false

    private init() {
        if UserDefaults.standard.object(forKey: Self.key) != nil {
            includeCommonWords = UserDefaults.standard.bool(forKey: Self.key)
        }
        didLoad = true
    }
}
