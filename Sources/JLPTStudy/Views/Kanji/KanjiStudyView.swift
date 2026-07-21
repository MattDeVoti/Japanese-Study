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
    @State private var currentCard: KanjiCard?
    @State private var isRevealed = false
    /// Weight mode for a locked chapter session — independent of the Study section.
    @State private var lockedWeightMode: WeightMode = .none
    @Namespace private var glyphNS

    private var pool: [KanjiCard] {
        if let locked = lockedChapter {
            return locked.kanji.compactMap { store.kanjiCard(for: $0) }
                .filter { !store.isKanjiExcluded($0.id) }
        }
        return store.filteredKanjiCards(filter: filter)
    }

    /// Card ids for this chapter's kanji (locked mode) — scopes "clear checkmarks".
    private var lockedCardIds: [String] {
        (lockedChapter?.kanji ?? []).compactMap { store.kanjiCard(for: $0)?.id }
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
        .onChange(of: lockedWeightMode) { _ in pickNext() }
    }

    // MARK: - Study card

    private func studyCard(_ card: KanjiCard) -> some View {
        let isFavorite = store.kanjiCards.first(where: { $0.id == card.id })?.isFavorite ?? card.isFavorite
        let isExcluded = store.isKanjiExcluded(card.id)

        return ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed top bar: favorite + checkmark + level (stay put while the kanji slides)
                HStack(spacing: 14) {
                    Button {
                        store.toggleFavorite(cardId: card.id)
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundColor(isFavorite ? .yellow : Color.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.toggleKanjiExcluded(cardId: card.id)
                        pickNext()
                    } label: {
                        Image(systemName: isExcluded ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 26))
                            .foregroundColor(isExcluded ? .green : Color.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    Spacer()

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
                            Text(card.kanji)
                                .font(.system(size: 80, weight: .bold))
                                .foregroundColor(.appText)
                                .matchedGeometryEffect(id: "glyph", in: glyphNS)
                                .padding(.top, 8)

                            KanjiCardBody(card: card)
                                .transition(.opacity.animation(.easeIn(duration: 0.3).delay(0.2)))

                            Spacer().frame(height: 90)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer()

                        Text(card.kanji)
                            .font(.system(size: 80, weight: .bold))
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
                                    .fill(Color.red.badgeGradient)
                                    .frame(width: 88, height: 88)
                                    .shadow(color: Color.red.opacity(0.40), radius: 10, x: 0, y: 4)
                                Text("Check")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)

                        Spacer()
                        Spacer().frame(height: 80)
                    }
                }
            }

            // Needs Work / Confident — always visible
            HStack(spacing: 12) {
                Button {
                    store.incrementNeedsWork(cardId: card.id)
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

                Button {
                    store.incrementConfident(cardId: card.id)
                    pickNext()
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
        }
        .standardNavBar(card.kanji)
        .kanjiOptionsBar(locked: lockedChapter, filter: filter, store: store,
                         chapterCardIds: lockedCardIds, weightMode: $lockedWeightMode, onAfterClear: { pickNext() })
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
                         chapterCardIds: lockedCardIds, weightMode: $lockedWeightMode, onAfterClear: { pickNext() })
    }

    // MARK: - Navigation

    private func pickNext() {
        let p = pool
        guard !p.isEmpty else { currentCard = nil; return }
        isRevealed = false
        currentCard = lockedChapter == nil
            ? store.selectWeightedKanji(from: p, filter: filter)
            : store.selectWeightedKanji(from: p, mode: lockedWeightMode, strength: filter.weightStrength)
    }
}

// MARK: - Options bar (study filter sheet, or a chapter's menu)

private struct KanjiOptionsBar: ViewModifier {
    let locked: LockedKanjiChapter?
    @ObservedObject var filter: KanjiFilter
    @ObservedObject var store: CardStore
    let chapterCardIds: [String]
    @Binding var weightMode: WeightMode
    let onAfterClear: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if locked != nil {
            content.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Priority", selection: $weightMode) {
                            Text("Random Order").tag(WeightMode.none)
                            Text("Prioritize “Needs Work”").tag(WeightMode.harder)
                            Text("Prioritize “Confident”").tag(WeightMode.easier)
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
                         chapterCardIds: [String], weightMode: Binding<WeightMode>,
                         onAfterClear: @escaping () -> Void) -> some View {
        modifier(KanjiOptionsBar(locked: locked, filter: filter, store: store,
                                 chapterCardIds: chapterCardIds, weightMode: weightMode,
                                 onAfterClear: onAfterClear))
    }
}
