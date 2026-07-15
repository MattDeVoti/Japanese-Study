import SwiftUI

struct LessonsView: View {
    @State private var levels: [LessonLevel] = []

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(levels) { level in
                        NavigationLink {
                            LevelView(level: level)
                        } label: {
                            LevelRow(level: level)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 20)
                    }

                    NavigationLink {
                        FavoritesView()
                    } label: {
                        FavoritesRow()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
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

// MARK: - Level row

private struct LevelRow: View {
    let level: LessonLevel

    private var isKana: Bool { level.jlptLevel == "Hiragana" || level.jlptLevel == "Katakana" }
    private var accentColor: Color { levelAccentColor(level.jlptLevel) }
    private var levelInt: Int { Int(level.jlptLevel.dropFirst()) ?? 5 }
    private var bookNumber: Int { 6 - levelInt }

    private var circleLabel: String {
        switch level.jlptLevel {
        case "Hiragana": return "ひ"
        case "Katakana": return "カ"
        default: return level.jlptLevel
        }
    }

    private var rowTitle: String {
        switch level.jlptLevel {
        case "Hiragana": return "Hiragana"
        case "Katakana": return "Katakana"
        default: return "Book \(bookNumber) (\(level.jlptLevel))"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(accentColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(circleLabel)
                        .font(.system(size: isKana ? 18 : 14, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appText)
                Text("\(level.chapters.count) \(isKana ? "lessons" : "chapters")")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
