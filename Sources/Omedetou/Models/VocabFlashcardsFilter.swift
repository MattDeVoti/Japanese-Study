import Foundation
import SwiftUI

struct VocabFlashCard: Identifiable {
    var id: String { word.id }
    let word: LessonVocabWord
    let chapterId: String
    let chapterNumber: Int
    let chapterTitle: String
    let accentColor: Color
}

/// Which way round a card is asked.
enum CardDirection: String, Codable, CaseIterable {
    /// Shown the Japanese, recall the meaning. Recognition.
    case japaneseToEnglish
    /// Either way, decided per card. Prefers whichever direction you haven't
    /// checked off yet, so a half-known word is asked the half you're missing.
    ///
    /// Sits between the two one-way cases because that is where it belongs on
    /// the picker — the middle of the two things it mixes. The raw value stays
    /// `random` so settings saved before it was renamed still load.
    case random
    /// Shown the meaning, recall the Japanese. Production — much harder, and
    /// the direction that actually gets a word into your mouth.
    case englishToJapanese

    var isReversed: Bool { self == .englishToJapanese }

    var displayName: String {
        switch self {
        case .japaneseToEnglish: return "日本語 → English"
        case .random:            return "Both"
        case .englishToJapanese: return "English → 日本語"
        }
    }

    /// The two real directions a card can be asked in. `.random` resolves to one
    /// of these before anything is shown.
    static let asked: [CardDirection] = [.japaneseToEnglish, .englishToJapanese]
}

/// What the filter sheet needs from a deck filter. Two conformers: the written
/// flashcards' filter, and the vocal deck's — same sheet, independent selections.
protocol VocabFiltering: AnyObject {
    var selectedChapterIds: Set<String> { get set }
    var selectedWordIds: Set<String> { get set }
    var showFavoritesOnly: Bool { get set }
    /// Per-deck, deliberately: the written cards and the audio cards are
    /// different exercises and there is no reason one should follow the other.
    var direction: CardDirection { get set }
    var hasActiveFilter: Bool { get }
    func reset()
    func clearWeights()
    func clearExclusions(for wordIds: [String]?)
}

extension VocabFiltering {
    /// Protocols can't carry default arguments; both conformers' call sites use
    /// the bare form for "clear everything".
    func clearExclusions() { clearExclusions(for: nil) }
}

final class VocabFlashcardsFilter: ObservableObject, VocabFiltering {
    /// Shared source of truth so the Study section and a chapter's Study Vocab
    /// read the same favorites, weights, and checkmarks — a change on one side is
    /// live on the other.
    static let shared = VocabFlashcardsFilter()

    @Published var selectedChapterIds: Set<String> = [] { didSet { persistSelection() } }
    @Published var selectedWordIds: Set<String> = []
    @Published var showFavoritesOnly: Bool = false
    @Published var direction: CardDirection = .japaneseToEnglish {
        didSet { UserDefaults.standard.set(direction.rawValue, forKey: directionKey) }
    }
    @Published private(set) var favoriteWordIds: Set<String> = []

    /// Word ids checked off for Japanese → English.
    ///
    /// Keeps the original key: every checkmark earned before a card could be
    /// asked both ways was earned reading Japanese, so that is what it means.
    @Published private(set) var excludedWordIds: Set<String> = []
    /// Word ids checked off for English → Japanese — the harder direction, and a
    /// separate piece of knowledge. A word is only finished when both are set.
    @Published private(set) var excludedReverseWordIds: Set<String> = []

    /// Chapters auto-selected because their lesson was completed. Tracked so a
    /// chapter the user manually deselects is not re-added on the next sync.
    @Published private(set) var autoSelectedChapterIds: Set<String> = [] { didSet { persistSelection() } }

    // Per-word study counts. The weighting *setting* (mode + strength) lives in
    // the app-wide StudyWeightSettings; only the counts are per-word here.
    @Published private(set) var needsWorkCounts: [String: Int] = [:]
    @Published private(set) var confidentCounts: [String: Int] = [:]

    private let favoritesKey = "VocabFavoriteWordIds"
    private let weightsKey = "VocabWordWeights"
    private let selectionKey = "VocabSelectionData"
    private let excludedKey = "VocabExcludedWordIds"
    private let excludedReverseKey = "VocabExcludedReverseWordIds"
    private let directionKey = "VocabCardDirection"
    private var didLoad = false

    init() {
        if let raw = UserDefaults.standard.string(forKey: directionKey),
           let d = CardDirection(rawValue: raw) { direction = d }
        loadFavorites()
        loadWeights()
        loadSelection()
        loadExcluded()
        didLoad = true
    }

    var hasActiveFilter: Bool {
        !selectedChapterIds.isEmpty || !selectedWordIds.isEmpty || showFavoritesOnly
    }

    // MARK: - Favorites

    func toggleFavorite(_ wordId: String) {
        if favoriteWordIds.contains(wordId) { favoriteWordIds.remove(wordId) }
        else { favoriteWordIds.insert(wordId) }
        saveFavorites()
    }

    func isFavorite(_ wordId: String) -> Bool { favoriteWordIds.contains(wordId) }

    // MARK: - Flashcard exclusion (green checkmark)

    /// Checked off in a specific direction.
    func isExcluded(_ wordId: String, direction: CardDirection) -> Bool {
        direction.isReversed ? excludedReverseWordIds.contains(wordId)
                             : excludedWordIds.contains(wordId)
    }

    /// Both directions — what "done with this word" means, and the only thing
    /// that counts towards a chapter.
    func isFullyExcluded(_ wordId: String) -> Bool {
        excludedWordIds.contains(wordId) && excludedReverseWordIds.contains(wordId)
    }

    /// Either direction — used where a single mark still reads as "started".
    func isExcluded(_ wordId: String) -> Bool {
        excludedWordIds.contains(wordId) || excludedReverseWordIds.contains(wordId)
    }

    func toggleExcluded(_ wordId: String, direction: CardDirection) {
        if direction.isReversed {
            if excludedReverseWordIds.contains(wordId) { excludedReverseWordIds.remove(wordId) }
            else { excludedReverseWordIds.insert(wordId) }
        } else {
            if excludedWordIds.contains(wordId) { excludedWordIds.remove(wordId) }
            else { excludedWordIds.insert(wordId) }
        }
        saveExcluded()
    }

    /// Clears checkmarks. Pass a set of ids (e.g. one chapter's words) to clear
    /// only those, or nil to clear every vocab checkmark.
    func clearExclusions(for wordIds: [String]? = nil) {
        if let wordIds = wordIds {
            excludedWordIds.subtract(wordIds)
            excludedReverseWordIds.subtract(wordIds)
        } else {
            excludedWordIds.removeAll()
            excludedReverseWordIds.removeAll()
        }
        saveExcluded()
    }

    // MARK: - Lesson-completion sync

    /// Auto-selects the chapter filter for each newly-completed lesson (once each).
    /// One-way: completing a lesson selects its chapter here, but deselecting a
    /// chapter never un-completes the lesson, and a deselected chapter stays
    /// deselected (it is remembered in `autoSelectedChapterIds`).
    func syncCompletedChapters(_ completedWithVocab: Set<String>) {
        let newOnes = completedWithVocab.subtracting(autoSelectedChapterIds)
        guard !newOnes.isEmpty else { return }
        autoSelectedChapterIds.formUnion(newOnes)
        selectedChapterIds.formUnion(newOnes)
    }

    // MARK: - Study weights

    // Both tallies are recorded on every answer, whatever the priority mode is set
    // to — the mode only decides how the counts are *used* when picking a card.

    /// Records a "Needs Work", and clears that direction's checkmark if it had one.
    ///
    /// A checkmark means "done with this"; Needs Work means the opposite. In
    /// Prioritize Needs Work mode checked-off words stay in rotation, so it is
    /// entirely possible to be shown one and realise you don't know it after
    /// all — and leaving it checked would retire it again the moment priority
    /// was switched off.
    ///
    /// Only ever the direction that was actually tested. Failing to recall the
    /// Japanese from the English says nothing about whether you can still read
    /// it, so clearing both halves would throw away a demonstrated skill on the
    /// strength of a different one. `direction` is nil where no direction was
    /// involved — a review session — and then no checkmark is touched at all.
    ///
    /// Returns whether a checkmark was cleared, so the deck's back button can
    /// put it back.
    @discardableResult
    func markNeedsWork(_ wordId: String, direction: CardDirection? = nil) -> Bool {
        needsWorkCounts[wordId, default: 0] += 1
        saveWeights()
        guard let direction else { return false }
        if direction.isReversed {
            guard excludedReverseWordIds.contains(wordId) else { return false }
            excludedReverseWordIds.remove(wordId)
        } else {
            guard excludedWordIds.contains(wordId) else { return false }
            excludedWordIds.remove(wordId)
        }
        saveExcluded()
        return true
    }

    /// Clears checkmarks on several words at once — one save, not one per word.
    func unexclude(_ wordIds: [String], direction: CardDirection) {
        if direction.isReversed {
            guard !excludedReverseWordIds.intersection(wordIds).isEmpty else { return }
            excludedReverseWordIds.subtract(wordIds)
        } else {
            guard !excludedWordIds.intersection(wordIds).isEmpty else { return }
            excludedWordIds.subtract(wordIds)
        }
        saveExcluded()
    }
    /// Undo one "Needs Work" tally (used by the flashcard back button). Floors at 0.
    func unmarkNeedsWork(_ wordId: String) {
        guard let c = needsWorkCounts[wordId], c > 0 else { return }
        if c - 1 == 0 { needsWorkCounts.removeValue(forKey: wordId) }
        else { needsWorkCounts[wordId] = c - 1 }
        saveWeights()
    }

    func markConfident(_ wordId: String) { confidentCounts[wordId, default: 0] += 1; saveWeights() }
    /// Undo one "Confident" tally (used by the flashcard back button). Floors at 0.
    func unmarkConfident(_ wordId: String) {
        guard let c = confidentCounts[wordId], c > 0 else { return }
        if c - 1 == 0 { confidentCounts.removeValue(forKey: wordId) }
        else { confidentCounts[wordId] = c - 1 }
        saveWeights()
    }
    func clearWeights() { needsWorkCounts = [:]; confidentCounts = [:]; saveWeights() }

    /// Adds a whole session's tallies in one go.
    ///
    /// Batched deliberately: the vocal summary can carry forty words, and going
    /// through `markConfident`/`markNeedsWork` one answer at a time would write
    /// the whole weights blob to disk once per answer.
    func addWeights(_ tallies: [(wordId: String, confident: Int, needsWork: Int)]) {
        var changed = false
        for t in tallies {
            if t.confident > 0 { confidentCounts[t.wordId, default: 0] += t.confident; changed = true }
            if t.needsWork > 0 { needsWorkCounts[t.wordId, default: 0] += t.needsWork; changed = true }
        }
        if changed { saveWeights() }
    }

    /// Checks off several words at once — one save rather than one per word.
    func exclude(_ wordIds: [String], direction: CardDirection) {
        if direction.isReversed { excludedReverseWordIds.formUnion(wordIds) }
        else { excludedWordIds.formUnion(wordIds) }
        saveExcluded()
    }

    /// Picks a card, biasing toward "Needs Work" words when the app-wide
    /// StudyWeightSettings has prioritization on. Shared logic with the other decks.
    func selectWeighted(from cards: [VocabFlashCard]) -> VocabFlashCard? {
        StudyWeightSettings.shared.pick(cards) { needsWorkCounts[$0.word.id] ?? 0 }
    }

    /// The deck's own draw: same weighting, but it won't repeat the card just
    /// shown and, with priority off, works through the pool before repeating.
    func selectNext(from cards: [VocabFlashCard],
                    using sequencer: DeckSequencer) -> VocabFlashCard? {
        sequencer.next(from: cards,
                       key: { $0.word.id },
                       needsWork: { [weak self] in self?.needsWorkCounts[$0.word.id] ?? 0 })
    }

    // MARK: - Apply

    /// Everything the current filters pick out, before checkmarks retire any of
    /// it. This is the denominator of the deck's "checked off" count — the size
    /// of the set you're working through, which doesn't shrink as you go.
    func selection(in cards: [VocabFlashCard]) -> [VocabFlashCard] {
        var result = cards
        if !selectedChapterIds.isEmpty {
            result = result.filter { selectedChapterIds.contains($0.chapterId) }
        }
        if !selectedWordIds.isEmpty {
            result = result.filter { selectedWordIds.contains($0.word.id) }
        }
        if showFavoritesOnly {
            let favs = result.filter { favoriteWordIds.contains($0.word.id) }
            if !favs.isEmpty { result = favs }
        }
        return result
    }

    func apply(to cards: [VocabFlashCard]) -> [VocabFlashCard] {
        let result = selection(in: cards)
        guard StudyWeightSettings.shared.filtersOutCheckedCards else { return result }
        // Random keeps a card until *both* halves are done; a fixed direction
        // only cares about its own.
        return result.filter {
            direction == .random ? !isFullyExcluded($0.word.id)
                                 : !isExcluded($0.word.id, direction: direction)
        }
    }

    /// Which way to ask this particular card.
    func resolvedDirection(for wordId: String) -> CardDirection {
        guard direction == .random else { return direction }
        let forward = excludedWordIds.contains(wordId)
        let back = excludedReverseWordIds.contains(wordId)
        if forward != back { return forward ? .englishToJapanese : .japaneseToEnglish }
        return Bool.random() ? .japaneseToEnglish : .englishToJapanese
    }

    func reset() {
        selectedChapterIds = []
        autoSelectedChapterIds = []
        selectedWordIds = []
        showFavoritesOnly = false
    }

    // MARK: - Persistence

    private func loadFavorites() {
        if let ids = UserDefaults.standard.decode(Set<String>.self, forKey: favoritesKey) {
            favoriteWordIds = ids
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.encode(favoriteWordIds, forKey: favoritesKey)
    }

    private func loadExcluded() {
        if let ids = UserDefaults.standard.decode(Set<String>.self, forKey: excludedKey) {
            excludedWordIds = ids
        }
        if let ids = UserDefaults.standard.decode(Set<String>.self, forKey: excludedReverseKey) {
            excludedReverseWordIds = ids
        }
    }

    private func saveExcluded() {
        UserDefaults.standard.encode(excludedWordIds, forKey: excludedKey)
        UserDefaults.standard.encode(excludedReverseWordIds, forKey: excludedReverseKey)
    }

    private struct WeightData: Codable {
        var needsWork: [String: Int]
        var confident: [String: Int]
    }

    private func loadWeights() {
        guard let d = UserDefaults.standard.decode(WeightData.self, forKey: weightsKey) else { return }
        needsWorkCounts = d.needsWork
        confidentCounts = d.confident
    }

    private func saveWeights() {
        UserDefaults.standard.encode(WeightData(needsWork: needsWorkCounts, confident: confidentCounts), forKey: weightsKey)
    }

    private struct SelectionData: Codable {
        var selected: Set<String>
        var autoSelected: Set<String>
    }

    private func loadSelection() {
        guard let d = UserDefaults.standard.decode(SelectionData.self, forKey: selectionKey) else { return }
        selectedChapterIds = d.selected
        autoSelectedChapterIds = d.autoSelected
    }

    private func persistSelection() {
        guard didLoad else { return }   // don't persist during init's loadSelection()
        UserDefaults.standard.encode(SelectionData(selected: selectedChapterIds, autoSelected: autoSelectedChapterIds), forKey: selectionKey)
    }
}

// MARK: - The vocal deck's filter

/// Filter selections for the vocal flashcards, independent of the written deck's.
///
/// Only the *selections* fork — which chapters, which words, favorites-only.
/// Everything that is data rather than a choice of view (which words are
/// favorites, which are checked off, the needs-work tallies) forwards to the
/// shared store: a word marked Confident from a vocal summary must be the same
/// Confident the written deck sees, or the two modes would drift into separate
/// records of the same learner.
final class VocalDeckFilter: ObservableObject, VocabFiltering {
    static let shared = VocalDeckFilter()

    /// The shared data behind both decks.
    private var store: VocabFlashcardsFilter { .shared }

    @Published var selectedChapterIds: Set<String> = [] { didSet { persist() } }
    @Published var selectedWordIds: Set<String> = []
    @Published var showFavoritesOnly = false
    @Published var direction: CardDirection = .japaneseToEnglish {
        didSet { UserDefaults.standard.set(direction.rawValue, forKey: directionKey) }
    }

    private let selectionKey = "VocalDeckSelectedChapters"
    private let directionKey = "VocalDeckDirection"
    private var didLoad = false

    private init() {
        if let ids = UserDefaults.standard.decode(Set<String>.self, forKey: selectionKey) {
            selectedChapterIds = ids
        }
        if let raw = UserDefaults.standard.string(forKey: directionKey),
           let d = CardDirection(rawValue: raw) { direction = d }
        didLoad = true
    }

    var hasActiveFilter: Bool {
        !selectedChapterIds.isEmpty || !selectedWordIds.isEmpty || showFavoritesOnly
    }

    /// The one-tap match-up: adopt whatever the written flashcards are filtered to.
    func copyFromFlashcards() {
        selectedChapterIds = store.selectedChapterIds
        selectedWordIds = store.selectedWordIds
        showFavoritesOnly = store.showFavoritesOnly
    }

    func reset() {
        selectedChapterIds = []
        selectedWordIds = []
        showFavoritesOnly = false
    }

    // MARK: Forwarded data operations (shared with the written deck)

    func isFavorite(_ wordId: String) -> Bool { store.isFavorite(wordId) }
    func toggleFavorite(_ wordId: String) { store.toggleFavorite(wordId) }
    func isExcluded(_ wordId: String, direction: CardDirection) -> Bool {
        store.isExcluded(wordId, direction: direction)
    }
    func isFullyExcluded(_ wordId: String) -> Bool { store.isFullyExcluded(wordId) }
    func toggleExcluded(_ wordId: String, direction: CardDirection) {
        store.toggleExcluded(wordId, direction: direction)
    }
    func clearExclusions(for wordIds: [String]? = nil) { store.clearExclusions(for: wordIds) }
    @discardableResult
    func markNeedsWork(_ wordId: String, direction: CardDirection? = nil) -> Bool {
        store.markNeedsWork(wordId, direction: direction)
    }
    func unexclude(_ wordIds: [String], direction: CardDirection) {
        store.unexclude(wordIds, direction: direction)
    }
    func markConfident(_ wordId: String) { store.markConfident(wordId) }
    func clearWeights() { store.clearWeights() }
    func addWeights(_ tallies: [(wordId: String, confident: Int, needsWork: Int)]) {
        store.addWeights(tallies)
    }
    func exclude(_ wordIds: [String], direction: CardDirection) {
        store.exclude(wordIds, direction: direction)
    }

    // MARK: Pool

    /// Same shape as the written deck's `apply`, but reading this filter's
    /// selections against the shared favorites/checkmark data.
    func apply(to cards: [VocabFlashCard]) -> [VocabFlashCard] {
        var result = cards
        if !selectedChapterIds.isEmpty {
            result = result.filter { selectedChapterIds.contains($0.chapterId) }
        }
        if !selectedWordIds.isEmpty {
            result = result.filter { selectedWordIds.contains($0.word.id) }
        }
        if showFavoritesOnly {
            let favs = result.filter { store.isFavorite($0.word.id) }
            if !favs.isEmpty { result = favs }
        }
        guard StudyWeightSettings.shared.filtersOutCheckedCards else { return result }
        return result.filter {
            direction == .random ? !store.isFullyExcluded($0.word.id)
                                 : !store.isExcluded($0.word.id, direction: direction)
        }
    }

    /// Which way to ask this particular card. See the written deck's copy.
    func resolvedDirection(for wordId: String) -> CardDirection {
        guard direction == .random else { return direction }
        let forward = store.isExcluded(wordId, direction: .japaneseToEnglish)
        let back = store.isExcluded(wordId, direction: .englishToJapanese)
        if forward != back { return forward ? .englishToJapanese : .japaneseToEnglish }
        return Bool.random() ? .japaneseToEnglish : .englishToJapanese
    }

    func selectNext(from cards: [VocabFlashCard],
                    using sequencer: DeckSequencer) -> VocabFlashCard? {
        sequencer.next(from: cards,
                       key: { $0.word.id },
                       needsWork: { [weak self] in self?.store.needsWorkCounts[$0.word.id] ?? 0 })
    }

    private func persist() {
        guard didLoad else { return }
        UserDefaults.standard.encode(selectedChapterIds, forKey: selectionKey)
    }
}
