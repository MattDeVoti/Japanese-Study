import Foundation
import Combine

enum WeightMode: String, CaseIterable {
    case none = "NONE"
    case needsWork = "NEEDS_WORK"
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
    @Published var selectedKanjiIds: Set<String> = []
    init() { super.init(type: .kanji) }
}

final class GrammarFilter: StudyFilter {
    init() { super.init(type: .grammar) }
}
