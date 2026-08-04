import Foundation

/// One hit from the Textbook-wide search, tagged with the chapter it came from
/// so results can be grouped by *where* they were found.
struct LessonSearchResult: Identifiable {
    enum Kind {
        case grammar(GrammarPoint)
        case vocab(LessonVocabWord)
        case kanji(String)
        case culture(CultureTopic)

        /// Sort order within a chapter group.
        var rank: Int {
            switch self {
            case .grammar: return 0
            case .vocab:   return 1
            case .kanji:   return 2
            case .culture: return 3
            }
        }

        var label: String {
            switch self {
            case let .grammar(p): return p.pointType == "kana" ? "Kana" : "Grammar"
            case .vocab:          return "Vocab"
            case .kanji:          return "Kanji"
            case .culture:        return "Culture"
            }
        }
    }

    let id: String
    let chapterId: String
    let chapterTitle: String
    let chapterNumber: Int
    let levelId: String
    /// Position of the owning chapter in the manifest — keeps groups in book order.
    let chapterOrder: Int
    let kind: Kind
    let primary: String
    let secondary: String
    fileprivate let haystack: String
}

/// Builds a one-time index over every chapter's grammar points, vocab, and kanji
/// (plus the Culture chapter) so the Textbook search can scan everything without
/// re-decoding chapter JSON on each keystroke.
final class LessonSearchService {
    static let shared = LessonSearchService()
    private init() {}

    private var entries: [LessonSearchResult]?

    func buildIfNeeded(cardStore: CardStore) {
        guard entries == nil else { return }
        LessonsService.shared.loadIfNeeded()

        var out: [LessonSearchResult] = []
        var order = 0

        for level in LessonsService.shared.manifest?.levels ?? [] {
            for summary in level.chapters {
                defer { order += 1 }
                guard let chapter = LessonsService.shared.loadChapter(summary.id) else { continue }

                func make(_ kind: LessonSearchResult.Kind, _ id: String,
                          _ primary: String, _ secondary: String, _ extra: String) -> LessonSearchResult {
                    LessonSearchResult(
                        id: id, chapterId: summary.id, chapterTitle: chapter.title,
                        chapterNumber: summary.chapterNumber, levelId: level.levelId,
                        chapterOrder: order, kind: kind, primary: primary, secondary: secondary,
                        haystack: "\(primary) \(secondary) \(extra)".lowercased())
                }

                for p in chapter.points {
                    out.append(make(.grammar(p), "g:\(summary.id)/\(p.id)",
                                    strippedFurigana(p.name), p.shortDescription,
                                    "\(p.formation) \(p.explanation) \(p.rules.joined(separator: " "))"))
                }
                for w in chapter.vocab ?? [] {
                    out.append(make(.vocab(w), "v:\(w.id)",
                                    w.kanji, w.definition, "\(w.kana) \(w.romaji) \(w.partOfSpeech)"))
                }
                for k in chapter.kanji ?? [] {
                    let card = cardStore.kanjiCard(for: k)
                    let readings = ((card?.onyomi ?? []) + (card?.kunyomi ?? []))
                        .map { "\($0.kana) \($0.romaji)" }.joined(separator: " ")
                    out.append(make(.kanji(k), "k:\(summary.id)/\(k)",
                                    k, card?.definition ?? "", readings))
                }
            }
        }

        // Culture chapter — part of the Textbook, so it's searchable too.
        for t in CultureContent.topics {
            out.append(LessonSearchResult(
                id: "c:\(t.id)", chapterId: CultureContent.chapterId, chapterTitle: "Culture",
                chapterNumber: 0, levelId: "Culture", chapterOrder: order,
                kind: .culture(t), primary: t.title, secondary: t.subtitle,
                haystack: "\(t.title) \(t.subtitle) \(t.body)".lowercased()))
        }

        entries = out
    }

    /// Case-insensitive substring match over each entry's searchable text, ranked
    /// so a hit on the word/name itself beats a hit on its meaning, which in turn
    /// beats a hit buried in explanation text.
    func search(_ query: String, cardStore: CardStore, limit: Int = 300) -> [LessonSearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        buildIfNeeded(cardStore: cardStore)

        func tier(_ r: LessonSearchResult) -> Int {
            if r.primary.lowercased().contains(q) { return 0 }
            if r.secondary.lowercased().contains(q) { return 1 }
            return 2
        }

        return (entries ?? [])
            .filter { $0.haystack.contains(q) }
            .sorted { a, b in
                let ta = tier(a), tb = tier(b)
                if ta != tb { return ta < tb }
                if a.chapterOrder != b.chapterOrder { return a.chapterOrder < b.chapterOrder }
                return a.kind.rank < b.kind.rank
            }
            .prefix(limit)
            .map { $0 }
    }
}
