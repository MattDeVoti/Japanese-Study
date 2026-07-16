import SwiftUI

struct LessonsView: View {
    @State private var levels: [LessonLevel] = []

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

    // Bubble grid: uniform-size, left-aligned, up to three per row.
    private let bubbleColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {

                    // MARK: Kana
                    VStack(alignment: .leading, spacing: 14) {
                        LessonSectionHeader("Kana")
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
                    VStack(alignment: .leading, spacing: 14) {
                        LessonSectionHeader("Grammar")
                        LazyVGrid(columns: bubbleColumns, alignment: .leading, spacing: 12) {
                            ForEach(grammarLevels) { level in
                                NavigationLink {
                                    LevelView(level: level)
                                } label: {
                                    GrammarCircleButton(level: level)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // MARK: Favorites
                    VStack(alignment: .leading, spacing: 14) {
                        LessonSectionHeader("Favorites")
                        NavigationLink {
                            FavoritesView()
                        } label: {
                            FavoritesRow()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .standardNavBar("Lessons")
        .onAppear {
            LessonsService.shared.loadIfNeeded()
            if levels.isEmpty {
                levels = LessonsService.shared.manifest?.levels ?? []
            }
        }
    }
}

// MARK: - Section header

private struct LessonSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.leading, 4)
    }
}

// MARK: - Kana circular button (large — two per row)

private struct KanaCircleButton: View {
    let level: LessonLevel

    private var color: Color { levelAccentColor(level.jlptLevel) }
    private var glyph: String { level.jlptLevel == "Hiragana" ? "ひ" : "カ" }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.badgeGradient)
                .shadow(color: color.opacity(0.35), radius: 7, x: 0, y: 3)

            VStack(spacing: 2) {
                Text(glyph)
                    .font(.system(size: 30, weight: .bold))
                Text(level.jlptLevel)
                    .font(.system(size: 14, weight: .semibold))
                Text("\(level.chapters.count) lessons")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.85)
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .padding(10)
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(0.9)
    }
}

// MARK: - Grammar circular button (small — five per row)

private struct GrammarCircleButton: View {
    let level: LessonLevel

    private var levelInt: Int { Int(level.jlptLevel.dropFirst()) ?? 5 }
    private var bookNumber: Int { 6 - levelInt }
    private var color: Color { nLevelColor(levelInt) }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.badgeGradient)
                .shadow(color: color.opacity(0.35), radius: 7, x: 0, y: 3)

            VStack(spacing: 2) {
                Text("Book \(bookNumber)")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.9)
                Text(level.jlptLevel)
                    .font(.system(size: 24, weight: .bold))
                Text("\(level.chapters.count) ch")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.9)
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(10)
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(0.9)
    }
}

// MARK: - Favorites row

private struct FavoritesRow: View {
    @ObservedObject private var store = LessonsProgressStore.shared

    private var subtitle: String {
        store.favorites.isEmpty ? "No favorites yet" : "\(store.favorites.count) saved"
    }

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.yellow.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.yellow)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Favorites")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appText)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .appCard(cornerRadius: 16)
    }
}

// MARK: - Level view

struct LevelView: View {
    let level: LessonLevel

    private var accentColor: Color { levelAccentColor(level.jlptLevel) }

    private var navTitle: String {
        switch level.jlptLevel {
        case "Hiragana": return "Hiragana"
        case "Katakana": return "Katakana"
        default:
            let n = Int(level.jlptLevel.dropFirst()) ?? 5
            return "Book \(6 - n) (\(level.jlptLevel))"
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            List(level.chapters) { summary in
                NavigationLink {
                    ChapterDetailView(summary: summary, accentColor: accentColor)
                } label: {
                    ChapterRow(summary: summary)
                }
                .listRowBackground(Color.appBackground)
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
    private var completedCount: Int { store.completedCount(chapterId: summary.id) }
    private var allDone: Bool { summary.pointCount > 0 && completedCount == summary.pointCount }

    private var rowLabel: String {
        isKana ? "Lesson \(summary.chapterNumber)" : "Chapter \(summary.chapterNumber)"
    }

    private var pointsLabel: String {
        isKana ? "\(summary.pointCount) characters" : "\(summary.pointCount) grammar points"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(rowLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(summary.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appText)
                Text(pointsLabel)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if allDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .padding(.trailing, 4)
            } else if completedCount > 0 {
                Text("\(completedCount)/\(summary.pointCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 6)
    }
}
