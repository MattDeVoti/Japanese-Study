import Foundation

final class LessonsProgressStore: ObservableObject {
    static let shared = LessonsProgressStore()
    private init() { load() }

    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var completed: Set<String> = []

    private struct Stored: Codable {
        var favorites: Set<String> = []
        var completed: Set<String> = []
    }

    private let storageKey = "LessonsProgressData"

    // MARK: - Key helpers

    private func pointKey(_ chapterId: String, _ pointId: String) -> String {
        "\(chapterId)/\(pointId)"
    }

    // MARK: - Queries

    func isFavorite(chapterId: String, pointId: String) -> Bool {
        favorites.contains(pointKey(chapterId, pointId))
    }

    func isCompleted(chapterId: String, pointId: String) -> Bool {
        completed.contains(pointKey(chapterId, pointId))
    }

    /// How many points in a chapter are completed. Pass `among:` the chapter's
    /// current point ids so that stale completions — for points that were moved or
    /// removed — don't inflate the count (which otherwise causes e.g. "3/2").
    func completedCount(chapterId: String, among validPointIds: [String]? = nil) -> Int {
        let prefix = "\(chapterId)/"
        let donePointIds = completed.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        guard let valid = validPointIds else { return donePointIds.count }
        let validSet = Set(valid)
        return donePointIds.filter { validSet.contains($0) }.count
    }

    func chapterIdsWithFavorites() -> [String] {
        let ids = favorites.compactMap { $0.components(separatedBy: "/").first }
        return Array(Set(ids)).sorted()
    }

    func favoritePointIds(in chapterId: String) -> Set<String> {
        let prefix = "\(chapterId)/"
        return Set(favorites.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) })
    }

    // MARK: - Mutations

    func toggleFavorite(chapterId: String, pointId: String) {
        let k = pointKey(chapterId, pointId)
        if favorites.contains(k) { favorites.remove(k) } else { favorites.insert(k) }
        persist()
    }

    func toggleCompleted(chapterId: String, pointId: String) {
        let k = pointKey(chapterId, pointId)
        if completed.contains(k) { completed.remove(k) } else { completed.insert(k) }
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let stored = UserDefaults.standard.decode(Stored.self, forKey: storageKey) else { return }
        favorites = stored.favorites
        completed = stored.completed
    }

    private func persist() {
        UserDefaults.standard.encode(Stored(favorites: favorites, completed: completed), forKey: storageKey)
    }
}
