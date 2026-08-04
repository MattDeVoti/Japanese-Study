import SwiftUI

// Report card, progression, and the deadline on the current test.
//
// Tests are not *scheduled* — they're *due*. A scheduled test says "come back on
// Friday", which is the same attendance pressure a streak applies. A deadline says
// "you have until Friday", which leaves the pace to the learner and only measures
// whether the work got done.

final class ExamStore: ObservableObject {
    static let shared = ExamStore()

    /// Every sitting ever, newest last. Failures are never removed.
    @Published private(set) var attempts: [ExamAttempt] = []
    /// Lessons the user chose to move past without clearing.
    @Published private(set) var skipped: Set<String> = []
    /// The deadline currently attached to each lesson. Only the lesson in front of
    /// you carries one; it's set when that lesson becomes current.
    @Published private(set) var deadlines: [String: Date] = [:]

    /// How long you get to complete a test once it's in front of you.
    @Published var intervalDays: Int = 7 { didSet { if loaded { persist() } } }

    private var loaded = false
    private static let file = "exams"

    /// Internal rather than private so the sync layer can merge two copies of it.
    struct Stored: Codable {
        var attempts: [ExamAttempt] = []
        var skipped: Set<String> = []
        var deadlines: [String: Date] = [:]
        var intervalDays: Int = 7
    }

    private init() {
        if let s = FileStore.load(Stored.self, Self.file) {
            attempts = s.attempts
            skipped = s.skipped
            deadlines = s.deadlines
            intervalDays = s.intervalDays
        }
        loaded = true
    }

    // MARK: - The track

    private(set) lazy var track: [ExamLesson] = buildTrack()

    /// Everything that must be cleared, in order. Test-outs are optional shortcuts
    /// and are excluded.
    var gradedTrack: [ExamLesson] { track.filter { !$0.isTestOut } }

    private func buildTrack() -> [ExamLesson] {
        LessonsService.shared.loadIfNeeded()
        guard let manifest = LessonsService.shared.manifest else { return [] }
        var out: [ExamLesson] = []

        for name in ["Hiragana", "Katakana"] {
            guard let level = manifest.levels.first(where: { $0.levelId == name }) else { continue }
            out += kanaLessons(level: level)
        }
        let grammar = manifest.levels
            .filter { $0.levelId.hasPrefix("N") }
            .sorted { (Int($0.levelId.dropFirst()) ?? 0) > (Int($1.levelId.dropFirst()) ?? 0) }
        for level in grammar {
            for ch in level.chapters {
                out.append(ExamLesson(id: ch.id, levelId: level.levelId, title: ch.title,
                                      coverage: "Grammar, vocab and kanji",
                                      chapterIds: [ch.id], kind: .chapter))
            }
        }
        return out
    }

    /// A syllabary in three parts, split where the rows naturally group, plus a
    /// single paper covering the lot for anyone who already knows it.
    private func kanaLessons(level: LessonLevel) -> [ExamLesson] {
        let chapters = level.chapters
        let name = level.levelId
        let key = name.lowercased()
        guard chapters.count >= 3 else { return [] }

        let cuts = [0, min(4, chapters.count), min(9, chapters.count), chapters.count]
        let labels = ["Vowels and the K, S, T rows",
                      "N, H, M, R, Y and W rows",
                      "Voiced and semi-voiced sounds"]

        var out: [ExamLesson] = []
        for i in 0..<3 {
            let range = cuts[i]..<cuts[i + 1]
            guard !range.isEmpty else { continue }
            out.append(ExamLesson(
                id: "\(key)-part\(i + 1)",
                levelId: name,
                title: "\(name) \(i + 1) of 3",
                coverage: labels[i],
                chapterIds: chapters[range].map(\.id),
                kind: .kanaChunk))
        }
        out.append(ExamLesson(
            id: "\(key)-all",
            levelId: name,
            title: "Test out of \(name)",
            coverage: "Every character at once — pass this and the parts above are done",
            chapterIds: chapters.map(\.id),
            kind: .kanaTestOut))
        return out
    }

    var levelOrder: [String] {
        var seen: [String] = []
        for l in track where !seen.contains(l.levelId) { seen.append(l.levelId) }
        return seen
    }

    /// The lessons a level requires. Excludes its test-out.
    func lessons(in levelId: String) -> [ExamLesson] {
        track.filter { $0.levelId == levelId && !$0.isTestOut }
    }

    func testOut(for levelId: String) -> ExamLesson? {
        track.first { $0.levelId == levelId && $0.isTestOut }
    }

    func lesson(id: String) -> ExamLesson? { track.first { $0.id == id } }

    // MARK: - Record

    func attempts(for lessonId: String) -> [ExamAttempt] {
        attempts.filter { $0.lessonId == lessonId }.sorted { $0.takenAt < $1.takenAt }
    }

    /// The best sitting. Earlier failures stay in the history, but the record
    /// shouldn't punish someone for having improved.
    func bestGrade(for lessonId: String) -> Grade? {
        attempts(for: lessonId).map(\.grade).max()
    }

    /// What the report card counts. A test whose deadline passed without being sat
    /// stands at zero until it's actually taken.
    func effectiveGrade(for lessonId: String) -> Grade? {
        if let g = bestGrade(for: lessonId) { return g }
        return isOverdue(lessonId) ? Grade(percent: 0) : nil
    }

    func hasFailedAttempt(for lessonId: String) -> Bool {
        attempts(for: lessonId).contains { !$0.grade.isPass }
    }

    /// Averaged over the whole track, test-outs included. `gradedTrack` excludes
    /// them, which meant someone who tested out of Hiragana had sat a real paper,
    /// scored an A, and still saw no GPA at all. A test-out only ever carries a
    /// grade once it's been taken (it gets no deadline, so it can't score an
    /// overdue zero), so including it can't invent marks out of nothing.
    var gpa: Double? { average(of: track.map(\.id)) }

    func gpa(level: String) -> Double? {
        var ids = lessons(in: level).map(\.id)
        if let out = testOut(for: level) { ids.append(out.id) }
        return average(of: ids)
    }

    private func average(of lessonIds: [String]) -> Double? {
        let graded = lessonIds.compactMap { effectiveGrade(for: $0) }
        guard !graded.isEmpty else { return nil }
        return graded.map(\.points).reduce(0, +) / Double(graded.count)
    }

    // MARK: - Deadlines

    func deadline(for lessonId: String) -> Date? { deadlines[lessonId] }

    /// Past its deadline and never sat. The zero stands until the test is taken —
    /// no new deadline is issued, so there's nothing further to miss.
    func isOverdue(_ lessonId: String, now: Date = Date()) -> Bool {
        guard attempts(for: lessonId).isEmpty, let due = deadlines[lessonId] else { return false }
        return due < now
    }

    /// Gives the lesson in front of the user a deadline if it hasn't got one.
    /// Call from `onAppear` rather than a view body — it mutates published state.
    func ensureCurrentDeadline(now: Date = Date()) {
        guard let lesson = currentLesson, deadlines[lesson.id] == nil,
              !lesson.isTestOut else { return }
        deadlines[lesson.id] = computeDeadline(from: now)
        persist()
    }

    /// Simply `intervalDays` from now. It used to be nudged onto a fixed weekday,
    /// which meant finishing a test early didn't buy you any time — the next
    /// deadline snapped back to the same day of the week regardless.
    private func computeDeadline(from now: Date) -> Date {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: max(intervalDays, 1),
                            to: cal.startOfDay(for: now)) ?? now
        // End of that day, so a deadline of the 7th means all of the 7th.
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }

    // MARK: - Progression

    /// Has this paper reached the mark it's held to? A lesson needs a B; a
    /// test-out needs an A, since it stands in for the whole syllabary.
    func clears(_ lesson: ExamLesson) -> Bool {
        effectiveGrade(for: lesson.id)?.meets(lesson.requiredMark) == true
    }

    /// Cleared either by every lesson reaching a B, or by taking the level's
    /// test-out at an A.
    func isLevelCleared(_ levelId: String) -> Bool {
        if let t = testOut(for: levelId), clears(t) { return true }
        let ls = lessons(in: levelId)
        guard !ls.isEmpty else { return false }
        return ls.allSatisfy { clears($0) }
    }

    func lessonsBelowAdvance(in levelId: String) -> [ExamLesson] {
        if let t = testOut(for: levelId), clears(t) { return [] }
        return lessons(in: levelId).filter { !clears($0) }
    }

    func isLevelUnlocked(_ levelId: String) -> Bool {
        guard let idx = levelOrder.firstIndex(of: levelId) else { return false }
        if levelId == "Hiragana" || levelId == "Katakana" { return true }
        return levelOrder.prefix(idx).allSatisfy { isLevelCleared($0) }
    }

    /// The lesson in front of the user: the first in an unlocked level that hasn't
    /// been passed or explicitly skipped.
    var currentLesson: ExamLesson? {
        gradedTrack.first { l in
            guard isLevelUnlocked(l.levelId), !isLevelCleared(l.levelId) else { return false }
            if skipped.contains(l.id) { return false }
            return bestGrade(for: l.id)?.isPass != true
        }
        ?? gradedTrack.filter { isLevelUnlocked($0.levelId) }
                      .filter { !clears($0) }
                      .min { (effectiveGrade(for: $0.id)?.percent ?? 0)
                           < (effectiveGrade(for: $1.id)?.percent ?? 0) }
    }

    // MARK: - Availability

    enum Availability: Equatable {
        /// Takeable, with time left.
        case due(Date)
        /// Deadline passed and never sat — scoring zero until it is.
        case overdue(Date)
        /// Takeable with no deadline attached (test-outs, and anything already sat).
        case open
        case levelLocked(String)
    }

    func availability(of lesson: ExamLesson, now: Date = Date()) -> Availability {
        guard isLevelUnlocked(lesson.levelId) else { return .levelLocked(lesson.levelId) }
        guard let due = deadlines[lesson.id], attempts(for: lesson.id).isEmpty else { return .open }
        return due < now ? .overdue(due) : .due(due)
    }

    // MARK: - Mutations

    func record(_ attempt: ExamAttempt, now: Date = Date()) {
        attempts.append(attempt)
        skipped.remove(attempt.lessonId)
        // The deadline has been met (or missed and now settled); clear it and hand
        // the next lesson its own.
        deadlines.removeValue(forKey: attempt.lessonId)
        persist()
        ensureCurrentDeadline(now: now)
    }

    /// Moves past a lesson without clearing it. The grade stays on the card and the
    /// lesson still blocks the level until it's brought up to a B.
    func skip(_ lessonId: String) {
        skipped.insert(lessonId)
        persist()
        ensureCurrentDeadline()
    }

    private func persist() {
        FileStore.save(snapshot(), Self.file)
    }

    // MARK: - Sync

    var snapshotName: String { Self.file }

    func snapshot() -> Stored {
        Stored(attempts: attempts, skipped: skipped,
               deadlines: deadlines, intervalDays: intervalDays)
    }

    @MainActor
    func adopt(_ s: Stored) {
        attempts = s.attempts
        skipped = s.skipped
        deadlines = s.deadlines
        loaded = false            // intervalDays has a persisting didSet
        intervalDays = s.intervalDays
        loaded = true
        FileStore.save(s, Self.file)
    }
}
