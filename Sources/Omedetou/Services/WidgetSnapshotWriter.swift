import SwiftUI
import WidgetKit

// Publishes what the widgets show.
//
// Written on launch and whenever the theme changes, so the widget stays in step
// with the user's Appearance without having to read the app's theme layer.

enum WidgetSnapshotWriter {
    /// Enough variety that the rotation doesn't repeat quickly, small enough to
    /// sit in a defaults suite without bloating it.
    private static let perKind = 150

    static func refresh(cardStore: CardStore) {
        let snapshot = WidgetSnapshot(kanjiWords: kanjiWords(cardStore),
                                      vocabWords: vocabWords(),
                                      theme: currentTheme())
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Only the theme changed — keep the words, swap the colours. Avoids rebuilding
    /// the word lists every time someone browses the Appearance picker.
    static func refreshThemeOnly() {
        guard let existing = WidgetSnapshot.load() else { return }
        WidgetSnapshot(kanjiWords: existing.kanjiWords,
                       vocabWords: existing.vocabWords,
                       theme: currentTheme()).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Content

    /// Example words drawn from the kanji cards — the widget shows 会議 rather
    /// than a bare 会, since a word in isolation is what you actually read.
    private static func kanjiWords(_ store: CardStore) -> [WidgetItem] {
        var out: [WidgetItem] = []
        for card in store.kanjiCards.shuffled() {
            // Essential words first — the widget should surface words worth
            // learning, not the card's bonus reference entries.
            guard let w = (card.commonWords.filter(\.essential).randomElement()
                            ?? card.commonWords.randomElement()),
                  !w.kanji.isEmpty, !w.meaning.isEmpty else { continue }
            out.append(WidgetItem(kind: .kanji, targetId: card.id, word: w.kanji,
                                  kana: w.kana, meaning: w.meaning,
                                  sourceKanji: card.kanji))
            if out.count >= perKind { break }
        }
        return out
    }

    private static func vocabWords() -> [WidgetItem] {
        LessonsService.shared.loadIfNeeded()
        guard let manifest = LessonsService.shared.manifest else { return [] }
        var out: [WidgetItem] = []
        for level in manifest.levels.shuffled() {
            for summary in level.chapters.shuffled() {
                guard let chapter = LessonsService.shared.loadChapter(summary.id),
                      let words = chapter.vocab else { continue }
                for w in words.shuffled() {
                    guard !w.kanji.isEmpty, !w.definition.isEmpty else { continue }
                    out.append(WidgetItem(kind: .vocab, targetId: w.id, word: w.kanji,
                                          kana: w.kana, meaning: w.definition))
                    if out.count >= perKind { return out }
                }
            }
        }
        return out
    }

    // MARK: - Theme

    private static func currentTheme() -> WidgetTheme {
        let t = _currentAppTheme
        return WidgetTheme(backgroundHex: t.background.hexString,
                           backgroundEndHex: (t.backgroundEnd ?? t.background).hexString,
                           accentHex: t.navBar.hexString,
                           isDark: t.colorScheme == .dark)
    }
}

private extension Color {
    /// The widget can't see SwiftUI `Color` values, so they cross as hex.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X",
                      Int((r * 255).rounded()), Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }
}
