import WidgetKit
import SwiftUI

// Home-screen and lock-screen widgets: one word at a time, in the same palette
// as the app.
//
// The timeline is built entirely up front — one entry per rotation for the next
// stretch — so the widget never needs to wake up to decide what to show next.
// WidgetKit budgets refreshes heavily; precomputing means the rotation the user
// asked for actually happens.

// MARK: - Timeline

struct WordProvider: TimelineProvider {
    /// Both pools together, interleaved so a shuffle can't land on a long run of
    /// one kind.
    private func items() -> [WidgetItem] {
        guard let snap = WidgetSnapshot.load() else { return [] }
        var out: [WidgetItem] = []
        let a = snap.kanjiWords, b = snap.vocabWords
        for i in 0..<max(a.count, b.count) {
            if i < a.count { out.append(a[i]) }
            if i < b.count { out.append(b[i]) }
        }
        return out
    }
    private func theme() -> WidgetTheme { WidgetSnapshot.load()?.theme ?? .fallback }

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(),
                  item: WidgetItem(kind: .vocab, targetId: "", word: "勉強",
                                   kana: "べんきょう", meaning: "study",
                                   sourceKanji: "勉"),
                  theme: theme())
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(WordEntry(date: Date(), item: items().randomElement() ?? placeholder(in: context).item,
                             theme: theme()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let pool = items()
        let theme = theme()
        guard !pool.isEmpty else {
            completion(Timeline(entries: [WordEntry(date: Date(), item: nil, theme: theme)],
                                policy: .after(Date().addingTimeInterval(3600))))
            return
        }
        let minutes = max(15, WidgetShared.refreshMinutes)
        // Roughly a day of rotations, capped so a 15-minute cadence doesn't build
        // a needlessly enormous timeline.
        let count = min(max(24 * 60 / minutes, 4), 64)
        let shuffled = pool.shuffled()
        var entries: [WordEntry] = []
        for i in 0..<count {
            let date = Date().addingTimeInterval(Double(i * minutes) * 60)
            entries.append(WordEntry(date: date, item: shuffled[i % shuffled.count], theme: theme))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widgets

struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.wordKind,
                            provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
                .omedetouContainer(entry.theme)
        }
        .configurationDisplayName("Word of the Moment")
        .description("A word from your kanji cards or your lessons, with its reading and meaning. Tap to open it in the app.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct OmedetouWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordWidget()
    }
}
