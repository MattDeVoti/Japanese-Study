import Foundation

protocol FlashCardProtocol: Identifiable {
    var id: String { get }
    var nLevel: Int { get }
    var imagePath: String { get }
    var isFavorite: Bool { get set }
    var needsWorkCount: Int { get set }
    var confidentCount: Int { get set }
}

struct KanjiReading: Codable, Hashable {
    let kana: String
    let romaji: String
}

struct KanjiCommonWord: Codable, Hashable {
    let kanji: String
    let kana: String
    let romaji: String
    let meaning: String
    /// Marked in kanji_data.json for the words a learner should actually know —
    /// every word that appears as chapter vocab, plus curated everyday words.
    /// The rest are bonus content: shown unbolded on the card, and never
    /// promoted into lesson decks. Absent in JSON means false.
    var essential: Bool = false

    private enum CodingKeys: String, CodingKey {
        case kanji, kana, romaji, meaning, essential
    }

    init(kanji: String, kana: String, romaji: String, meaning: String,
         essential: Bool = false) {
        self.kanji = kanji
        self.kana = kana
        self.romaji = romaji
        self.meaning = meaning
        self.essential = essential
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kanji = try c.decode(String.self, forKey: .kanji)
        kana = try c.decode(String.self, forKey: .kana)
        romaji = try c.decode(String.self, forKey: .romaji)
        meaning = try c.decode(String.self, forKey: .meaning)
        essential = try c.decodeIfPresent(Bool.self, forKey: .essential) ?? false
    }
}

/// One visual piece of a kanji, as decomposed by KRADFILE: the glyph to show
/// and a short learner-facing name ("water (left)", "roof", "heart").
struct KanjiComponent: Codable, Hashable {
    let glyph: String
    let name: String
}

struct KanjiCard: FlashCardProtocol, Hashable {
    let kanjiId: String
    let kanji: String
    let nLevel: Int
    let definition: String
    let onyomi: [KanjiReading]
    let kunyomi: [KanjiReading]
    let commonWords: [KanjiCommonWord]
    let components: [KanjiComponent]
    let mnemonic: String
    var isFavorite: Bool
    var needsWorkCount: Int
    var confidentCount: Int

    /// The character, not `kanjiId`.
    ///
    /// Every bit of saved kanji progress — review scheduling, checkmarks,
    /// favourites, needs-work counts — is keyed on this. `kanjiId` is a random
    /// 10-character string from the source data, so regenerating that data from
    /// a newer upstream would issue new ids and orphan all of it. 会 is 会 in
    /// every version of every dataset, so the character is the stable key.
    var id: String { kanji }
    var imagePath: String { "" }
}

struct GrammarCard: FlashCardProtocol, Hashable {
    let id: String
    let romaji: String
    let japanese: String
    let nLevel: Int
    let imagePath: String
    var isFavorite: Bool
    var needsWorkCount: Int
    var confidentCount: Int
}

struct VocabFile: Identifiable {
    var id: String { path }
    let level: Int
    let displayName: String
    let path: String
}

struct ParticleCard: Identifiable {
    let id: String       // particleId from JSON
    let particle: String
    let romaji: String
    let meaning: String       // short description shown at the top
    let explanation: String   // comprehensive usage explanation (may be empty)
    let nLevel: Int
}

struct DictionaryEntry: Identifiable {
    let id: Int
    let word: String
    let reading: String?
    let definitions: [String]
    let partsOfSpeech: [String]
    let sortKeyEn: String
    let sortKeyJp: String
}

/// One example sentence attached to a dictionary entry.
///
/// `fromLesson` marks the ones taken from the app's own chapters. Those carry
/// furigana in the 漢字[かんじ] form and can be rendered with FuriganaText;
/// corpus sentences are plain text and have to be drawn as-is, which is why the
/// two are told apart rather than merged.
struct DictionaryExample: Identifiable {
    let id = UUID()
    let japanese: String
    let english: String
    let fromLesson: Bool
}
