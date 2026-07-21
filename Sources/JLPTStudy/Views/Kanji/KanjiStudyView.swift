import SwiftUI

struct KanjiStudyView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var filter: KanjiFilter
    @State private var currentCard: KanjiCard?
    @State private var isRevealed = false
    @Namespace private var glyphNS

    private var pool: [KanjiCard] {
        store.filteredKanjiCards(filter: filter)
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
    }

    // MARK: - Study card

    private func studyCard(_ card: KanjiCard) -> some View {
        let isFavorite = store.kanjiCards.first(where: { $0.id == card.id })?.isFavorite ?? card.isFavorite

        return ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed top bar: favorite + level (stays put while the kanji slides)
                HStack {
                    Button {
                        store.toggleFavorite(cardId: card.id)
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundColor(isFavorite ? .yellow : Color.gray.opacity(0.5))
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
        .withOptions(filter: filter, store: store, section: .kanji, label: "Kanji")
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
        .withOptions(filter: filter, store: store, section: .kanji, label: "Kanji")
    }

    // MARK: - Navigation

    private func pickNext() {
        let p = pool
        guard !p.isEmpty else { currentCard = nil; return }
        isRevealed = false
        currentCard = store.selectWeightedKanji(from: p, filter: filter)
    }
}
