import SwiftUI

struct KanjiListView: View {
    @EnvironmentObject private var store: CardStore
    @State private var searchText = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    private var cards: [KanjiCard] {
        // Lookup shows every kanji; only the search bar narrows it — the kanji
        // flashcard filter (levels / selected kanji) intentionally does NOT apply.
        let base = store.allKanjiCards()
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.kanji.contains(searchText) }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                SearchBar(text: $searchText, placeholder: "Search kanji…")

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(cards) { card in
                            NavigationLink {
                                KanjiCardDetailView(card: card)
                            } label: {
                                Text(card.kanji)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(nLevelColor(card.nLevel))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
        }
        .standardNavBar("Kanji")
    }
}
