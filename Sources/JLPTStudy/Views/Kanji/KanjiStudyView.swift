import SwiftUI

struct KanjiStudyView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var filter: KanjiFilter
    @State private var currentCard: KanjiCard?
    @State private var isRevealed = false

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

            if isRevealed {
                ScrollView {
                    VStack(spacing: 20) {
                        KanjiCardHeader(card: card, isFavorite: isFavorite) {
                            store.toggleFavorite(cardId: card.id)
                        }
                        .padding(.top, 16)

                        KanjiCardBody(card: card)

                        Spacer().frame(height: 80)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    KanjiCardHeader(card: card, isFavorite: isFavorite) {
                        store.toggleFavorite(cardId: card.id)
                    }
                    .padding(.top, 16)

                    Spacer()

                    Button { isRevealed = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 88, height: 88)
                            Text("Check")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Spacer().frame(height: 80)
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
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
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
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.85)))
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
