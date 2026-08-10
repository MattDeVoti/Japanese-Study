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

/// What the filter sheet needs from a deck filter. Two conformers: the written
/// flashcards' filter, and the vocal deck's — same sheet, independent selections.
protocol VocabFiltering: AnyObject {
    var selectedChapterIds: Set<String> { get set }
    var selectedWordIds: Set<String> { get set }
    var showFavoritesOnly: Bool { get set }
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
    @Published private(set) var favoriteWordIds: Set<String> = []

    /// Word ids the user has "checked off" — excluded from the flashcard lineup
    /// (Study section and any chapter's Study Vocab).
    @Published private(set) var excludedWordIds: Set<String> = []

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
    private var didLoad = false

    init() {
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

    func isExcluded(_ wordId: String) -> Bool { excludedWordIds.contains(wordId) }

    func toggleExcluded(_ wordId: String) {
        if excludedWordIds.contains(wordId) { excludedWordIds.remove(wordId) }
        else { excludedWordIds.insert(wordId) }
        saveExcluded()
    }

    /// Clears checkmarks. Pass a set of ids (e.g. one chapter's words) to clear
    /// only those, or nil to clear every vocab checkmark.
    func clearExclusions(for wordIds: [String]? = nil) {
        if let wordIds = wordIds { excludedWordIds.subtract(wordIds) }
        else { excludedWordIds.removeAll() }
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

    /// Records a "Needs Work", and clears the word's checkmark if it had one.
    ///
    /// A checkmark means "done with this"; Needs Work means the opposite. In
    /// Prioritize Needs Work mode checked-off words stay in rotation, so it is
    /// entirely possible to be shown one and realise you don't know it after
    /// all — and leaving it checked would retire it again the moment priority
    /// was switched off. Returns whether a checkmark was cleared, so the deck's
    /// back button can put it back.
    @discardableResult
    func markNeedsWork(_ wordId: String) -> Bool {
        needsWorkCounts[wordId, default: 0] += 1
        saveWeights()
        guard excludedWordIds.contains(wordId) else { return false }
        excludedWordIds.remove(wordId)
        saveExcluded()
        return true
    }

    /// Clears checkmarks on several words at once — one save, not one per word.
    func unexclude(_ wordIds: [String]) {
        let removals = excludedWordIds.intersection(wordIds)
        guard !removals.isEmpty else { return }
        excludedWordIds.subtract(removals)
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
    func exclude(_ wordIds: [String]) {
        let additions = Set(wordIds).subtracting(excludedWordIds)
        guard !additions.isEmpty else { return }
        excludedWordIds.formUnion(additions)
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
        return result.filter { !excludedWordIds.contains($0.word.id) }
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
    }

    private func saveExcluded() {
        UserDefaults.standard.encode(excludedWordIds, forKey: excludedKey)
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

    private let selectionKey = "VocalDeckSelectedChapters"
    private var didLoad = false

    private init() {
        if let ids = UserDefaults.standard.decode(Set<String>.self, forKey: selectionKey) {
            selectedChapterIds = ids
        }
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
    func isExcluded(_ wordId: String) -> Bool { store.isExcluded(wordId) }
    func toggleExcluded(_ wordId: String) { store.toggleExcluded(wordId) }
    func clearExclusions(for wordIds: [String]? = nil) { store.clearExclusions(for: wordIds) }
    @discardableResult
    func markNeedsWork(_ wordId: String) -> Bool { store.markNeedsWork(wordId) }
    func unexclude(_ wordIds: [String]) { store.unexclude(wordIds) }
    func markConfident(_ wordId: String) { store.markConfident(wordId) }
    func clearWeights() { store.clearWeights() }
    func addWeights(_ tallies: [(wordId: String, confident: Int, needsWork: Int)]) {
        store.addWeights(tallies)
    }
    func exclude(_ wordIds: [String]) { store.exclude(wordIds) }

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
        return result.filter { !store.isExcluded($0.word.id) }
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
