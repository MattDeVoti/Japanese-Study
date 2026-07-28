import SwiftUI

/// Textbook-wide search results, grouped by the chapter each hit was found in.
struct LessonSearchResultsView: View {
    let results: [LessonSearchResult]
    let query: String

    private struct ChapterGroup: Identifiable {
        let id: String
        let title: String
        let jlptLevel: String
        let chapterNumber: Int
        let items: [LessonSearchResult]
    }

    /// Groups by chapter, keeping each chapter at the position of its best hit.
    private var groups: [ChapterGroup] {
        var order: [String] = []
        var buckets: [String: [LessonSearchResult]] = [:]
        for r in results {
            if buckets[r.chapterId] == nil { order.append(r.chapterId) }
            buckets[r.chapterId, default: []].append(r)
        }
        return order.compactMap { id in
            guard let items = buckets[id], let first = items.first else { return nil }
            // Keep the service's ranking (relevance tier, then type) inside each group.
            return ChapterGroup(id: id, title: first.chapterTitle, jlptLevel: first.jlptLevel,
                                chapterNumber: first.chapterNumber, items: items)
        }
    }

    var body: some View {
        if results.isEmpty {
            emptyState
        } else {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
                    .padding(.leading, 4)

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        header(group)
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, result in
                                if idx != 0 { Divider().padding(.leading, 14) }
                                SearchResultRow(result: result)
                            }
                        }
                        .appCard(cornerRadius: 14)
                    }
                }
            }
        }
    }

    private func header(_ group: ChapterGroup) -> some View {
        let isCulture = group.jlptLevel == "Culture"
        let levelText = isCulture ? "Culture" : levelName(jlpt: group.jlptLevel)
        let color = isCulture ? CultureContent.accent : levelAccentColor(group.jlptLevel)
        return HStack(spacing: 6) {
            Text(levelText.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            if group.chapterNumber > 0 {
                Text("· CH\(group.chapterNumber)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
            if !isCulture {
                Text("· \(group.title)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No results for “\(query)”.")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - One result row

private struct SearchResultRow: View {
    let result: LessonSearchResult
    @EnvironmentObject private var cardStore: CardStore

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                Text(result.kind.label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(badgeColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.primary)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)
                    if !result.secondary.isEmpty {
                        Text(result.secondary)
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var badgeColor: Color {
        switch result.kind {
        case .grammar: return levelAccentColor(result.jlptLevel)
        case .vocab:   return .vocabColor
        case .kanji:   return .kanjiColor
        case .culture: return CultureContent.accent
        }
    }

    @ViewBuilder
    private var destination: some View {
        switch result.kind {
        case let .grammar(point):
            if let summary = LessonsService.shared.chapterSummary(for: result.chapterId) {
                ChapterDetailView(summary: summary,
                                  accentColor: levelAccentColor(result.jlptLevel),
                                  focusPointId: point.id)
            }
        case let .vocab(word):
            VocabDictionaryView(word: word)
        case let .kanji(char):
            if let card = cardStore.kanjiCard(for: char) {
                KanjiCardDetailView(card: card)
            }
        case .culture:
            CultureChapterView()
        }
    }
}
