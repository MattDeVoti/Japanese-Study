import SwiftUI

/// One side-agnostic review card, resolved from an `SRSItemID` against the app's
/// existing content. The review session renders these so it doesn't need to know
/// anything about vocab vs kanji vs grammar.
struct ReviewCard: Identifiable {
    let id: SRSItemID
    /// The prompt shown first — Japanese, possibly with furigana markup.
    let front: String
    /// Kana reading, used for audio and shown on the answer side.
    let reading: String?
    /// The answer.
    let back: String
    /// Supporting line under the answer (readings, romaji, chapter).
    let extra: String?
    /// Badge text. Kana characters live in grammar chapters but are not grammar,
    /// so the storage kind and the label the learner sees can differ.
    var label: String?
    var accentOverride: Color?
    /// Kana and single kanji can be set huge; phrases cannot.
    var isSingleGlyph: Bool = false

    var kind: SRSItemKind { id.kind }
    var badge: String { label ?? id.kind.label }
    var accent: Color { accentOverride ?? id.kind.color }
}

enum SRSCatalogue {

    // MARK: - Resolution

    static func card(for id: SRSItemID, cardStore: CardStore) -> ReviewCard? {
        switch id.kind {
        case .vocab:
            guard let w = LessonsService.shared.vocabWord(id: id.key) else { return nil }
            return ReviewCard(id: id,
                              front: w.kanji,
                              reading: w.kana,
                              back: w.definition,
                              extra: [w.partOfSpeech, w.romaji].joined(separator: " · "))
        case .kanji:
            guard let c = cardStore.kanjiCards.first(where: { $0.id == id.key }) else { return nil }
            // Reviewed as the chapter taught it. Falling back to the card's full
            // reference entry is what put 分ける on the back of 分 — right about
            // the character, wrong for someone who learned it as ふん.
            if let taught = LessonsService.shared.kanjiEntry(c.kanji) {
                return ReviewCard(id: id,
                                  front: taught.word,
                                  reading: taught.reading,
                                  back: taught.meaning,
                                  extra: taught.word == taught.char ? nil : taught.char,
                                  isSingleGlyph: taught.word.count <= 2)
            }
            let on = c.onyomi.map(\.kana).joined(separator: "、")
            let kun = c.kunyomi.map(\.kana).joined(separator: "、")
            var readings: [String] = []
            if !on.isEmpty { readings.append("音 \(on)") }
            if !kun.isEmpty { readings.append("訓 \(kun)") }
            return ReviewCard(id: id,
                              front: c.kanji,
                              reading: c.kunyomi.first?.kana ?? c.onyomi.first?.kana,
                              back: c.definition,
                              extra: readings.isEmpty ? nil : readings.joined(separator: "   "),
                              isSingleGlyph: c.kanji.count <= 2)
        case .grammar:
            guard let (chapterId, pointId) = splitGrammarKey(id.key),
                  let chapter = LessonsService.shared.loadChapter(chapterId),
                  let p = chapter.points.first(where: { $0.id == pointId }) else { return nil }
            let chapterLabel = "ch\(String(format: "%02d", chapter.chapterNumber))  \(chapter.title)"

            // Kana characters are stored as grammar points but behave like kanji
            // cards: one glyph on the front, its sound on the back.
            if p.isKanaCharacter {
                let isKatakana = p.name.unicodeScalars.first.map { $0.value >= 0x30A0 } ?? false
                return ReviewCard(id: id,
                                  front: p.name,
                                  reading: p.name,
                                  back: p.formation.isEmpty ? p.shortDescription : p.formation,
                                  extra: p.shortDescription,
                                  label: "Kana",
                                  accentOverride: isKatakana ? .katakanaColor : .hiraganaColor,
                                  isSingleGlyph: true)
            }
            return ReviewCard(id: id,
                              front: p.flashcardHeader ?? p.name,
                              reading: nil,
                              back: p.flashcardAnswer ?? p.shortDescription,
                              extra: chapterLabel)
        }
    }

    private static func splitGrammarKey(_ key: String) -> (String, String)? {
        guard let slash = key.firstIndex(of: "/") else { return nil }
        return (String(key[key.startIndex..<slash]), String(key[key.index(after: slash)...]))
    }

    // MARK: - Enrolment candidates

    /// Everything the user has already worked through: checked-off vocab, kanji and
    /// completed grammar points. Seeding the schedule from this means an existing
    /// library turns into a review queue instead of starting from nothing.
    static func studiedItems(cardStore: CardStore) -> [SRSItemID] {
        var out: [SRSItemID] = []

        // Vocab and kanji use "excluded" to mean "checked off".
        for wordId in VocabFlashcardsFilter.shared.excludedWordIds {
            out.append(.vocab(wordId))
        }
        for kanjiId in cardStore.excludedKanjiIds {
            out.append(.kanji(kanjiId))
        }
        for key in LessonsProgressStore.shared.completed {
            guard splitGrammarKey(key) != nil else { continue }
            out.append(SRSItemID(kind: .grammar, key: key))
        }
        return out
    }

    /// Counts by kind, for the "set up reviews" prompt.
    static func studiedBreakdown(cardStore: CardStore) -> [SRSItemKind: Int] {
        var out: [SRSItemKind: Int] = [:]
        for id in studiedItems(cardStore: cardStore) {
            out[id.kind, default: 0] += 1
        }
        return out
    }
}
