import Foundation
import NaturalLanguage

/// Resolves a (possibly inflected) Japanese surface word to a dictionary entry
/// for the reading pop-up. Strategy, cheapest first:
///   1. per-reading glossary override (surface → dictionary form)
///   2. exact match on word or reading
///   3. NLTagger lemma (dictionary form)
///   4. small deinflection heuristics (i-adjectives, する, polite/plain verbs)
///   5. progressively trim trailing kana (handles over-segmented spans)
struct WordDefinition {
    let word: String
    let reading: String?
    let definitions: [String]
    let partsOfSpeech: [String]
}

enum WordLookup {
    /// Resolved lookups, kept for the life of the process.
    ///
    /// Worth it because of how the reading view searches. A press first tries
    /// every substring forward from the token, and if none of them resolve it
    /// walks the start backwards and tries again from each earlier character —
    /// up to about a hundred candidates for one press, most of them misses, and
    /// every miss is several SQLite queries plus a lemma pass. Measured at up to
    /// 130ms on the main thread during the gesture. The dictionary is read-only,
    /// so a result never goes stale, and neighbouring presses ask about mostly
    /// the same substrings.
    private static var cache: [String: WordDefinition?] = [:]
    private static let cacheLock = NSLock()
    /// Passages are small; this is a backstop, not a working limit.
    private static let cacheLimit = 8000

    static func lookup(_ raw: String, glossary: [String: String]? = nil) -> WordDefinition? {
        // Only the plain form is cached. A per-reading glossary would change the
        // answer for the same key, and nothing passes one today.
        if glossary == nil {
            cacheLock.lock()
            let hit = cache[raw]
            cacheLock.unlock()
            if let hit { return hit }
        }
        let result = resolve(raw, glossary: glossary)
        if glossary == nil {
            cacheLock.lock()
            if cache.count >= cacheLimit { cache.removeAll(keepingCapacity: true) }
            cache[raw] = result
            cacheLock.unlock()
        }
        return result
    }

    private static func resolve(_ raw: String, glossary: [String: String]? = nil) -> WordDefinition? {
        let w = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "、。「」『』（）！？・…　")))
        guard !w.isEmpty, containsJapanese(w) else { return nil }

        if let base = glossary?[w], let hit = query(base) { return hit }
        if let hit = query(w) { return hit }
        if let lemma = lemma(of: w), lemma != w, let hit = query(lemma) { return hit }
        for cand in deinflections(w) where cand != w {
            if let hit = query(cand) { return hit }
        }
        // Trim trailing kana one at a time (e.g. an over-segmented "食べて" → "食べ" → 食べる via lemma isn't needed;
        // this mainly rescues compounds where the tail is an attached particle/aux).
        var trimmed = w
        while trimmed.count > 1, let last = trimmed.last, isKana(last) {
            trimmed.removeLast()
            if let hit = query(trimmed) { return hit }
            for cand in deinflections(trimmed + "る") where cand != trimmed {
                if let hit = query(cand) { return hit }
            }
        }
        // Grammatical particle fallback (holding は / を / に shows its role, not "no match").
        if let gloss = particleGloss[w] {
            return WordDefinition(word: w, reading: nil, definitions: [gloss], partsOfSpeech: ["particle"])
        }
        return nil
    }

    private static let particleGloss: [String: String] = [
        "は": "topic marker (\"as for…\")", "が": "subject marker", "を": "direct-object marker",
        "に": "to, at, in (time/place/target)", "で": "at, in, by means of", "へ": "to, toward (direction)",
        "と": "and; with; that (quotation)", "も": "also, too", "の": "possessive / noun-linking \"of\"",
        "か": "question marker; or", "から": "from; because", "まで": "until, as far as",
        "や": "and (among others)", "ね": "right? (seeking agreement)", "よ": "you know (emphasis)",
        "ので": "because, since", "けど": "but, although", "しか": "only (with negative)",
        "だけ": "only, just", "ました": "past polite verb ending", "ます": "polite verb ending",
        "です": "polite \"to be\"", "でした": "was (polite past)"
    ]

    // MARK: - Dictionary query

    private static func query(_ w: String) -> WordDefinition? {
        let entries = DictionaryService.shared.lookup(w)
        guard !entries.isEmpty else { return nil }
        // Short all-kana input (particles / okurigana fragments like に, か, で) must
        // not match a kanji homophone found only by reading (二, 火, 出). Require a
        // kana headword. Longer kana (≥3) may still resolve to a kanji headword.
        if isAllKana(w) && w.count <= 2 {
            guard let e = entries.first(where: { $0.word == w || isAllKana($0.word) }) else { return nil }
            return def(e)
        }
        return def(entries[0])
    }

    private static func def(_ e: DictionaryEntry) -> WordDefinition {
        WordDefinition(word: e.word, reading: e.reading,
                       definitions: e.definitions, partsOfSpeech: e.partsOfSpeech)
    }

    private static func isAllKana(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy { $0.value >= 0x3040 && $0.value <= 0x30FF }
    }

    // MARK: - Lemma

    /// One tagger, reused. Building an `NLTagger` is not cheap, and this is on
    /// the miss path — which the reading view's word search hits dozens of times
    /// for a single press, since most candidates it tries are not words.
    /// Guarded by `cacheLock`, as `NLTagger` is not thread-safe.
    private static let sharedTagger = NLTagger(tagSchemes: [.lemma])

    private static func lemma(of word: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let tagger = sharedTagger
        tagger.string = word
        var result: String?
        tagger.enumerateTags(in: word.startIndex..<word.endIndex, unit: .word,
                             scheme: .lemma, options: [.omitWhitespace]) { tag, _ in
            if let t = tag?.rawValue, !t.isEmpty { result = t; return false }
            return true
        }
        return result
    }

    // MARK: - Deinflection heuristics

    private static func deinflections(_ w: String) -> [String] {
        var out: [String] = []
        func add(_ s: String) { if s.count >= 1 { out.append(s) } }

        // Bare verb stems left when the tokenizer splits verb + auxiliary
        // (行きます → 行き + ます ; 住んでいます → 住ん + で + い + ます).
        if hasKanji(w) {
            add(w + "る")                        // ichidan: 食べ → 食べる, 見 → 見る
            add(godanDictionary(fromIStem: w))   // godan i-stem: 行き → 行く, 話し → 話す
            let base = String(w.dropLast())
            if w.hasSuffix("ん") { add(base + "む"); add(base + "ぶ"); add(base + "ぬ") }        // 住ん → 住む, 死ん → 死ぬ
            if w.hasSuffix("っ") { add(base + "つ"); add(base + "る"); add(base + "う"); add(base + "く") }  // 待っ→待つ, 取っ→取る, 行っ→行く
            if w.hasSuffix("い") { add(base + "う"); add(base + "く"); add(base + "ぐ") }        // 買い→買う, 書い→書く, 泳い→泳ぐ
            if w.hasSuffix("た") { add(base + "る") }                                          // 見た → 見る (ichidan past)
            // nai-stem / a-row → dictionary (読ま→読む, 会わ→会う, 待た→待つ, 話さ→話す …)
            let arow: [Character: Character] = ["わ":"う","か":"く","が":"ぐ","さ":"す","た":"つ","な":"ぬ","ば":"ぶ","ま":"む","ら":"る"]
            if let last = w.last, let u = arow[last] { add(base + String(u)) }
            // volitional (行こう→行く, 会おう→会う, 食べよう→食べる)
            if w.hasSuffix("よう") { add(String(w.dropLast(2)) + "る") }
            if w.hasSuffix("う"), w.count >= 3 {
                let chars = Array(w)
                let vol: [Character: Character] = ["お":"う","こ":"く","ご":"ぐ","そ":"す","と":"つ","の":"ぬ","ぼ":"ぶ","も":"む","ろ":"る"]
                if let u = vol[chars[chars.count - 2]] { add(String(w.dropLast(2)) + String(u)) }
            }
            // potential: godan stem + [e-row]る → [u-row] (過ごせる→過ごす, 書ける→書く, 思える→思う)
            if w.hasSuffix("る"), w.count >= 3 {
                let chars = Array(w)
                let pot: [Character: Character] = ["え":"う","け":"く","げ":"ぐ","せ":"す","て":"つ","ね":"ぬ","べ":"ぶ","め":"む","れ":"る"]
                if let u = pot[chars[chars.count - 2]] { add(String(w.dropLast(2)) + String(u)) }
            }
            if w.hasSuffix("られる") { add(String(w.dropLast(3)) + "る") }  // ichidan potential/passive
        }

        // i-adjectives (incl. tokenizer fragments that drop the final た)
        if w.hasSuffix("かった") { add(String(w.dropLast(3)) + "い") }
        if w.hasSuffix("かっ")   { add(String(w.dropLast(2)) + "い") }   // 安かっ→安い, 面白かっ→面白い
        if w.hasSuffix("くない") { add(String(w.dropLast(3)) + "い") }
        if w.hasSuffix("くて")   { add(String(w.dropLast(2)) + "い") }
        if w.hasSuffix("く") && w.count >= 2 { add(String(w.dropLast(1)) + "い") }   // 悪く→悪い

        // する compounds
        if w.hasSuffix("しました") { add(String(w.dropLast(4)) + "する") }
        if w.hasSuffix("します")   { add(String(w.dropLast(3)) + "する") }
        if w.hasSuffix("して")     { add(String(w.dropLast(2)) + "する") }

        // Polite verb endings → ichidan (drop ます/…, add る) + godan reconstruction from the i-stem
        for suf in ["ませんでした", "ましょう", "ました", "ません", "まして", "ます"] where w.hasSuffix(suf) {
            let stem = String(w.dropLast(suf.count))
            add(stem + "る")                 // ichidan (食べます → 食べる)
            add(godanDictionary(fromIStem: stem)) // godan (行きます → 行く)
        }

        // Plain past / te-form (best effort: ichidan)
        if w.hasSuffix("て") || w.hasSuffix("た") { add(String(w.dropLast(1)) + "る") }
        if w.hasSuffix("ない") { add(String(w.dropLast(2)) + "る") }

        return out
    }

    /// Reconstructs a godan dictionary form from its ren'yōkei (i-stem):
    /// 行き → 行く, 話し → 話す, 待ち → 待つ, 飲み → 飲む, etc.
    private static func godanDictionary(fromIStem stem: String) -> String {
        guard let last = stem.last else { return stem }
        let map: [Character: Character] = [
            "い": "う", "き": "く", "ぎ": "ぐ", "し": "す", "ち": "つ",
            "に": "ぬ", "び": "ぶ", "み": "む", "り": "る"
        ]
        guard let u = map[last] else { return stem }
        return String(stem.dropLast()) + String(u)
    }

    // MARK: - Helpers

    static func containsJapanese(_ s: String) -> Bool {
        s.unicodeScalars.contains { $0.value >= 0x3040 && $0.value <= 0x9FFF }
    }

    private static func hasKanji(_ s: String) -> Bool {
        s.unicodeScalars.contains { ($0.value >= 0x4E00 && $0.value <= 0x9FFF) || ($0.value >= 0x3400 && $0.value <= 0x4DBF) }
    }

    private static func isKana(_ c: Character) -> Bool {
        c.unicodeScalars.allSatisfy { ($0.value >= 0x3040 && $0.value <= 0x30FF) }
    }
}
