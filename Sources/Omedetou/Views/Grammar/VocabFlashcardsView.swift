import SwiftUI

/// Identifies a chapter when the vocab flashcards are opened from a lesson's
/// "Study Vocab" button — the pool auto-filters to just that chapter's words.
struct LockedVocabChapter {
    let id: String
    let number: Int
    let title: String
    let accent: Color
}

struct VocabFlashcardsView: View {
    /// When set, this is a chapter's "Study Vocab" session (pool locked to the
    /// chapter). When nil, it's the global Study-section vocab flashcards.
    var lockedChapter: LockedVocabChapter? = nil

    /// When provided (custom lessons), the locked pool is built from these exact
    /// words instead of loading a chapter's vocab. Requires `lockedChapter` too,
    /// which supplies the title/accent.
    var lockedWords: [LessonVocabWord]? = nil

    @ObservedObject private var filter = VocabFlashcardsFilter.shared
    @ObservedObject private var weightSettings = StudyWeightSettings.shared
    @State private var allCards: [VocabFlashCard] = []
    @State private var current: VocabFlashCard?
    @State private var isRevealed = false
    @StateObject private var sequencer = DeckSequencer()
    @State private var isLoading = true
    @State private var showFilter = false
    /// Shows the green-check pop over the card after "Confident" is tapped.
    @State private var showConfidentPop = false
    /// Undo history for the back button — each answered card + what to reverse.
    @State private var history: [VocabStudyHistoryEntry] = []
    /// The direction the card on screen is being asked in — resolved when it's
    /// dealt, so a Random run can't flip it under the learner mid-card.
    @State private var cardDirection: CardDirection = .japaneseToEnglish
    @Namespace private var wordNS

    /// The chapter's word ids (locked mode only) — used to scope "clear checkmarks".
    private var chapterWordIds: [String] { lockedChapter == nil ? [] : allCards.map(\.word.id) }

    // MARK: - Smart Study
    //
    // This deck is one of the two `SmartStudyEngine` drives — see that file's
    // "Integration contract" for the ordering rules the calls below follow.
    //
    // Every call is guarded on `lockedChapter == nil`. A chapter-locked session
    // ("Study Vocab" from a chapter) has a pool the learner pinned deliberately,
    // and the whole point of the programme is choosing the pool for them, so it
    // stays out of those entirely — including its mode switching, which would
    // otherwise pull in words from outside the chapter they opened.

    private var pool: [VocabFlashCard] {
        if lockedChapter == nil { return filter.apply(to: allCards) }
        guard StudyWeightSettings.shared.filtersOutCheckedCards else { return allCards }
        return allCards.filter {
            filter.direction == .random ? !filter.isFullyExcluded($0.word.id)
                                        : !filter.isExcluded($0.word.id, direction: filter.direction)
        }
    }

    /// How much of this set has been checked off, for the counter on the card.
    /// Nil outside No-Priority mode, where checking a word doesn't retire it and
    /// there's no set to work through.
    private var checkedProgress: (done: Int, total: Int)? {
        if weightSettings.smartStudy, lockedChapter == nil {
            return SmartStudyEngine.written.progress(cards: allCards, filter: filter)
        }
        guard weightSettings.filtersOutCheckedCards else { return nil }
        let total = lockedChapter == nil ? filter.selection(in: allCards).count : allCards.count
        guard total > 0 else { return nil }
        return (total - pool.count, total)
    }

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    AppBackground()
                    ProgressView()
                }
                .vocabNavBar(title: "Vocab Flash Cards", filter: filter, showFilter: $showFilter, locked: lockedChapter, chapterWordIds: chapterWordIds, onAfterClear: { pickNext() })
            } else if let card = current {
                cardView(card)
            } else {
                emptyState
            }
        }
        .smartStudyDebug(SmartStudyEngine.written, cards: allCards,
                         filter: filter, topPadding: 54)
        // Draws nothing unless SmartStudyDebugOverlay.isEnabled is flipped on.
        .onAppear(perform: load)
        // A changed selection means a changed pool, so the card on screen may no
        // longer belong — except when Smart Study made the change itself, having
        // just dealt the next card. Re-dealing there would replace a card the
        // learner never got to see.
        .onChange(of: filter.selectedChapterIds) { _ in
            guard lockedChapter == nil else { return }
            guard !SmartStudyEngine.written.consumeSelfAppliedChange() else { return }
            pickNext()
        }
        .onChange(of: filter.selectedWordIds) { _ in if lockedChapter == nil { pickNext() } }
        .onChange(of: filter.showFavoritesOnly) { _ in if lockedChapter == nil { pickNext() } }
        // Smart Study rewrites the mode as part of dealing, so reacting to it
        // here would deal a second card on top of the one it just dealt. Only a
        // human flipping the switch should re-deal.
        .onChange(of: weightSettings.mode) { _ in if !weightSettings.smartStudy { pickNext() } }
        // Handing the deck to the programme, or taking it back. Either way the
        // pool changes, so re-deal.
        .onChange(of: weightSettings.smartStudy) { on in
            guard lockedChapter == nil else { return }
            if on { SmartStudyEngine.written.prepare(cards: allCards, filter: filter) }
            else { SmartStudyEngine.written.release() }
            pickNext()
        }
        .onChange(of: filter.direction) { _ in pickNext() }
        .sheet(isPresented: $showFilter) {
            VocabFilterSheet(filter: filter, allCards: allCards)
        }
    }

    // MARK: - Card

    private func cardView(_ card: VocabFlashCard) -> some View {
        let isFav = filter.isFavorite(card.word.id)

        let reversed = cardDirection.isReversed

        // The prompt: shared by both faces so it slides between them. Going the
        // other way it's the meaning that leads and the Japanese that's hidden.
        let wordBlock = VStack(spacing: 10) {
            Text(card.word.partOfSpeech)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(card.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(card.accentColor.opacity(0.12))
                .cornerRadius(6)

            if reversed {
                // Set smaller than the Japanese: a definition is a phrase, and
                // 48pt turns "to be in time for" into three lines.
                Text(card.word.definition)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(card.word.kanji)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)

                if card.word.kanji != card.word.kana {
                    Text(card.word.kana)
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .matchedGeometryEffect(id: "word", in: wordNS)

        return ZStack(alignment: .bottom) {
            AppBackground()

            VStack(spacing: 0) {
                // Fixed top bar: favorite and audio (stay put while the word slides)
                HStack {
                    Button {
                        filter.toggleFavorite(card.word.id)
                        FeedbackSounds.shared.playFavorite(filter.isFavorite(card.word.id))
                    } label: {
                        Image(systemName: isFav ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundColor(isFav ? .yellow : Color.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    // Speak the kana, which is the word's authoritative reading.
                    // Hidden before the reveal when the Japanese *is* the answer —
                    // otherwise the card reads itself out.
                    if !reversed || isRevealed {
                        SpeakButton(text: card.word.kana, size: 24, tint: card.accentColor)
                    }
                }
                .deckProgress(checkedProgress)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if isRevealed {
                    ScrollView {
                        VStack(spacing: 20) {
                            wordBlock
                                .padding(.top, 8)

                            // Answer box — whichever half wasn't the prompt.
                            VStack(alignment: .leading, spacing: 6) {
                                if reversed {
                                    Text(card.word.kanji)
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.appText)
                                    if card.word.kanji != card.word.kana {
                                        Text(card.word.kana)
                                            .font(.system(size: 17))
                                            .foregroundColor(.appText)
                                    }
                                    Text(card.word.romaji)
                                        .font(.system(size: 14))
                                        .foregroundColor(card.accentColor)
                                        .italic()
                                } else {
                                    Text(card.word.romaji)
                                        .font(.system(size: 14))
                                        .foregroundColor(card.accentColor)
                                        .italic()
                                    Text(card.word.definition)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.appText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(card.accentColor.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal, 24)
                            .transition(.opacity.animation(.easeIn(duration: 0.3).delay(0.2)))

                            // Chapter
                            Text("ch\(String(format: "%02d", card.chapterNumber))  \(card.chapterTitle)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(card.accentColor)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .transition(.opacity.animation(.easeIn(duration: 0.3).delay(0.2)))

                            Spacer().frame(height: 90)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer()

                        wordBlock

                        Spacer()

                        CheckButton {
                            // Turning the card over is neither right nor wrong, so it
                            // gets the neutral tone rather than a verdict cue.
                            FeedbackSounds.shared.play(.notification)
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                                isRevealed = true
                            }
                        }
                        .offset(y: -56)
                        .transition(.opacity)

                        Spacer()
                        Spacer().frame(height: 88)
                    }
                }
            }

            // Bottom bar: Needs Work / back / Confident
            HStack(spacing: 12) {
                Button {
                    FeedbackSounds.shared.play(.incorrect)
                    let didUncheck = filter.markNeedsWork(card.word.id, direction: cardDirection)
                    history.append(VocabStudyHistoryEntry(card: card, direction: cardDirection,
                                                         action: .needsWork(didUncheck: didUncheck)))
                    // Counted before the next deal, and never mind the verdict:
                    // the programme tracks cards seen, not cards got right.
                    if lockedChapter == nil {
                        SmartStudyEngine.written.cardAnswered(cards: allCards, filter: filter)
                    }
                    pickNext()
                } label: {
                    Text("Needs Work")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.badgeGradient)
                                .shadow(color: Color.red.opacity(0.30), radius: 6, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)

                Button { goBack() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appText)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.appSurfaceHigh))
                        .overlay(Circle().strokeBorder(Color.appHairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(history.isEmpty || showConfidentPop)
                .opacity(history.isEmpty ? 0.35 : 1)

                Button { confirmConfident(card) } label: {
                    Text("Confident")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.green.badgeGradient)
                                .shadow(color: Color.green.opacity(0.30), radius: 6, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackgroundEnd.ignoresSafeArea(edges: .bottom))

            // Green-check pop shown briefly when "Confident" is tapped
            if showConfidentPop {
                ConfidentCheckPop()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // The title would otherwise print the answer above a card that is asking
        // for it. Only safe to show once the card is turned over.
        .vocabNavBar(title: (reversed && !isRevealed) ? "Vocab Flash Cards" : card.word.kanji,
                     filter: filter, showFilter: $showFilter, locked: lockedChapter, chapterWordIds: chapterWordIds, onAfterClear: { pickNext() })
    }

    // MARK: - Empty

    private var emptyState: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "rectangle.stack.badge.minus")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No words match\nthe current filters.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                if filter.hasActiveFilter {
                    Button("Clear Filters") { filter.reset() }
                        .padding(.top, 4)
                }
                Spacer()
            }
        }
        .vocabNavBar(title: "Vocab Flash Cards", filter: filter, showFilter: $showFilter, locked: lockedChapter, chapterWordIds: chapterWordIds, onAfterClear: { pickNext() })
    }

    // MARK: - Data

    private func load() {
        guard isLoading else { return }
        LessonsService.shared.loadIfNeeded()

        // Chapter (or custom-lesson) "Study Vocab": pool is locked to a fixed set.
        if let locked = lockedChapter {
            let words = lockedWords ?? (LessonsService.shared.loadChapter(locked.id)?.vocab ?? [])
            allCards = words.map { word in
                VocabFlashCard(word: word, chapterId: locked.id, chapterNumber: locked.number,
                               chapterTitle: locked.title, accentColor: locked.accent)
            }.shuffled()
            isLoading = false
            pickNext()
            return
        }

        // Shared with the vocal flashcards, so both decks are provably the same
        // set of words.
        allCards = VocabDeck.allCards().shuffled()
        sequencer.reset()
        isLoading = false
        syncCompletedChapters()
        // Seeds the tour on a cold start, or adopts the chapters already
        // selected. No-op unless Smart Study is switched on.
        SmartStudyEngine.written.prepare(cards: allCards, filter: filter)
        pickNext()
    }

    /// Auto-selects the chapter filter for any lesson whose grammar points are all
    /// checked complete. One-way: lessons drive the filter, never the reverse.
    private func syncCompletedChapters() {
        guard let manifest = LessonsService.shared.manifest else { return }
        let store = LessonsProgressStore.shared
        let chaptersWithVocab = Set(allCards.map(\.chapterId))
        var completed: Set<String> = []
        for level in manifest.levels {
            for ch in level.chapters where chaptersWithVocab.contains(ch.id) {
                let pointIds = LessonsService.shared.pointIds(for: ch.id)
                if !pointIds.isEmpty && store.completedCount(chapterId: ch.id, among: pointIds) == pointIds.count {
                    completed.insert(ch.id)
                }
            }
        }
        filter.syncCompletedChapters(completed)
    }

    private func pickNext() {
        // Before `pool`, never after: the mode decides whether checked-off cards
        // are in the pool at all.
        if lockedChapter == nil {
            SmartStudyEngine.written.applyMode(cards: allCards, filter: filter)
        }
        let p = pool
        guard !p.isEmpty else { current = nil; return }
        isRevealed = false
        current = filter.selectNext(from: p, using: sequencer)
        if let picked = current {
            cardDirection = filter.resolvedDirection(for: picked.word.id)
        }
    }

    /// "Confident" activates the word's checkmark (excludes it from the lineup),
    /// pops a green check over the card, then advances to the next card.
    private func confirmConfident(_ card: VocabFlashCard) {
        guard !showConfidentPop else { return }
        // Same shuffled piano sting the audio flashcards answer a correct card with.
        FeedbackSounds.shared.playCorrectVariation()
        filter.markConfident(card.word.id)
        let wasChecked = filter.isExcluded(card.word.id, direction: cardDirection)
        if !wasChecked { filter.toggleExcluded(card.word.id, direction: cardDirection) }
        history.append(VocabStudyHistoryEntry(card: card, direction: cardDirection,
                                             action: .confident(didCheck: !wasChecked)))
        // Counted now rather than inside the delayed block below, so leaving the
        // deck mid-animation can't lose the card. `cardAnswered` settles the
        // next card's mode itself, so the readout stays consistent across the
        // 0.55s the green check is on screen.
        if lockedChapter == nil {
            SmartStudyEngine.written.cardAnswered(cards: allCards, filter: filter)
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { showConfidentPop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.2)) { showConfidentPop = false }
            pickNext()
        }
    }

    /// Back button: return to the previous card and undo the answer given on it.
    private func goBack() {
        guard let last = history.popLast() else { return }
        switch last.action {
        case .needsWork(let didUncheck):
            filter.unmarkNeedsWork(last.card.word.id)
            if didUncheck { filter.toggleExcluded(last.card.word.id, direction: last.direction) }
        case .confident(let didCheck):
            filter.unmarkConfident(last.card.word.id)
            if didCheck { filter.toggleExcluded(last.card.word.id, direction: last.direction) }
        }
        isRevealed = false
        current = last.card
        cardDirection = last.direction
        // Un-count the answer being undone, so backing out can't quietly push
        // the learner toward the next chapter.
        if lockedChapter == nil { SmartStudyEngine.written.cardUndone() }
        // So the next draw doesn't hand back the card we just returned to.
        sequencer.note(last.card.word.id)
    }
}

// MARK: - Back-button undo history

private enum VocabStudyAction {
    case needsWork(didUncheck: Bool)
    case confident(didCheck: Bool)
}

private struct VocabStudyHistoryEntry {
    let card: VocabFlashCard
    let direction: CardDirection
    let action: VocabStudyAction
}

// MARK: - Filter Sheet

/// Shared with the vocal flashcards: generic over the filter so each deck can
/// carry its own selections through one identical sheet.
struct VocabFilterSheet<F: ObservableObject & VocabFiltering>: View {
    @ObservedObject var filter: F
    @ObservedObject private var weightSettings = StudyWeightSettings.shared
    let allCards: [VocabFlashCard]
    /// Set by the vocal deck: one tap adopts the written flashcards' selections.
    var copyFromFlashcards: (() -> Void)? = nil
    /// Set by the audio deck. Its answer window is a property of a spoken
    /// session, so it belongs in that deck's own options rather than in the
    /// app-wide sheet where it used to sit — nothing about it applies to the
    /// written cards.
    var showsAudioOptions: Bool = false
    @ObservedObject private var vocalSettings = VocalStudySettings.shared
    @Environment(\.dismiss) private var dismiss

    private var manifest: LessonManifest? { LessonsService.shared.manifest }

    // Only chapters that actually have vocab cards (kana chapters have none).
    private var chapterIdsWithCards: Set<String> { Set(allCards.map(\.chapterId)) }

    private var levelsWithVocab: [LessonLevel] {
        (manifest?.levels ?? []).filter { level in
            level.chapters.contains { chapterIdsWithCards.contains($0.id) }
        }
    }

    private var wordsInSelection: [VocabFlashCard] {
        guard !filter.selectedChapterIds.isEmpty else { return allCards }
        return allCards.filter { filter.selectedChapterIds.contains($0.chapterId) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let copy = copyFromFlashcards {
                        Button {
                            copy()
                        } label: {
                            Label("Copy from Flash Card Filters", systemImage: "doc.on.doc")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.readableOnPage(.appAccent))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.appSurfaceHigh))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.appHairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }

                    if showsAudioOptions {
                        VoiceSpeedSlider(showsHeading: true)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Time to answer")
                                .font(.headline)
                                .foregroundColor(.appText)
                            HStack {
                                Text("\(Int(vocalSettings.answerSeconds)) seconds")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.appText)
                                    .monospacedDigit()
                                Spacer()
                            }
                            Slider(value: $vocalSettings.answerSeconds,
                                   in: VocalStudySettings.secondsRange,
                                   step: 1)
                                .tint(.appAccent)
                            Text("How long the microphone stays open after each word is read out. Answering early moves straight on, so a longer window only costs you when you're stuck.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Direction")
                            .font(.headline)
                            .foregroundColor(.appText)
                        Picker("", selection: $filter.direction) {
                            ForEach(CardDirection.allCases, id: \.self) { direction in
                                Text(direction.displayName).tag(direction)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text({
                            switch filter.direction {
                            case .japaneseToEnglish:
                                return "You're shown the Japanese and recall the meaning."
                            case .englishToJapanese:
                                return "You're shown the meaning and recall the Japanese."
                            case .random:
                                return "Both ways, favouring the half you haven't checked off."
                            }
                        }())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    // Favorites
                    Toggle(isOn: $filter.showFavoritesOnly) {
                        Label("Favorites Only", systemImage: "star.fill")
                            .foregroundColor(.appText)
                    }
                    .tint(.yellow)

                    Divider()

                    weightedSection

                    Divider()

                    checkmarksSection

                    Divider()

                    if weightSettings.smartStudy {
                        Label(StudyPriorityCopy.smartOwnsPool, systemImage: "wand.and.stars")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    chaptersSection

                    if !filter.selectedChapterIds.isEmpty {
                        Divider()
                        wordsSection
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") { filter.reset() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { FeedbackSounds.shared.playNavigate(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color.appNavBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Weighted shuffle

    private var weightedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Priority")
                .font(.headline)
                .foregroundColor(.appText)

            WeightPrioritySection()

            Button { filter.clearWeights() } label: {
                Text("Reset Study Weights")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Checkmarks

    private var checkmarksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Checkmarks")
                .font(.headline)
                .foregroundColor(.appText)
            Text("In Standard mode, checked-off words are hidden from the flashcard lineup (here and in their chapter). In Priority Study they stay in rotation.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button { filter.clearExclusions() } label: {
                Text("Clear All Vocab Checkmarks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Chapters (grid of CH# squares)

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chapters")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                Text(filter.selectedChapterIds.isEmpty ? "All shown"
                                                       : "\(filter.selectedChapterIds.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(levelsWithVocab, id: \.levelId) { level in
                levelBlock(level)
            }
        }
    }

    private func levelBlock(_ level: LessonLevel) -> some View {
        let color = levelAccentColor(level.levelId)
        let chapters = level.chapters.filter { chapterIdsWithCards.contains($0.id) }
        let allSelected = chapters.allSatisfy { filter.selectedChapterIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(levelName(jlpt: level.levelId))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Button(allSelected ? "Deselect All" : "Select All") {
                    for c in chapters {
                        if allSelected { filter.selectedChapterIds.remove(c.id) }
                        else { filter.selectedChapterIds.insert(c.id) }
                    }
                    filter.selectedWordIds = []
                }
                .font(.caption)
                .foregroundColor(color)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                ForEach(chapters) { summary in
                    ChapterSquare(
                        number: summary.chapterNumber,
                        color: color,
                        selected: filter.selectedChapterIds.contains(summary.id)
                    ) {
                        if filter.selectedChapterIds.contains(summary.id) {
                            filter.selectedChapterIds.remove(summary.id)
                        } else {
                            filter.selectedChapterIds.insert(summary.id)
                        }
                        filter.selectedWordIds = []
                    }
                }
            }
        }
    }

    // MARK: - Words

    private var wordsSection: some View {
        let words = wordsInSelection
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Words")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                if !filter.selectedWordIds.isEmpty {
                    Button("Show All") { filter.selectedWordIds = [] }
                        .font(.caption)
                }
            }

            if words.count > 60 {
                Text("Select 5 or fewer chapters to filter individual words (\(words.count) words in current selection).")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(words) { card in
                    let selected = filter.selectedWordIds.isEmpty
                        || filter.selectedWordIds.contains(card.word.id)
                    Button {
                        toggleWord(card.word.id, in: words)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(card.word.kanji)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.appText)
                                    if card.word.kanji != card.word.kana {
                                        Text(card.word.kana)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text(card.word.definition)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(card.accentColor)
                            }
                        }
                        .opacity(selected ? 1 : 0.4)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private func toggleWord(_ wordId: String, in pool: [VocabFlashCard]) {
        if filter.selectedWordIds.isEmpty {
            // All currently shown; start excluding this one
            filter.selectedWordIds = Set(pool.map(\.word.id)).subtracting([wordId])
        } else if filter.selectedWordIds.contains(wordId) {
            filter.selectedWordIds.remove(wordId)
            if filter.selectedWordIds.isEmpty {
                // All deselected — reset to "all"
                filter.selectedWordIds = Set(pool.map(\.word.id))
            }
        } else {
            filter.selectedWordIds.insert(wordId)
        }
    }
}

// MARK: - Chapter square

/// A numbered chapter tile in a filter's chapter grid. Shared by the vocab
/// filter sheet and the kanji options sheet so the two pick chapters alike.
struct ChapterSquare: View {
    let number: Int
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10)
                .fill(selected ? color : Color.clear)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(selected ? 0 : 0.55), lineWidth: 1.5)
                )
                .overlay(
                    Text("CH\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selected ? .white : color)
                        .minimumScaleFactor(0.7)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nav bar modifier

private struct VocabNavBar: ViewModifier {
    let title: String
    @ObservedObject var filter: VocabFlashcardsFilter
    @Binding var showFilter: Bool
    /// nil for the global Study section; set for a chapter's Study Vocab session.
    let locked: LockedVocabChapter?
    let chapterWordIds: [String]
    let onAfterClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.appNavBarText)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appNavBarText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if locked != nil {
                        Menu {
                            // Chapter study is the written deck scoped to one
                            // chapter, so it shares that deck's direction — the
                            // filter sheet just isn't reachable from here, which
                            // left the setting applied but unchangeable.
                            Picker("Direction", selection: $filter.direction) {
                                ForEach(CardDirection.allCases, id: \.self) { direction in
                                    Text(direction.displayName).tag(direction)
                                }
                            }
                            Divider()
                            WeightPriorityMenuItems()
                            Divider()
                            Button(role: .destructive) {
                                filter.clearExclusions(for: chapterWordIds)
                                onAfterClear()
                            } label: {
                                Label("Clear Checkmarks (This Chapter)", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.appNavBarText)
                        }
                    } else {
                        Button {
                            showFilter = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .foregroundColor(.appNavBarText)
                                if filter.hasActiveFilter {
                                    Circle()
                                        .fill(Color.yellow)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                }
            }
            .toolbarBackground(Color.appNavBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private extension View {
    func vocabNavBar(title: String, filter: VocabFlashcardsFilter, showFilter: Binding<Bool>,
                     locked: LockedVocabChapter?, chapterWordIds: [String],
                     onAfterClear: @escaping () -> Void) -> some View {
        modifier(VocabNavBar(title: title, filter: filter, showFilter: showFilter,
                             locked: locked, chapterWordIds: chapterWordIds,
                             onAfterClear: onAfterClear))
    }
}
