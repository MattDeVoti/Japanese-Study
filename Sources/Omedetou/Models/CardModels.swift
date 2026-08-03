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
}

struct KanjiCard: FlashCardProtocol, Hashable {
    let kanjiId: String
    let kanji: String
    let nLevel: Int
    let definition: String
    let onyomi: [KanjiReading]
    let kunyomi: [KanjiReading]
    let commonWords: [KanjiCommonWord]
    var isFavorite: Bool
    var needsWorkCount: Int
    var confidentCount: Int

    var id: String { kanjiId }
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
