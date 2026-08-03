import SwiftUI

struct ParticlesView: View {
    @EnvironmentObject private var store: CardStore
    @State private var searchText = ""

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var cards: [ParticleCard] {
        guard !searchText.isEmpty else { return store.particleCards }
        let q = searchText.lowercased()
        return store.particleCards.filter {
            $0.particle.contains(searchText) || $0.romaji.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                SearchBar(text: $searchText, placeholder: "Search particles…")

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(cards) { card in
                            NavigationLink {
                                ParticleCardDetailView(card: card)
                            } label: {
                                ParticleGridCell(card: card)
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
        .standardNavBar("Particles")
    }
}

private struct ParticleGridCell: View {
    let card: ParticleCard
    private var color: Color { nLevelColor(card.nLevel) }

    var body: some View {
        VStack(spacing: 6) {
            Text(card.particle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .multilineTextAlignment(.center)
            Text(card.romaji)
                .font(.system(size: 11))
                .foregroundColor(color.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
    }
}
