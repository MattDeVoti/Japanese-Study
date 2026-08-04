import SwiftUI
import WidgetKit

// The widget's presentation layer. It lives in Shared rather than the extension
// so the app can render the exact same tile — a widget can't be driven from a
// test, and rendering it in-app is the only way to actually see the layout.

struct WordEntry: TimelineEntry {
    let date: Date
    let item: WidgetItem?
    let theme: WidgetTheme
}

// MARK: - Shared chrome

struct WidgetBackground: View {
    let theme: WidgetTheme
    var body: some View {
        LinearGradient(colors: [Color(widgetHex: theme.backgroundHex),
                                Color(widgetHex: theme.backgroundEndHex)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension WidgetTheme {
    var text: Color { isDark ? .white : Color(white: 0.12) }
    var secondary: Color { isDark ? Color(white: 0.78) : Color(white: 0.38) }
    var accent: Color { Color(widgetHex: accentHex) }
}

// MARK: - Home screen

struct WordWidgetView: View {
    let entry: WordEntry
    @Environment(\.widgetFamily) private var family

    /// Whether this word came from a kanji card or a lesson — read off the item,
    /// since one widget now shows both.
    private var kind: WidgetItemKind { entry.item?.kind ?? .vocab }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: lockRectangular
            case .accessoryInline:      lockInline
            default:                    square
            }
        }
        .widgetURL(entry.item.flatMap(WidgetShared.url(for:)))
    }

    // The square tile: word, kana under it, then as much English as fits.
    private var square: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(kind == .kanji ? "漢字" : "単語")
                    .font(.system(size: 10, weight: .black))
                if let k = entry.item?.sourceKanji, kind == .kanji {
                    Text("· \(k)").font(.system(size: 10, weight: .bold))
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(entry.theme.accent.opacity(0.85))

            Spacer(minLength: 4)

            if let item = entry.item {
                Text(item.word)
                    .font(.system(size: wordSize(item.word), weight: .bold))
                    .foregroundColor(entry.theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(item.kana)
                    .font(.system(size: 12))
                    .foregroundColor(entry.theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 1)
                // Trails off rather than shrinking — a definition is allowed to be
                // longer than the tile.
                Text(item.meaning)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(entry.theme.text.opacity(0.85))
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            } else {
                Text("Open Omedetou\nto load words")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(entry.theme.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A long compound has to start smaller or it just scales down to mush.
    private func wordSize(_ s: String) -> CGFloat {
        switch s.count {
        case 0...2: return 34
        case 3:     return 28
        case 4:     return 23
        default:    return 19
        }
    }

    // MARK: Lock screen
    //
    // Rendered as a monochrome vibrant stencil by the system, so colour is
    // ignored here — only the shapes and the hierarchy matter.

    private var lockRectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let item = entry.item {
                Text(item.word)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(item.kana)
                    .font(.system(size: 11))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(item.meaning)
                    .font(.system(size: 11))
                    .lineLimit(1).truncationMode(.tail)
            } else {
                Text("Omedetou").font(.system(size: 14, weight: .semibold))
                Text("Open the app to load words").font(.system(size: 11)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lockInline: some View {
        if let item = entry.item {
            Text("\(item.word) · \(item.meaning)")
        } else {
            Text("Omedetou")
        }
    }
}

extension View {
    /// `containerBackground` is required from iOS 17 and unavailable before it, so
    /// the two paths have to be written separately.
    @ViewBuilder func omedetouContainer(_ theme: WidgetTheme) -> some View {
        if #available(iOS 17.0, *) {
            self.padding(12)
                .containerBackground(for: .widget) { WidgetBackground(theme: theme) }
        } else {
            ZStack {
                WidgetBackground(theme: theme)
                self.padding(12)
            }
        }
    }
}

