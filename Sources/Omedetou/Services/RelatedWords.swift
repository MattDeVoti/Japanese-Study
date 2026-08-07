import Foundation

// "See also" for a dictionary entry: words with the same sense, and words with
// the opposite one.
//
// The two halves are built completely differently, on purpose.
//
// ANTONYMS are written by hand. There is no way to infer "big is the opposite of
// small" from a set of English glosses, and guessing would be worse than saying
// nothing. Every pair below was checked against the bundled data before shipping,
// so none of them can point at a word that isn't there.
//
// SYNONYMS are derived, because hand-listing them across four thousand entries
// isn't realistic — but derived carefully. The obvious approach, "two entries
// share an English gloss", produces nonsense: 見る and 会う both carry "to see",
// 上 and 右 both carry "above" (as in "the above statement"), いる and 待つ both
// carry "to need". English polysemy, not Japanese synonymy.
//
// Three filters fix it:
//
//   1. A gloss shared by more than five entries is thrown away. Those are the
//      English words doing too many jobs — "well", "all", "to get".
//   2. Two entries must agree on at least TWO glosses. One shared gloss is a
//      coincidence; two is a claim.
//   3. Entries with the same reading are dropped — いる and 居る are one word
//      spelled two ways, not a pair of synonyms.
//
// That takes coverage from about 1,900 entries down to roughly 430. The trade is
// deliberate: a page that says nothing is fine, a page that says something wrong
// is not.

enum RelatedWords {

    // MARK: - Antonyms, written by hand

    private static let antonymPairs: [(String, String)] = [
        ("大きい", "小さい"),
        ("高い", "安い"),
        ("高い", "低い"),
        ("暑い", "寒い"),
        ("熱い", "冷たい"),
        ("新しい", "古い"),
        ("多い", "少ない"),
        ("長い", "短い"),
        ("早い", "遅い"),
        ("速い", "遅い"),
        ("良い", "悪い"),
        ("いい", "悪い"),
        ("強い", "弱い"),
        ("重い", "軽い"),
        ("明るい", "暗い"),
        ("近い", "遠い"),
        ("広い", "狭い"),
        ("難しい", "易しい"),
        ("難しい", "簡単"),
        ("面白い", "つまらない"),
        ("忙しい", "暇"),
        ("上手", "下手"),
        ("好き", "嫌い"),
        ("安全", "危険"),
        ("便利", "不便"),
        ("きれい", "汚い"),
        ("太い", "細い"),
        ("深い", "浅い"),
        ("おいしい", "まずい"),
        ("若い", "古い"),
        ("行く", "来る"),
        ("買う", "売る"),
        ("開ける", "閉める"),
        ("開く", "閉まる"),
        ("始まる", "終わる"),
        ("入る", "出る"),
        ("立つ", "座る"),
        ("起きる", "寝る"),
        ("乗る", "降りる"),
        ("貸す", "借りる"),
        ("教える", "習う"),
        ("押す", "引く"),
        ("増える", "減る"),
        ("覚える", "忘れる"),
        ("着る", "脱ぐ"),
        ("出す", "入れる"),
        ("上がる", "下がる"),
        ("勝つ", "負ける"),
        ("笑う", "泣く"),
        ("生まれる", "死ぬ"),
        ("男", "女"),
        ("朝", "夜"),
        ("前", "後ろ"),
        ("上", "下"),
        ("右", "左"),
        ("北", "南"),
        ("東", "西"),
        ("父", "母"),
        ("兄", "弟"),
        ("姉", "妹"),
        ("夏", "冬"),
        ("春", "秋"),
        ("白", "黒"),
        ("昼", "夜"),
        ("大人", "子供"),
        ("先生", "学生"),
        ("質問", "答え"),
        ("出口", "入口"),
        ("最初", "最後"),
        ("男の人", "女の人"),
        ("兄弟", "姉妹"),
        ("親", "子供")
    ]

    private static let antonymIndex: [String: [String]] = {
        var map: [String: [String]] = [:]
        for (a, b) in antonymPairs {
            map[a, default: []].append(b)
            map[b, default: []].append(a)
        }
        return map
    }()

    static func antonyms(for entry: DictionaryEntry) -> [DictionaryEntry] {
        (antonymIndex[entry.word] ?? []).compactMap {
            DictionaryService.shared.entry(word: $0, reading: nil)
        }
    }

    // MARK: - Synonyms, derived

    /// A gloss on more than this many entries is an English coincidence.
    private static let maxCluster = 5
    /// How many glosses two entries must agree on before they count as related.
    private static let minShared = 2
    /// Kept short — this is a footnote on the page, not a thesaurus.
    private static let maxShown = 6

    private static var index: [Int: [Int]]?

    /// One full pass over the dictionary, cached for the life of the process.
    /// Runs on first use rather than at launch, so a user who never opens an
    /// entry never pays for it.
    private static func buildIndex() -> [Int: [Int]] {
        let all = DictionaryService.shared.allEntries()

        var byGloss: [String: [Int]] = [:]
        var glosses: [Int: Set<String>] = [:]
        var reading: [Int: String] = [:]
        var word: [Int: String] = [:]

        for e in all {
            let g = Set(e.definitions.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                                     .filter { !$0.isEmpty })
            glosses[e.id] = g
            reading[e.id] = e.reading ?? ""
            word[e.id] = e.word
            for gloss in g { byGloss[gloss, default: []].append(e.id) }
        }

        var shared: [Int: [Int: Int]] = [:]
        for (_, ids) in byGloss where ids.count <= maxCluster {
            let unique = Array(Set(ids)).sorted()
            for i in 0..<unique.count {
                for j in (i + 1)..<unique.count {
                    shared[unique[i], default: [:]][unique[j], default: 0] += 1
                    shared[unique[j], default: [:]][unique[i], default: 0] += 1
                }
            }
        }

        var out: [Int: [Int]] = [:]
        for (a, partners) in shared {
            let kept = partners
                .filter { $0.value >= minShared }
                .map(\.key)
                .filter { b in
                    // Same spelling, or the same reading spelled differently, is
                    // the same word — not something to link to.
                    word[a] != word[b] && !(reading[a] == reading[b] && !(reading[a] ?? "").isEmpty)
                }
            if !kept.isEmpty { out[a] = kept }
        }
        return out
    }

    static func synonyms(for entry: DictionaryEntry) -> [DictionaryEntry] {
        if index == nil { index = buildIndex() }
        let ids = index?[entry.id] ?? []
        return ids.prefix(maxShown).compactMap { DictionaryService.shared.entry(id: $0) }
            .sorted { $0.word.count < $1.word.count }
    }
}
