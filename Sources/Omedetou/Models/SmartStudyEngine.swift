import Foundation

// MARK: - Smart Study
//
// An automatic tour through the course that drives the two card-priority modes
// on a schedule, so neither has to be chosen by hand.
//
//
// ## Why it exists
//
// The two priority modes pull in opposite directions, and neither is much good
// on its own:
//
//   • Standard (`WeightMode.none`) hides what you've checked off, so it drives
//     you *through* a chapter. Left alone it marches you into new material and
//     never looks back — you finish chapters and forget them.
//   • Priority Study (`WeightMode.needsWork`) keeps everything in rotation and
//     favours what you've missed, so it drives you *back over* old ground. Left
//     alone it never lets you finish anything.
//
// Smart Study alternates between them on a fixed schedule so that new material
// gets cleared *and* old material keeps resurfacing.
//
//
// ## The shape of one cycle
//
//   1. Work a chapter in Standard until it is nearly cleared — fewer cards left
//      than `startThreshold` (see `uncheckedCount` for what "cards" means).
//   2. That starts a hidden countdown: `countdownTarget` more answers before the
//      tour moves on. The gap is deliberate — it stops a chapter being abandoned
//      the instant its last few words are checked.
//   3. On reaching the target, the next unfinished chapter is *added* to the
//      selection and becomes the new current chapter.
//   4. From then on Priority Study cards are mixed back in at a thinning rate —
//      `Phase.alternating`, then `.tapering`, then indefinite `.upkeep`.
//
// The recovery path that justifies the whole design: a word you've forgotten
// resurfaces on one of those Priority cards, you mark it Needs Work, that
// *unchecks* it, and it re-enters the Standard rotation as unfinished business.
// Without the mixed-in Priority cards a forgotten word would never be seen
// again, because Standard hides everything checked.
//
//
// ## Two counts that are easy to confuse
//
//   • The **pool** is every selected chapter. Chapters only ever accumulate —
//     the programme adds, never removes — so the deck grows as the tour goes on
//     and older material stays reachable.
//   • The **current chapter** (`State.chapterId`) is the only thing "nearly
//     cleared" is measured against. Measuring the whole growing pool instead
//     would make each move harder to earn than the last, and the tour would
//     stall a few chapters in.
//
//
// ## Scope, and what is shared with what
//
//   • `StudyWeightSettings.mode` is **app-wide**. Smart Study drives it, so the
//     kanji and grammar decks follow whichever side of the cycle the vocab deck
//     in your hands last reached. That is intended, but it does mean those decks
//     can be entered in either mode depending on where you left off.
//   • Chapter **selections** are per-deck: the written deck uses
//     `VocabFlashcardsFilter.shared`, the audio deck `VocalDeckFilter.shared`.
//     Hence one engine per deck (`written` / `audio`), each with its own saved
//     position.
//   • Checkmarks (**exclusions**) are shared by both decks and live only on
//     `VocabFlashcardsFilter.shared` — see `unclearedSlots`, which always reads
//     that store regardless of which deck's filter it was handed.
//
//
// ## Integration contract for a deck
//
// A deck must make these four calls. Getting the order wrong causes real,
// hard-to-spot bugs, noted against each:
//
//   1. `prepare(cards:filter:)` — on appear. Seeds the tour, or adopts whatever
//      is already selected.
//   2. `applyMode(cards:filter:)` — immediately **before** reading the card
//      pool, every deal. The mode decides whether checked-off cards are in the
//      pool at all, so reading the pool first deals the previous card's mode.
//   3. `cardAnswered(cards:filter:)` — once per answered card, **before**
//      dealing the next one. It also settles the next card's mode itself, so
//      the deck's own `applyMode` on the following deal is a no-op.
//   4. `cardUndone()` — on a back button, if the deck has one.
//
// Two further hazards for a SwiftUI deck:
//
//   • The engine writes to `filter.selectedChapterIds`, which is `@Published`.
//     A deck that re-deals on that change will deal a second card on top of the
//     one it just dealt. Guard with `consumeSelfAppliedChange()`.
//   • The engine writes to `StudyWeightSettings.mode`, also `@Published`. A deck
//     that re-deals on mode changes must skip doing so while Smart Study is on.
//
//
// ## Testing
//
// The `BEGIN-SCHEDULE` / `END-SCHEDULE` markers are load-bearing. The schedule
// between them is pure — no state, no storage, no app types beyond `WeightMode`
// — so it can be lifted out verbatim and compiled standalone to check the card
// counts of each phase without booting the app. Keep new dependencies out of
// that region, and keep the markers.

final class SmartStudyEngine: ObservableObject {
    /// One programme per vocab deck, because the decks' chapter selections are
    /// independent — so their positions in the cycle have to be too. The
    /// `storageKey` keeps their saved state apart.
    static let written = SmartStudyEngine(storageKey: "SmartStudyWritten")
    static let audio = SmartStudyEngine(storageKey: "SmartStudyAudio")

    /// Bumped every time the programme moves, purely so SwiftUI has something to
    /// observe.
    ///
    /// None of the real state is `@Published` — it is deliberately invisible to
    /// the learner. But the engine is a reference held unchanged across renders,
    /// so a view showing its counters (the debug readout) would otherwise have
    /// no reason to redraw and would sit frozen until something else forced a
    /// render.
    @Published private(set) var revision = 0

    // MARK: - Tuning
    //
    // These are the dials. They interact, so a note on each about what moving it
    // actually does.

    /// Answers between "this chapter is nearly cleared" and actually moving on.
    ///
    /// Lower it and chapters get abandoned as soon as their last few words are
    /// checked; raise it and you grind on a chapter with almost nothing left to
    /// show — which is what `starvedThreshold` exists to soften.
    static let countdownTarget = 40

    /// Cards left in the current chapter that starts the countdown.
    static let startThreshold = 10

    /// The same, when the deck is running both directions.
    ///
    /// Higher, not lower: in Both mode every word is two cards, so the chapter
    /// is twice the work and worth leaving sooner in card terms.
    static let startThresholdBothDirections = 15

    /// Below this many cards left, the rest of the countdown is served entirely
    /// from Priority Study.
    ///
    /// Standard hides checked cards, so a chapter down to its last one or two
    /// would just cycle the same card for the remainder of the countdown.
    static let starvedThreshold = 3

    /// Cards held in plain Standard after the learner picks chapters themselves.
    ///
    /// Choosing a chapter is a statement of intent — they want to work on it —
    /// so the programme gets out of the way and lets them clear some of it
    /// before it starts mixing anything back in.
    static let manualGraceCards = 50

    // The post-move mix, in three phases that run in order; the last one repeats
    // forever. See `Phase` for what each is for, and `scheduledMode` for the
    // arithmetic. Ratios are Standard : Priority Study.
    static let alternatingCards = 30      // 30 cards, 1:1
    static let taperCards = 60            // 60 cards of a repeating 10:5
    static let taperCycle = 15
    static let taperStandard = 10
    static let settledCycle = 21          // then a repeating 20:1, indefinitely
    static let settledStandard = 20

    /// How many un-checked cards have to pile up at the end of the course before
    /// the programme dips back into Standard. Exactly one settled run's worth of
    /// Standard slots, so a batch is worked through in one cycle rather than
    /// running dry a few cards in.
    static let refillTarget = settledStandard

    // MARK: - State

    /// Everything that has to survive a hard close, in one `Codable` blob under
    /// `storageKey`.
    ///
    /// All of it is invisible to the learner by design — a visible countdown
    /// would turn the programme into a score to game, and people would grind
    /// cards to trip it rather than study.
    private struct State: Codable {
        /// The chapter the countdown is watching: the newest one the tour added,
        /// or the furthest one the learner selected.
        ///
        /// Not the same as the pool — see the "two counts" note in the file
        /// header. Nil only before the tour has ever been seeded.
        var chapterId: String?

        /// True while a move is being counted down. Set when the current chapter
        /// thins past the threshold, cleared if it thickens again (a Needs Work
        /// un-checks a word) or when the move lands.
        var counting = false

        /// Answers since `counting` began. Compared against `countdownTarget`.
        var countdown = 0

        /// Position in the post-move mix, counted from the move. Feeds `Phase`.
        /// Only meaningful once `hasAdvanced`.
        var cardsSinceAdvance = 0

        /// Whether the tour has ever moved chapters.
        ///
        /// The mix starts after the *first* move, not on the first chapter:
        /// until something is behind you there is nothing to review, so mixing
        /// in Priority cards would just re-show the chapter you are already on.
        var hasAdvanced = false

        /// Cards left in the post-manual-change Standard run. See
        /// `manualGraceCards` and `adoptManualSelection`.
        var manualGrace = 0

        /// The chapter selection this engine last put in place.
        ///
        /// Anything else showing up in the filter must have been the learner, so
        /// this is what `adoptManualSelection` diffs against. Nil means "not
        /// tracking yet" — adopt whatever is there without treating it as a
        /// change.
        var appliedSelection: [String]?

        /// No chapter anywhere in the course has work left. The tour has nowhere
        /// to move on to, so the schedule switches to its end-of-course loop.
        var courseComplete = false

        /// Within the end-of-course loop: true while waiting for forgotten words
        /// to pile up again, false while working through the batch that piled up.
        var refilling = false

        // Decoded field by field so that adding one doesn't throw away a
        // learner's programme: the synthesised decoder fails outright on a key
        // that isn't in an older saved blob, and the caller treats a decode
        // failure as "start over".
        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            chapterId = try c.decodeIfPresent(String.self, forKey: .chapterId)
            counting = try c.decodeIfPresent(Bool.self, forKey: .counting) ?? false
            countdown = try c.decodeIfPresent(Int.self, forKey: .countdown) ?? 0
            cardsSinceAdvance = try c.decodeIfPresent(Int.self, forKey: .cardsSinceAdvance) ?? 0
            hasAdvanced = try c.decodeIfPresent(Bool.self, forKey: .hasAdvanced) ?? false
            manualGrace = try c.decodeIfPresent(Int.self, forKey: .manualGrace) ?? 0
            appliedSelection = try c.decodeIfPresent([String].self, forKey: .appliedSelection)
            courseComplete = try c.decodeIfPresent(Bool.self, forKey: .courseComplete) ?? false
            refilling = try c.decodeIfPresent(Bool.self, forKey: .refilling) ?? false
        }
    }

    private var state = State()
    private let storageKey: String

    /// Set when the programme changes the chapter selection itself.
    ///
    /// Deliberately *not* part of `State`: it is a within-session handshake with
    /// the view, meaningless across launches. See `consumeSelfAppliedChange`.
    private var selfAppliedChange = false

    private init(storageKey: String) {
        self.storageKey = storageKey
        // A decode failure leaves the default state, which is a clean start
        // rather than a crash — worth it for something this peripheral.
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = saved
        }
    }

    /// Saves, and tells any observing view that something moved.
    ///
    /// Called on every answered card. `UserDefaults` batches its own writes, so
    /// the cost here is the JSON encode, not disk I/O.
    private func persist() {
        revision &+= 1
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Whether the last change to the chapter selection was the programme's own.
    /// **Reading it clears it.**
    ///
    /// A deck re-deals whenever the selection changes. That is right when the
    /// learner picks a chapter, and wrong when the programme adds one: there it
    /// has already dealt the next card, and dealing again would silently replace
    /// a card the learner never saw. The deck asks this before re-dealing.
    func consumeSelfAppliedChange() -> Bool {
        defer { selfAppliedChange = false }
        return selfAppliedChange
    }

    // MARK: - Driving a deck
    //
    // The four entry points a deck calls. See the integration contract in the
    // file header for the ordering rules.

    /// Call on appear. Seeds the tour on first run; otherwise adopts whatever is
    /// already selected as the set.
    ///
    /// Deliberately never *replaces* a selection. It may be the learner's, or it
    /// may be chapters this engine accumulated on a previous run — either way,
    /// throwing it away would discard study that has actually happened.
    func prepare(cards: [VocabFlashCard], filter: VocabFiltering) {
        guard StudyWeightSettings.shared.smartStudy, !cards.isEmpty else { return }

        if filter.selectedChapterIds.isEmpty {
            // Cold start: begin at the lowest chapter with work left in it.
            if let first = firstUnfinishedChapter(in: cards, filter: filter) {
                filter.selectedChapterIds = [first]
                state.chapterId = first
                selfAppliedChange = true
            }
        } else if let current = state.chapterId,
                  filter.selectedChapterIds.contains(current) {
            // Already pointing at something in play. Leave it — re-anchoring
            // here would move the countdown's target every time the deck opened.
        } else {
            // Selection exists but the anchor is stale or unset (first run with
            // a selection, or a chapter that has since gone away).
            state.chapterId = currentChapter(in: cards, filter: filter)
        }

        state.appliedSelection = filter.selectedChapterIds.sorted()
        persist()
        applyMode(cards: cards, filter: filter)
    }

    /// Call when the learner switches Smart Study off.
    ///
    /// The chapters stay. The programme only ever added them, and removing them
    /// on the way out would undo study that has actually been done. Cycle
    /// progress is kept too, so switching back on resumes rather than restarts;
    /// only the selection-tracking is dropped, so the next `prepare` adopts what
    /// it finds instead of reading it as the learner having changed something.
    func release() {
        state.appliedSelection = nil
        persist()
    }

    /// Notices the learner picking chapters themselves, and hands the set over.
    ///
    /// Both the countdown and the mix were pacing a chapter that may no longer
    /// be the one in front of them, so both are abandoned rather than carried
    /// over. Runs on every card (cheaply — it diffs a sorted array of chapter
    /// ids and returns) because there is no single place a deck's filter change
    /// can be intercepted.
    private func adoptManualSelection(cards: [VocabFlashCard], filter: VocabFiltering) {
        let current = filter.selectedChapterIds.sorted()

        // Nil means we aren't tracking yet — first call after a launch or a
        // `release`. Adopt silently; this is not a change the learner made.
        guard let applied = state.appliedSelection else {
            state.appliedSelection = current
            return
        }
        guard applied != current else { return }

        state.appliedSelection = current
        state.chapterId = currentChapter(in: cards, filter: filter)
        state.counting = false
        state.countdown = 0
        // The learner may have just added a chapter with work left in it, which
        // is precisely what "course complete" claimed there was none of. Let the
        // ordinary tour decide again rather than staying in the end-of-course
        // loop over a deck that has grown.
        state.courseComplete = false
        state.refilling = false

        // The grace only means anything once the mix is running. Before the
        // first move everything is plain Standard already, so a grace here would
        // buy nothing — and worse, it *ends* by setting `hasAdvanced`, which
        // would declare the mix started and pull Priority cards in with nothing
        // yet behind the learner to review. Pre-move is left only by earning a
        // move.
        if state.hasAdvanced { state.manualGrace = Self.manualGraceCards }
        persist()
    }

    /// Sets the app-wide mode for the card about to be dealt.
    ///
    /// **Must run before the deck reads its pool.** `WeightMode` decides whether
    /// checked-off cards are in the pool at all, so a deck that builds its pool
    /// first deals the previous card under the previous card's rules.
    ///
    /// Safe to call repeatedly: it only writes when the mode actually differs,
    /// so it won't churn `@Published` notifications.
    func applyMode(cards: [VocabFlashCard], filter: VocabFiltering) {
        guard StudyWeightSettings.shared.smartStudy else { return }
        adoptManualSelection(cards: cards, filter: filter)
        let mode = modeForNextCard(unchecked: uncheckedCount(cards: cards, filter: filter))
        if StudyWeightSettings.shared.mode != mode {
            StudyWeightSettings.shared.mode = mode
        }
    }

    /// One card answered. Confident or Needs Work makes no difference here — the
    /// programme counts cards seen, not cards got right.
    ///
    /// Returns true if this answer earned a move to a new chapter, which the
    /// deck can use to re-deal from the enlarged pool.
    @discardableResult
    func cardAnswered(cards: [VocabFlashCard], filter: VocabFiltering) -> Bool {
        guard StudyWeightSettings.shared.smartStudy else { return false }
        adoptManualSelection(cards: cards, filter: filter)
        let advanced = record(cards: cards, filter: filter)
        persist()

        // Settle the next card's mode here rather than leaving it to whenever
        // the deck next deals. The written deck delays its deal behind the
        // "Confident" animation, so the counters would move a beat before the
        // mode they imply — and in the alternating phase, a counter shown
        // against the previous card's mode reads as the two being swapped.
        // `record` has several exits, so this sits after all of them: no
        // answered card can escape it.
        applyMode(cards: cards, filter: filter)
        return advanced
    }

    /// The state transition for one answered card. Returns true if it earned a
    /// move. Split out from `cardAnswered` so that every path through it is
    /// followed by the same bookkeeping.
    private func record(cards: [VocabFlashCard], filter: VocabFiltering) -> Bool {
        // The grace run stands outside the mix entirely: it neither advances the
        // cycle nor counts toward a move. When it runs out the mix begins from
        // its first card, which is what makes 50 cards of Standard a prelude to
        // the cycle rather than a hole punched in the middle of one.
        //
        // Checked before the deck is counted, because counting the deck is the
        // expensive part of this method and the grace doesn't need it.
        if state.manualGrace > 0 {
            state.manualGrace -= 1
            if state.manualGrace == 0 {
                state.hasAdvanced = true
                state.cardsSinceAdvance = 0
            }
            return false
        }

        let unchecked = uncheckedCount(cards: cards, filter: filter)
        let threshold = Self.threshold(bothDirections: filter.direction == .random)

        state.cardsSinceAdvance += 1
        if state.counting { state.countdown += 1 }

        // End of the course: there is no next chapter, so the tour stops moving
        // and runs a loop of its own instead. Measured across the whole
        // selection rather than the current chapter — a word forgotten in
        // chapter 3 is exactly what this loop exists to bring back.
        if state.courseComplete {
            let pile = uncheckedInSelection(cards: cards, filter: filter)
            if state.refilling {
                if pile >= Self.refillTarget {
                    // A batch is due. Before running it, check once whether the
                    // course really is still finished: a content update can add
                    // chapters, and this is the one cheap moment to notice —
                    // once per batch rather than once per card.
                    if advanceChapter(cards: cards, filter: filter) { return true }
                    state.refilling = false
                    // Start the batch at the top of a settled cycle, so it opens
                    // with its twenty Standard cards rather than partway through.
                    state.cardsSinceAdvance = 0
                }
            } else if pile == 0 {
                state.refilling = true
            }
            return false
        }

        if state.counting, unchecked >= threshold {
            // The chapter got *thicker*: marking a forgotten word Needs Work
            // unchecks it, which can push the count back over the line. That
            // word now needs clearing again, so the move is called off outright
            // rather than merely postponed — the countdown restarts from zero
            // the next time the chapter thins out.
            state.counting = false
            state.countdown = 0
        } else if !state.counting, unchecked < threshold {
            // Nearly cleared. Note the card that trips this does not itself
            // count toward the target; the countdown starts from the next one.
            state.counting = true
            state.countdown = 0
        }

        guard state.counting, state.countdown >= Self.countdownTarget else { return false }
        return advanceChapter(cards: cards, filter: filter)
    }

    /// A deck's back button. Un-counts the answer being undone, so backing out
    /// of a card can't quietly push you toward the next chapter.
    ///
    /// Only the countdown is rewound, not `cardsSinceAdvance` — the mix is about
    /// how many cards have gone past, and one of them did.
    func cardUndone() {
        guard StudyWeightSettings.shared.smartStudy, state.countdown > 0 else { return }
        state.countdown -= 1
        persist()
    }

    /// Cards left in the current chapter that trips the countdown, which depends
    /// on whether the deck is asking each word one way or both.
    static func threshold(bothDirections: Bool) -> Int {
        bothDirections ? startThresholdBothDirections : startThreshold
    }

    // MARK: - The schedule

    /// Which mode the next card should be dealt under, given where the programme
    /// currently stands. A thin wrapper that feeds `state` to the pure function.
    func modeForNextCard(unchecked: Int) -> WeightMode {
        Self.scheduledMode(cardsSinceAdvance: state.cardsSinceAdvance,
                           hasAdvanced: state.hasAdvanced,
                           counting: state.counting,
                           unchecked: unchecked,
                           manualGrace: state.manualGrace,
                           courseComplete: state.courseComplete,
                           refilling: state.refilling)
    }

    // BEGIN-SCHEDULE (extracted verbatim by the schedule test — see the file
    // header. Everything between the markers must stay free of state, storage
    // and app types other than `WeightMode`.)

    /// Where the programme is in its cycle.
    ///
    /// Named rather than numbered: "stage 2" says nothing, and this gets read
    /// off a card mid-session. The associated value is always the position
    /// *within* that phase, counted from its first card — not the absolute card
    /// count, which is `State.cardsSinceAdvance`.
    enum Phase: Equatable {
        /// The tour has never moved chapters, so nothing is behind the learner
        /// and there is nothing to review. Runs as plain Standard throughout.
        case preMove
        /// The learner chose the chapters themselves. The mix stands down for
        /// `manualGraceCards` and lets them clear some of it first.
        case grace(left: Int)
        /// Straight after a move, when the chapter just left is freshest and
        /// most fragile: every other card looks back at it.
        case alternating(n: Int)
        /// Review thinning out as the old chapter settles — ten forward, five
        /// back, repeating.
        case tapering(n: Int)
        /// The long run: one backward glance every twenty-one cards, for as long
        /// as the learner stays on this chapter.
        case upkeep(n: Int)
        /// The course is finished — every chapter cleared, nothing left to move
        /// on to. Standard can only deal words that have since been un-checked,
        /// so the programme waits on the Priority side while a batch of them
        /// piles up (`refilling`), then runs the settled mix over that batch.
        case finished(refilling: Bool, n: Int)

        /// Compact description for the debug readout. The trailing ratio is
        /// Standard : Priority Study, so the mix can be read without having to
        /// remember what each phase does.
        var label: String {
            switch self {
            case .preMove:
                return "pre-move"
            case .grace(let left):
                return "grace \(left)"
            case .alternating(let n):
                return "alternating \(n)/\(alternatingCards) (1:1)"
            case .tapering(let n):
                return "tapering \(n)/\(taperCards)"
                    + " (\(taperStandard):\(taperCycle - taperStandard))"
            case .upkeep(let n):
                return "upkeep \(n % settledCycle)/\(settledCycle) (\(settledStandard):1)"
            case .finished(let refilling, let n):
                return refilling
                    ? "finished · refilling (priority only)"
                    : "finished · batch \(n % settledCycle)/\(settledCycle) (\(settledStandard):1)"
            }
        }
    }

    /// The one place the phase is worked out.
    ///
    /// Both the mode the deck deals and the readout drawn on the card come from
    /// here. Deriving the phase in two places is exactly how a readout ends up
    /// quietly disagreeing with the deck it claims to describe.
    static func phase(cardsSinceAdvance n: Int, hasAdvanced: Bool,
                      manualGrace: Int,
                      courseComplete: Bool = false, refilling: Bool = false) -> Phase {
        if manualGrace > 0 { return .grace(left: manualGrace) }
        // Outranks the ordinary cycle: with nothing left to move on to, the
        // phases that exist to pace a move through new material no longer mean
        // anything.
        if courseComplete { return .finished(refilling: refilling, n: n) }
        guard hasAdvanced else { return .preMove }
        if n < alternatingCards { return .alternating(n: n) }
        if n < alternatingCards + taperCards {
            return .tapering(n: n - alternatingCards)
        }
        return .upkeep(n: n - alternatingCards - taperCards)
    }

    /// The schedule itself, as a pure function of where the programme stands.
    ///
    /// Two overrides sit above the phase mix, and their order matters:
    /// grace beats starvation beats the mix.
    static func scheduledMode(cardsSinceAdvance n: Int, hasAdvanced: Bool,
                              counting: Bool, unchecked: Int,
                              manualGrace: Int = 0,
                              courseComplete: Bool = false,
                              refilling: Bool = false) -> WeightMode {
        let phase = phase(cardsSinceAdvance: n, hasAdvanced: hasAdvanced,
                          manualGrace: manualGrace,
                          courseComplete: courseComplete, refilling: refilling)

        // A chapter the learner chose themselves is theirs to clear first. This
        // outranks even the starvation override below — they asked for this
        // material, so give them all of it before mixing anything else in.
        if case .grace = phase { return .none }

        // Running dry mid-countdown: Standard has nothing left to show, so the
        // remainder of the wait is served from the full deck. Applies in
        // pre-move too, where the very first chapter can be worked to the bone
        // before any move has happened.
        if counting, unchecked < starvedThreshold { return .needsWork }

        switch phase {
        case .grace, .preMove:
            return .none
        case .alternating(let n):
            return n.isMultiple(of: 2) ? .none : .needsWork
        case .tapering(let n):
            return n % taperCycle < taperStandard ? .none : .needsWork
        case .upkeep(let n):
            return n % settledCycle < settledStandard ? .none : .needsWork
        case .finished(let refilling, let n):
            // Nothing new is left to clear, so Standard would deal from an empty
            // pile. Stay on the Priority side until a full batch of forgotten
            // words has been marked, then run the settled mix over that batch
            // until it is cleared and the wait starts again.
            if refilling { return .needsWork }
            return n % settledCycle < settledStandard ? .none : .needsWork
        }
    }
    // END-SCHEDULE

    /// Moves the tour on to the next chapter with work left. Returns false if
    /// there was nowhere to go.
    private func advanceChapter(cards: [VocabFlashCard], filter: VocabFiltering) -> Bool {
        let remaining = unclearedByChapter(cards, filter: filter)
        let order = chapterOrder(in: cards)

        // Anchor on the furthest chapter actually in play, not on `chapterId`.
        // After a manual multi-chapter selection those differ: the learner's
        // furthest pick is where the tour should continue from, rather than
        // whichever chapter the programme happened to be on before they
        // intervened.
        let selected = filter.selectedChapterIds
        let anchor = order.last { selected.contains($0) } ?? state.chapterId

        guard let next = nextChapter(after: anchor, order: order, remaining: remaining) else {
            // Nothing unfinished left anywhere in the course. Stand the
            // countdown down rather than leaving it at target: otherwise every
            // subsequent card re-runs this whole search and reports a move that
            // never happens.
            state.counting = false
            state.countdown = 0
            // Hand over to the end-of-course loop, starting on the Priority side:
            // everything is checked, so Standard has nothing it could deal.
            state.courseComplete = true
            state.refilling = true
            return false
        }

        state.chapterId = next
        state.counting = false
        state.countdown = 0
        state.cardsSinceAdvance = 0   // the mix restarts from its first card
        state.hasAdvanced = true
        // There was somewhere to go after all — new chapters can arrive with an
        // update, or the learner can select one the tour hasn't reached.
        state.courseComplete = false
        state.refilling = false
        addChapter(next, filter: filter)
        return true
    }

    // MARK: - Reading the deck
    //
    // Everything below is read-only against the card list and the checkmark
    // store, except `addChapter`. Several of these run on every card or every
    // render, so they are written as single passes that allocate nothing.

    /// Adds a chapter to the set. **Only ever adds.**
    ///
    /// The deck grows as the tour goes on, which is what keeps older chapters in
    /// the rotation to be met again on the Priority Study cards the mix deals.
    private func addChapter(_ chapterId: String, filter: VocabFiltering) {
        filter.selectedChapterIds.insert(chapterId)
        // Record it as the programme's own doing on both channels: the diff in
        // `adoptManualSelection`, so it isn't read as the learner intervening,
        // and the view handshake, so the deck doesn't re-deal on top of the card
        // this move is about to produce.
        state.appliedSelection = filter.selectedChapterIds.sorted()
        selfAppliedChange = true
    }

    /// The furthest-along selected chapter in course order — the newest material
    /// in play, and so the one "nearly cleared" should be about.
    private func currentChapter(in cards: [VocabFlashCard], filter: VocabFiltering) -> String? {
        let selected = filter.selectedChapterIds
        return chapterOrder(in: cards).last { selected.contains($0) }
    }

    /// Cards still to clear in the current chapter — the quantity the countdown
    /// threshold is compared against.
    ///
    /// Counted in *cards*, not words. In Both mode a word is two cards, and
    /// knowing one direction takes exactly one card off the total, leaving the
    /// other still to earn. That is also why `startThresholdBothDirections` is
    /// the larger number: the same chapter is twice the work.
    private func uncheckedCount(cards: [VocabFlashCard], filter: VocabFiltering) -> Int {
        let store = VocabFlashcardsFilter.shared
        let direction = filter.direction
        var total = 0

        if let chapterId = state.chapterId {
            for card in cards where card.chapterId == chapterId {
                total += Self.unclearedSlots(card.word.id, store: store, direction: direction)
            }
            return total
        }

        // No current chapter yet. Counting the whole selection is a poor
        // substitute, but returning zero would read as "chapter cleared", start
        // a countdown against nothing, and then starve into permanent Priority
        // Study — a much worse failure than a slightly wrong number.
        return uncheckedInSelection(cards: cards, filter: filter)
    }

    /// Un-checked cards across every selected chapter, in the same card units as
    /// `uncheckedCount`. What the end-of-course loop weighs: once the tour has
    /// nowhere left to move, "the chapter" stops being the meaningful unit and
    /// the whole deck is the pile.
    private func uncheckedInSelection(cards: [VocabFlashCard], filter: VocabFiltering) -> Int {
        let store = VocabFlashcardsFilter.shared
        let direction = filter.direction
        let ids = filter.selectedChapterIds
        var total = 0
        for card in cards where ids.isEmpty || ids.contains(card.chapterId) {
            total += Self.unclearedSlots(card.word.id, store: store, direction: direction)
        }
        return total
    }

    /// How much of the whole set is cleared, in the same card units — so a word
    /// checked off one way in a two-way run counts as the half it is.
    ///
    /// Exists because the deck's own counter can't be used under Smart Study: it
    /// hides itself whenever the mode isn't Standard, and the programme moves in
    /// and out of Standard constantly, so the count would blink away every few
    /// cards. See `DeckProgressCount`.
    ///
    /// Called from a SwiftUI computed property, so it runs on **every render** of
    /// the deck — hence one pass, no intermediate arrays.
    func progress(cards: [VocabFlashCard], filter: VocabFiltering) -> (done: Int, total: Int)? {
        let store = VocabFlashcardsFilter.shared
        let direction = filter.direction
        let perCard = direction == .random ? 2 : 1
        let ids = filter.selectedChapterIds
        var total = 0
        var left = 0
        for card in cards where ids.isEmpty || ids.contains(card.chapterId) {
            total += perCard
            left += Self.unclearedSlots(card.word.id, store: store, direction: direction)
        }
        guard total > 0 else { return nil }
        return (total - left, total)
    }

    /// How many cards this one word still owes: 0, 1, or — in Both mode, when
    /// neither direction is checked — 2.
    ///
    /// Note it reads `VocabFlashcardsFilter.shared` rather than the filter it
    /// was handed. Checkmarks are shared by both decks and live only on that
    /// store; the per-deck filter supplies the *direction*, not the marks.
    /// Static and store-injected so callers can hoist the lookup out of a loop.
    private static func unclearedSlots(_ wordId: String, store: VocabFlashcardsFilter,
                                       direction: CardDirection) -> Int {
        guard direction == .random else {
            return store.isExcluded(wordId, direction: direction) ? 0 : 1
        }
        var slots = 0
        if !store.isExcluded(wordId, direction: .japaneseToEnglish) { slots += 1 }
        if !store.isExcluded(wordId, direction: .englishToJapanese) { slots += 1 }
        return slots
    }

    /// Cards left to clear per chapter, in one pass. Finished chapters are
    /// simply absent, so `remaining[id] != nil` reads as "still has work".
    ///
    /// Asking "is this chapter done?" one chapter at a time means a full sweep
    /// of ~2,000 cards for each of ~58 chapters. This answers all of them at
    /// once, and is only built when the tour actually moves.
    private func unclearedByChapter(_ cards: [VocabFlashCard],
                                    filter: VocabFiltering) -> [String: Int] {
        let store = VocabFlashcardsFilter.shared
        let direction = filter.direction
        var remaining: [String: Int] = [:]
        remaining.reserveCapacity(64)
        for card in cards {
            let slots = Self.unclearedSlots(card.word.id, store: store, direction: direction)
            if slots > 0 { remaining[card.chapterId, default: 0] += slots }
        }
        return remaining
    }

    /// Chapter ids in course order, restricted to chapters actually present in
    /// `cards`.
    ///
    /// Read from the manifest rather than from the card array, because the
    /// written deck shuffles its cards — "the lowest chapter you haven't
    /// finished" has to mean the syllabus's order, not the deal's.
    private func chapterOrder(in cards: [VocabFlashCard]) -> [String] {
        let present = Set(cards.map(\.chapterId))
        LessonsService.shared.loadIfNeeded()
        let ordered = LessonsService.shared.manifest?.levels
            .flatMap { $0.chapters.map(\.id) } ?? []
        return ordered.filter(present.contains)
    }

    /// Where a cold start begins: the earliest chapter in the course with any
    /// work left in it.
    private func firstUnfinishedChapter(in cards: [VocabFlashCard],
                                        filter: VocabFiltering) -> String? {
        let remaining = unclearedByChapter(cards, filter: filter)
        return chapterOrder(in: cards).first { remaining[$0] != nil }
    }

    /// The next chapter with work left, scanning forward from `current` and
    /// wrapping around the end of the course.
    ///
    /// Wrapping matters late on, where everything ahead is finished but
    /// stragglers remain behind. Returns nil only when nothing anywhere is
    /// unfinished — which `advanceChapter` treats as the end of the tour.
    private func nextChapter(after current: String?, order: [String],
                             remaining: [String: Int]) -> String? {
        guard !order.isEmpty else { return nil }
        // Unknown or absent anchor: fall back to the earliest unfinished one.
        guard let current, let start = order.firstIndex(of: current) else {
            return order.first { remaining[$0] != nil }
        }
        for offset in 1...order.count {
            let candidate = order[(start + offset) % order.count]
            if remaining[candidate] != nil { return candidate }
        }
        return nil
    }

    // MARK: - Debug readout
    //
    // The only part of the engine that exposes its state, and the only reason
    // any of it is reachable from outside. Feeds `SmartStudyDebugOverlay`, which
    // is switched off in shipping builds — see `SmartStudyDebugOverlay.isEnabled`
    // to turn it back on. Kept rather than deleted because the programme is
    // otherwise invisible by design, so there is no other way to watch a
    // countdown run or check which phase a session is in.

    /// One line per fact, shortest first, for the overlay pinned to the corner
    /// of a card. Deliberately terse — it has to fit beside the deck.
    func debugLines(cards: [VocabFlashCard], filter: VocabFiltering) -> [String] {
        let both = filter.direction == .random
        let set = progress(cards: cards, filter: filter) ?? (done: 0, total: 0)
        let cardsLeft = uncheckedCount(cards: cards, filter: filter)
        let phase = Self.phase(cardsSinceAdvance: state.cardsSinceAdvance,
                               hasAdvanced: state.hasAdvanced,
                               manualGrace: state.manualGrace,
                               courseComplete: state.courseComplete,
                               refilling: state.refilling)
        let chapters = filter.selectedChapterIds.sorted()

        return [
            // Proof the readout is live: if this stops moving, the view isn't
            // observing the engine.
            "rev \(revision)",
            "set " + (chapters.isEmpty ? "(all)" : chapters.joined(separator: ",")),
            "cur \(state.chapterId ?? "-")  cards left \(cardsLeft)",
            "thr \(Self.threshold(bothDirections: both))\(both ? " (2-way)" : "")",
            "set done \(set.done)/\(set.total)",
            phase.label,
            "cd \(state.counting ? "ON" : "off") \(state.countdown)/\(Self.countdownTarget)",
            "n \(state.cardsSinceAdvance)  moved \(state.hasAdvanced ? "y" : "n")",
            state.courseComplete
                ? "pile \(uncheckedInSelection(cards: cards, filter: filter))/\(Self.refillTarget)"
                : "pile -",
            "mode \(StudyWeightSettings.shared.mode.displayName)",
        ]
    }
}
