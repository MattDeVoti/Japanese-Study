import SwiftUI

// Shared between the app and the widget extension.
//
// The widget doesn't parse the app's content itself — kanji_data.json alone is
// 1.3 MB and a widget gets a small memory budget and is woken often. Instead the
// app writes a compact snapshot (a few hundred pre-picked words plus the current
// theme's colours) into the shared suite, and the widget just reads that.

public enum WidgetShared {
    /// Both targets carry this App Group so they see the same defaults suite.
    public static let appGroup = "group.com.mattdevoti1.omedetou"

    /// One widget, mixing kanji example words and lesson vocabulary. They were
    /// two separate widgets at first, which was a distinction without a
    /// difference — both show a word, a reading and a meaning.
    public static let wordKind = "OmedetouWordWidget"

    public enum Key {
        public static let snapshot = "WidgetSnapshot"
        /// Minutes between rotations, chosen by the user in Options.
        public static let refreshMinutes = "WidgetRefreshMinutes"
    }

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// How often the shown word rotates. 60 minutes unless the user says otherwise.
    public static var refreshMinutes: Int {
        let v = defaults.integer(forKey: Key.refreshMinutes)
        return v > 0 ? v : 60
    }

    public static func setRefreshMinutes(_ m: Int) {
        defaults.set(m, forKey: Key.refreshMinutes)
    }

    // MARK: - Deep links

    /// `omedetou://kanji/<kanjiId>` and `omedetou://vocab/<wordId>`. Tapping a
    /// widget opens the card the word came from, not just the app.
    public static func url(for item: WidgetItem) -> URL? {
        URL(string: "omedetou://\(item.kind.rawValue)/\(item.targetId)")
    }
}

// MARK: - Payload

public enum WidgetItemKind: String, Codable {
    case kanji, vocab
}

/// One word as the widget shows it: the written form, its kana, and the English.
public struct WidgetItem: Codable, Identifiable, Hashable {
    public var id: String { "\(kind.rawValue):\(targetId):\(word)" }
    public let kind: WidgetItemKind
    /// What the card opens to — a kanji's id, or a vocabulary word's id.
    public let targetId: String
    public let word: String
    public let kana: String
    public let meaning: String
    /// The parent kanji, for the caption on a kanji widget.
    public let sourceKanji: String?

    public init(kind: WidgetItemKind, targetId: String, word: String,
                kana: String, meaning: String, sourceKanji: String? = nil) {
        self.kind = kind; self.targetId = targetId; self.word = word
        self.kana = kana; self.meaning = meaning; self.sourceKanji = sourceKanji
    }
}

/// Colours copied from the user's chosen Appearance so the widget matches the app.
public struct WidgetTheme: Codable, Hashable {
    public let backgroundHex: String
    public let backgroundEndHex: String
    public let accentHex: String
    public let isDark: Bool

    public init(backgroundHex: String, backgroundEndHex: String,
                accentHex: String, isDark: Bool) {
        self.backgroundHex = backgroundHex; self.backgroundEndHex = backgroundEndHex
        self.accentHex = accentHex; self.isDark = isDark
    }

    public static let fallback = WidgetTheme(backgroundHex: "FFE9D6",
                                             backgroundEndHex: "FFD6E6",
                                             accentHex: "E0574F",
                                             isDark: false)
}

public struct WidgetSnapshot: Codable {
    public let kanjiWords: [WidgetItem]
    public let vocabWords: [WidgetItem]
    public let theme: WidgetTheme

    public init(kanjiWords: [WidgetItem], vocabWords: [WidgetItem], theme: WidgetTheme) {
        self.kanjiWords = kanjiWords; self.vocabWords = vocabWords; self.theme = theme
    }

    public static func load() -> WidgetSnapshot? {
        guard let data = WidgetShared.defaults.data(forKey: WidgetShared.Key.snapshot) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        WidgetShared.defaults.set(data, forKey: WidgetShared.Key.snapshot)
    }
}

// MARK: - Colour helper

public extension Color {
    /// Widget-side hex parser. The app has its own `Color(hex:)`, but the widget
    /// target doesn't compile the app's theme layer.
    init(widgetHex: String) {
        var s = widgetHex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red:   Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue:  Double(v & 0xFF) / 255,
                  opacity: 1)
    }
}
