import Foundation

// Judging a spoken English answer against a dictionary definition.
//
// The problem this solves: a definition is a list of glosses ("to hear, to ask"),
// and a learner who knows the word says one of them, in whatever order, with or
// without the infinitive "to". All of these are right:
//
//     "hear"   "to hear"   "to ask, to hear"   "ask"
//
// and this is not, because it carries no meaning at all:
//
//     "to"
//
// Deliberately kept free of UIKit/AVFoundation so it can be compiled and
// exercised on its own — see the header of `judge` for the rules it guarantees.

enum VocalVerdict: Equatable {
    case correct
    case incorrect
    /// The learner explicitly gave up on this word ("skip", "I don't know").
    case skipped
    /// The learner asked to end the session ("stop", "quit").
    case stopped
    /// Nothing was heard at all — the window closed on silence.
    case silent
}

enum VocalAnswerMatcher {

    // MARK: - Entry point

    /// Judges `heard` against `definition`.
    ///
    /// The contract, in order:
    /// 1. Nothing heard → `.silent`.
    /// 2. An outright "I don't know", in English or Japanese → `.skipped`.
    /// 3. The learner covers any one gloss of the definition → `.correct`.
    /// 4. A bare command — "stop"/"quit" → `.stopped`, "skip"/"pass" → `.skipped`.
    /// 5. Otherwise → `.incorrect`.
    ///
    /// The order of 3 and 4 is the whole point of the split. Commands are single
    /// ordinary words that are also perfectly good answers — "stop" is 止[と]まる,
    /// "skip" is サボる — so the word is judged *first*, and a right answer is
    /// never mistaken for a request to leave. The phrases in step 2 carry their
    /// own negation and can't be anyone's definition, so they need no such care.
    ///
    /// "Covers a gloss" means: every *distinctive* word of that gloss was said,
    /// in any order, and the learner said at least one word that carries meaning.
    /// That last clause is what stops a bare "to" — or "the", or a cough
    /// transcribed as "a" — from passing.
    static func judge(heard: String, definition: String) -> VocalVerdict {
        if normalise(heard).isEmpty { return .silent }
        if isGivingUp(heard) { return .skipped }

        let saidAll = allWords(in: heard)
        let saidContent = saidAll.subtracting(stopWords)
        let definitionWords = allWords(in: definition)

        for gloss in glosses(in: definition) {
            if covers(saidContent: saidContent, saidAll: saidAll,
                      definitionWords: definitionWords, gloss: gloss) {
                return .correct
            }
        }

        let said = normalise(heard)
        if isCommand(said, in: endPhrases, definitionWords: definitionWords) { return .stopped }
        if isCommand(said, in: moveOnPhrases, definitionWords: definitionWords) { return .skipped }
        return .incorrect
    }

    /// Whether a bare command should be honoured as one.
    ///
    /// Only when the definition isn't about it. Two real words in the deck make
    /// this necessary: 停止 is "stopping", so a learner answering "stop" would be
    /// thrown out of their own session; and かなり is "quite", which a recogniser
    /// listening in English will sometimes hand back as "quit". Ending a session
    /// on a decent answer is the worst mistake available here, so any shared
    /// prefix in either direction disqualifies the command reading and the
    /// utterance is judged as the ordinary wrong answer it probably is.
    private static func isCommand(_ said: String, in phrases: Set<String>,
                                  definitionWords: Set<String>) -> Bool {
        guard phrases.contains(said) else { return false }
        return !definitionWords.contains { word in
            word.count >= 3 && (word.hasPrefix(said) || said.hasPrefix(word))
        }
    }

    /// Judges a spoken *Japanese* answer against the word it should have been.
    ///
    /// A different problem from the English direction, and a more delicate one.
    /// Recognition is trained on native speakers, so a learner's pronunciation
    /// will sometimes miss through no fault of their own — which is exactly why
    /// this errs generous. Both the written form and the kana are accepted, and
    /// a containment match counts, because recognition returns 食べる for
    /// "たべる" as often as not and pads answers with particles and stray sounds.
    /// The session's "I was right" button is the backstop for the rest.
    static func judgeJapanese(heard: String, word: String, kana: String) -> VocalVerdict {
        if japanese(heard).isEmpty, normalise(heard).isEmpty { return .silent }
        if isGivingUp(heard) { return .skipped }

        let said = japanese(heard)
        let targets = [word, kana].map(japanese).filter { $0.count >= 1 }
        if !said.isEmpty {
            for target in targets where said == target || said.contains(target) {
                return .correct
            }
        }

        // Commands come last for the same reason as in the English direction:
        // the answer is checked before anything is read as an instruction.
        let plain = normalise(heard)
        if endPhrases.contains(plain) { return .stopped }
        if moveOnPhrases.contains(plain) { return .skipped }
        return .incorrect
    }

    /// Kana and kanji only, with katakana folded to hiragana — so ライス and
    /// らいす compare equal, and spacing or punctuation the recogniser invents
    /// can't decide an answer.
    private static func japanese(_ text: String) -> String {
        String(text.unicodeScalars.compactMap { scalar -> Character? in
            let v = scalar.value
            if (0x30A1...0x30F6).contains(v) {                 // katakana → hiragana
                return Character(UnicodeScalar(v - 0x60)!)
            }
            if (0x3041...0x3096).contains(v)                    // hiragana
                || (0x4E00...0x9FFF).contains(v)                // kanji
                || v == 0x30FC {                                // ー
                return Character(scalar)
            }
            return nil
        })
    }

    // MARK: - Gloss matching

    /// True when everything the gloss genuinely rests on was said.
    ///
    /// A gloss's distinctive words are its content words minus the "light" ones —
    /// the `take`/`make`/`get` scaffolding that English hangs phrases on. So
    /// "to take a picture" rests on *picture*, and saying "picture" is enough,
    /// while "to hear" rests on *hear* and nothing else will do.
    ///
    /// When a gloss is *entirely* light ("to go out", "to put on") there is no
    /// distinctive core to demand, so any one of its content words carries it.
    private static func covers(saidContent: Set<String>, saidAll: Set<String>,
                               definitionWords: Set<String>, gloss: String) -> Bool {
        let content = contentWords(in: gloss)

        // A gloss made entirely of grammatical words — 俺 "I; me", これ "this",
        // 及び "and". Here the function word *is* the answer, so it has to be
        // matched against everything the learner said rather than against their
        // content words, which by definition are empty.
        //
        // The safeguard is the second clause: every meaningful word they did say
        // must belong to this definition. That keeps a stray "and" inside a wrong
        // answer from passing, while "it's me" and "this thing" still count.
        if content.isEmpty {
            let glossWords = allWords(in: gloss)
            guard !glossWords.isEmpty else { return false }
            return glossWords.allSatisfy { matches($0, in: saidAll) }
                && saidContent.allSatisfy { matches($0, in: definitionWords) }
        }

        // Nothing meaningful was said, so there is nothing to credit — this is
        // what stops a bare "to", or a cough transcribed as "a".
        guard !saidContent.isEmpty else { return false }

        let distinctive = content.filter { !lightWords.contains($0) }
        if distinctive.isEmpty {
            return content.contains { matches($0, in: saidContent) }
        }
        return distinctive.allSatisfy { matches($0, in: saidContent) }
    }

    /// Word equality, loosened just enough to absorb recognition slips.
    ///
    /// Plurals are folded, and a single-character difference is forgiven on long
    /// words only — "expensive"/"expencive" yes, "hear"/"heat" no. Recognition
    /// swapping one short word for another is exactly the case where forgiving
    /// it would credit an answer the learner never gave.
    private static func matches(_ word: String, in said: Set<String>) -> Bool {
        if said.contains(word) { return true }
        let wordStems = stems(of: word)
        for candidate in said {
            if !wordStems.isDisjoint(with: stems(of: candidate)) { return true }
            if word.count >= 6, candidate.count >= 6, editDistanceIsAtMostOne(word, candidate) {
                return true
            }
        }
        return false
    }

    /// Every form a word might reasonably be reduced to, compared as a set
    /// because English inflection is ambiguous in both directions: "passing"
    /// could come from "pass", and "stopping" from "stop", and no single rule
    /// gets both without mangling one of them.
    ///
    /// This is what lets 停止 "stopping" be answered with "stop" and 合格
    /// "passing" with "pass" — real deck entries where the gloss is inflected
    /// and the natural spoken answer isn't.
    private static func stems(of word: String) -> Set<String> {
        var out: Set<String> = [word]
        if word.count > 4, word.hasSuffix("es") { out.insert(String(word.dropLast(2))) }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") {
            out.insert(String(word.dropLast()))
        }
        if word.count > 5, word.hasSuffix("ing") {
            let base = String(word.dropLast(3))
            out.insert(base)                                  // passing → pass
            out.insert(base + "e")                            // making  → make
            if let last = base.last, base.dropLast().last == last {
                out.insert(String(base.dropLast()))           // stopping → stop
            }
        }
        return out
    }

    /// Bounded Levenshtein: gives up as soon as two edits are needed, which is all
    /// the caller asks about.
    private static func editDistanceIsAtMostOne(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let x = Array(a), y = Array(b)
        if abs(x.count - y.count) > 1 { return false }

        var i = 0, j = 0, edits = 0
        while i < x.count, j < y.count {
            if x[i] == y[j] { i += 1; j += 1; continue }
            edits += 1
            if edits > 1 { return false }
            if x.count == y.count { i += 1; j += 1 }        // substitution
            else if x.count > y.count { i += 1 }            // deletion from a
            else { j += 1 }                                 // insertion into a
        }
        // Whatever is left over on either side is one more edit.
        return edits + (x.count - i) + (y.count - j) <= 1
    }

    // MARK: - Splitting

    /// The separate meanings in a definition. "to hear, to ask" is two promises,
    /// and satisfying either one is knowing the word.
    ///
    /// Parenthetical asides are dropped first: "session (of a legislature)" must
    /// not require the learner to recite the legislature.
    static func glosses(in definition: String) -> [String] {
        var stripped = ""
        var depth = 0
        for ch in definition {
            if ch == "(" || ch == "[" { depth += 1; stripped.append(" "); continue }
            if ch == ")" || ch == "]" { depth = max(0, depth - 1); stripped.append(" "); continue }
            if depth == 0 { stripped.append(ch) }
        }
        return stripped
            .components(separatedBy: CharacterSet(charactersIn: ",;/·、"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Words

    /// Every lowercased word, scaffolding included.
    private static func allWords(in text: String) -> Set<String> {
        Set(normalise(text).split(separator: " ").map(String.init))
    }

    /// Lowercased words with the grammatical scaffolding removed.
    private static func contentWords(in text: String) -> Set<String> {
        allWords(in: text).subtracting(stopWords)
    }

    /// Lowercase, and anything that isn't a letter, digit or apostrophe becomes a
    /// space. Speech recognition punctuates unpredictably, so punctuation can
    /// never be allowed to decide an answer.
    private static func normalise(_ text: String) -> String {
        let flattened = text.lowercased().map { ch -> Character in
            if ch.isLetter || ch.isNumber || ch == "'" { return ch }
            return " "
        }
        return String(flattened).split(separator: " ").joined(separator: " ")
    }

    /// An outright "I don't know", in either language.
    private static func isGivingUp(_ heard: String) -> Bool {
        let said = normalise(heard)
        if giveUpPhrases.contains(said) { return true }
        // Japanese is matched on a squashed string rather than whole-utterance
        // equality, because recognition is running in English: わからない may come
        // back as kana, as "wakaranai", or as "waka ranai", and the spacing is
        // anyone's guess. Substring matching absorbs all three. None of these
        // stems occur inside an English gloss, so nothing legitimate is caught.
        let squashed = said.replacingOccurrences(of: " ", with: "")
        return japaneseGiveUpStems.contains { squashed.contains($0) }
    }

    // MARK: - Vocabulary

    /// Words that never carry a definition on their own. Note what is *absent*:
    /// in, on, out, up, down, off, over. Those look like filler but they are the
    /// whole difference between 出る and 出す in English glosses, so they stay.
    private static let stopWords: Set<String> = [
        "a", "an", "the", "to", "of", "and", "or",
        "be", "is", "am", "are", "was", "were", "been", "being",
        "it", "its", "this", "that", "these", "those", "as",
        "i", "you", "he", "she", "we", "they", "my", "your",
        "one's", "oneself", "someone", "somebody", "something", "sth", "s.o",
        "etc", "e.g", "i.e", "'s",
    ]

    /// Verbs and nouns so general that a gloss built on them is really about the
    /// word beside them. Only ever used to *relax* what a gloss demands, never to
    /// discard what the learner said.
    private static let lightWords: Set<String> = [
        "make", "makes", "made", "do", "does", "done", "take", "takes", "taken",
        "get", "gets", "got", "have", "has", "had", "give", "gives", "given",
        "become", "becomes", "go", "goes", "come", "comes", "put", "puts",
        "in", "on", "at", "for", "with", "from", "by", "into", "onto", "out",
        "up", "down", "off", "over", "about", "thing", "things", "person", "way",
    ]

    /// Outright "I don't know". Every one of these negates, so none of them can
    /// be a word's meaning — they're safe to honour before judging the answer.
    private static let giveUpPhrases: Set<String> = [
        "dunno", "no idea", "i have no idea",
        "i don't know", "i dont know", "don't know", "dont know",
        "not sure", "i'm not sure", "im not sure",
    ]

    /// The same thing in Japanese, which is what a learner reaches for by
    /// reflex. Both the written forms and the romaji a recogniser listening in
    /// English is likely to produce.
    private static let japaneseGiveUpStems: [String] = [
        "わからない", "分からない", "わかりません", "分かりません",
        "わかんない", "わからん",
        "しらない", "知らない", "しりません", "知りません",
        "wakaranai", "wakarimasen", "wakannai", "wakaran",
        "shiranai", "shirimasen", "shiran",
    ]

    /// Move on from this word. Ordinary words, so these are only honoured once
    /// the answer has been ruled out — "skip" really is what サボる means.
    private static let moveOnPhrases: Set<String> = ["skip", "pass", "next"]

    /// End the session. Same caveat: 止[と]まる is "stop" and 辞[や]める is "quit",
    /// so these are checked only after the word itself.
    private static let endPhrases: Set<String> = [
        "stop", "quit", "i'm done", "im done", "stop the quiz",
    ]
}
