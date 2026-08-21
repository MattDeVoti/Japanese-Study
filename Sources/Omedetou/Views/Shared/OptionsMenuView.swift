import SwiftUI

struct OptionsMenuView: View {
    @ObservedObject var filter: StudyFilter
    let onClearWeights: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // Provided only for the kanji picker sub-screen
    var store: CardStore? = nil

    /// Provided only for kanji: clears every kanji flashcard checkmark.
    var onClearExclusions: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Card priority (app-wide setting, shared everywhere).
                    // Above the chapter grid, matching the vocab filter sheet:
                    // the long list of chapters would otherwise bury it.
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Card Priority")
                            .font(.headline)
                            .foregroundColor(.appText)
                        WeightPrioritySection()
                    }

                    Divider()

                    // The kanji deck deals lesson words, so its scope is chosen
                    // by chapter — the same grid, in the same order, as the vocab
                    // filter's, so the two decks are filtered the same way.
                    if let kanjiFilter = filter as? KanjiFilter {
                        KanjiChaptersSection(filter: kanjiFilter)
                        Divider()
                    }

                    // Show favorites only
                    Toggle(isOn: $filter.showFavoritesOnly) {
                        Text("Show Favorites Only")
                            .font(.headline)
                            .foregroundColor(.appText)
                    }
                    .tint(.yellow)

                    Divider()

                    // Clear weights
                    Button {
                        onClearWeights()
                    } label: {
                        Text("Reset Study Weights")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.85)))
                    }
                    .buttonStyle(.plain)

                    // Clear checkmarks (kanji only)
                    if let onClearExclusions = onClearExclusions {
                        Button {
                            onClearExclusions()
                        } label: {
                            Text("Clear All Kanji Checkmarks")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppBackground())
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { FeedbackSounds.shared.playNavigate(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color.appNavBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Chapters
//
// Deliberately the same shape as `VocabFilterSheet.chaptersSection`: levels in
// course order, a square per chapter, Select All per level. The kanji deck and
// the vocab deck are filtered by the same gesture.

private struct KanjiChaptersSection: View {
    @ObservedObject var filter: KanjiFilter

    /// Levels that have at least one chapter teaching kanji words.
    private var levels: [LessonLevel] {
        LessonsService.shared.loadIfNeeded()
        return (LessonsService.shared.manifest?.levels ?? []).filter { level in
            level.chapters.contains { !LessonsService.shared.kanjiWords(for: $0.id).isEmpty }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chapters")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                Text(filter.selectedChapterIds.isEmpty ? "All shown"
                                                       : "\(filter.selectedChapterIds.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(levels, id: \.levelId) { level in
                levelBlock(level)
            }
        }
    }

    private func levelBlock(_ level: LessonLevel) -> some View {
        let color = levelAccentColor(level.levelId)
        let chapters = level.chapters.filter {
            !LessonsService.shared.kanjiWords(for: $0.id).isEmpty
        }
        let allSelected = chapters.allSatisfy { filter.selectedChapterIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(levelName(jlpt: level.levelId))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Button(allSelected ? "Deselect All" : "Select All") {
                    for c in chapters {
                        if allSelected { filter.selectedChapterIds.remove(c.id) }
                        else { filter.selectedChapterIds.insert(c.id) }
                    }
                }
                .font(.caption)
                .foregroundColor(color)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                ForEach(chapters) { summary in
                    ChapterSquare(
                        number: summary.chapterNumber,
                        color: color,
                        selected: filter.selectedChapterIds.contains(summary.id)
                    ) {
                        if filter.selectedChapterIds.contains(summary.id) {
                            filter.selectedChapterIds.remove(summary.id)
                        } else {
                            filter.selectedChapterIds.insert(summary.id)
                        }
                    }
                }
            }
        }
    }
}
