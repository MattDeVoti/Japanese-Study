import SwiftUI

struct LessonsView: View {
    @State private var levels: [LessonLevel] = []
    @ObservedObject private var customStore = CustomLessonsStore.shared
    @EnvironmentObject private var cardStore: CardStore
    @State private var query = ""
    @State private var results: [LessonSearchResult] = []

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Two kana levels, in fixed display order.
    private var kanaLevels: [LessonLevel] {
        ["Hiragana", "Katakana"].compactMap { name in
            levels.first { $0.jlptLevel == name }
        }
    }

    // The five grammar books, N5 → N1.
    private var grammarLevels: [LessonLevel] {
        levels
            .filter { $0.jlptLevel.hasPrefix("N") }
            .sorted { (Int($0.jlptLevel.dropFirst()) ?? 0) > (Int($1.jlptLevel.dropFirst()) ?? 0) }
    }

    /// The slang book — its own bubble after Level 5.
    private var slangLevel: LessonLevel? {
        levels.first { $0.jlptLevel == SlangContent.levelId }
    }

    // Bubble grid: uniform-size, left-aligned, up to three per row.
    private let bubbleColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                SearchBar(text: $query, placeholder: "Search the whole textbook…")

                if isSearching {
                    ScrollView {
                        LessonSearchResultsView(results: results, query: query)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 36)
                    }
                } else {
                    browseSections
                }
            }
        }
        .standardNavBar("Lessons")
        .onChange(of: query) { q in
            results = LessonSearchService.shared.search(q, cardStore: cardStore)
        }
        .onAppear {
            LessonsService.shared.loadIfNeeded()
            if levels.isEmpty {
                levels = LessonsService.shared.manifest?.levels ?? []
            }
            // Keeps results consistent if the view reappears with a query already set.
            if isSearching && results.isEmpty {
                results = LessonSearchService.shared.search(query, cardStore: cardStore)
            }
        }
    }

    private var browseSections: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {

                    // MARK: Kana
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading("Kana")
                        LazyVGrid(columns: bubbleColumns, alignment: .leading, spacing: 12) {
                            ForEach(kanaLevels) { level in
                                NavigationLink {
                                    LevelView(level: level)
                                } label: {
                                    KanaCircleButton(level: level)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // MARK: Grammar
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading("Grammar")
                        LazyVGrid(columns: bubbleColumns, alignment: .leading, spacing: 12) {
                            ForEach(grammarLevels) { level in
                                NavigationLink {
                                    LevelView(level: level)
                                } label: {
                                    GrammarCircleButton(level: level)
                                }
                                .buttonStyle(.plain)
                            }

                            // Slang — its own book, sixth bubble after Level 5
                            if let slang = slangLevel {
                                NavigationLink {
                                    LevelView(level: slang)
                                } label: {
                                    SlangCircleButton(chapterCount: slang.chapters.count)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // MARK: Culture
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading("Culture")
                        LazyVGrid(columns: bubbleColumns, alignment: .leading, spacing: 12) {
                            NavigationLink {
                                CultureChapterView()
                            } label: {
                                CultureCircleButton()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // MARK: Favorites
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading("Favorites")
                        LazyVGrid(columns: bubbleColumns, alignment: .leading, spacing: 12) {
                            NavigationLink {
                                FavoritesView()
                            } label: {
                                FavoritesCircleButton()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // MARK: Custom — the "+" bubble is always first
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading("Custom")
                        LazyVGrid(columns: bubbleColumns, alignment: .leading, spacing: 12) {
                            NewCustomLessonBubble()

                            ForEach(customStore.lessons) { lesson in
                                NavigationLink {
                                    CustomLessonDetailView(lessonId: lesson.id)
                                } label: {
                                    CustomLessonCircleButton(lesson: lesson)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
    }
}

// MARK: - Slang chapter

/// The standalone slang chapter: not a JLPT level, so it gets its own manifest
/// "level" and its own bubble at the end of the Grammar row.
enum SlangContent {
    /// The manifest level id that holds the single slang chapter.
    static let levelId = "Slang"
    static let chapterId = "ch_slang"
    static let accent = Color(hex: "DB2777")   // magenta — distinct from the N-level colors
}

private struct SlangCircleButton: View {
    let chapterCount: Int

    var body: some View {
        AestheticTile(title: "Slang", subtitle: "\(chapterCount) chapters", glyph: "俗",
                      icon: "bubble.left.and.text.bubble.right.fill", color: SlangContent.accent)
    }
}

// MARK: - Section tiles

private struct KanaCircleButton: View {
    let level: LessonLevel
    private var color: Color { levelAccentColor(level.jlptLevel) }
    private var glyph: String { level.jlptLevel == "Hiragana" ? "ひ" : "カ" }

    var body: some View {
        AestheticTile(title: level.jlptLevel, subtitle: "\(level.chapters.count) lessons",
                      glyph: glyph, icon: "textformat", color: color)
    }
}

private struct GrammarCircleButton: View {
    let level: LessonLevel
    private var levelInt: Int { Int(level.jlptLevel.dropFirst()) ?? 5 }

    var body: some View {
        AestheticTile(title: levelName(levelInt), subtitle: "\(level.chapters.count) chapters",
                      glyph: "\(levelNumber(levelInt))", icon: "book.fill", color: nLevelColor(levelInt))
    }
}

private struct CultureCircleButton: View {
    var body: some View {
        AestheticTile(title: "Culture", subtitle: "\(CultureContent.topics.count) topics",
                      glyph: "文", icon: "building.columns.fill", color: CultureContent.accent)
    }
}

private struct FavoritesCircleButton: View {
    @ObservedObject private var store = LessonsProgressStore.shared
    private var count: Int { store.favorites.count }

    var body: some View {
        // A gold deep enough for white text/icon to read on the filled tile.
        AestheticTile(title: "Favorites", subtitle: count == 0 ? "None yet" : "\(count) saved",
                      glyph: "星", icon: "star.fill", color: Color(hex: "CA8A04"))
    }
}

// MARK: - Level view

struct LevelView: View {
    let level: LessonLevel

    private var accentColor: Color { levelAccentColor(level.jlptLevel) }

    private var navTitle: String { levelName(jlpt: level.jlptLevel) }

    var body: some View {
        ZStack {
            AppBackground()

            List(level.chapters) { summary in
                NavigationLink {
                    ChapterDetailView(summary: summary, accentColor: accentColor)
                } label: {
                    ChapterRow(summary: summary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Color.primary.opacity(0.1))
            }
            .listStyle(.plain)
        }
        .standardNavBar(navTitle)
    }
}

// MARK: - Chapter row

private struct ChapterRow: View {
    let summary: ChapterSummary
    @ObservedObject private var store = LessonsProgressStore.shared

    private var isKana: Bool { summary.chapterType == "kana" }
    // Point ids read live from the chapter file — the single source of truth for
    // both the total and which completions still count (no hardcoded totals).
    private var pointIds: [String] { LessonsService.shared.pointIds(for: summary.id) }
    private var pointCount: Int { LessonsService.shared.pointCount(for: summary.id) }
    private var completedCount: Int { store.completedCount(chapterId: summary.id, among: pointIds) }
    private var allDone: Bool { pointCount > 0 && completedCount == pointCount }

    private var rowLabel: String {
        isKana ? "Lesson \(summary.chapterNumber)" : "Chapter \(summary.chapterNumber)"
    }

    private var pointsLabel: String {
        isKana ? "\(pointCount) characters" : "\(pointCount) grammar points"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(rowLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
                    .textCase(.uppercase)
                Text(summary.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appText)
                Text(pointsLabel)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            if allDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .padding(.trailing, 4)
            } else if completedCount > 0 {
                Text("\(completedCount)/\(pointCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appTextSecondary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 6)
    }
}
