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

final class VocabFlashcardsFilter: ObservableObject {
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

    func markNeedsWork(_ wordId: String) { needsWorkCounts[wordId, default: 0] += 1; saveWeights() }
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

    /// Picks a card, biasing toward "Needs Work" words when the app-wide
    /// StudyWeightSettings has prioritization on. Shared logic with the other decks.
    func selectWeighted(from cards: [VocabFlashCard]) -> VocabFlashCard? {
        StudyWeightSettings.shared.pick(cards) { needsWorkCounts[$0.word.id] ?? 0 }
    }

    // MARK: - Apply

    func apply(to cards: [VocabFlashCard]) -> [VocabFlashCard] {
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
        if StudyWeightSettings.shared.filtersOutCheckedCards {
            result = result.filter { !excludedWordIds.contains($0.word.id) }
        }
        return result
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
