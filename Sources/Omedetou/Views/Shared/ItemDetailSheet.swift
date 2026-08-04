import SwiftUI

// "What is this, again?" — the full card behind any reviewable item.
//
// A review shows a prompt and asks you to recall it. When you can't, the useful
// next move is to look at the thing properly rather than guess, grade yourself
// harshly and move on none the wiser. This resolves an item id to whatever view
// already exists for it, so tapping the prompt opens the same card you'd reach
// from the dictionary or the textbook.
//
// Shared rather than written into the review screen, because the kanji matching
// round wants exactly the same thing from its results list.

struct ItemDetailSheet: View {
    let id: SRSItemID
    @EnvironmentObject private var cardStore: CardStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch id.kind {
                case .kanji:
                    if let card = cardStore.kanjiCard(id: id.key) {
                        KanjiCardDetailView(card: card)
                    } else {
                        missing("That kanji card isn't available.")
                    }
                case .vocab:
                    if let word = LessonsService.shared.vocabWord(id: id.key) {
                        VocabDeepLinkCard(word: word)
                    } else {
                        missing("That word isn't available.")
                    }
                case .grammar:
                    grammarPoint
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    /// Grammar ids are "chapterId/pointId" — resolve both halves and show the
    /// same card the chapter itself uses.
    @ViewBuilder private var grammarPoint: some View {
        let parts = id.key.split(separator: "/", maxSplits: 1).map(String.init)
        if parts.count == 2,
           let chapter = LessonsService.shared.loadChapter(parts[0]),
           let point = chapter.points.first(where: { $0.id == parts[1] }) {
            ScrollView {
                GrammarPointCard(point: point, chapterId: chapter.id,
                                 accentColor: .appAccent, initiallyExpanded: true)
                    .padding(16)
            }
            .background(AppBackground())
        } else {
            missing("That grammar point isn't available.")
        }
    }

    private func missing(_ text: String) -> some View {
        ZStack {
            AppBackground()
            VStack(spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 34))
                    .foregroundColor(.appTextSecondary)
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }
}
