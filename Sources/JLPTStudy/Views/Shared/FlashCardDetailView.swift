import SwiftUI

// Reusable full-screen flashcard display used by both detail and study views.
struct FlashCardDetailView: View {
    let imagePath: String
    let cardId: String
    let isStudyMode: Bool

    @EnvironmentObject private var store: CardStore

    var onNeedsWork: (() -> Void)? = nil
    var onConfident: (() -> Void)? = nil

    private var isFavorite: Bool {
        if let k = store.kanjiCards.first(where: { $0.id == cardId }) { return k.isFavorite }
        if let g = store.grammarCards.first(where: { $0.id == cardId }) { return g.isFavorite }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Card image – full width, top of content area
            if let image = loadCardImage(path: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Text("Image not found")
                            .foregroundColor(.secondary)
                    )
            }

            Spacer(minLength: 12)

            // Bottom action area — star is always centered via ZStack
            ZStack {
                if isStudyMode {
                    HStack(spacing: 0) {
                        Button {
                            onNeedsWork?()
                        } label: {
                            Text("Needs Work")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.red))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            onConfident?()
                        } label: {
                            Text("Confident")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                }

                Button {
                    store.toggleFavorite(cardId: cardId)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 30))
                        .foregroundColor(isFavorite ? .yellow : Color.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppBackground())
    }
}
