import Foundation

// Chooses the next flashcard for one deck.
//
// The weighted pick on its own is memoryless, which produces two things that read
// as bugs even though each draw is fair:
//
//   • the same card twice in a row, which looks like the button didn't work;
//   • in an unweighted deck, some cards coming up repeatedly while others don't
//     appear at all.
//
// So this keeps a little state. The no-repeat rule applies in both modes. The
// "everything once before anything twice" rule applies *only* with priority off,
// because that mode already hides what you've checked — the pool is exactly what
// you have left to learn, and working through it is what a deck should do. With
// Prioritize Needs Work on, repetition is the whole point of the setting, so the
// cycle would fight it and is skipped.
//
// One instance per deck view: the vocab cycle and the kanji cycle are unrelated.

final class DeckSequencer: ObservableObject {
    /// What was shown last, so it isn't shown again immediately.
    private var lastKey: String?
    /// Keys already seen in the current pass. Only used with priority off.
    private var seen: Set<String> = []

    /// Forget everything — for a deck reload or a filter change.
    func reset() {
        lastKey = nil
        seen.removeAll()
    }

    /// Record a card shown by some route other than `next` (the Back button), so
    /// the following draw doesn't repeat it.
    func note(_ key: String) { lastKey = key }

    func next<T>(from pool: [T], key: (T) -> String, needsWork: (T) -> Int) -> T? {
        guard !pool.isEmpty else { lastKey = nil; return nil }
        // A one-card deck can only repeat; pretending otherwise would return nil.
        guard pool.count > 1 else {
            lastKey = key(pool[0])
            return pool[0]
        }

        let settings = StudyWeightSettings.shared
        let chosen = (settings.mode == .needsWork && settings.strength > 0)
            ? weighted(pool, key: key, needsWork: needsWork)
            : cycled(pool, key: key)

        if let chosen { lastKey = key(chosen) }
        return chosen
    }

    /// Weighted draw, retried until it isn't the card just shown. Bounded, so a
    /// pool whose weight sits almost entirely on one card can't spin forever.
    private func weighted<T>(_ pool: [T], key: (T) -> String, needsWork: (T) -> Int) -> T? {
        for _ in 0..<12 {
            guard let c = StudyWeightSettings.shared.pick(pool, needsWork: needsWork) else {
                return nil
            }
            if key(c) != lastKey { return c }
        }
        return pool.first { key($0) != lastKey } ?? pool.first
    }

    /// Every card in the pool once, in random order, before any of them repeats.
    ///
    /// Tracking what's been *seen* rather than what's left means a pool that
    /// changes mid-pass behaves sensibly on its own: a card checked off simply
    /// stops being a candidate, and a card that appears (filter change, or an
    /// unchecked card coming back) is immediately eligible.
    private func cycled<T>(_ pool: [T], key: (T) -> String) -> T? {
        var candidates = pool.filter { !seen.contains(key($0)) }
        // The pass ends when nothing is unseen — or when the only unseen card is
        // the one already on screen. That second case only arises via `note` (the
        // Back button); rather than repeat it, the pass ends a card early and
        // that card leads the next one. Not repeating matters more than a pass
        // being exactly complete.
        if candidates.isEmpty || (candidates.count == 1 && key(candidates[0]) == lastKey) {
            seen.removeAll()
            candidates = pool
        }
        // Don't open a new pass with the card that closed the last one. Guarded
        // so this can never empty the list.
        if candidates.count > 1 {
            candidates.removeAll { key($0) == lastKey }
        }
        guard let chosen = candidates.randomElement() else { return pool.first }
        seen.insert(key(chosen))
        return chosen
    }
}
