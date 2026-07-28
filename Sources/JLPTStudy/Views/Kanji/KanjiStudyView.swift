import SwiftUI

/// Identifies a chapter when the kanji flashcards are opened from a lesson's
/// "Study Kanji" button — the pool auto-filters to just that chapter's kanji.
struct LockedKanjiChapter {
    let title: String
    let kanji: [String]
}

struct KanjiStudyView: View {
    /// When set, this is a chapter's "Study Kanji" session (pool locked to the
    /// chapter's kanji). When nil, it's the global Study-section kanji flashcards.
    var lockedChapter: LockedKanjiChapter? = nil

    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var filter: KanjiFilter
    @ObservedObject private var weightSettings = StudyWeightSettings.shared
    @ObservedObject private var kanjiSettings = KanjiStudySettings.shared
    @State private var currentCard: KanjiStudyItem?
    @State private var isRevealed = false
    /// Shows the green-check pop over the card after "Confident" is tapped.
    @State private var showConfidentPop = false
    /// Undo history for the back button — each answered card + what to reverse.
    @State private var history: [KanjiStudyHistoryEntry] = []
    @Namespace private var glyphNS

    /// Base kanji before checkmarks are applied — the study pool decides that per
    /// item so a kanji's words survive the kanji itself being checked off.
    private var baseCards: [KanjiCard] {
        if let locked = lockedChapter {
            return locked.kanji.compactMap { store.kanjiCard(for: $0) }
        }
        return store.filteredKanjiCards(filter: filter, applyChecks: false)
    }

    private var pool: [KanjiStudyItem] { store.kanjiStudyPool(from: baseCards) }

    /// Card ids for this chapter (locked mode) — scopes "clear checkmarks".
    /// Includes the chapter's word cards so the option clears those too.
    private var lockedCardIds: [String] {
        let cards = (lockedChapter?.kanji ?? []).compactMap { store.kanjiCard(for: $0) }
        return cards.map(\.id) + store.wordCards(from: cards).map(\.id)
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
        .onChange(of: filter.selectedLevels) { _ in pickNext() }
        .onChange(of: filter.showFavoritesOnly) { _ in pickNext() }
        .onChange(of: filter.selectedKanjiIds) { _ in pickNext() }
        .onChange(of: weightSettings.mode) { _ in pickNext() }
        .onChange(of: kanjiSettings.includeCommonWords) { _ in pickNext() }
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
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed top bar: favorite + level (stay put while the face slides)
                HStack(spacing: 14) {
                    if let base = baseCard {
                        Button {
                            store.toggleFavorite(cardId: base.id)
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

                        Button {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                                isRevealed = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.appText, lineWidth: 2)
                                    .frame(width: 88, height: 88)
                                Text("Check")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.appText)
                            }
                        }
                        .buttonStyle(.plain)
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
                    store.incrementNeedsWork(cardId: card.id)
                    history.append(KanjiStudyHistoryEntry(card: card, action: .needsWork))
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
            .background(Color.appBackground.ignoresSafeArea(edges: .bottom))

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
            Color.appBackground.ignoresSafeArea()
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
        currentCard = store.selectWeightedKanjiItem(from: p)
    }

    /// "Confident" activates the card's checkmark (excludes it from the lineup),
    /// pops a green check over the card, then advances to the next card.
    private func confirmConfident(_ card: KanjiStudyItem) {
        guard !showConfidentPop else { return }
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
        case .needsWork:
            store.decrementNeedsWork(cardId: last.card.id)
        case .confident(let didCheck):
            if didCheck { store.toggleKanjiExcluded(cardId: last.card.id) }
        }
        isRevealed = false
        currentCard = last.card
    }
}

// MARK: - Back-button undo history

private enum KanjiStudyAction {
    case needsWork
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
    @ObservedObject private var weightSettings = StudyWeightSettings.shared
    @ObservedObject private var kanjiSettings = KanjiStudySettings.shared
    let chapterCardIds: [String]
    let onAfterClear: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if locked != nil {
            content.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Priority", selection: $weightSettings.mode) {
                            Text("No Priority").tag(WeightMode.none)
                            Text("Prioritize Needs Work").tag(WeightMode.needsWork)
                        }
                        Divider()
                        Toggle(isOn: $kanjiSettings.includeCommonWords) {
                            Label("Include Example Words", systemImage: "text.book.closed")
                        }
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
