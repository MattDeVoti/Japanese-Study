import SwiftUI

/// Identifies a chapter when the kanji flashcards are opened from a lesson's
/// "Study Kanji" button — the pool is exactly that chapter's kanji words.
struct LockedKanjiChapter {
    let title: String
    let words: [ChapterKanjiWord]
}

struct KanjiStudyView: View {
    /// When set, this is a chapter's "Study Kanji" session (pool locked to the
    /// chapter's kanji). When nil, it's the global Study-section kanji flashcards.
    var lockedChapter: LockedKanjiChapter? = nil

    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var filter: KanjiFilter
    @ObservedObject private var weightSettings = StudyWeightSettings.shared
    @State private var currentCard: KanjiStudyItem?
    @State private var isRevealed = false
    @StateObject private var sequencer = DeckSequencer()
    /// Shows the green-check pop over the card after "Confident" is tapped.
    @State private var showConfidentPop = false
    /// Undo history for the back button — each answered card + what to reverse.
    @State private var history: [KanjiStudyHistoryEntry] = []
    @Namespace private var glyphNS

    /// The deck before checkmarks are applied: kanji *words*, per the reworked
    /// kanji teaching — a chapter's own words when locked, otherwise every
    /// selected chapter's words (all chapters when none are picked).
    private var baseItems: [KanjiStudyItem] {
        if let locked = lockedChapter {
            return locked.words.map { store.wordItem(from: $0) }
        }
        var pool = LessonsService.shared.allKanjiWords()
        if !filter.selectedChapterIds.isEmpty {
            pool = pool.filter { filter.selectedChapterIds.contains($0.chapterId) }
        }
        var items = pool.map { store.wordItem(from: $0.word) }
        if filter.showFavoritesOnly {
            // A word is a favorite if any kanji it contains is starred.
            let favs = items.filter { item in
                if case let .word(w) = item {
                    return w.parentIds.contains { store.kanjiCard(id: $0)?.isFavorite == true }
                }
                return false
            }
            if !favs.isEmpty { items = favs }
        }
        return items
    }

    private var pool: [KanjiStudyItem] {
        guard weightSettings.filtersOutCheckedCards else { return baseItems }
        return baseItems.filter { !store.excludedKanjiIds.contains($0.id) }
    }

    /// How much of this set has been checked off, for the counter on the card.
    /// Nil outside No-Priority mode, where checking a card doesn't retire it and
    /// there's no set to work through.
    private var checkedProgress: (done: Int, total: Int)? {
        guard weightSettings.filtersOutCheckedCards else { return nil }
        let total = baseItems.count
        guard total > 0 else { return nil }
        return (total - pool.count, total)
    }

    /// Ids scoped to this chapter for "clear checkmarks": its word cards, plus
    /// the characters themselves so lookup-table checkmarks clear with them.
    private var lockedCardIds: [String] {
        guard let locked = lockedChapter else { return [] }
        return locked.words.map(\.id)
            + locked.words.flatMap(\.chars).compactMap { store.kanjiCard(for: $0)?.id }
    }

    var body: some View {
        Group {
            if let card = currentCard {
                studyCard(card)
            } else {
                emptyState
            }
        }
        .onAppear { pickNext() }
        .onChange(of: filter.showFavoritesOnly) { _ in pickNext() }
        .onChange(of: filter.selectedChapterIds) { _ in pickNext() }
        .onChange(of: weightSettings.mode) { _ in pickNext() }
    }

    // MARK: - Study card

    private func studyCard(_ card: KanjiStudyItem) -> some View {
        // Words have no favorite of their own — only base kanji show the star.
        let baseCard: KanjiCard? = {
            if case let .kanji(c) = card { return store.kanjiCard(id: c.id) ?? c }
            return nil
        }()
        // A long word needs a smaller face than a single glyph.
        let faceSize: CGFloat = card.face.count >= 4 ? 52 : (card.face.count >= 2 ? 64 : 80)

        return ZStack(alignment: .bottom) {
            AppBackground()

            VStack(spacing: 0) {
                // Fixed top bar: favorite + level (stay put while the face slides)
                HStack(spacing: 14) {
                    if let base = baseCard {
                        Button {
                            store.toggleFavorite(cardId: base.id)
                            FeedbackSounds.shared.playFavorite(store.kanjiCard(id: base.id)?.isFavorite ?? false)
                        } label: {
                            Image(systemName: base.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 26))
                                .foregroundColor(base.isFavorite ? .yellow : Color.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if card.isWord {
                        Text("WORD")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.vocabColor))
                    }

                    Text(levelName(card.nLevel))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(nLevelColor(card.nLevel)))
                }
                .deckProgress(checkedProgress)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if isRevealed {
                    ScrollView {
                        VStack(spacing: 20) {
                            Text(card.face)
                                .font(.system(size: faceSize, weight: .bold))
                                .foregroundColor(.appText)
                                .matchedGeometryEffect(id: "glyph", in: glyphNS)
                                .padding(.top, 8)

                            revealedBody(card)
                                .transition(.opacity.animation(.easeIn(duration: 0.3).delay(0.2)))

                            Spacer().frame(height: 90)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer()

                        Text(card.face)
                            .font(.system(size: faceSize, weight: .bold))
                            .foregroundColor(.appText)
                            .matchedGeometryEffect(id: "glyph", in: glyphNS)

                        Spacer()

                        CheckButton {
                            FeedbackSounds.shared.play(.notification)
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                                isRevealed = true
                            }
                        }
                        .offset(y: -56)
                        .transition(.opacity)

                        Spacer()
                        Spacer().frame(height: 80)
                    }
                }
            }

            // Needs Work / back / Confident — always visible
            HStack(spacing: 12) {
                Button {
                    FeedbackSounds.shared.play(.incorrect)
                    let didUncheck = store.incrementNeedsWork(cardId: card.id)
                    history.append(KanjiStudyHistoryEntry(card: card,
                                                         action: .needsWork(didUncheck: didUncheck)))
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

                Button {
                    confirmConfident(card)
                } label: {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appBackgroundEnd.ignoresSafeArea(edges: .bottom))

            // Green-check pop shown briefly when "Confident" is tapped
            if showConfidentPop {
                ConfidentCheckPop()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .standardNavBar(card.face)
        .kanjiOptionsBar(locked: lockedChapter, filter: filter, store: store,
                         chapterCardIds: lockedCardIds, onAfterClear: { pickNext() })
    }

    // MARK: - Revealed side

    @ViewBuilder
    private func revealedBody(_ card: KanjiStudyItem) -> some View {
        switch card {
        case let .kanji(c):
            KanjiCardBody(card: c)
        case let .word(w):
            WordCardBody(word: w, parents: w.parentIds.compactMap { store.kanjiCard(id: $0) })
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "rectangle.stack.badge.minus")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No kanji cards match\nthe current filters.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .standardNavBar("Kanji")
        .kanjiOptionsBar(locked: lockedChapter, filter: filter, store: store,
                         chapterCardIds: lockedCardIds, onAfterClear: { pickNext() })
    }

    // MARK: - Navigation

    private func pickNext() {
        let p = pool
        guard !p.isEmpty else { currentCard = nil; return }
        isRevealed = false
        currentCard = store.selectNextKanjiItem(from: p, using: sequencer)
    }

    /// "Confident" activates the card's checkmark (excludes it from the lineup),
    /// pops a green check over the card, then advances to the next card.
    private func confirmConfident(_ card: KanjiStudyItem) {
        guard !showConfidentPop else { return }
        FeedbackSounds.shared.playCorrectVariation()
        store.incrementConfident(cardId: card.id)
        let wasChecked = store.isKanjiExcluded(card.id)
        if !wasChecked { store.toggleKanjiExcluded(cardId: card.id) }
        history.append(KanjiStudyHistoryEntry(card: card, action: .confident(didCheck: !wasChecked)))
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
            store.decrementNeedsWork(cardId: last.card.id)
            if didUncheck { store.toggleKanjiExcluded(cardId: last.card.id) }
        case .confident(let didCheck):
            store.decrementConfident(cardId: last.card.id)
            if didCheck { store.toggleKanjiExcluded(cardId: last.card.id) }
        }
        isRevealed = false
        currentCard = last.card
        // So the next draw doesn't hand back the card we just returned to.
        sequencer.note(last.card.id)
    }
}

// MARK: - Back-button undo history

private enum KanjiStudyAction {
    case needsWork(didUncheck: Bool)
    case confident(didCheck: Bool)
}

private struct KanjiStudyHistoryEntry {
    let card: KanjiStudyItem
    let action: KanjiStudyAction
}

// MARK: - Options bar (study filter sheet, or a chapter's menu)

private struct KanjiOptionsBar: ViewModifier {
    let locked: LockedKanjiChapter?
    @ObservedObject var filter: KanjiFilter
    @ObservedObject var store: CardStore
    let chapterCardIds: [String]
    let onAfterClear: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if locked != nil {
            content.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        WeightPriorityMenuItems()
                        Divider()
                        Button(role: .destructive) {
                            store.clearKanjiExclusions(ids: chapterCardIds)
                            onAfterClear()
                        } label: {
                            Label("Clear Checkmarks (This Chapter)", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.appNavBarText)
                    }
                }
            }
        } else {
            content.withOptions(filter: filter, store: store, section: .kanji, label: "Kanji")
        }
    }
}

private extension View {
    func kanjiOptionsBar(locked: LockedKanjiChapter?, filter: KanjiFilter, store: CardStore,
                         chapterCardIds: [String],
                         onAfterClear: @escaping () -> Void) -> some View {
        modifier(KanjiOptionsBar(locked: locked, filter: filter, store: store,
                                 chapterCardIds: chapterCardIds,
                                 onAfterClear: onAfterClear))
    }
}
