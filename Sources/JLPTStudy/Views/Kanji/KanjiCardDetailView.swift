import SwiftUI

struct KanjiCardDetailView: View {
    let card: KanjiCard

    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var filter: KanjiFilter

    private var isFavorite: Bool {
        store.kanjiCards.first(where: { $0.id == card.id })?.isFavorite ?? card.isFavorite
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    KanjiCardHeader(card: card, isFavorite: isFavorite) {
                        store.toggleFavorite(cardId: card.id)
                    }
                    .padding(.top, 16)

                    KanjiCardBody(card: card)

                    Spacer().frame(height: 24)
                }
            }
        }
        .standardNavBar(card.kanji)
        .withOptions(filter: filter, store: store, section: .kanji, label: "Kanji")
    }
}

// MARK: - Shared sub-views (used by both detail and study)

struct KanjiCardHeader: View {
    let card: KanjiCard
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        ZStack {
            Text(card.kanji)
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(.appText)

            HStack {
                Button(action: onToggleFavorite) {
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
        }
        .frame(maxWidth: .infinity)
    }
}

struct KanjiCardBody: View {
    let card: KanjiCard

    var body: some View {
        VStack(spacing: 20) {
            if !card.definition.isEmpty {
                Text(card.definition)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.appText)
                    .padding(.horizontal, 20)
            }

            if !card.onyomi.isEmpty || !card.kunyomi.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    ReadingsColumn(label: "Onyomi", readings: card.onyomi)
                    ReadingsColumn(label: "Kunyomi", readings: card.kunyomi)
                }
                .padding(.horizontal, 16)
            }

            if !card.commonWords.isEmpty {
                CommonWordsTable(words: card.commonWords)
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Reading columns

struct ReadingsColumn: View {
    let label: String
    let readings: [KanjiReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)

            if readings.isEmpty {
                Text("—")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(readings, id: \.self) { r in
                    HStack {
                        Text(r.kana)
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                        Spacer()
                        Text(r.romaji)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.appHairline, lineWidth: 1)
        )
    }
}

// MARK: - Common words table

struct CommonWordsTable: View {
    let words: [KanjiCommonWord]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Kana")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Kanji")
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("English")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.appSurfaceHigh)

            ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                HStack(alignment: .top, spacing: 0) {
                    Text(word.kana)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(word.kanji)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(word.meaning)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 13))
                .foregroundColor(.appText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(idx % 2 == 0 ? Color.appSurface : Color.appSurfaceHigh)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.appHairline, lineWidth: 1))
    }
}
