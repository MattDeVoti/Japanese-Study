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
//     forward, so per item the later `lastReview` wins;
//   • exam attempts are immutable once sat, so the union by id is exactly right.
//
// Scalars that are genuinely settings rather than history (how many days you get
// for a test) can't be merged — there's no right answer to "7 here, 10 there" —
// so those follow whichever copy was written more recently.

enum SyncMerge {

    /// Which copy was modified more recently. Only consulted for plain settings.
    enum Newer { case local, remote }

    // MARK: - Review schedule

    static func mergeSRS(local: SRSStore.Stored, remote: SRSStore.Stored,
                         newer: Newer) -> SRSStore.Stored {
        var out = SRSStore.Stored()

        // Per item, the copy that saw it more recently. Ties break on reps, so a
        // review recorded in the same second as another isn't silently dropped.
        var memories = local.memories
        for (key, r) in remote.memories {
            guard let l = memories[key] else { memories[key] = r; continue }
            if r.lastReview > l.lastReview { memories[key] = r }
            else if r.lastReview == l.lastReview && r.reps > l.reps { memories[key] = r }
        }
        out.memories = memories

        // Reviews-ever is reconstructed from the merged items rather than added
        // up, because summing two copies would double-count all the shared
        // history. Never allowed to go backwards.
        let fromReps = memories.values.reduce(0) { $0 + $1.reps }
        out.totalReviews = max(fromReps, max(local.totalReviews, remote.totalReviews))

        out.lastStudyDay = latest(local.lastStudyDay, remote.lastStudyDay)
        // The later finish wins: a round done on either device starts the wait.
        out.lastReviewFinished = latest(local.lastReviewFinished, remote.lastReviewFinished)

        // Today's counter only means anything within one day. Same day: take the
        // larger, since the two can't be added without knowing the overlap.
        let cal = Calendar.current
        switch (local.reviewsTodayDay, remote.reviewsTodayDay) {
        case let (l?, r?) where cal.isDate(l, inSameDayAs: r):
            out.reviewsTodayDay = l
            out.reviewsToday = max(local.reviewsToday, remote.reviewsToday)
        case let (l?, r?):
            let localNewer = l > r
            out.reviewsTodayDay = localNewer ? l : r
            out.reviewsToday = localNewer ? local.reviewsToday : remote.reviewsToday
        case let (l?, nil):
            out.reviewsTodayDay = l; out.reviewsToday = local.reviewsToday
        case let (nil, r?):
            out.reviewsTodayDay = r; out.reviewsToday = remote.reviewsToday
        case (nil, nil):
            break
        }
        return out
    }

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
