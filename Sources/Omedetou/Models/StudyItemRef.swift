import SwiftUI

// A reference to one studiable item, independent of any deck or screen.
//
// This is all that outlived the review feature. The reviews are gone, but two
// things still need to say "this particular word / kanji / grammar point" and
// open it: the kanji matching round's results list, and the detail sheet it
// shares with anything else that wants the same. Keeping the reference type
// rather than the schedule around it is the smallest thing that serves both.

enum StudyItemKind: String, Codable, CaseIterable {
    case vocab, kanji, grammar

    var label: String {
        switch self {
        case .vocab:   return "Vocab"
        case .kanji:   return "Kanji"
        case .grammar: return "Grammar"
        }
    }
    var color: Color {
        switch self {
        case .vocab:   return .vocabColor
        case .kanji:   return .kanjiColor
        case .grammar: return .grammarColor
        }
    }
}

/// `key` is the vocab word id, the kanji card or word id, or "chapterId/pointId"
/// for a grammar point.
struct StudyItemRef: Hashable, Codable, Identifiable {
    let kind: StudyItemKind
    let key: String

    /// Already unique per item, so it doubles as the SwiftUI identity.
    var id: String { "\(kind.rawValue):\(key)" }

    init(kind: StudyItemKind, key: String) {
        self.kind = kind
        self.key = key
    }

    static func vocab(_ id: String) -> StudyItemRef { .init(kind: .vocab, key: id) }
    static func kanji(_ id: String) -> StudyItemRef { .init(kind: .kanji, key: id) }
    static func grammar(chapterId: String, pointId: String) -> StudyItemRef {
        .init(kind: .grammar, key: "\(chapterId)/\(pointId)")
    }
}
