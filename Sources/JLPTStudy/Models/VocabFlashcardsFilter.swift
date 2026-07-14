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
    @Published var selectedChapterIds: Set<String> = [] { didSet { persistSelection() } }
    @Published var selectedWordIds: Set<String> = []
    @Published var showFavoritesOnly: Bool = false
    @Published private(set) var favoriteWordIds: Set<String> = []

    /// Chapters auto-selected because their lesson was completed. Tracked so a
    /// chapter the user manually deselects is not re-added on the next sync.
    @Published private(set) var autoSelectedChapterIds: Set<String> = [] { didSet { persistSelection() } }

    // Weighted shuffle (mirrors the kanji/grammar flashcards)
    @Published var weightMode: WeightMode = .none
    @Published var weightStrength: Double = 0.25
    @Published private(set) var needsWorkCounts: [String: Int] = [:]
    @Published private(set) var confidentCounts: [String: Int] = [:]

    private let favoritesKey = "VocabFavoriteWordIds"
    private let weightsKey = "VocabWordWeights"
    private let selectionKey = "VocabSelectionData"
    private var didLoad = false

    init() {
        loadFavorites()
        loadWeights()
        loadSelection()
        didLoad = true
    }

    var hasActiveFilter: Bool {
        !selectedChapterIds.isEmpty || !selectedWordIds.isEmpty || showFavoritesOnly || weightMode != .none
    }

    // MARK: - Favorites

    func toggleFavorite(_ wordId: String) {
        if favoriteWordIds.contains(wordId) { favoriteWordIds.remove(wordId) }
        else { favoriteWordIds.insert(wordId) }
        saveFavorites()
    }

    func isFavorite(_ wordId: String) -> Bool { favoriteWordIds.contains(wordId) }

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

    func markNeedsWork(_ wordId: String) { needsWorkCounts[wordId, default: 0] += 1; saveWeights() }
    func markConfident(_ wordId: String) { confidentCounts[wordId, default: 0] += 1; saveWeights() }
    func clearWeights() { needsWorkCounts = [:]; confidentCounts = [:]; saveWeights() }

    /// Picks a card, biasing toward "harder" (Don't Know) or "easier" (Got It)
    /// words when a weight mode is active. Same formula as CardStore.selectWeighted.
    func selectWeighted(from cards: [VocabFlashCard]) -> VocabFlashCard? {
        guard !cards.isEmpty else { return nil }
        guard weightMode != .none, weightStrength > 0 else { return cards.randomElement() }
        let weights: [Double] = cards.map { card in
            let count = weightMode == .harder ? (needsWorkCounts[card.word.id] ?? 0)
                                              : (confidentCounts[card.word.id] ?? 0)
            return 1.0 + Double(count) * 5.0 * weightStrength
        }
        var r = Double.random(in: 0..<weights.reduce(0, +))
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return cards[i] }
        }
        return cards.last
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
        return result
    }

    func reset() {
        selectedChapterIds = []
        autoSelectedChapterIds = []
        selectedWordIds = []
        showFavoritesOnly = false
        weightMode = .none
    }

    // MARK: - Persistence

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data)
        else { return }
        favoriteWordIds = ids
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteWordIds) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    private struct WeightData: Codable {
        var needsWork: [String: Int]
        var confident: [String: Int]
    }

    private func loadWeights() {
        guard let data = UserDefaults.standard.data(forKey: weightsKey),
              let d = try? JSONDecoder().decode(WeightData.self, from: data)
        else { return }
        needsWorkCounts = d.needsWork
        confidentCounts = d.confident
    }

    private func saveWeights() {
        let d = WeightData(needsWork: needsWorkCounts, confident: confidentCounts)
        if let data = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(data, forKey: weightsKey)
        }
    }

    private struct SelectionData: Codable {
        var selected: Set<String>
        var autoSelected: Set<String>
    }

    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey),
              let d = try? JSONDecoder().decode(SelectionData.self, from: data)
        else { return }
        selectedChapterIds = d.selected
        autoSelectedChapterIds = d.autoSelected
    }

    private func persistSelection() {
        guard didLoad else { return }   // don't persist during init's loadSelection()
        let d = SelectionData(selected: selectedChapterIds, autoSelected: autoSelectedChapterIds)
        if let data = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(data, forKey: selectionKey)
        }
    }
}
