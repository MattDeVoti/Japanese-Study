import SwiftUI

struct FavoritesView: View {
    @ObservedObject private var store = LessonsProgressStore.shared
    @State private var sections: [FavSection] = []

    private struct FavSection: Identifiable {
        let id: String          // chapterId
        let title: String
        let accentColor: Color
        let points: [GrammarPoint]
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if store.favorites.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 10) {
                                    ForEach(section.points) { point in
                                        GrammarPointCard(
                                            point: point,
                                            chapterId: section.id,
                                            accentColor: section.accentColor
                                        )
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .standardNavBar("Favorites")
        .onAppear { reload() }
        .onChange(of: store.favorites) { _ in reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No favorites yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            Text("Tap the star on any grammar point to save it here.")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
    }

    private func reload() {
        LessonsService.shared.loadIfNeeded()
        var result: [FavSection] = []
        for chId in store.chapterIdsWithFavorites() {
            let favIds = store.favoritePointIds(in: chId)
            guard let chapter = LessonsService.shared.loadChapter(chId) else { continue }
            let pts = chapter.points.filter { favIds.contains($0.id) }
            guard !pts.isEmpty else { continue }
            let jlpt = LessonsService.shared.jlptLevel(for: chId) ?? "N5"
            let lvl = Int(jlpt.dropFirst()) ?? 5
            result.append(FavSection(id: chId, title: chapter.title, accentColor: nLevelColor(lvl), points: pts))
        }
        sections = result
    }
}
