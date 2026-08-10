import SwiftUI

/// The whole vocabulary deck, assembled from the lesson chapters.
///
/// Shared so the written flashcards and the vocal ones are demonstrably the same
/// pool — "the words that would show up in the normal deck" is the promise the
/// vocal mode makes, and the only way to keep it is to draw from one place.
enum VocabDeck {

    /// Every vocab word in the course, in manifest order. Callers shuffle.
    static func allCards() -> [VocabFlashCard] {
        LessonsService.shared.loadIfNeeded()
        guard let manifest = LessonsService.shared.manifest else { return [] }

        var result: [VocabFlashCard] = []
        for level in manifest.levels {
            let color = levelAccentColor(level.levelId)
            for summary in level.chapters {
                guard let chapter = LessonsService.shared.loadChapter(summary.id),
                      let words = chapter.vocab else { continue }
                for word in words {
                    result.append(VocabFlashCard(
                        word: word,
                        chapterId: summary.id,
                        chapterNumber: summary.chapterNumber,
                        chapterTitle: chapter.title,
                        accentColor: color
                    ))
                }
            }
        }
        return result
    }
}
