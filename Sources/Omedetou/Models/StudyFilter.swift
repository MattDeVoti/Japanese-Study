import Foundation
import Combine

enum WeightMode: String, CaseIterable {
    case none = "NONE"
    case needsWork = "NEEDS_WORK"

    /// What the learner sees. Deliberately separate from the raw value, which is
    /// what gets persisted — renaming a mode must never invalidate saved
    /// settings, and these two have been renamed once already.
    var displayName: String {
        switch self {
        case .none:     return "Standard"
        case .needsWork: return "Priority Study"
        }
    }

    /// Shown wherever the mode can be changed, so the choice never has to be
    /// guessed at from the name.
    var explanation: String {
        switch self {
        case .none:
            return "An even shuffle, with anything you\u{2019}ve checked off hidden. The deck shrinks as you work through it, so this is what clears new material."
        case .needsWork:
            return "Everything stays in rotation, including cards you\u{2019}ve checked off, and ones you\u{2019}ve marked Needs Work come up more often. This is what brings old words back."
        }
    }
}

class StudyFilter: ObservableObject {
    enum FilterType {
        case kanji, grammar
    }

    let filterType: FilterType
    let availableLevels: [Int]

    @Published var selectedLevels: Set<Int> = []
    @Published var showFavoritesOnly: Bool = false

    init(type: FilterType) {
        self.filterType = type
        switch type {
        case .kanji:
            availableLevels = [5, 4, 3, 2, 1]
        case .grammar:
            availableLevels = [5, 4, 3, 2, 1]
        }
    }
}

// Distinct subclasses so @EnvironmentObject can resolve them independently
final class KanjiFilter: StudyFilter {
    /// The chapters whose kanji words the study deck deals — the kanji deck's
    /// version of the vocab deck's chapter filter. Empty means every chapter.
    /// Persisted, like the vocab selection, so the deck opens where it was left.
    @Published var selectedChapterIds: Set<String> = [] {
        didSet {
            guard didLoad else { return }
            UserDefaults.standard.encode(selectedChapterIds, forKey: Self.chaptersKey)
        }
    }

    private static let chaptersKey = "KanjiSelectedChapterIds"
    private var didLoad = false

    init() {
        super.init(type: .kanji)
        if let saved = UserDefaults.standard.decode(Set<String>.self, forKey: Self.chaptersKey) {
            selectedChapterIds = saved
        }
        didLoad = true
    }
}

final class GrammarFilter: StudyFilter {
    init() { super.init(type: .grammar) }
}
