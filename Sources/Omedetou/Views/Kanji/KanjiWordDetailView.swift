import SwiftUI

// The lesson-facing faces of the kanji-words rework: the tile a chapter lists a
// word with, and the detail screen behind it. The flashcards' reveal reuses
// `WordCardBody`, so all three show the same thing — the word's reading and
// meaning, then the kanji card(s) it contains.

// MARK: - Chapter tile

/// A chapter's kanji-word tile: taps through to the word detail and carries the
/// green "exclude from flashcards" checkmark, exactly like the vocab rows above
/// it. The checkmark id is the shared kanji-word id, so the deck, the chapter
/// and the study filters all agree on what has been cleared.
struct KanjiWordExcludeCell: View {
    let entry: ChapterKanjiWord
    @EnvironmentObject private var cardStore: CardStore

    private var level: Int {
        entry.chars.compactMap { cardStore.kanjiCard(for: $0)?.nLevel }.max() ?? 5
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                KanjiWordDetailView(entry: entry)
            } label: {
                VStack(spacing: 2) {
                    Text(entry.word)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(nLevelColor(level))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(entry.kana)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(nLevelColor(level).opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(entry.meaning)
                        .font(.system(size: 9))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.appHairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                FeedbackSounds.shared.play(.notification)
                cardStore.toggleKanjiExcluded(cardId: entry.id)
            } label: {
                Image(systemName: cardStore.isKanjiExcluded(entry.id) ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 15))
                    .foregroundColor(cardStore.isKanjiExcluded(entry.id) ? .kanjiColor : Color.secondary.opacity(0.45))
                    .padding(3)
                    .background(Circle().fill(Color.appSurface))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
}

// MARK: - Word detail

/// A kanji word opened from a lesson: the word large, its reading, romaji and
/// meaning, and the kanji card(s) it contains — the same layout the flashcard
/// reveals, so the lesson and the deck teach identically.
struct KanjiWordDetailView: View {
    let entry: ChapterKanjiWord
    @EnvironmentObject private var cardStore: CardStore

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 20) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(entry.word)
                            .font(.system(size: entry.word.count >= 4 ? 44 : 56, weight: .bold))
                            .foregroundColor(.appText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        SpeakButton(text: entry.kana, size: 22, tint: .kanjiColor)
                    }
                    .padding(.top, 20)

                    if case let .word(card) = cardStore.wordItem(from: entry) {
                        WordCardBody(word: card,
                                     parents: card.parentIds.compactMap { cardStore.kanjiCard(id: $0) })
                    }

                    Spacer().frame(height: 24)
                }
            }
        }
        .standardNavBar(entry.word)
    }
}

// MARK: - Custom-lesson hook

extension View {
    /// Long-press → add this word's kanji to a custom lesson. Custom lessons
    /// collect characters, so a one-kanji word adds directly and a compound
    /// offers each of its kanji.
    @ViewBuilder
    func addToCustomLessonKanji(chars: [String]) -> some View {
        if chars.count == 1, let only = chars.first {
            addToCustomLesson(.kanji(char: only))
        } else if chars.isEmpty {
            self
        } else {
            modifier(AddWordKanjiToCustomLessonModifier(chars: chars))
        }
    }
}

private struct PickedChar: Identifiable {
    let char: String
    var id: String { char }
}

private struct AddWordKanjiToCustomLessonModifier: ViewModifier {
    let chars: [String]
    @State private var picked: PickedChar?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                ForEach(chars, id: \.self) { char in
                    Button {
                        picked = PickedChar(char: char)
                    } label: {
                        Label("Add \(char) to Custom Lesson", systemImage: "plus.circle")
                    }
                }
            }
            .sheet(item: $picked) { picked in
                AddToCustomLessonSheet(item: .kanji(char: picked.char))
            }
    }
}
