import SwiftUI

struct GrammarListView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var grammarFilter: GrammarFilter
    @State private var searchText = ""

    private var cards: [GrammarCard] {
        let base = store.filteredGrammarCards(filter: grammarFilter)
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter {
            $0.romaji.lowercased().contains(q) || $0.japanese.contains(searchText)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                SearchBar(text: $searchText, placeholder: "Search grammar…")

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(cards) { card in
                            NavigationLink {
                                GrammarCardDetailView(card: card)
                            } label: {
                                GrammarCardButton(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
        }
        .standardNavBar("Grammar")
        .withOptions(filter: grammarFilter, store: store, section: .grammar, label: "Grammar")
    }
}

private struct GrammarCardButton: View {
    let card: GrammarCard
    private var color: Color { nLevelColor(card.nLevel) }

    var body: some View {
        VStack(spacing: 4) {
            Text(card.romaji)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(card.japanese)
                .font(.system(size: 15))
                .foregroundColor(color.opacity(0.85))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
    }
}
