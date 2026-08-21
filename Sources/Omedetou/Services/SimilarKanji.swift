import Foundation

// Kanji that get mistaken for each other.
//
// The sets are written by hand rather than computed. The bundled kanji data
// carries readings, meanings and example words but no component or radical
// breakdown, so there is nothing to compute visual similarity *from* — and a
// guess dressed up as an algorithm would be worse than an honest list, because
// the whole exercise depends on the pairs actually being confusable. A round
// built from kanji that look nothing alike teaches nothing.
//
// Groups are only as good as their worst member, so each one shares a real
// visual feature: an identical component (待/持/特), a shared frame (開/閉/間/聞/問),
// or a one-stroke difference (未/末, 千/干, 石/右).

enum SimilarKanji {

    /// Each string is one confusable set. Members missing from the bundled data
    /// are dropped at load, and a set left with fewer than two is skipped.
    private static let sets: [String] = [
        "大太犬", "未末", "日目白", "千干", "手毛", "石右", "貝見",
        "待持特", "使便", "王玉主", "木本休体", "人入", "何荷", "話語",
        "買売", "開閉間聞問", "学字", "牛午", "田由申", "自白", "近返",
        "料科", "険験", "続読", "者著", "陽場湯", "堂常", "少小",
        "母毎海", "鳥島", "青晴清静", "花化", "水氷永", "米来", "先洗",
        "分公", "半判", "友反", "天夫失", "重動働", "同回", "北比",
        "旅族", "館官", "薬楽", "帰掃",
    ]

    struct Item: Identifiable, Hashable {
        let kanji: String
        let reading: String
        let meaning: String
        var id: String { kanji }
    }

    /// One playable round: the kanji to fill, and the tiles that fit them.
    struct Round {
        let items: [Item]
        /// Order the holes appear in — separate from the tiles' order, so the
        /// answer can't be read off the layout.
        let holeOrder: [Item]
        let tileOrder: [Item]
    }

    /// Sets that survive filtering against the bundled data.
    ///
    /// Duplicate readings are dropped *here*, not when a round is dealt. Two
    /// tiles both reading かん are separable only by meaning, which isn't the
    /// skill this drills — so a member whose reading is already spoken for is
    /// removed, and a set left with one usable member is removed with it. That
    /// retires 館/官 and 半/判 outright: both pairs share their only common
    /// reading, and neither has a second one worth teaching in its place.
    ///
    /// Filtering later instead was a real bug: the set passed the two-member
    /// check on its raw members, then collapsed to one when the readings were
    /// deduplicated, and the round came back nil — a spinner the game never
    /// came back from, on 4% of deals.
    static func availableSets(cardStore: CardStore) -> [[Item]] {
        sets.compactMap { set -> [Item]? in
            var readings = Set<String>()
            let items = set.compactMap { char -> Item? in
                guard let item = item(for: String(char), cardStore: cardStore),
                      readings.insert(item.reading).inserted else { return nil }
                return item
            }
            return items.count >= 2 ? items : nil
        }
    }

    /// A round of `size` kanji drawn from one set. `size` is clamped to what the
    /// chosen set can actually supply. Non-nil whenever any set survived the
    /// filter above, which for the bundled data is always.
    static func round(size: Int, cardStore: CardStore) -> Round? {
        guard let pool = availableSets(cardStore: cardStore).randomElement() else { return nil }
        let picked = Array(pool.shuffled().prefix(min(max(size, 2), pool.count)))
        return Round(items: picked,
                     holeOrder: picked.shuffled(),
                     tileOrder: picked.shuffled())
    }

    // MARK: - Building one item

    private static func item(for kanji: String, cardStore: CardStore) -> Item? {
        guard let card = cardStore.kanjiCard(id: kanji) else { return nil }
        let reading = primaryReading(card)
        guard !reading.isEmpty else { return nil }
        return Item(kanji: kanji, reading: reading, meaning: shortMeaning(card.definition))
    }

    /// Readings the count below gets wrong, pinned by hand.
    ///
    /// Counting example words favours whichever form opens the most compounds,
    /// and for a handful of characters that is not a form worth teaching. It
    /// picks the 連用形 stem over the dictionary form when the stem happens to
    /// head more nouns (待 → まち from 待ち合わせ, rather than まつ), a fragment
    /// that isn't a word at all (重 → おも, 静 → しず), or a reading that is real
    /// but rare (千 → ち, 氷 → ひ, 験 → あかし). A tile in this exercise is the
    /// only thing naming the kanji, so it has to be the reading the character is
    /// actually known by.
    ///
    /// Every pin is a reading the card already lists — this chooses between what
    /// the data holds, it doesn't invent. `primaryReading` checks that before
    /// honouring one, so a pin that stops matching the data quietly falls back
    /// to the count rather than teaching a reading the card doesn't carry.
    private static let pinnedReadings: [String: String] = [
        "待": "まつ", "持": "もつ", "読": "よむ", "申": "もうす",   // dictionary form, not the stem
        "重": "おもい", "静": "しずか",                            // stems that aren't words
        "千": "せん", "氷": "こおり", "験": "けん",                  // the reading it's known by
        "間": "あいだ",                                          // ま is real but thin
        // 小 and 洗 both computed to the same reading as the character they are
        // meant to be told apart from (しょう, せん), which retired 少/小 and
        // 先/洗 — two of the more confusable pairs in the list — without a word
        // anywhere. Their kun readings separate them and are what the character
        // is known by regardless.
        "小": "ちいさい", "洗": "あらう",
    ]

    /// The reading a learner has actually met, chosen by how often it opens one
    /// of the kanji's own example words.
    ///
    /// Taking the first kun reading instead looks reasonable and isn't: 自 lists
    /// みずから first, which is correct and useless — the reading anyone knows is
    /// じ, from 自分. Counting against the example words picks じ, and picks み for
    /// 未 (未知) and おお for 大, all without hand-listing anything.
    private static func primaryReading(_ card: KanjiCard) -> String {
        let kun = card.kunyomi.map(\.kana).filter { !$0.isEmpty }
        let on = card.onyomi.map(\.kana).filter { !$0.isEmpty }

        if let pin = pinnedReadings[card.kanji],
           (kun + on).contains(where: { hiragana($0).replacingOccurrences(of: "-", with: "") == pin }) {
            return pin
        }
        let words = card.commonWords.map { hiragana($0.kana) }

        var best: (score: Int, kunFirst: Int, reading: String)?
        for (list, rank) in [(kun, 0), (on, 1)] {
            for raw in list {
                let r = hiragana(raw).replacingOccurrences(of: "-", with: "")
                guard !r.isEmpty else { continue }
                let score = words.reduce(0) { $0 + ($1.hasPrefix(r) ? 1 : 0) }
                let candidate = (score, -rank, r)
                if best == nil || (candidate.0, candidate.1) > (best!.score, best!.kunFirst) {
                    best = (candidate.0, candidate.1, candidate.2)
                }
            }
        }
        if let best, best.score > 0 { return best.reading }
        // No example word corroborates any reading — fall back to kun, then on.
        let fallback = (kun + on).first ?? ""
        return hiragana(fallback).replacingOccurrences(of: "-", with: "")
    }

    /// On readings are stored in katakana; tiles read better all in hiragana.
    private static func hiragana(_ s: String) -> String {
        String(s.unicodeScalars.map { scalar -> Character in
            (0x30A1...0x30F6).contains(scalar.value)
                ? Character(Unicode.Scalar(scalar.value - 0x60)!)
                : Character(scalar)
        })
    }

    /// Definitions run long ("meeting, meet, party, association, interview").
    /// Two senses is enough to tell one kanji from another without a wall of text.
    private static func shortMeaning(_ definition: String) -> String {
        // "(kokuji)" and "(no. 61)" are notes about the character, not meanings,
        // and reading "work, (kokuji)" on a tile is just noise. Other bracketed
        // fragments — "(cards)", "(chess)", "(music)" — disambiguate a sense and
        // are kept.
        let senses = definition
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { $0 != "(kokuji)" && !$0.hasPrefix("(no.") }
        guard !senses.isEmpty else { return definition }
        let kept = senses.prefix(2).joined(separator: ", ")
        return senses.count > 2 ? kept + "…" : kept
    }
}
