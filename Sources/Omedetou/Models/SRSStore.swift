import SwiftUI

// The review schedule: which items are enrolled, what the scheduler knows about
// each, and the daily review counter.
//
// Deliberately no streak: a streak rewards showing up, which pushes people toward
// a daily minimum. Motivation lives in the graded tests instead.
//
// This sits *alongside* the existing checkmarks and needs-work weights rather
// than replacing them. Those answer "have I studied this?"; this answers "when
// should I see it again?".

enum SRSItemKind: String, Codable, CaseIterable {
    case vocab, kanji, grammar

    var label: String {
        switch self {
        case .vocab:   return "Vocab"
        case .kanji:   return "Kanji"
        case .grammar: return "Grammar"
        }
    }
    var color: Color {
        switch self {
        case .vocab:   return .vocabColor
        case .kanji:   return .kanjiColor
        case .grammar: return .grammarColor
        }
    }
}

/// Identifies a reviewable item. `key` is the vocab word id, the kanji character
/// id, or "chapterId/pointId" for a grammar point.
struct SRSItemID: Hashable, Codable, Identifiable {
    let kind: SRSItemKind
    let key: String

    /// Already unique per item, so it doubles as the SwiftUI identity.
    var id: String { storageKey }

    var storageKey: String { "\(kind.rawValue):\(key)" }

    init(kind: SRSItemKind, key: String) {
        self.kind = kind
        self.key = key
    }

    init?(storageKey: String) {
        guard let sep = storageKey.firstIndex(of: ":") else { return nil }
        guard let k = SRSItemKind(rawValue: String(storageKey[storageKey.startIndex..<sep])) else {
            return nil
        }
        kind = k
        key = String(storageKey[storageKey.index(after: sep)...])
    }

    static func vocab(_ id: String) -> SRSItemID { .init(kind: .vocab, key: id) }
    static func kanji(_ id: String) -> SRSItemID { .init(kind: .kanji, key: id) }
    static func grammar(chapterId: String, pointId: String) -> SRSItemID {
        .init(kind: .grammar, key: "\(chapterId)/\(pointId)")
    }
}

final class SRSStore: ObservableObject {
    static let shared = SRSStore()

    @Published private(set) var memories: [String: SRSMemory] = [:]
    @Published private(set) var reviewsToday: Int = 0
    /// Total reviews ever, purely for the stats panel.
    @Published private(set) var totalReviews: Int = 0

    private var lastStudyDay: Date?
    /// When the last practice round was finished, so the next one can wait an hour.
    @Published private(set) var lastReviewFinished: Date?
    private var reviewsTodayDay: Date?
    private var loaded = false
    private static let file = "srs"

    /// Internal rather than private so the sync layer can merge two copies of it.
    struct Stored: Codable {
        var memories: [String: SRSMemory] = [:]
        var lastReviewFinished: Date?
        var lastStudyDay: Date?
        var reviewsToday: Int = 0
        var reviewsTodayDay: Date?
        var totalReviews: Int = 0
    }

    private init() {
        if let s = FileStore.load(Stored.self, Self.file) {
            memories = s.memories
            lastReviewFinished = s.lastReviewFinished
            lastStudyDay = s.lastStudyDay
            reviewsToday = s.reviewsToday
            reviewsTodayDay = s.reviewsTodayDay
            totalReviews = s.totalReviews
        }
        loaded = true
        rolloverDayIfNeeded()
    }

    // MARK: - Queries

    func memory(for id: SRSItemID) -> SRSMemory? { memories[id.storageKey] }
    var enrolledCount: Int { memories.count }

    /// Items whose scheduled time has arrived.
    func dueIDs(at now: Date = Date()) -> [SRSItemID] {
        memories
            .filter { $0.value.due <= now }
            .sorted { $0.value.due < $1.value.due }
            .compactMap { SRSItemID(storageKey: $0.key) }
    }

    func dueCount(at now: Date = Date()) -> Int {
        memories.values.reduce(0) { $0 + ($1.due <= now ? 1 : 0) }
    }

    func dueCount(kind: SRSItemKind, at now: Date = Date()) -> Int {
        memories.reduce(0) { acc, entry in
            guard entry.value.due <= now,
                  let id = SRSItemID(storageKey: entry.key), id.kind == kind else { return acc }
            return acc + 1
        }
    }

    /// The items the model finds hardest: highest difficulty first, then the ones
    /// lapsed most often. This is the "what do I actually need work on" signal.
    func hardestIDs(limit: Int, at now: Date = Date()) -> [SRSItemID] {
        memories
            .sorted { a, b in
                if a.value.difficulty != b.value.difficulty {
                    return a.value.difficulty > b.value.difficulty
                }
                return a.value.lapses > b.value.lapses
            }
            .prefix(limit)
            .compactMap { SRSItemID(storageKey: $0.key) }
    }

    /// What a practice run should contain. Anything genuinely ready comes first,
    /// then the weakest items fill the rest — so practice is always available and
    /// never presents itself as a queue that has to be emptied.
    func practiceIDs(limit: Int, at now: Date = Date()) -> [SRSItemID] {
        var out = Array(dueIDs(at: now).prefix(limit))
        guard out.count < limit else { return out }
        let seen = Set(out.map(\.storageKey))
        for id in hardestIDs(limit: limit * 3, at: now) where !seen.contains(id.storageKey) {
            out.append(id)
            if out.count == limit { break }
        }
        return out
    }

    /// Rewrites review memories saved under the old random kanji ids so they
    /// follow their character. Called once by CardStore, which owns the map.
    func migrateKanjiKeys(_ idToCharacter: [String: String]) {
        var changed = false
        for (old, new) in idToCharacter {
            let oldKey = SRSItemID(kind: .kanji, key: old).storageKey
            guard let memory = memories.removeValue(forKey: oldKey) else { continue }
            let newKey = SRSItemID(kind: .kanji, key: new).storageKey
            // If both somehow exist, keep whichever was reviewed more recently.
            if let existing = memories[newKey], existing.lastReview >= memory.lastReview {
                changed = true
                continue
            }
            memories[newKey] = memory
            changed = true
        }
        if changed { persist() }
    }

    // MARK: - Round availability
    //
    // A round is a fixed, finishable piece of work rather than a tap you can keep
    // repeating. Capping it and then making the next one wait keeps practice
    // something you do and then leave, instead of a counter to grind down —
    // which is the same reason there's no streak.

    /// How long after finishing a round before another is offered.
    static let reviewCooldown: TimeInterval = 60 * 60

    /// Questions in one round, drawn from whatever is available.
    static let reviewLength = 15

    var nextReviewAvailable: Date? {
        lastReviewFinished.map { $0.addingTimeInterval(Self.reviewCooldown) }
    }

    func reviewAvailable(at now: Date = Date()) -> Bool {
        guard let next = nextReviewAvailable else { return true }
        return now >= next
    }

    /// Seconds until the next round, or nil when one is ready now.
    func reviewWait(at now: Date = Date()) -> TimeInterval? {
        guard let next = nextReviewAvailable, next > now else { return nil }
        return next.timeIntervalSince(now)
    }

    func markReviewFinished(at now: Date = Date()) {
        lastReviewFinished = now
        persist()
    }

    // MARK: - Grading

    func grade(_ id: SRSItemID, _ grade: ReviewGrade, now: Date = Date()) {
        rolloverDayIfNeeded(now: now)
        let updated = FSRS.review(memories[id.storageKey], grade: grade, now: now)
        memories[id.storageKey] = updated
        reviewsToday += 1
        totalReviews += 1
        lastStudyDay = Calendar.current.startOfDay(for: now)
        persist()
    }

    /// Enrols items without reviewing them, spreading first due dates over
    /// `fanOutDays` so seeding an existing library doesn't produce one huge pile.
    /// Items already enrolled are left untouched.
    func enroll(_ ids: [SRSItemID], fanOutDays: Int = 14, now: Date = Date()) {
        guard !ids.isEmpty else { return }
        let fresh = ids.filter { memories[$0.storageKey] == nil }
        guard !fresh.isEmpty else { return }
        let span = max(fanOutDays, 1)
        for (i, id) in fresh.shuffled().enumerated() {
            // Treat as already-learned material: a modest starting stability, then
            // deal them out day by day.
            let dayOffset = Double(i % span)
            let stability = FSRS.w[2]                       // the "Good" first-step stability
            memories[id.storageKey] = SRSMemory(
                stability: stability,
                difficulty: 5.0,
                due: Calendar.current.startOfDay(for: now)
                    .addingTimeInterval(dayOffset * 86_400 + 9 * 3_600),
                lastReview: now,
                reps: 0,
                lapses: 0
            )
        }
        persist()
    }

    func unenroll(_ id: SRSItemID) {
        memories.removeValue(forKey: id.storageKey)
        persist()
    }

    /// Zeroes today's counter when the calendar day changes.
    func rolloverDayIfNeeded(now: Date = Date()) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        if reviewsTodayDay == nil || reviewsTodayDay! != today {
            reviewsTodayDay = today
            reviewsToday = 0
        }
        if loaded { persist() }
    }

    // MARK: - Persistence

    private func persist() {
        FileStore.save(snapshot(), Self.file)
    }

    // MARK: - Sync

    var snapshotName: String { Self.file }

    func snapshot() -> Stored {
        Stored(memories: memories, lastReviewFinished: lastReviewFinished,
               lastStudyDay: lastStudyDay,
               reviewsToday: reviewsToday, reviewsTodayDay: reviewsTodayDay,
               totalReviews: totalReviews)
    }

    /// Replaces everything with a merged document from sync. Writes through to
    /// disk so a crash before the next review can't lose what just arrived.
    @MainActor
    func adopt(_ s: Stored) {
        memories = s.memories
        lastReviewFinished = s.lastReviewFinished
        lastStudyDay = s.lastStudyDay
        reviewsToday = s.reviewsToday
        reviewsTodayDay = s.reviewsTodayDay
        totalReviews = s.totalReviews
        FileStore.save(s, Self.file)
    }
}
