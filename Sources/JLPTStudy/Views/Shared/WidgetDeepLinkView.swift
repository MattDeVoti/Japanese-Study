import SwiftUI

// Where a widget tap lands.
//
// Presented as a sheet from the app root rather than pushed, so arriving from the
// home screen never disturbs wherever the user already was inside the app.

struct WidgetDeepLink: Identifiable {
    enum Target { case kanji(String), vocab(String) }
    let id: String
    let target: Target

    /// `omedetou://kanji/<kanjiId>` · `omedetou://vocab/<wordId>`
    init?(url: URL) {
        guard url.scheme == "omedetou" else { return nil }
        let value = url.pathComponents.filter { $0 != "/" }.joined(separator: "/")
        guard !value.isEmpty else { return nil }
        switch url.host {
        case "kanji": target = .kanji(value)
        case "vocab": target = .vocab(value)
        default: return nil
        }
        id = "\(url.host ?? "")/\(value)"
    }
}

struct WidgetDeepLinkView: View {
    let link: WidgetDeepLink

    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch link.target {
            case .kanji(let id):
                if let card = store.kanjiCard(id: id) {
                    KanjiCardDetailView(card: card)
                } else {
                    missing("That kanji card isn't available.")
                }
            case .vocab(let id):
                if let word = LessonsService.shared.vocabWord(id: id) {
                    VocabDeepLinkCard(word: word)
                } else {
                    missing("That word isn't available.")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }
        }
    }

    private func missing(_ message: String) -> some View {
        ZStack {
            AppBackground()
            VStack(spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.appTextSecondary)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }
}

/// A vocabulary word has no detail screen of its own, so the widget opens a card
/// showing the same material a flashcard would.
struct VocabDeepLinkCard: View {
    let word: LessonVocabWord

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            FuriganaText(text: word.kanji, fontSize: 40,
                                         color: .appText, weight: .bold)
                                .fixedSize(horizontal: false, vertical: true)
                            SpeakButton(text: word.kana.isEmpty ? word.kanji : word.kana,
                                        size: 22)
                            Spacer(minLength: 0)
                        }
                        if !word.kana.isEmpty, word.kana != word.kanji {
                            Text(word.kana)
                                .font(.system(size: 18))
                                .foregroundColor(.appTextSecondary)
                        }
                        if !word.romaji.isEmpty {
                            Text(word.romaji)
                                .font(.system(size: 14))
                                .foregroundColor(.appTextSecondary.opacity(0.85))
                        }
                    }

                    Text(word.definition)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.appText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(Color.appSurface))
                }
                .padding(20)
            }
        }
        .standardNavBar("Vocabulary")
    }
}
