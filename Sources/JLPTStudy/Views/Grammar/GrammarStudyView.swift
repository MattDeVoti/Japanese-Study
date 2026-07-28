import SwiftUI

struct GrammarStudyView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var grammarFilter: GrammarFilter
    @State private var currentCard: GrammarCard?

    private var pool: [GrammarCard] {
        store.filteredGrammarCards(filter: grammarFilter)
    }

    var body: some View {
        ZStack {
            AppBackground()

            if let card = currentCard {
                FlashCardDetailView(
                    imagePath: card.imagePath,
                    cardId: card.id,
                    isStudyMode: true,
                    onNeedsWork: {
                        store.incrementNeedsWork(cardId: card.id)
                        pickNext()
                    },
                    onConfident: {
                        store.incrementConfident(cardId: card.id)
                        pickNext()
                    }
                )
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "rectangle.stack.badge.minus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No grammar cards match\nthe current filters.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .standardNavBar("Grammar")
        .withOptions(filter: grammarFilter, store: store, section: .grammar, label: "Grammar")
        .onAppear { pickNext() }
        .onChange(of: grammarFilter.selectedLevels) { _ in pickNext() }
        .onChange(of: grammarFilter.showFavoritesOnly) { _ in pickNext() }
    }

    private func pickNext() {
        let p = pool
        guard !p.isEmpty else { currentCard = nil; return }
        currentCard = store.selectWeightedGrammar(from: p)
    }
}
