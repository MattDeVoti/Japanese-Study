import SwiftUI

struct GrammarCardDetailView: View {
    let card: GrammarCard
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var grammarFilter: GrammarFilter

    var body: some View {
        FlashCardDetailView(
            imagePath: card.imagePath,
            cardId: card.id,
            isStudyMode: false
        )
        .standardNavBar("Grammar")
        .withOptions(filter: grammarFilter, store: store, section: .grammar, label: "Grammar")
    }
}
