import Foundation

/// Kana word lists for the two word games, built once from the dictionary the app
/// already ships. Nothing new is bundled — the 4,000-entry dictionary is the
/// word bank.
enum KanaWordBank {

    struct Word: Hashable {
        let kana: String        // the chain / guess form
        let display: String     // how it's normally written (漢字 where it has one)
        let meaning: String     // the first sense, for one-line use
        /// Every sense, and the dictionary row this came from, so a game can
        /// hand the player straight through to the full entry.
        var meanings: [String] = []
        var entryId: Int = -1
    }

    // MARK: - Loading

    private static var cache: [Word]?

    /// Every entry whose reading is pure kana. Small kana and ー are kept here —
    /// they're perfectly good shiritori words, they just can't be Kotoba answers.
    static var all: [Word] {
        if let c = cache { return c }
        var out: [Word] = []
        var seen = Set<String>()
        for e in DictionaryService.shared.allEntries() {
            let kana = kanaForm(word: e.word, reading: e.reading)
            guard let k = kana, k.count >= 2, !seen.contains(k) else { continue }
            guard let m = e.definitions.first, !m.isEmpty else { continue }
            seen.insert(k)
            out.append(Word(kana: k, display: e.word, meaning: m,
                            meanings: e.definitions, entryId: e.id))
        }
        cache = out
        return out
    }

    private static func kanaForm(word: String, reading: String?) -> String? {
        if let r = reading, !r.isEmpty, isAllKana(r) { return r }
        return isAllKana(word) ? word : nil
    }

    private static func isAllKana(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy {
            ($0.value >= 0x3041 && $0.value <= 0x309F) || $0.value == 0x30FC
        }
    }

    // MARK: - Shiritori

    private static let smallToLarge: [Character: Character] = [
        "ゃ": "や", "ゅ": "ゆ", "ょ": "よ", "っ": "つ",
        "ぁ": "あ", "ぃ": "い", "ぅ": "う", "ぇ": "え", "ぉ": "お",
    ]

    /// The kana a word hands to the next player. A trailing ー is ignored and a
    /// small kana counts as its full-size form, which is how the game is played.
    static func tail(of kana: String) -> Character? {
        var s = Substring(kana)
        while s.last == "ー" { s = s.dropLast() }
        guard let c = s.last else { return nil }
        return smallToLarge[c] ?? c
    }

    static func head(of kana: String) -> Character? {
        guard let c = kana.first else { return nil }
        return smallToLarge[c] ?? c
    }

    /// Playable words: nothing ending in ん (that's a loss, not a move) and
    /// nothing with ん in the middle of the chain position.
    static var shiritoriPool: [Word] {
        all.filter { $0.kana.count >= 2 && !$0.kana.hasSuffix("ん") }
    }

    static func endsGame(_ kana: String) -> Bool { kana.hasSuffix("ん") }

    // MARK: - Kotoba (five kana)

    private static let smallOrLong = Set("ぁぃぅぇぉゃゅょっー")

    /// Answers are five *full* morae — no small kana, no long mark — so every
    /// cell of the grid is a character the player can reason about.
    static var kotobaAnswers: [Word] {
        all.filter { $0.kana.count == 5 && !$0.kana.contains(where: smallOrLong.contains) }
    }

    /// Guesses are laxer: any five-kana dictionary word is accepted, the same way
    /// Wordle takes a far wider guess list than its answer list.
    static var kotobaGuesses: Set<String> {
        Set(all.filter { $0.kana.count == 5 }.map(\.kana))
    }

    /// The keyboard is the plain gojūon plus a ゛/゜ modifier, the way Japanese
    /// input actually works — listing every voiced row separately made a
    /// fourteen-row keyboard that pushed Enter off the screen.
    static let kotobaKeyboard: [[Character]] = [
        Array("あいうえお"), Array("かきくけこ"), Array("さしすせそ"),
        Array("たちつてと"), Array("なにぬねの"), Array("はひふへほ"),
        Array("まみむめも"), Array("やゆよわを"), Array("らりるれろ"),
    ]

    private static let dakuten: [Character: Character] = [
        "か":"が","き":"ぎ","く":"ぐ","け":"げ","こ":"ご",
        "さ":"ざ","し":"じ","す":"ず","せ":"ぜ","そ":"ぞ",
        "た":"だ","ち":"ぢ","つ":"づ","て":"で","と":"ど",
        "は":"ば","ひ":"び","ふ":"ぶ","へ":"べ","ほ":"ぼ",
    ]
    private static let handakuten: [Character: Character] = [
        "は":"ぱ","ひ":"ぴ","ふ":"ぷ","へ":"ぺ","ほ":"ぽ",
    ]

    /// What a key types under the active modifier. Keys with no voiced form keep
    /// their plain kana rather than going dead.
    static func keyGlyph(_ base: Character, mark: Int) -> Character {
        switch mark {
        case 1:  return dakuten[base] ?? base
        case 2:  return handakuten[base] ?? base
        default: return base
        }
    }

    static func hasMark(_ base: Character, mark: Int) -> Bool {
        mark == 1 ? dakuten[base] != nil : (mark == 2 ? handakuten[base] != nil : true)
    }
}
