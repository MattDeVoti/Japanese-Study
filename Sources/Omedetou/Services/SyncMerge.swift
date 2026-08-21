import Foundation

// Reconciling two copies of the app's data that were both used offline.
//
// This is the part that decides whether switching devices costs you work.
// Last-writer-wins on a whole document is the easy answer and the wrong one:
// review ten cards on the iPad while the phone still holds yesterday's srs.json,
// and whichever device syncs second erases the other's session.
//
// Both documents happen to have shapes that merge honestly:
//   • review memories are keyed by item id, and a review only ever moves an item
//   • exam attempts are immutable once sat, so the union by id is exactly right.
//
// Scalars that are genuinely settings rather than history (how many days you get
// for a test) can't be merged — there's no right answer to "7 here, 10 there" —
// so those follow whichever copy was written more recently.

enum SyncMerge {

    /// Which copy was modified more recently. Only consulted for plain settings.
    enum Newer { case local, remote }

    // MARK: - Report card

    static func mergeExams(local: ExamStore.Stored, remote: ExamStore.Stored,
                           newer: Newer) -> ExamStore.Stored {
        var out = ExamStore.Stored()

        // A sitting never changes after the fact, so the union by id is the whole
        // history. Sorted by when it was taken, which is the order the report
        // card reads in.
        var byId: [String: ExamAttempt] = [:]
        for a in local.attempts + remote.attempts { byId[a.id] = a }
        out.attempts = byId.values.sorted { $0.takenAt < $1.takenAt }

        out.skipped = local.skipped.union(remote.skipped)

        // A deadline is re-set whenever a lesson comes back round, so the later
        // one is the current one. It also errs toward giving the learner time,
        // which is the right way to be wrong.
        var deadlines = local.deadlines
        for (lesson, date) in remote.deadlines {
            deadlines[lesson] = latest(deadlines[lesson], date)
        }
        out.deadlines = deadlines

        // A preference, not history — nothing to reconcile, so the newer copy wins.
        out.intervalDays = newer == .local ? local.intervalDays : remote.intervalDays
        return out
    }

    private static func latest(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (x?, y?): return max(x, y)
        case let (x?, nil): return x
        case let (nil, y?): return y
        default: return nil
        }
    }
}
