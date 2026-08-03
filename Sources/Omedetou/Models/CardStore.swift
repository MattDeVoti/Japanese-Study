import Foundation
import Combine

class CardStore: ObservableObject {
    @Published var kanjiCards: [KanjiCard] = []
    @Published var grammarCards: [GrammarCard] = []
    @Published var vocabFiles: [VocabFile] = []
    @Published var particleCards: [ParticleCard] = []

    // O(1) lookups into the card arrays. Built once at load; the arrays are only
    // ever mutated in place (never reordered or resized), so positions stay valid.
    private var kanjiIndexById: [String: Int] = [:]
    private var kanjiIndexByChar: [String: Int] = [:]
    private var grammarIndexById: [String: Int] = [:]
    /// Word id → every kanji card id that word appears under (usually one).
    private var wordParents: [String: [String]] = [:]


    // MARK: - Persistence

    private struct PersistentData: Codable {
        var favorites: Set<String> = []
        var needsWorkCounts: [String: Int] = [:]
        var confidentCounts: [String: Int] = [:]
        var excludedKanji: Set<String> = []
    }

    private let defaultsKey = "OmedetouCardStoreData"
    /// Key this data lived under before the product was renamed.
    private let legacyDefaultsKey = "JLPTCardStoreData"
    private var data = PersistentData()

    /// Kanji card ids the user has "checked off" — excluded from the flashcard
    /// lineup (both the Study section and any chapter's Study Kanji). Shared here
    /// so a checkmark toggled anywhere is reflected everywhere.
    @Published private(set) var excludedKanjiIds: Set<String> = []

    init() {
        loadPersistedData()
        migrateKanjiIdsToCharacters()
        excludedKanjiIds = data.excludedKanji
        loadAllCards()
    }

    /// Moves progress saved under the old random `kanjiId` onto the character.
    ///
    /// Only the ids present in the shipped data are remapped — grammar cards
    /// share these same collections and their ids (`g_n5_…`) are left alone.
    private func migrateKanjiIdsToCharacters() {
        let flag = "KanjiIdsAreCharactersV1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        defer { UserDefaults.standard.set(true, forKey: flag) }

        struct Row: Decodable { let kanji: String; let kanjiId: String }
        guard let url = Bundle.main.url(forResource: "kanji_data", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Row].self, from: raw) else { return }
        let map = Dictionary(rows.map { ($0.kanjiId, $0.kanji) }, uniquingKeysWith: { a, _ in a })
        guard !map.isEmpty else { return }

        var moved = 0
        for (old, new) in map {
            if data.favorites.remove(old) != nil { data.favorites.insert(new); moved += 1 }
            if let n = data.needsWorkCounts.removeValue(forKey: old) {
                data.needsWorkCounts[new] = n; moved += 1
            }
            if let n = data.confidentCounts.removeValue(forKey: old) {
                data.confidentCounts[new] = n; moved += 1
            }
            if data.excludedKanji.remove(old) != nil { data.excludedKanji.insert(new); moved += 1 }
        }
        SRSStore.shared.migrateKanjiKeys(map)
        if moved > 0 { persist() }
    }

    // MARK: - Card Loading

    func loadAllCards() {
        kanjiCards = loadKanjiCards()
        grammarCards = loadGrammarCards()
        vocabFiles = loadVocabFiles()
        particleCards = loadParticleCards()
        rebuildIndices()
    }

    private func rebuildIndices() {
        kanjiIndexById = Dictionary(kanjiCards.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        kanjiIndexByChar = Dictionary(kanjiCards.enumerated().map { ($1.kanji, $0) }, uniquingKeysWith: { first, _ in first })
        grammarIndexById = Dictionary(grammarCards.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })

        var parents: [String: [String]] = [:]
        for card in kanjiCards {
            for word in card.commonWords {
                parents[KanjiWordCard.id(for: word), default: []].append(card.id)
            }
        }
        wordParents = parents
    }

    /// Mutate a kanji and/or grammar card by id in place (an id is one or the
    /// other). Centralizes the index lookup the study operations all share.
    private func mutateCard(_ cardId: String,
                            kanji: ((inout KanjiCard) -> Void),
                            grammar: ((inout GrammarCard) -> Void)) {
        if let i = kanjiIndexById[cardId] { kanji(&kanjiCards[i]) }
        if let i = grammarIndexById[cardId] { grammar(&grammarCards[i]) }
    }

    private func loadParticleCards() -> [ParticleCard] {
        guard let url = Bundle.main.url(forResource: "particles_data", withExtension: "json") else {
            return []
        }

        guard let raw = try? Data(contentsOf: url) else { return [] }

        struct ParticleJSON: Codable {
            let particleId: String
            let particle: String
            let romaji: String
            let meaning: String
            let explanation: String?
            let level: String
        }

        guard let entries = try? JSONDecoder().decode([ParticleJSON].self, from: raw) else { return [] }

        return entries.compactMap { json in
            guard let lvl = Int(json.level.dropFirst()) else { return nil }
            return ParticleCard(id: json.particleId, particle: json.particle,
                                romaji: json.romaji, meaning: json.meaning,
                                explanation: json.explanation ?? "", nLevel: lvl)
        }
    }

    private func loadKanjiCards() -> [KanjiCard] {
        guard let url = Bundle.main.url(forResource: "kanji_data", withExtension: "json") else {
            return []
        }

        guard let raw = try? Data(contentsOf: url) else { return [] }

        struct KanjiJSON: Codable {
            let kanji: String
            let kanjiId: String
            let level: String
            let definition: String?
            let onyomi: [KanjiReading]?
            let kunyomi: [KanjiReading]?
            let commonWords: [KanjiCommonWord]?
        }

        guard let entries = try? JSONDecoder().decode([KanjiJSON].self, from: raw) else { return [] }

        return entries.enumerated().compactMap { idx, json -> (Int, KanjiCard)? in
            guard let lvl = Int(json.level.dropFirst()) else { return nil }
            let card = KanjiCard(
                kanjiId: json.kanjiId,
                kanji: json.kanji,
                nLevel: lvl,
                definition: json.definition ?? "",
                onyomi: json.onyomi ?? [],
                kunyomi: json.kunyomi ?? [],
                commonWords: json.commonWords ?? [],
                isFavorite: data.favorites.contains(json.kanji),
                needsWorkCount: data.needsWorkCounts[json.kanji] ?? 0,
                confidentCount: data.confidentCounts[json.kanji] ?? 0
            )
            return (idx, card)
        }
        .sorted { a, b in a.1.nLevel != b.1.nLevel ? a.1.nLevel > b.1.nLevel : a.0 < b.0 }
        .map { $0.1 }
    }

    /// Vestigial. This deck was driven by printable flashcard images that were
    /// never bundled, and no screen displays it — the app's grammar teaching
    /// comes from the lesson files instead.
    private func loadGrammarCards() -> [GrammarCard] { [] }

    /// Vestigial, for the same reason as `loadGrammarCards`.
    private func loadVocabFiles() -> [VocabFile] { [] }

    // MARK: - Filename Parsing

    private func parseGrammarFilename(_ filename: String) -> (String, String) {
        var name = filename.replacingOccurrences(of: ".png", with: "")
        if let r = name.range(of: " jlpt ", options: .caseInsensitive) {
            name = String(name[..<r.lowerBound])
        }
        // Split at the first non-ASCII character (start of Japanese text)
        if let r = name.range(of: "[^\u{0000}-\u{007F}]", options: .regularExpression) {
            let romaji = String(name[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            let japanese = String(name[r.lowerBound...]).trimmingCharacters(in: .whitespaces)
            return (romaji, japanese)
        }
        return (name.trimmingCharacters(in: .whitespaces), "")
    }


    // MARK: - Card Operations

    func toggleFavorite(cardId: String) {
        if data.favorites.contains(cardId) {
            data.favorites.remove(cardId)
        } else {
            data.favorites.insert(cardId)
        }
        let fav = data.favorites.contains(cardId)
        mutateCard(cardId, kanji: { $0.isFavorite = fav }, grammar: { $0.isFavorite = fav })
        persist()
    }

    func incrementNeedsWork(cardId: String) {
        data.needsWorkCounts[cardId, default: 0] += 1
        let n = data.needsWorkCounts[cardId]!
        mutateCard(cardId, kanji: { $0.needsWorkCount = n }, grammar: { $0.needsWorkCount = n })
        persist()
    }

    /// Undo one "Needs Work" tally (used by the flashcard back button). Floors at 0.
    func decrementNeedsWork(cardId: String) {
        guard let c = data.needsWorkCounts[cardId], c > 0 else { return }
        let n = c - 1
        if n == 0 { data.needsWorkCounts.removeValue(forKey: cardId) }
        else { data.needsWorkCounts[cardId] = n }
        mutateCard(cardId, kanji: { $0.needsWorkCount = n }, grammar: { $0.needsWorkCount = n })
        persist()
    }

    func incrementConfident(cardId: String) {
        data.confidentCounts[cardId, default: 0] += 1
        let n = data.confidentCounts[cardId]!
        mutateCard(cardId, kanji: { $0.confidentCount = n }, grammar: { $0.confidentCount = n })
        persist()
    }

    /// Undo one "Confident" tally (used by the flashcard back button). Floors at 0.
    func decrementConfident(cardId: String) {
        guard let c = data.confidentCounts[cardId], c > 0 else { return }
        let n = c - 1
        if n == 0 { data.confidentCounts.removeValue(forKey: cardId) }
        else { data.confidentCounts[cardId] = n }
        mutateCard(cardId, kanji: { $0.confidentCount = n }, grammar: { $0.confidentCount = n })
        persist()
    }

    // MARK: - Flashcard exclusion (green checkmark)

    func isKanjiExcluded(_ cardId: String) -> Bool { excludedKanjiIds.contains(cardId) }

    func toggleKanjiExcluded(cardId: String) {
        if excludedKanjiIds.contains(cardId) { excludedKanjiIds.remove(cardId) }
        else { excludedKanjiIds.insert(cardId) }
        data.excludedKanji = excludedKanjiIds
        persist()
    }

    /// Clears checkmarks. Pass a set of ids (e.g. one chapter's kanji) to clear
    /// only those, or nil to clear every kanji checkmark.
    func clearKanjiExclusions(ids: [String]? = nil) {
        if let ids = ids { excludedKanjiIds.subtract(ids) }
        else { excludedKanjiIds.removeAll() }
        data.excludedKanji = excludedKanjiIds
        persist()
    }

    enum CardSection { case kanji, grammar }

    func clearWeights(for section: CardSection) {
        let ids: [String]
        switch section {
        case .kanji: ids = kanjiCards.map(\.id)
        case .grammar: ids = grammarCards.map(\.id)
        }
        for id in ids {
            data.needsWorkCounts.removeValue(forKey: id)
            data.confidentCounts.removeValue(forKey: id)
        }
        switch section {
        case .kanji:
            kanjiCards = kanjiCards.map { var c = $0; c.needsWorkCount = 0; c.confidentCount = 0; return c }
        case .grammar:
            grammarCards = grammarCards.map { var c = $0; c.needsWorkCount = 0; c.confidentCount = 0; return c }
        }
        persist()
    }

    // MARK: - Filtered Lists

    /// Applies the study filter (levels, chosen kanji, favorites). `applyChecks`
    /// additionally drops checked-off cards — the study pool skips that step so
    /// it can decide per item, letting a kanji's words survive the kanji itself
    /// being checked off.
    func filteredKanjiCards(filter: StudyFilter, applyChecks: Bool = true) -> [KanjiCard] {
        var cards = kanjiCards
        if !filter.selectedLevels.isEmpty {
            cards = cards.filter { filter.selectedLevels.contains($0.nLevel) }
        }
        if let kf = filter as? KanjiFilter, !kf.selectedKanjiIds.isEmpty {
            cards = cards.filter { kf.selectedKanjiIds.contains($0.id) }
        }
        if filter.showFavoritesOnly {
            let favs = cards.filter(\.isFavorite)
            if !favs.isEmpty { cards = favs }
        }
        if applyChecks, StudyWeightSettings.shared.filtersOutCheckedCards {
            cards = cards.filter { !excludedKanjiIds.contains($0.id) }
        }
        return pinNumberKanji(cards)
    }

    /// Every kanji, number kanji pinned to the front — no study filter applied.
    /// Used by the Kanji lookup screen, which is driven only by its own search bar.
    func allKanjiCards() -> [KanjiCard] {
        pinNumberKanji(kanjiCards)
    }

    // Look up a kanji card by its character (used by lesson chapters). O(1).
    func kanjiCard(for char: String) -> KanjiCard? {
        kanjiIndexByChar[char].map { kanjiCards[$0] }
    }

    func kanjiCard(id: String) -> KanjiCard? {
        kanjiIndexById[id].map { kanjiCards[$0] }
    }

    /// Study weight for any id — kanji cards and synthetic word ids alike.
    func needsWorkCount(forId id: String) -> Int {
        data.needsWorkCounts[id] ?? 0
    }

    // MARK: - Kanji study pool (kanji + their example words)

    /// The example words belonging to `cards`, de-duplicated. Each word carries
    /// every kanji card it appears under, so the flashcard can show them as tabs.
    func wordCards(from cards: [KanjiCard]) -> [KanjiWordCard] {
        var seen = Set<String>()
        var out: [KanjiWordCard] = []
        for card in cards {
            for word in card.commonWords {
                let id = KanjiWordCard.id(for: word)
                guard !seen.contains(id) else { continue }
                seen.insert(id)
                let parents = wordParents[id] ?? [card.id]
                // Easiest parent (N5 = 5) — where a learner meets the word first.
                let level = parents.compactMap { kanjiCard(id: $0)?.nLevel }.max() ?? card.nLevel
                out.append(KanjiWordCard(word: word, parentIds: parents, nLevel: level))
            }
        }
        return out
    }

    /// Builds the full study pool from a set of base kanji: the kanji themselves,
    /// plus their example words when that option is on. Checked-off cards drop
    /// out only in No-Priority mode, matching the rest of the app.
    func kanjiStudyPool(from cards: [KanjiCard]) -> [KanjiStudyItem] {
        var items = cards.map { KanjiStudyItem.kanji($0) }
        if KanjiStudySettings.shared.includeCommonWords {
            items += wordCards(from: cards).map { KanjiStudyItem.word($0) }
        }
        guard StudyWeightSettings.shared.filtersOutCheckedCards else { return items }
        return items.filter { !excludedKanjiIds.contains($0.id) }
    }

    func selectWeightedKanjiItem(from items: [KanjiStudyItem]) -> KanjiStudyItem? {
        StudyWeightSettings.shared.pick(items) { needsWorkCount(forId: $0.id) }
    }

    /// The deck's own draw: same weighting, but it won't repeat the card just
    /// shown and, with priority off, works through the pool before repeating.
    func selectNextKanjiItem(from items: [KanjiStudyItem],
                             using sequencer: DeckSequencer) -> KanjiStudyItem? {
        sequencer.next(from: items,
                       key: { $0.id },
                       needsWork: { [weak self] in self?.needsWorkCount(forId: $0.id) ?? 0 })
    }

    // Pin number kanji to the front in ascending order
    private func pinNumberKanji(_ cards: [KanjiCard]) -> [KanjiCard] {
        let pinnedOrder = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "百", "千", "万"]
        let pinnedSet = Set(pinnedOrder)
        let pinned = pinnedOrder.compactMap { k in cards.first(where: { $0.kanji == k }) }
        let rest = cards.filter { !pinnedSet.contains($0.kanji) }
        return pinned + rest
    }

    func filteredGrammarCards(filter: StudyFilter) -> [GrammarCard] {
        var cards = grammarCards
        if !filter.selectedLevels.isEmpty {
            cards = cards.filter { filter.selectedLevels.contains($0.nLevel) }
        }
        if filter.showFavoritesOnly {
            let favs = cards.filter(\.isFavorite)
            if !favs.isEmpty { cards = favs }
        }
        return cards
    }

    func selectWeightedGrammar(from cards: [GrammarCard]) -> GrammarCard? {
        selectWeighted(cards)
    }

    /// Weighting comes from the app-wide `StudyWeightSettings`, shared by every
    /// deck and every place the setting can be changed.
    private func selectWeighted<T: FlashCardProtocol>(_ cards: [T]) -> T? {
        StudyWeightSettings.shared.pick(cards) { $0.needsWorkCount }
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        if let decoded = UserDefaults.standard.decode(PersistentData.self, forKey: defaultsKey) {
            data = decoded
            return
        }
        // Nothing under the current key — fall back to the pre-rename one and
        // write it forward, so favourites and checkmarks survive the rename.
        if let legacy = UserDefaults.standard.decode(PersistentData.self, forKey: legacyDefaultsKey) {
            data = legacy
            persist()
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        }
    }

    private func persist() {
        UserDefaults.standard.encode(data, forKey: defaultsKey)
    }
}
