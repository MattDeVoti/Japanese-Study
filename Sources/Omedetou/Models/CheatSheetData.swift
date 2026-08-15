import SwiftUI

// Quick-reference charts. These are the tables a learner keeps re-looking-up —
// the ones where the pattern is regular except for four entries that aren't, and
// where prose is the wrong shape for the information.
//
// `irregular` is the point of the whole feature: 四時 is よじ and never しじ, 八日
// is ようか, 六百 is ろっぴゃく. Those are marked so the eye lands on them first.

struct CheatItem: Identifiable {
    let id = UUID()
    /// What you'd write.
    let main: String
    /// How it's read, plus the meaning where that isn't obvious.
    let sub: String
    /// Breaks the pattern — worth memorising separately.
    var irregular: Bool = false
    /// Shown as a filled chip. Only for the colour sheet, where naming a colour
    /// in two languages you can't yet read is strictly worse than showing it.
    var swatch: Color? = nil
    /// A glyph that carries meaning — the element a weekday is named for, the
    /// weather it describes. Not used where it would just be a bullet point.
    var symbol: String? = nil

    init(_ main: String, _ sub: String, irregular: Bool = false,
         swatch: Color? = nil, symbol: String? = nil) {
        self.main = main; self.sub = sub; self.irregular = irregular
        self.swatch = swatch; self.symbol = symbol
    }
}

/// A section can carry a diagram instead of, or as well as, its cells.
enum CheatVisual {
    case none, positionMap, distanceMap, frequencyScale, clock, compass, body, face, familyTree
}

/// One line of a multi-column chart. `cells` must match the section's headers;
/// use "—" where a form doesn't exist rather than leaving a gap, so the eye can
/// see that the absence is real and not an omission.
struct CheatRow: Identifiable {
    let id = UUID()
    let cells: [String]
    init(_ cells: String...) { self.cells = cells }
}

struct CheatSection: Identifiable {
    let id = UUID()
    var title: String? = nil
    var note: String? = nil
    var columns: Int = 3
    var items: [CheatItem] = []
    /// Set these two together to render a headed chart instead of a card grid.
    var headers: [String] = []
    var rows: [CheatRow] = []
    var visual: CheatVisual = .none

    var isTable: Bool { !headers.isEmpty && !rows.isEmpty }
}

struct CheatSheet: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tintIndex: Int
    /// Extra search terms that don't appear in the visible text.
    let keywords: [String]
    let sections: [CheatSection]

    var tint: Color { .themeTile(tintIndex) }

    /// Whether anything on this sheet is flagged as breaking the pattern. Sheets
    /// with no irregulars shouldn't carry a legend explaining the highlighting.
    var hasIrregulars: Bool {
        sections.contains { $0.items.contains(where: \.irregular) }
    }

    /// Everything searchable about this sheet, lowercased. Built with plain
    /// appends — the equivalent chain of `+` and nested flatMaps is more than the
    /// type checker will infer in reasonable time.
    var haystack: String {
        var parts: [String] = [title, subtitle]
        parts.append(contentsOf: keywords)
        for section in sections {
            if let t = section.title { parts.append(t) }
            if let n = section.note { parts.append(n) }
            for item in section.items {
                parts.append(item.main)
                parts.append(item.sub)
            }
            for row in section.rows {
                parts.append(contentsOf: row.cells)
            }
        }
        return parts.joined(separator: " ").lowercased()
    }
}

enum CheatSheetLibrary {
    /// Built in chunks: a single 22-element literal is more than the type checker
    /// will infer in reasonable time.
    /// The sheet that hides the sudoku. Named rather than spelled out at each
    /// use: two separate views test for it, and a sheet id typo would silently
    /// remove the game with nothing failing to say so.
    static let sudokuHostSheetId = "numbers"

    static let all: [CheatSheet] = {
        var out: [CheatSheet] = []
        // Reached for constantly, from day one.
        out += [particles, time, numbers, verbForms, adjectives]
        // Needed as soon as you start arranging your life in Japanese.
        out += [counters, weekdays, dates, months, relativeTime]
        // The everyday closed sets.
        out += [questionWords, kosoado, greetings, directions, colours]
        // Useful, but looked up less often.
        out += [family, giving, conditionals, seeming, transitivity, adverbs, connectors]
        out += [onomatopoeia, teHelpers, voices, obligation, comparisons]
        out += [restaurant]
        // Specialist or late-stage.
        out += [weather, body, keigo, names]
        return out
    }()

    // MARK: Time

    static let time = CheatSheet(
        id: "time", title: "Telling the Time", subtitle: "Hours, minutes, AM/PM",
        icon: "clock.fill", tintIndex: 0,
        keywords: ["じ", "ふん", "ぷん", "はん", "clock", "oclock", "minutes", "hour"],
        sections: [
            CheatSection(title: "The dial",
                         note: "Three hours break the pattern — they're picked out here "
                             + "and in the list below.",
                         visual: .clock),
            CheatSection(title: "Hours 〜時 (ji)", columns: 3, items: [
                CheatItem("1時", "いちじ"), CheatItem("2時", "にじ"), CheatItem("3時", "さんじ"),
                CheatItem("4時", "よじ", irregular: true), CheatItem("5時", "ごじ"),
                CheatItem("6時", "ろくじ"),
                CheatItem("7時", "しちじ", irregular: true), CheatItem("8時", "はちじ"),
                CheatItem("9時", "くじ", irregular: true),
                CheatItem("10時", "じゅうじ"), CheatItem("11時", "じゅういちじ"),
                CheatItem("12時", "じゅうにじ"),
            ]),
            CheatSection(title: "Minutes 〜分",
                         note: "ふん after 2, 5, 7, 9 — ぷん after 1, 3, 4, 6, 8, 10.",
                         columns: 3, items: [
                CheatItem("1分", "いっぷん", irregular: true), CheatItem("2分", "にふん"),
                CheatItem("3分", "さんぷん", irregular: true),
                CheatItem("4分", "よんぷん", irregular: true), CheatItem("5分", "ごふん"),
                CheatItem("6分", "ろっぷん", irregular: true),
                CheatItem("7分", "ななふん"), CheatItem("8分", "はっぷん", irregular: true),
                CheatItem("9分", "きゅうふん"),
                CheatItem("10分", "じゅっぷん", irregular: true),
                CheatItem("30分", "さんじゅっぷん"), CheatItem("何分", "なんぷん — how many?"),
            ]),
            CheatSection(title: "Around the clock", columns: 2, items: [
                CheatItem("午前", "ごぜん — AM"), CheatItem("午後", "ごご — PM"),
                CheatItem("〜半", "〜はん — half past"), CheatItem("何時", "なんじ — what time?"),
                CheatItem("3時半", "さんじはん — 3:30"), CheatItem("午後4時", "ごごよじ — 4 PM"),
            ]),
        ])

    // MARK: Days of the month

    static let dates = CheatSheet(
        id: "dates", title: "Days of the Month", subtitle: "1st – 31st",
        icon: "calendar", tintIndex: 3,
        keywords: ["にち", "か", "date", "day", "ついたち", "calendar"],
        sections: [
            CheatSection(title: "1st – 10th",
                         note: "All ten are irregular. These are the ones to memorise.",
                         columns: 3, items: [
                CheatItem("1日", "ついたち", irregular: true), CheatItem("2日", "ふつか", irregular: true),
                CheatItem("3日", "みっか", irregular: true),
                CheatItem("4日", "よっか", irregular: true), CheatItem("5日", "いつか", irregular: true),
                CheatItem("6日", "むいか", irregular: true),
                CheatItem("7日", "なのか", irregular: true), CheatItem("8日", "ようか", irregular: true),
                CheatItem("9日", "ここのか", irregular: true),
                CheatItem("10日", "とおか", irregular: true),
            ]),
            CheatSection(title: "11th – 31st",
                         note: "Regular 〜にち, except the three marked.",
                         columns: 3, items: [
                CheatItem("11日", "じゅういちにち"), CheatItem("12日", "じゅうににち"),
                CheatItem("13日", "じゅうさんにち"),
                CheatItem("14日", "じゅうよっか", irregular: true), CheatItem("15日", "じゅうごにち"),
                CheatItem("16日", "じゅうろくにち"),
                CheatItem("17日", "じゅうしちにち"), CheatItem("18日", "じゅうはちにち"),
                CheatItem("19日", "じゅうくにち"),
                CheatItem("20日", "はつか", irregular: true), CheatItem("21日", "にじゅういちにち"),
                CheatItem("24日", "にじゅうよっか", irregular: true),
                CheatItem("30日", "さんじゅうにち"), CheatItem("31日", "さんじゅういちにち"),
                CheatItem("何日", "なんにち — which day?"),
            ]),
        ])

    // MARK: Months

    static let months = CheatSheet(
        id: "months", title: "Months", subtitle: "January – December",
        icon: "calendar.badge.clock", tintIndex: 6,
        keywords: ["がつ", "month", "january", "december", "しがつ"],
        sections: [
            CheatSection(note: "Regular 〜がつ, but 4, 7 and 9 take special readings — "
                             + "the same three that misbehave when telling the time.",
                         columns: 3, items: [
                CheatItem("1月", "いちがつ — Jan"), CheatItem("2月", "にがつ — Feb"),
                CheatItem("3月", "さんがつ — Mar"),
                CheatItem("4月", "しがつ — Apr", irregular: true),
                CheatItem("5月", "ごがつ — May"), CheatItem("6月", "ろくがつ — Jun"),
                CheatItem("7月", "しちがつ — Jul", irregular: true),
                CheatItem("8月", "はちがつ — Aug"),
                CheatItem("9月", "くがつ — Sep", irregular: true),
                CheatItem("10月", "じゅうがつ — Oct"), CheatItem("11月", "じゅういちがつ — Nov"),
                CheatItem("12月", "じゅうにがつ — Dec"),
                CheatItem("何月", "なんがつ — which month?"),
            ]),
        ])

    // MARK: Weekdays

    static let weekdays = CheatSheet(
        id: "weekdays", title: "Days of the Week", subtitle: "Monday – Sunday",
        icon: "calendar.day.timeline.left", tintIndex: 9,
        keywords: ["ようび", "monday", "sunday", "week", "げつようび", "gold", "metal", "planet", "element", "venus", "mars"],
        sections: [
            CheatSection(note: "Sun and moon, then the five classical planets — which in "
                             + "Japanese carry the names of the five elements. 金 is "
                             + "\"metal\" as an element but \"gold\" as an everyday word, "
                             + "so you'll meet both.",
                         columns: 2, items: [
                CheatItem("月曜日", "げつようび — Monday (moon)", symbol: "moon.fill"),
                CheatItem("火曜日", "かようび — Tuesday (fire)", symbol: "flame.fill"),
                CheatItem("水曜日", "すいようび — Wednesday (water)", symbol: "drop.fill"),
                CheatItem("木曜日", "もくようび — Thursday (wood)", symbol: "tree.fill"),
                CheatItem("金曜日", "きんようび — Friday (gold · metal)",
                          symbol: "circle.hexagongrid.fill"),
                CheatItem("土曜日", "どようび — Saturday (earth)", symbol: "globe.asia.australia.fill"),
                CheatItem("日曜日", "にちようび — Sunday (sun)", symbol: "sun.max.fill"),
                CheatItem("何曜日", "なんようび — which day?", symbol: "questionmark"),
            ]),
            CheatSection(
                title: "Why those five",
                note: "Each weekday kanji is also the first character of a planet, and "
                    + "that's where the element names come from.",
                headers: ["Day", "Planet", "Element"],
                rows: [
                    CheatRow("火曜日", "火星 かせい — Mars", "fire"),
                    CheatRow("水曜日", "水星 すいせい — Mercury", "water"),
                    CheatRow("木曜日", "木星 もくせい — Jupiter", "wood"),
                    CheatRow("金曜日", "金星 きんせい — Venus", "gold / metal"),
                    CheatRow("土曜日", "土星 どせい — Saturn", "earth"),
                ]),
        ])

    // MARK: Numbers

    static let numbers = CheatSheet(
        id: "numbers", title: "Numbers", subtitle: "1 – 10, hundreds, thousands",
        icon: "number", tintIndex: 1,
        keywords: ["ひゃく", "せん", "まん", "hundred", "thousand", "count", "ろっぴゃく"],
        sections: [
            CheatSection(title: "1 – 10", columns: 3, items: [
                CheatItem("一", "いち"), CheatItem("二", "に"), CheatItem("三", "さん"),
                CheatItem("四", "よん / し"), CheatItem("五", "ご"), CheatItem("六", "ろく"),
                CheatItem("七", "なな / しち"), CheatItem("八", "はち"),
                CheatItem("九", "きゅう / く"), CheatItem("十", "じゅう"),
            ]),
            CheatSection(title: "Hundreds 〜百",
                         note: "3, 6 and 8 change sound.", columns: 3, items: [
                CheatItem("百", "ひゃく — 100"), CheatItem("二百", "にひゃく"),
                CheatItem("三百", "さんびゃく", irregular: true),
                CheatItem("四百", "よんひゃく"), CheatItem("五百", "ごひゃく"),
                CheatItem("六百", "ろっぴゃく", irregular: true),
                CheatItem("七百", "ななひゃく"), CheatItem("八百", "はっぴゃく", irregular: true),
                CheatItem("九百", "きゅうひゃく"),
            ]),
            CheatSection(title: "Thousands and beyond",
                         note: "Japanese counts in units of 10,000 (万), not 1,000.",
                         columns: 3, items: [
                CheatItem("千", "せん — 1,000"), CheatItem("三千", "さんぜん", irregular: true),
                CheatItem("八千", "はっせん", irregular: true),
                CheatItem("一万", "いちまん — 10,000"), CheatItem("十万", "じゅうまん — 100,000"),
                CheatItem("百万", "ひゃくまん — 1,000,000"),
            ]),
        ])

    // MARK: Counters

    static let counters = CheatSheet(
        id: "counters", title: "Counters", subtitle: "つ, 人, 本, 枚, 匹 and friends",
        icon: "square.stack.3d.up.fill", tintIndex: 4,
        keywords: ["ひとつ", "ふたり", "ほん", "まい", "ひき", "counting", "counter"],
        sections: [
            CheatSection(title: "〜つ — the all-purpose counter",
                         note: "Works for most objects when you don't know the specific "
                             + "counter. Stops at 10.",
                         columns: 3, items: [
                CheatItem("一つ", "ひとつ"), CheatItem("二つ", "ふたつ"), CheatItem("三つ", "みっつ"),
                CheatItem("四つ", "よっつ"), CheatItem("五つ", "いつつ"), CheatItem("六つ", "むっつ"),
                CheatItem("七つ", "ななつ"), CheatItem("八つ", "やっつ"), CheatItem("九つ", "ここのつ"),
                CheatItem("十", "とお"), CheatItem("いくつ", "how many?"),
            ]),
            CheatSection(title: "People 〜人", columns: 3, items: [
                CheatItem("一人", "ひとり", irregular: true), CheatItem("二人", "ふたり", irregular: true),
                CheatItem("三人", "さんにん"),
                CheatItem("四人", "よにん", irregular: true), CheatItem("五人", "ごにん"),
                CheatItem("何人", "なんにん — how many?"),
            ]),
            CheatSection(title: "What each counter is for", columns: 1, items: [
                CheatItem("〜本 (ほん)", "Long thin things — pens, bottles, umbrellas. 1本 いっぽん, 3本 さんぼん, 6本 ろっぽん"),
                CheatItem("〜枚 (まい)", "Flat things — paper, plates, shirts, tickets"),
                CheatItem("〜個 (こ)", "Small round-ish objects — apples, erasers"),
                CheatItem("〜匹 (ひき)", "Small animals — cats, dogs, fish. 1匹 いっぴき, 3匹 さんびき"),
                CheatItem("〜台 (だい)", "Machines and vehicles — cars, computers"),
                CheatItem("〜冊 (さつ)", "Bound volumes — books, magazines"),
                CheatItem("〜杯 (はい)", "Cupfuls and glassfuls. 1杯 いっぱい, 3杯 さんばい"),
                CheatItem("〜回 (かい)", "Times / occurrences"),
                CheatItem("〜歳 (さい)", "Years of age. 20歳 is はたち"),
            ]),
        ])

    // MARK: こそあど

    static let kosoado = CheatSheet(
        id: "kosoado", title: "これ・それ・あれ・どれ", subtitle: "The こそあど words",
        icon: "hand.point.right.fill", tintIndex: 7,
        keywords: ["kosoado", "this", "that", "here", "there", "demonstrative", "この", "ここ"],
        sections: [
            CheatSection(title: "What each prefix means",
                         note: "The whole series is about distance from the two people talking.",
                         visual: .distanceMap),
            CheatSection(title: "The full set",
                         note: "Every row follows the same こ・そ・あ・ど pattern.",
                         columns: 4, items: [
                CheatItem("これ", "this one"), CheatItem("それ", "that one"),
                CheatItem("あれ", "that over there"), CheatItem("どれ", "which one?"),
                CheatItem("この〜", "this ~"), CheatItem("その〜", "that ~"),
                CheatItem("あの〜", "that ~ over there"), CheatItem("どの〜", "which ~?"),
                CheatItem("ここ", "here"), CheatItem("そこ", "there"),
                CheatItem("あそこ", "over there"), CheatItem("どこ", "where?"),
                CheatItem("こちら", "this way"), CheatItem("そちら", "that way"),
                CheatItem("あちら", "that way over there"), CheatItem("どちら", "which way?"),
                CheatItem("こんな", "this kind of"), CheatItem("そんな", "that kind of"),
                CheatItem("あんな", "that kind of, over there"), CheatItem("どんな", "what kind of?"),
                CheatItem("こう", "like this"), CheatItem("そう", "like that"),
                CheatItem("ああ", "like that, over there"), CheatItem("どう", "how?"),
            ]),
        ])

    // MARK: Question words

    static let questionWords = CheatSheet(
        id: "questions", title: "Question Words", subtitle: "who, what, when, where, why",
        icon: "questionmark.circle.fill", tintIndex: 10,
        keywords: ["なに", "だれ", "いつ", "どこ", "なぜ", "how much", "interrogative"],
        sections: [
            CheatSection(columns: 2, items: [
                CheatItem("何", "なに / なん — what"),
                CheatItem("誰", "だれ — who"),
                CheatItem("いつ", "when"),
                CheatItem("どこ", "where"),
                CheatItem("なぜ / どうして", "why"),
                CheatItem("どう", "how / in what way"),
                CheatItem("いくら", "how much (cost)"),
                CheatItem("いくつ", "how many / how old"),
                CheatItem("どの", "which ~"),
                CheatItem("どちら", "which of two / where (polite)"),
            ]),
            CheatSection(title: "Turning them into some- / any- / every- / no-",
                         note: "Add か for \"some\", も + negative for \"no\", でも for \"any\".",
                         columns: 1, items: [
                CheatItem("誰か・誰も・誰でも", "someone · no one (+neg) · anyone"),
                CheatItem("何か・何も・何でも", "something · nothing (+neg) · anything"),
                CheatItem("どこか・どこも・どこでも", "somewhere · nowhere (+neg) · anywhere"),
                CheatItem("いつか・いつも・いつでも", "sometime · always · anytime"),
            ]),
        ])

    // MARK: Keigo

    static let keigo = CheatSheet(
        id: "keigo", title: "Honorifics (敬語)", subtitle: "Plain · respectful · humble",
        icon: "person.2.fill", tintIndex: 2,
        keywords: ["keigo", "sonkeigo", "kenjougo", "polite", "尊敬語", "謙譲語", "humble",
                   "respectful", "formal"],
        sections: [
            CheatSection(
                title: "The special forms",
                note: "尊敬語 raises the other person — never use it about yourself. "
                    + "謙譲語 lowers you, so it's only ever for your own actions. "
                    + "A dash means that verb has no special form; use the general "
                    + "pattern below instead. Ordered by the plain form.",
                headers: ["Plain", "Respectful 尊敬語", "Humble 謙譲語"],
                rows: [
                    CheatRow("あげる  ageru", "—", "さしあげる"),
                    CheatRow("ある  aru", "—", "ござる (ございます)"),
                    CheatRow("会う  au", "お会いになる", "お目にかかる"),
                    CheatRow("行く  iku", "いらっしゃる · おいでになる", "まいる · うかがう"),
                    CheatRow("いる  iru", "いらっしゃる · おいでになる", "おる"),
                    CheatRow("言う  iu", "おっしゃる", "申す · 申し上げる"),
                    CheatRow("借りる  kariru", "—", "拝借する"),
                    CheatRow("聞く  kiku", "お聞きになる", "うかがう · 拝聴する"),
                    CheatRow("着る  kiru", "お召しになる", "—"),
                    CheatRow("くれる  kureru", "くださる", "—"),
                    CheatRow("来る  kuru", "いらっしゃる · お見えになる", "まいる"),
                    CheatRow("見る  miru", "ご覧になる", "拝見する"),
                    CheatRow("見せる  miseru", "—", "お目にかける · ご覧に入れる"),
                    CheatRow("もらう  morau", "—", "いただく · 頂戴する"),
                    CheatRow("寝る  neru", "お休みになる", "—"),
                    CheatRow("飲む  nomu", "召し上がる", "いただく"),
                    CheatRow("思う  omou", "—", "存じる"),
                    CheatRow("知る  shiru", "ご存じだ", "存じる · 存じ上げる"),
                    CheatRow("する  suru", "なさる", "いたす"),
                    CheatRow("食べる  taberu", "召し上がる", "いただく"),
                    CheatRow("尋ねる  tazuneru (ask)", "—", "うかがう"),
                    CheatRow("訪ねる  tazuneru (visit)", "—", "うかがう · お邪魔する"),
                    CheatRow("手伝う  tetsudau", "—", "お手伝いする"),
                    CheatRow("わかる  wakaru", "—", "承知する · かしこまる"),
                    CheatRow("読む  yomu", "お読みになる", "拝読する"),
                ]),
            CheatSection(
                title: "When there's no special form",
                note: "Wrap the ます-stem in one of these instead.",
                headers: ["Pattern", "Use", "Example"],
                rows: [
                    CheatRow("お + stem + になる", "Respectful", "お書きになる — (you) write"),
                    CheatRow("お + stem + する", "Humble", "お持ちする — (I) carry it for you"),
                    CheatRow("ご + noun + になる", "Respectful, する-nouns", "ご利用になる"),
                    CheatRow("ご + noun + する", "Humble, する-nouns", "ご案内する"),
                    CheatRow("〜ていらっしゃる", "Respectful 〜ている", "待っていらっしゃる"),
                    CheatRow("〜ております", "Humble 〜ている", "待っております"),
                    CheatRow("〜れる · 〜られる", "Lightly respectful", "書かれる — softer than なさる"),
                ]),
            CheatSection(
                title: "Polite fixtures",
                note: "The everyday words that swap out in formal speech.",
                headers: ["Plain", "Polite", "Meaning"],
                rows: [
                    CheatRow("です", "でございます", "is / am / are"),
                    CheatRow("いい", "よろしい", "good, all right"),
                    CheatRow("どう", "いかが", "how / how about"),
                    CheatRow("すみません", "申し訳ありません", "sorry / excuse me"),
                    CheatRow("わかりました", "かしこまりました", "understood"),
                    CheatRow("ちょっと", "少々 (しょうしょう)", "a little, a moment"),
                    CheatRow("だれ", "どなた", "who"),
                    CheatRow("どこ", "どちら", "where"),
                    CheatRow("〜さん", "〜様 (さま)", "name suffix"),
                ]),
        ])


    // MARK: Particles

    static let particles = CheatSheet(
        id: "particles", title: "Particles", subtitle: "は, が, を, に, で, へ, と…",
        icon: "link", tintIndex: 0,
        keywords: ["particle", "wa", "ga", "wo", "ni", "de", "he", "to", "mo", "kara", "made", "no"],
        sections: [
            CheatSection(
                title: "The core set",
                note: "は is written は but said wa. を is said o. へ is said e.",
                headers: ["Particle", "Marks", "Example"],
                rows: [
                    CheatRow("は  (wa)", "Topic — what we're talking about", "私は学生です"),
                    CheatRow("が", "Subject — new or emphasised information", "雨が降っている"),
                    CheatRow("を  (o)", "Direct object", "パンを食べる"),
                    CheatRow("に", "Time, destination, indirect object, existence", "七時に起きる"),
                    CheatRow("で", "Place of action, means, cause", "電車で行く"),
                    CheatRow("へ  (e)", "Direction (softer than に)", "東京へ行く"),
                    CheatRow("と", "\"and\" (exhaustive), \"with\", quoting", "友達と行く"),
                    CheatRow("も", "Also, too, even", "私も行く"),
                    CheatRow("の", "Possession, linking nouns", "私の本"),
                    CheatRow("から", "From (time or place), because", "九時から"),
                    CheatRow("まで", "Until, as far as", "五時まで"),
                    CheatRow("や", "\"and\" (a partial list)", "本やペン"),
                ]),
            CheatSection(
                title: "Sentence-final",
                headers: ["Particle", "Effect", "Example"],
                rows: [
                    CheatRow("か", "Makes a question", "行きますか"),
                    CheatRow("ね", "Seeking agreement — \"isn't it?\"", "きれいですね"),
                    CheatRow("よ", "Telling them something new", "違いますよ"),
                    CheatRow("よね", "Checking something you believe", "行きますよね"),
                    CheatRow("な", "Casual ね, or a blunt prohibition", "すごいな"),
                ]),
            CheatSection(
                title: "は vs が — the usual confusion",
                columns: 1, items: [
                    CheatItem("は sets the topic", "Everything after it is a comment about that topic. 象は鼻が長い — as for elephants, the nose is long."),
                    CheatItem("が points at the subject", "Answers \"which one?\" and introduces new information. 誰が来た? → 田中さんが来た."),
                    CheatItem("Question words take が", "誰が, 何が, どれが — never 誰は."),
                    CheatItem("が with likes and abilities", "日本語が分かる · すしが好きだ — the thing liked takes が."),
                ]),
        ])

    // MARK: Adjectives

    static let adjectives = CheatSheet(
        id: "adjectives", title: "Adjectives", subtitle: "い-adjectives vs な-adjectives",
        icon: "textformat.size", tintIndex: 5,
        keywords: ["adjective", "i-adjective", "na-adjective", "keiyoushi", "takai", "kirei"],
        sections: [
            CheatSection(
                title: "い-adjectives — 高い (expensive)",
                note: "The い itself conjugates. Never put だ after one.",
                headers: ["Form", "Plain", "Polite"],
                rows: [
                    CheatRow("Present", "高い", "高いです"),
                    CheatRow("Negative", "高くない", "高くないです · 高くありません"),
                    CheatRow("Past", "高かった", "高かったです"),
                    CheatRow("Past negative", "高くなかった", "高くなかったです"),
                    CheatRow("て-form", "高くて", "—"),
                    CheatRow("Adverb", "高く", "—"),
                ]),
            CheatSection(
                title: "な-adjectives — 静か (quiet)",
                note: "Behaves like a noun: it takes だ/です and needs な before a noun.",
                headers: ["Form", "Plain", "Polite"],
                rows: [
                    CheatRow("Present", "静かだ", "静かです"),
                    CheatRow("Negative", "静かじゃない", "静かじゃないです · ではありません"),
                    CheatRow("Past", "静かだった", "静かでした"),
                    CheatRow("Past negative", "静かじゃなかった", "静かじゃなかったです"),
                    CheatRow("て-form", "静かで", "—"),
                    CheatRow("Before a noun", "静かな部屋", "—"),
                    CheatRow("Adverb", "静かに", "—"),
                ]),
            CheatSection(
                title: "Traps",
                columns: 1, items: [
                    CheatItem("いい is irregular", "いい → よくない · よかった · よくて. The よ- stem comes from 良い.", irregular: true),
                    CheatItem("きれい, ゆうめい, きらい", "End in い but are な-adjectives. きれいな人, not きれいい人.", irregular: true),
                    CheatItem("〜くない vs 〜じゃない", "い-adj drops い for く. な-adj uses じゃ/では."),
                ]),
        ])

    // MARK: Transitivity

    static let transitivity = CheatSheet(
        id: "transitivity", title: "Transitive & Intransitive", subtitle: "開ける vs 開く",
        icon: "arrow.left.arrow.right", tintIndex: 8,
        keywords: ["transitive", "intransitive", "jidoushi", "tadoushi", "pairs", "自動詞", "他動詞"],
        sections: [
            CheatSection(
                note: "Transitive takes を — someone does it to something. Intransitive "
                    + "takes が — the thing does it itself. Japanese keeps these as "
                    + "separate verbs where English reuses one.",
                headers: ["Transitive (を)", "Intransitive (が)", "Meaning"],
                rows: [
                    CheatRow("開ける  akeru", "開く  aku", "open"),
                    CheatRow("閉める  shimeru", "閉まる  shimaru", "close"),
                    CheatRow("始める  hajimeru", "始まる  hajimaru", "begin"),
                    CheatRow("終える  oeru", "終わる  owaru", "finish"),
                    CheatRow("入れる  ireru", "入る  hairu", "put in / enter"),
                    CheatRow("出す  dasu", "出る  deru", "take out / go out"),
                    CheatRow("つける  tsukeru", "つく  tsuku", "switch on / come on"),
                    CheatRow("消す  kesu", "消える  kieru", "turn off / go out"),
                    CheatRow("落とす  otosu", "落ちる  ochiru", "drop / fall"),
                    CheatRow("壊す  kowasu", "壊れる  kowareru", "break"),
                    CheatRow("直す  naosu", "直る  naoru", "fix / be fixed"),
                    CheatRow("上げる  ageru", "上がる  agaru", "raise / rise"),
                    CheatRow("下げる  sageru", "下がる  sagaru", "lower / go down"),
                    CheatRow("集める  atsumeru", "集まる  atsumaru", "gather"),
                    CheatRow("決める  kimeru", "決まる  kimaru", "decide / be decided"),
                    CheatRow("変える  kaeru", "変わる  kawaru", "change"),
                    CheatRow("止める  tomeru", "止まる  tomaru", "stop"),
                    CheatRow("並べる  naraberu", "並ぶ  narabu", "line up"),
                    CheatRow("見つける  mitsukeru", "見つかる  mitsukaru", "find / be found"),
                ]),
        ])

    // MARK: Relative time

    static let relativeTime = CheatSheet(
        id: "reltime", title: "Yesterday, Today, Tomorrow", subtitle: "Relative time words",
        icon: "calendar.badge.exclamationmark", tintIndex: 1,
        keywords: ["kyou", "ashita", "kinou", "today", "tomorrow", "yesterday", "week", "next", "last"],
        sections: [
            CheatSection(
                headers: ["", "Last", "This", "Next"],
                rows: [
                    CheatRow("Day", "昨日 きのう", "今日 きょう", "明日 あした"),
                    CheatRow("±2 days", "一昨日 おととい", "—", "明後日 あさって"),
                    CheatRow("Week", "先週 せんしゅう", "今週 こんしゅう", "来週 らいしゅう"),
                    CheatRow("Month", "先月 せんげつ", "今月 こんげつ", "来月 らいげつ"),
                    CheatRow("Year", "去年 きょねん", "今年 ことし", "来年 らいねん"),
                    CheatRow("Morning", "—", "今朝 けさ", "明日の朝"),
                    CheatRow("Night", "昨夜 ゆうべ", "今夜 こんや", "明日の夜"),
                ]),
            CheatSection(
                title: "Parts of the day",
                columns: 3, items: [
                    CheatItem("朝", "あさ — morning"), CheatItem("昼", "ひる — midday"),
                    CheatItem("夕方", "ゆうがた — evening"),
                    CheatItem("夜", "よる — night"), CheatItem("午前中", "ごぜんちゅう — during the morning"),
                    CheatItem("毎日", "まいにち — every day"),
                    CheatItem("毎朝", "まいあさ — every morning"), CheatItem("毎週", "まいしゅう — every week"),
                    CheatItem("毎年", "まいとし — every year"),
                ]),
        ])

    // MARK: Greetings

    static let greetings = CheatSheet(
        id: "greetings", title: "Greetings & Set Phrases", subtitle: "What to say, and when",
        icon: "hand.wave.fill", tintIndex: 4,
        keywords: ["greeting", "hello", "thanks", "sorry", "konnichiwa", "arigatou", "sumimasen"],
        sections: [
            CheatSection(
                headers: ["Phrase", "Reading", "When"],
                rows: [
                    CheatRow("おはようございます", "ohayou gozaimasu", "Morning greeting"),
                    CheatRow("こんにちは", "konnichiwa", "Daytime greeting"),
                    CheatRow("こんばんは", "konbanwa", "Evening greeting"),
                    CheatRow("おやすみなさい", "oyasuminasai", "Going to bed"),
                    CheatRow("さようなら", "sayounara", "Goodbye — a long parting"),
                    CheatRow("じゃあ、また", "jaa, mata", "See you — casual"),
                    CheatRow("ありがとうございます", "arigatou gozaimasu", "Thank you"),
                    CheatRow("どういたしまして", "dou itashimashite", "You're welcome"),
                    CheatRow("すみません", "sumimasen", "Sorry / excuse me / thanks"),
                    CheatRow("ごめんなさい", "gomen nasai", "Sorry — apology only"),
                    CheatRow("いただきます", "itadakimasu", "Before eating"),
                    CheatRow("ごちそうさまでした", "gochisousama deshita", "After eating"),
                    CheatRow("いってきます", "ittekimasu", "Leaving home"),
                    CheatRow("いってらっしゃい", "itterasshai", "To the person leaving"),
                    CheatRow("ただいま", "tadaima", "Arriving home"),
                    CheatRow("おかえりなさい", "okaerinasai", "To the person returning"),
                    CheatRow("おつかれさまでした", "otsukaresama deshita", "After work, to a colleague"),
                    CheatRow("よろしくお願いします", "yoroshiku onegaishimasu", "Meeting someone; asking a favour"),
                    CheatRow("はじめまして", "hajimemashite", "First meeting"),
                    CheatRow("おめでとうございます", "omedetou gozaimasu", "Congratulations"),
                ]),
        ])

    // MARK: Adverbs

    static let adverbs = CheatSheet(
        id: "adverbs", title: "Frequency & Degree", subtitle: "always, often, a bit, not at all",
        icon: "chart.bar.fill", tintIndex: 7,
        keywords: ["adverb", "itsumo", "yoku", "amari", "zenzen", "totemo", "chotto", "frequency"],
        sections: [
            CheatSection(
                title: "How often",
                note: "These only mean anything relative to each other, so here they "
                    + "are on one scale.",
                visual: .frequencyScale),
            CheatSection(
                title: "How much",
                columns: 2, items: [
                    CheatItem("とても", "totemo — very"), CheatItem("すごく", "sugoku — really (casual)"),
                    CheatItem("かなり", "kanari — quite, fairly"), CheatItem("けっこう", "kekkou — pretty, rather"),
                    CheatItem("少し", "sukoshi — a little"), CheatItem("ちょっと", "chotto — a bit (casual)"),
                    CheatItem("もっと", "motto — more"), CheatItem("いちばん", "ichiban — most, -est"),
                    CheatItem("だいたい", "daitai — roughly"), CheatItem("ほとんど", "hotondo — almost all / hardly any"),
                ]),
        ])

    // MARK: Connectors

    static let connectors = CheatSheet(
        id: "connectors", title: "Connecting Sentences", subtitle: "but, so, and, then",
        icon: "arrow.turn.down.right", tintIndex: 10,
        keywords: ["conjunction", "connector", "demo", "shikashi", "dakara", "soshite", "however"],
        sections: [
            CheatSection(
                headers: ["Word", "Meaning", "Register"],
                rows: [
                    CheatRow("でも", "but, however", "Casual, starts a sentence"),
                    CheatRow("しかし", "however", "Formal, written"),
                    CheatRow("けど · けれども", "but", "Mid-sentence, casual → formal"),
                    CheatRow("が", "but", "Mid-sentence, formal"),
                    CheatRow("だから", "so, therefore", "Casual"),
                    CheatRow("ですから", "so, therefore", "Polite"),
                    CheatRow("それで", "and so, that's why", "Neutral"),
                    CheatRow("そして", "and then, and also", "Neutral"),
                    CheatRow("それから", "after that, and then", "Sequence"),
                    CheatRow("また", "also, again", "Neutral"),
                    CheatRow("それに", "moreover, what's more", "Adding a reason"),
                    CheatRow("ところで", "by the way", "Changing subject"),
                    CheatRow("つまり", "in other words", "Restating"),
                    CheatRow("たとえば", "for example", "Neutral"),
                ]),
        ])

    // MARK: Colours

    static let colours = CheatSheet(
        id: "colours", title: "Colours", subtitle: "Nouns and adjective forms",
        icon: "paintpalette.fill", tintIndex: 6,
        keywords: ["colour", "color", "aka", "ao", "midori", "red", "blue", "green"],
        sections: [
            CheatSection(
                note: "Six take true い-adjective forms. The rest are nouns "
                    + "and need の before a noun: 緑の車.",
                columns: 2, items: [
                    CheatItem("赤 · あか", "red — 赤い", swatch: Color(hex: "D93A2B")),
                    CheatItem("青 · あお", "blue — 青い", swatch: Color(hex: "2B5FD9")),
                    CheatItem("白 · しろ", "white — 白い", swatch: Color(hex: "FAFAF7")),
                    CheatItem("黒 · くろ", "black — 黒い", swatch: Color(hex: "1C1C1E")),
                    CheatItem("黄色 · きいろ", "yellow — 黄色い", swatch: Color(hex: "F2C230")),
                    CheatItem("茶色 · ちゃいろ", "brown — 茶色い", swatch: Color(hex: "8A5A2B")),
                    CheatItem("緑 · みどり", "green (noun only)", swatch: Color(hex: "2E9E5B")),
                    CheatItem("紫 · むらさき", "purple (noun only)", swatch: Color(hex: "7B4FC4")),
                    CheatItem("灰色 · はいいろ", "grey (noun only)", swatch: Color(hex: "9A9A9E")),
                    CheatItem("水色 · みずいろ", "light blue (noun only)", swatch: Color(hex: "76C8E8")),
                    CheatItem("ピンク", "pink (noun only)", swatch: Color(hex: "E86FA6")),
                    CheatItem("オレンジ", "orange (noun only)", swatch: Color(hex: "E8862B")),
                ]),
        ])

    // MARK: Body

    static let body = CheatSheet(
        id: "body", title: "The Body", subtitle: "Head to toe",
        icon: "figure.stand", tintIndex: 3,
        keywords: ["body", "atama", "me", "mimi", "te", "ashi", "head", "hand", "doctor", "hurt"],
        sections: [
            CheatSection(title: "Head to toe", visual: .body),
            CheatSection(title: "The face", visual: .face),
            CheatSection(title: "The rest", columns: 3, items: [
                CheatItem("歯", "は — tooth"), CheatItem("のど", "throat"),
                CheatItem("指", "ゆび — finger"),
                CheatItem("背中", "せなか — back"), CheatItem("腰", "こし — lower back"),
                CheatItem("膝", "ひざ — knee"),
                CheatItem("肘", "ひじ — elbow"), CheatItem("爪", "つめ — nail"),
                CheatItem("骨", "ほね — bone"),
            ]),
            CheatSection(title: "At the doctor", columns: 1, items: [
                CheatItem("〜が痛いです", "〜 ga itai desu — my 〜 hurts. 頭が痛いです."),
                CheatItem("熱があります", "netsu ga arimasu — I have a fever."),
                CheatItem("気分が悪いです", "kibun ga warui desu — I feel unwell."),
                CheatItem("風邪をひきました", "kaze wo hikimashita — I've caught a cold."),
            ]),
        ])

    // MARK: Weather

    static let weather = CheatSheet(
        id: "weather", title: "Weather & Seasons", subtitle: "晴れ, 雨, 春夏秋冬",
        icon: "cloud.sun.fill", tintIndex: 9,
        keywords: ["weather", "season", "hare", "ame", "yuki", "haru", "natsu", "rain", "snow"],
        sections: [
            CheatSection(title: "Weather", columns: 2, items: [
                CheatItem("晴れ", "はれ — clear", symbol: "sun.max.fill"),
                CheatItem("曇り", "くもり — cloudy", symbol: "cloud.fill"),
                CheatItem("雨", "あめ — rain", symbol: "cloud.rain.fill"),
                CheatItem("雪", "ゆき — snow", symbol: "snowflake"),
                CheatItem("風", "かぜ — wind", symbol: "wind"),
                CheatItem("台風", "たいふう — typhoon", symbol: "tropicalstorm"),
                CheatItem("暑い", "あつい — hot (weather)"), CheatItem("寒い", "さむい — cold (weather)"),
                CheatItem("暖かい", "あたたかい — warm"),
                CheatItem("涼しい", "すずしい — cool"), CheatItem("蒸し暑い", "むしあつい — humid"),
                CheatItem("天気", "てんき — weather"),
            ]),
            CheatSection(title: "Seasons", columns: 2, items: [
                CheatItem("春", "はる — spring", symbol: "leaf.fill"),
                CheatItem("夏", "なつ — summer", symbol: "sun.max.fill"),
                CheatItem("秋", "あき — autumn", symbol: "wind"),
                CheatItem("冬", "ふゆ — winter", symbol: "snowflake"),
            ]),
            CheatSection(title: "Hot and cold — two words each", columns: 1, items: [
                CheatItem("暑い vs 熱い", "あつい both. 暑い = hot weather · 熱い = hot to the touch.", irregular: true),
                CheatItem("寒い vs 冷たい", "さむい = cold weather · つめたい = cold to the touch.", irregular: true),
            ]),
        ])

    // MARK: Directions

    static let directions = CheatSheet(
        id: "directions", title: "Position & Direction", subtitle: "上, 下, 前, 隣…",
        icon: "location.fill", tintIndex: 2,
        keywords: ["position", "direction", "ue", "shita", "mae", "tonari", "above", "next to"],
        sections: [
            CheatSection(
                title: "Where each word points",
                note: "Used as 〜の上に, 〜の前に — the reference point takes の. "
                    + "机の上に本があります: the book is on the desk.",
                visual: .positionMap),
            CheatSection(
                title: "Relative to something else",
                note: "These describe a relationship between two things rather than "
                    + "a direction from one, so they don't sit on the diagram.",
                columns: 2, items: [
                CheatItem("隣", "となり — next door to (same kind)"),
                CheatItem("横", "よこ — beside (to the side)"),
                CheatItem("間", "あいだ — between two things"),
                CheatItem("近く", "ちかく — near"),
                CheatItem("向かい", "むかい — opposite, facing"),
                CheatItem("そば", "beside, close by"),
                CheatItem("真ん中", "まんなか — the very middle"),
                CheatItem("奥", "おく — the far end, deep inside"),
            ]),
            CheatSection(
                title: "Compass",
                note: "The four compounds are just the cardinals stuck together — but "
                    + "note the order is north/south first: 北東, not 東北.",
                visual: .compass),
            CheatSection(columns: 1, items: [
                CheatItem("東西南北", "とうざいなんぼく — \"all directions\", as a set phrase. "
                                    + "The order here is east-west-south-north."),
            ]),
        ])

    // MARK: Family

    static let family = CheatSheet(
        id: "family", title: "Family Terms", subtitle: "Yours vs someone else's",
        icon: "figure.2.and.child.holdinghands", tintIndex: 5,
        keywords: ["family", "ちち", "はは", "おとうさん", "brother", "sister", "parents",
                   "uncle", "aunt", "cousin", "grandmother", "grandfather", "in-law",
                   "兄", "姉", "弟", "妹", "おじ", "おば", "いとこ", "義理"],
        sections: [
            CheatSection(
                title: "The shape of a Japanese family",
                note: "There is no plain word for \"brother\" or \"sister\" — only older and "
                    + "younger. You have to know which one someone is before you can name them, "
                    + "and it is the first question you will be asked about your own siblings.",
                visual: .familyTree),

            CheatSection(
                title: "Your family vs someone else's",
                note: "Talking about your own family to an outsider, you use the plain, humble "
                    + "column. Talking about theirs — or speaking to your own relative directly — "
                    + "you use the polite one. So you call your own mother お母さん to her face, "
                    + "and 母 when telling a colleague about her.",
                headers: ["", "Your own", "Someone else's"],
                rows: [
                    CheatRow("family", "家族\nかぞく", "ご家族\nごかぞく"),
                    CheatRow("parents", "両親\nりょうしん", "ご両親\nごりょうしん"),
                    CheatRow("father", "父\nちち", "お父さん\nおとうさん"),
                    CheatRow("mother", "母\nはは", "お母さん\nおかあさん"),
                    CheatRow("older brother", "兄\nあに", "お兄さん\nおにいさん"),
                    CheatRow("older sister", "姉\nあね", "お姉さん\nおねえさん"),
                    CheatRow("younger brother", "弟\nおとうと", "弟さん\nおとうとさん"),
                    CheatRow("younger sister", "妹\nいもうと", "妹さん\nいもうとさん"),
                    CheatRow("siblings", "兄弟\nきょうだい", "ご兄弟\nごきょうだい"),
                    CheatRow("husband", "夫\nおっと", "ご主人\nごしゅじん"),
                    CheatRow("wife", "妻\nつま", "奥さん\nおくさん"),
                    CheatRow("child", "子供\nこども", "お子さん\nおこさん"),
                    CheatRow("son", "息子\nむすこ", "息子さん\nむすこさん"),
                    CheatRow("daughter", "娘\nむすめ", "娘さん\nむすめさん"),
                    CheatRow("grandfather", "祖父\nそふ", "おじいさん"),
                    CheatRow("grandmother", "祖母\nそぼ", "おばあさん"),
                    CheatRow("grandchild", "孫\nまご", "お孫さん\nおまごさん"),
                ]),

            CheatSection(
                title: "Aunts, uncles and cousins",
                note: "おじ and おば each have two kanji, read identically. 伯 is used when they "
                    + "are older than your parent, 叔 when younger — a distinction you only meet "
                    + "in writing, and one many Japanese people look up too.",
                headers: ["", "Your own", "Someone else's"],
                rows: [
                    CheatRow("uncle (older)", "伯父\nおじ", "おじさん"),
                    CheatRow("uncle (younger)", "叔父\nおじ", "おじさん"),
                    CheatRow("aunt (older)", "伯母\nおば", "おばさん"),
                    CheatRow("aunt (younger)", "叔母\nおば", "おばさん"),
                    CheatRow("cousin", "いとこ", "いとこ"),
                    CheatRow("nephew", "甥\nおい", "甥御さん\nおいごさん"),
                    CheatRow("niece", "姪\nめい", "姪御さん\nめいごさん"),
                    CheatRow("relatives", "親戚\nしんせき", "ご親戚\nごしんせき"),
                ]),

            CheatSection(
                title: "In-laws",
                note: "義 marks a relationship by marriage. Spoken aloud you still say お父さん "
                    + "and お母さん — the kanji does the distinguishing, not the sound.",
                headers: ["", "Written", "Spoken"],
                rows: [
                    CheatRow("father-in-law", "義父\nぎふ", "お義父さん\nおとうさん"),
                    CheatRow("mother-in-law", "義母\nぎぼ", "お義母さん\nおかあさん"),
                    CheatRow("brother-in-law", "義兄\nぎけい / 義弟\nぎてい", "お兄さん / 弟さん"),
                    CheatRow("sister-in-law", "義姉\nぎし / 義妹\nぎまい", "お姉さん / 妹さん"),
                ]),

            CheatSection(
                title: "Which form, when",
                note: "The same person can be 母 or お母さん depending on who you are "
                    + "speaking to. The rule is about the listener, not about her.",
                headers: ["Who you're talking to", "What you say"],
                rows: [
                    CheatRow("Your mother, to her face", "お母さん"),
                    CheatRow("Anyone outside the family, about her", "母"),
                    CheatRow("A friend, casually, about her", "うちの母"),
                    CheatRow("Anyone, about *their* mother", "お母さん"),
                ]),

            CheatSection(
                title: "Two words to be careful with",
                note: "First: ご主人 literally means \"master\", and 奥さん means \"the one "
                    + "inside\" — both come from a time when that described the household. "
                    + "Plenty of people still use them, but many younger speakers avoid them. "
                    + "夫 and 妻 are neutral and safe with anyone.\n\n"
                    + "Second: the おじ／おば words do double duty. おじさん and おばさん also "
                    + "simply mean \"middle-aged man\" and \"middle-aged woman\", and おじいさん "
                    + "and おばあさん mean \"old man\" and \"old woman\". So calling a stranger "
                    + "おばさん is not a friendly \"auntie\" — you are telling her she looks "
                    + "middle-aged.",
                columns: 2, items: [
                CheatItem("夫 · 妻", "neutral — safe with anyone"),
                CheatItem("ご主人 · 奥さん", "older, gendered — many now avoid these"),
                CheatItem("パートナー", "increasingly common, and avoids the issue"),
                CheatItem("おばさん", "also just \"middle-aged woman\" — careful"),
            ]),

            CheatSection(
                title: "More family words",
                columns: 2, items: [
                CheatItem("親\nおや", "parent, as a category rather than a person"),
                CheatItem("赤ちゃん\nあかちゃん", "baby"),
                CheatItem("双子\nふたご", "twins"),
                CheatItem("一人っ子\nひとりっこ", "an only child"),
                CheatItem("長男\nちょうなん", "eldest son"),
                CheatItem("長女\nちょうじょ", "eldest daughter"),
                CheatItem("末っ子\nすえっこ", "the youngest child"),
                CheatItem("家内\nかない", "one's own wife — traditional, dated"),
            ]),
        ])

    // MARK: Giving & receiving

    static let giving = CheatSheet(
        id: "giving", title: "Giving & Receiving", subtitle: "あげる・くれる・もらう",
        icon: "hands.and.sparkles.fill", tintIndex: 3,
        keywords: ["giving", "receiving", "あげる", "くれる", "もらう", "いただく",
                   "くださる", "さしあげる", "favour", "favor", "ageru", "kureru", "morau"],
        sections: [
            CheatSection(
                title: "Which verb",
                note: "English uses \"give\" in both directions. Japanese does not. The verb "
                    + "changes depending on which way the thing moves relative to you — and "
                    + "くれる is the one with no English equivalent, so it is the one to learn "
                    + "first.",
                headers: ["Verb", "Direction", "Example"],
                rows: [
                    CheatRow("あげる", "you → someone else\n(never toward you)",
                             "私は友達に本をあげた\nI gave my friend a book"),
                    CheatRow("くれる", "someone → you\n(or your family)",
                             "友達が私に本をくれた\nMy friend gave me a book"),
                    CheatRow("もらう", "you receive\nfrom someone",
                             "私は友達に本をもらった\nI got a book from my friend"),
                ]),

            CheatSection(
                title: "Particles",
                note: "Get these wrong and the sentence reverses. Note that もらう marks the "
                    + "giver with に or から, while あげる marks the receiver with に.",
                headers: ["Verb", "Pattern"],
                rows: [
                    CheatRow("あげる", "giver は — receiver に — thing を"),
                    CheatRow("くれる", "giver が — me に — thing を"),
                    CheatRow("もらう", "receiver は — giver に / から — thing を"),
                ]),

            CheatSection(
                title: "Politeness",
                note: "Same three directions, adjusted for who is above or below whom. "
                    + "やる is for plants, animals and small children; used of an adult it "
                    + "sounds rough.",
                headers: ["Direction", "Humble / plain / honorific"],
                rows: [
                    CheatRow("giving outward", "さしあげる  ›  あげる  ›  やる"),
                    CheatRow("giving to me", "くださる  ›  くれる"),
                    CheatRow("receiving", "いただく  ›  もらう"),
                ]),

            CheatSection(
                title: "Doing something for someone",
                note: "Attach the same three verbs to a て-form and they stop moving objects "
                    + "and start moving favours. 〜てあげる can sound like you want credit for "
                    + "it, so 〜ましょうか is often the kinder offer.",
                columns: 1, items: [
                CheatItem("〜てあげる", "do something for someone else — 手伝ってあげる, I'll help you"),
                CheatItem("〜てくれる", "someone does something for me — 手伝ってくれた, they helped me"),
                CheatItem("〜てもらう", "have someone do something — 手伝ってもらった, I got them to help"),
                CheatItem("〜ていただく", "the humble form — 手伝っていただけますか, could you help me?"),
            ]),
        ])

    // MARK: Conditionals

    static let conditionals = CheatSheet(
        id: "conditionals", title: "If & When", subtitle: "と・ば・たら・なら",
        icon: "arrow.triangle.branch", tintIndex: 7,
        keywords: ["conditional", "if", "when", "と", "ば", "たら", "なら",
                   "tara", "nara", "eba", "condition"],
        sections: [
            CheatSection(
                title: "The four, at a glance",
                note: "たら is the flexible one. If you are unsure which to use, たら is almost "
                    + "always grammatical — the others are narrower, and each has a restriction "
                    + "worth knowing.",
                headers: ["", "Use it for", "Example"],
                rows: [
                    CheatRow("と", "an automatic result —\nA always causes B",
                             "春になると桜が咲く\nWhen spring comes, the cherries bloom"),
                    CheatRow("ば", "a general condition,\nproverbs, hypotheticals",
                             "安ければ買います\nIf it's cheap, I'll buy it"),
                    CheatRow("たら", "if or when — the\nall-purpose one",
                             "雨が降ったら行きません\nIf it rains, I won't go"),
                    CheatRow("なら", "if it's true that…\npicking up what was said",
                             "日本に行くなら京都へ\nIf you're going to Japan, go to Kyoto"),
                ]),

            CheatSection(
                title: "How they're formed",
                headers: ["", "Verb", "い-adjective", "Noun / な-adj"],
                rows: [
                    CheatRow("と", "行く + と", "安い + と", "静かだ + と"),
                    CheatRow("ば", "行けば", "安ければ", "静かなら(ば)"),
                    CheatRow("たら", "行ったら", "安かったら", "静かだったら"),
                    CheatRow("なら", "行くなら", "安いなら", "静かなら"),
                ]),

            CheatSection(
                title: "The catches",
                columns: 1, items: [
                CheatItem("と takes no will", "The second half can't be a request, an order or an intention. ✗ 春になると花見をしましょう"),
                CheatItem("たら is sequential", "A happens, then B. It's the only one that comfortably reports a one-off past event: 家に帰ったら誰もいなかった."),
                CheatItem("なら can run backwards", "The なら clause needn't come first in time — 日本に行くなら、カメラを買ったほうがいい means buy it before you go."),
                CheatItem("ば likes generalities", "Proverbs live here: 塵も積もれば山となる — even dust piled up becomes a mountain."),
            ]),
        ])

    // MARK: Seems & looks like

    static let seeming = CheatSheet(
        id: "seeming", title: "Seems & Looks Like", subtitle: "そう・よう・みたい・らしい",
        icon: "eye.fill", tintIndex: 4,
        keywords: ["そう", "よう", "みたい", "らしい", "seems", "looks like", "apparently",
                   "hearsay", "sou", "you", "mitai", "rashii"],
        sections: [
            CheatSection(
                title: "The two そう — this is the trap",
                note: "Same syllable, opposite meanings, told apart only by what it attaches "
                    + "to. On a verb stem it means you can see it coming. On a plain form it "
                    + "means somebody told you.",
                headers: ["", "Attaches to", "Means"],
                rows: [
                    CheatRow("降りそう", "ます-stem\n降ります → 降り", "It looks like it'll rain\n— from the sky"),
                    CheatRow("降るそう", "plain form\n降る", "I hear it's going to rain\n— from someone"),
                ]),

            CheatSection(
                title: "All four, side by side",
                note: "Ordered from what you can see to what you were told. みたい is just the "
                    + "casual よう — same job, softer register.",
                headers: ["", "Based on", "Example"],
                rows: [
                    CheatRow("〜そう\n(stem)", "what's in front of you\nright now",
                             "おいしそう！\nThat looks delicious"),
                    CheatRow("〜ようだ", "your own reasoning\nfrom evidence",
                             "誰かいたようだ\nSomeone seems to have been here"),
                    CheatRow("〜みたい", "the same, spoken\ncasually",
                             "雨が降るみたい\nLooks like rain"),
                    CheatRow("〜らしい", "what you heard\nfrom elsewhere",
                             "彼は来ないらしい\nApparently he isn't coming"),
                ]),

            CheatSection(
                title: "How they attach",
                headers: ["", "Verb", "い-adj", "な-adj / noun"],
                rows: [
                    CheatRow("〜そう (looks)", "降りそう", "おいしそう", "元気そう / —"),
                    CheatRow("〜そう (heard)", "降るそうだ", "おいしいそうだ", "元気だそうだ"),
                    CheatRow("〜ようだ", "降るようだ", "おいしいようだ", "元気なようだ / 雨のようだ"),
                    CheatRow("〜みたい", "降るみたい", "おいしいみたい", "元気みたい / 雨みたい"),
                    CheatRow("〜らしい", "降るらしい", "おいしいらしい", "元気らしい / 雨らしい"),
                ]),

            CheatSection(
                title: "Catches", columns: 1, items: [
                CheatItem("いい → よさそう", "Not いさそう. ない behaves the same way: なさそう."),
                CheatItem("〜そう can't report the past", "For \"it looked like it had rained\", use ようだ, not そう."),
                CheatItem("らしい has a second job", "After a noun it means \"typical of\" — 男らしい, manly; 春らしい, properly spring-like."),
                CheatItem("ようだ also makes similes", "雪のように白い — white like snow."),
            ]),
        ])

    // MARK: Onomatopoeia

    static let onomatopoeia = CheatSheet(
        id: "onomatopoeia", title: "Sound & Feeling Words", subtitle: "擬音語・擬態語",
        icon: "waveform", tintIndex: 9,
        keywords: ["onomatopoeia", "擬音語", "擬態語", "giongo", "gitaigo", "sound words",
                   "ドキドキ", "ぺこぺこ", "キラキラ", "mimetic"],
        sections: [
            CheatSection(
                note: "Japanese uses these far more than English does, and in places English "
                    + "never would — describing textures, moods and the way someone sleeps. "
                    + "They usually come in pairs of repeated syllables. Actual sounds are "
                    + "normally written in katakana; states and feelings in hiragana.",
                columns: 1, items: []),

            CheatSection(title: "Sounds you can hear 擬音語", columns: 2, items: [
                CheatItem("ワンワン", "a dog barking", symbol: "pawprint.fill"),
                CheatItem("ニャーニャー", "a cat", symbol: "pawprint.fill"),
                CheatItem("ザーザー", "rain pouring down", symbol: "cloud.heavyrain.fill"),
                CheatItem("ポツポツ", "the first few drops", symbol: "cloud.drizzle.fill"),
                CheatItem("ゴロゴロ", "thunder rumbling", symbol: "cloud.bolt.fill"),
                CheatItem("ガタガタ", "something rattling", symbol: "wind"),
                CheatItem("パチパチ", "clapping, or crackling", symbol: "hands.clap.fill"),
                CheatItem("ペラペラ", "fluent in a language", symbol: "text.bubble.fill"),
            ]),

            CheatSection(title: "States and feelings 擬態語", columns: 2, items: [
                CheatItem("ドキドキ", "heart pounding — nerves or excitement", symbol: "heart.fill"),
                CheatItem("ワクワク", "excited, looking forward to it", symbol: "sparkles"),
                CheatItem("イライラ", "irritated, on edge", symbol: "bolt.fill"),
                CheatItem("ぺこぺこ", "starving — お腹がぺこぺこ", symbol: "fork.knife"),
                CheatItem("くたくた", "worn out, exhausted", symbol: "zzz"),
                CheatItem("キラキラ", "sparkling, glittering", symbol: "sparkle"),
                CheatItem("ぴかぴか", "shiny, spotless", symbol: "sun.max.fill"),
                CheatItem("ふわふわ", "soft and fluffy", symbol: "cloud.fill"),
                CheatItem("びしょびしょ", "soaked through", symbol: "drop.fill"),
                CheatItem("つるつる", "smooth or slippery", symbol: "circle.fill"),
            ]),

            CheatSection(
                title: "The 〜り adverbs",
                note: "These behave like ordinary adverbs and turn up constantly in speech. "
                    + "Worth learning as vocabulary rather than as sound words.",
                columns: 2, items: [
                CheatItem("ゆっくり", "slowly, unhurriedly"),
                CheatItem("はっきり", "clearly, plainly"),
                CheatItem("しっかり", "firmly, properly"),
                CheatItem("ぐっすり", "sleeping soundly — ぐっすり寝た"),
                CheatItem("さっぱり", "refreshed — or \"not at all\" with a negative"),
                CheatItem("のんびり", "at a relaxed, easy pace"),
                CheatItem("そろそろ", "about time to — そろそろ行こう"),
                CheatItem("だんだん", "gradually, little by little"),
            ]),
        ])

    // MARK: Passive, causative, potential

    static let voices = CheatSheet(
        id: "voices", title: "Passive · Causative · Potential", subtitle: "られる・させる・できる",
        icon: "arrow.left.arrow.right", tintIndex: 6,
        keywords: ["passive", "causative", "potential", "受身", "使役", "可能",
                   "られる", "させる", "できる", "rareru", "saseru", "dekiru", "ra-nuki"],
        sections: [
            CheatSection(
                title: "What each one does",
                headers: ["", "Means", "Example"],
                rows: [
                    CheatRow("Passive\n受身", "it was done\nto someone", "先生に褒められた\nI was praised by the teacher"),
                    CheatRow("Causative\n使役", "made or let\nsomeone do it", "子供に野菜を食べさせた\nI made the child eat vegetables"),
                    CheatRow("Potential\n可能", "can do it", "日本語が話せる\nI can speak Japanese"),
                    CheatRow("Causative-\npassive", "was made\nto do it", "野菜を食べさせられた\nI was made to eat vegetables"),
                ]),

            CheatSection(
                title: "Building them — the two regular groups",
                note: "Group 1 works off the あ-row stem; Group 2 just drops る. Note the "
                    + "collision in the last column and the row above it.",
                headers: ["", "Group 1 · 書く", "Group 2 · 食べる"],
                rows: [
                    CheatRow("Passive", "書かれる", "食べられる"),
                    CheatRow("Causative", "書かせる", "食べさせる"),
                    CheatRow("Potential", "書ける", "食べられる"),
                    CheatRow("Caus-passive", "書かされる", "食べさせられる"),
                ]),

            CheatSection(
                title: "The two irregulars",
                headers: ["", "する", "来る  くる"],
                rows: [
                    CheatRow("Passive", "される", "来られる  こられる"),
                    CheatRow("Causative", "させる", "来させる  こさせる"),
                    CheatRow("Potential", "できる", "来られる  こられる"),
                    CheatRow("Caus-passive", "させられる", "来させられる  こさせられる"),
                ]),

            CheatSection(
                title: "Particles change too",
                note: "The potential is the one that catches people: the object stops taking "
                    + "を and takes が instead.",
                headers: ["", "Pattern"],
                rows: [
                    CheatRow("Passive", "victim は — doer に — verb られる"),
                    CheatRow("Causative", "boss は — person に / を — thing を — verb させる"),
                    CheatRow("Potential", "person は — thing が — verb られる／ける"),
                ]),

            CheatSection(
                title: "Catches", columns: 1, items: [
                CheatItem("食べられる is two things", "For Group 2 verbs the passive and the potential are identical. Only context tells them apart."),
                CheatItem("ら抜き言葉", "In speech many people say 食べれる for the potential, which removes the ambiguity. Extremely common, still avoided in writing."),
                CheatItem("する has no られる potential", "It becomes できる, a separate verb."),
                CheatItem("The suffering passive", "Japanese can make the passive out of an intransitive verb to say something inconvenienced you: 雨に降られた — I got rained on, and it ruined things."),
                CheatItem("Causative に vs を", "を for making someone do an intransitive action (子供を行かせる); に when there is already a を object (子供に野菜を食べさせる)."),
            ]),
        ])

    // MARK: て-form helpers

    static let teHelpers = CheatSheet(
        id: "tehelpers", title: "て-form Helpers", subtitle: "ている・ておく・てしまう・てみる",
        icon: "square.stack.3d.up.fill", tintIndex: 1,
        keywords: ["ている", "てある", "ておく", "てしまう", "てみる", "ていく", "てくる",
                   "teiru", "teoku", "teshimau", "temiru", "helper", "auxiliary"],
        sections: [
            CheatSection(
                title: "Attach a verb to a て-form and it changes the meaning",
                note: "All of these take the plain て-form and add a second verb behind it. "
                    + "They are extremely common in speech — far more so than textbooks "
                    + "usually suggest.",
                headers: ["", "Means", "Example"],
                rows: [
                    CheatRow("〜ている", "happening now, or\na state that continues", "食べている\nis eating / 住んでいる lives"),
                    CheatRow("〜てある", "someone did it,\nand it stays done", "窓が開けてある\nthe window has been opened"),
                    CheatRow("〜ておく", "do it in advance,\nor leave it that way", "買っておく\nbuy it ahead of time"),
                    CheatRow("〜てしまう", "finish it off —\nor regret it", "食べてしまった\nate it all / ate it by mistake"),
                    CheatRow("〜てみる", "try it and see", "食べてみる\ntry eating it"),
                    CheatRow("〜ていく", "carry on from\nhere onward", "増えていく\nwill keep increasing"),
                    CheatRow("〜てくる", "up to now, or\ngo and come back", "増えてきた\nhas been increasing"),
                ]),

            CheatSection(
                title: "Contractions you will actually hear",
                note: "Nobody says these in full in casual speech. Recognising the short "
                    + "forms matters more than producing them.",
                headers: ["Full", "Casual", "Example"],
                rows: [
                    CheatRow("〜ておく", "〜とく", "買っとく"),
                    CheatRow("〜でおく", "〜どく", "読んどく"),
                    CheatRow("〜てしまう", "〜ちゃう", "食べちゃった"),
                    CheatRow("〜でしまう", "〜じゃう", "飲んじゃった"),
                    CheatRow("〜ている", "〜てる", "食べてる"),
                ]),

            CheatSection(
                title: "The two that get mixed up", columns: 1, items: [
                CheatItem("ている vs てある", "窓が開いている — the window is open, no comment on why. 窓が開けてある — someone opened it on purpose and left it. てある always implies an agent."),
                CheatItem("ていく vs てくる", "Think of a timeline. くる brings you up to now (寒くなってきた — it's been getting colder). いく carries on into the future (寒くなっていく — it'll keep getting colder)."),
                CheatItem("てしまう is not always regret", "宿題をしてしまった can mean \"I finished the homework\" as easily as \"I did it, unfortunately\". Tone and context decide."),
            ]),
        ])

    // MARK: Must, may, mustn't

    static let obligation = CheatSheet(
        id: "obligation", title: "Must, May, Mustn't", subtitle: "Permission & obligation",
        icon: "checkmark.shield.fill", tintIndex: 2,
        keywords: ["must", "have to", "may", "permission", "obligation", "forbidden",
                   "なければならない", "てもいい", "てはいけない", "なくてもいい",
                   "ほうがいい", "なきゃ", "なくちゃ"],
        sections: [
            CheatSection(
                title: "The whole set",
                note: "English has four separate words — may, needn't, mustn't, must. Japanese "
                    + "builds all four out of the て-form and the ない-form, which is why they "
                    + "look so alike.",
                headers: ["Means", "Pattern", "Example"],
                rows: [
                    CheatRow("you may", "〜てもいい", "食べてもいいです\nYou may eat"),
                    CheatRow("you needn't", "〜なくてもいい", "食べなくてもいいです\nYou don't have to eat"),
                    CheatRow("you mustn't", "〜てはいけない", "食べてはいけません\nYou mustn't eat"),
                    CheatRow("you must", "〜なければならない", "食べなければなりません\nYou must eat"),
                    CheatRow("you should", "〜たほうがいい", "食べたほうがいい\nYou'd better eat"),
                    CheatRow("you shouldn't", "〜ないほうがいい", "食べないほうがいい\nYou'd better not eat"),
                ]),

            CheatSection(
                title: "Why \"must\" is a double negative",
                note: "There is no single word for must. 食べなければならない is literally "
                    + "\"if I don't eat, it won't do\" — a negative condition plus a negative "
                    + "result. Once you see that, the whole family stops looking arbitrary.",
                headers: ["Piece", "Literally"],
                rows: [
                    CheatRow("食べ・なければ", "if (I) don't eat"),
                    CheatRow("なら・ない", "it won't become / it won't do"),
                    CheatRow("together", "I have to eat"),
                ]),

            CheatSection(
                title: "All the variants mean the same thing",
                note: "Any negative condition plus any negative result works. Textbooks pick "
                    + "one; real speech uses all of them.",
                columns: 2, items: [
                CheatItem("〜なければならない", "the formal, written one"),
                CheatItem("〜なければいけない", "everyday spoken"),
                CheatItem("〜なくてはならない", "same again"),
                CheatItem("〜なくてはいけない", "same again"),
            ]),

            CheatSection(
                title: "Casual forms you'll hear",
                note: "The second half is usually dropped entirely. 行かなきゃ on its own is a "
                    + "complete, natural sentence — \"I've got to go\".",
                headers: ["Full", "Casual", "In speech"],
                rows: [
                    CheatRow("〜なければ", "〜なきゃ", "行かなきゃ"),
                    CheatRow("〜なくては", "〜なくちゃ", "行かなくちゃ"),
                    CheatRow("〜てはいけない", "〜ちゃだめ", "食べちゃだめ"),
                    CheatRow("〜ではいけない", "〜じゃだめ", "飲んじゃだめ"),
                ]),
        ])

    // MARK: Comparisons

    static let comparisons = CheatSheet(
        id: "comparisons", title: "Comparing Things", subtitle: "より・ほう・一番",
        icon: "arrow.up.arrow.down", tintIndex: 8,
        keywords: ["comparison", "より", "ほう", "一番", "same", "same as", "どちら",
                   "ichiban", "yori", "hou", "than", "most", "best"],
        sections: [
            CheatSection(
                title: "The patterns",
                note: "Japanese has no -er or -est. The adjective never changes; the sentence "
                    + "does the comparing.",
                headers: ["Meaning", "Pattern", "Example"],
                rows: [
                    CheatRow("A is more ~\nthan B", "A は B より ~", "日本は韓国より大きい\nJapan is bigger than Korea"),
                    CheatRow("B is the\nmore ~ one", "A より B の ほうが ~", "紅茶よりコーヒーのほうが好き\nI prefer coffee to tea"),
                    CheatRow("the most ~", "〜の中で 一番 ~", "クラスで一番背が高い\nthe tallest in the class"),
                    CheatRow("as ~ as", "A は B と 同じくらい ~", "兄と同じくらい高い\nas tall as my brother"),
                    CheatRow("not as ~ as", "A は B ほど ~ない", "日本はロシアほど大きくない\nJapan isn't as big as Russia"),
                ]),

            CheatSection(
                title: "Asking, and answering",
                note: "どちら for a choice between two; 一番 with a group. Note that the answer "
                    + "to a どちら question almost always comes back with ほう.",
                headers: ["Question", "Answer"],
                rows: [
                    CheatRow("犬と猫とどちらが好きですか\nDogs or cats?", "猫のほうが好きです\nI prefer cats"),
                    CheatRow("果物の中で何が一番好きですか\nFavourite fruit?", "りんごが一番好きです\nApples, most of all"),
                ]),

            CheatSection(
                title: "Catches", columns: 1, items: [
                CheatItem("ほど needs a negative", "〜ほど〜ない only works in the negative. For the positive, use より."),
                CheatItem("The group takes で or の中で", "クラスで一番 — in the class. 果物の中で — among fruits. Both are common; の中で is clearer with a plain noun."),
                CheatItem("どちら, not どれ, for two", "どれ is for three or more. Spoken casually, どちら becomes どっち."),
            ]),
        ])

    // MARK: Eating out

    static let restaurant = CheatSheet(
        id: "restaurant", title: "Eating Out", subtitle: "Ordering, paying, and what to expect",
        icon: "fork.knife", tintIndex: 10,
        keywords: ["restaurant", "food", "order", "menu", "bill", "cheque", "check",
                   "いらっしゃいませ", "お会計", "定食", "お通し", "izakaya"],
        sections: [
            CheatSection(title: "What the staff will say first", columns: 1, items: [
                CheatItem("いらっしゃいませ", "Welcome — said to everyone who walks in. No reply is expected.", symbol: "hand.wave.fill"),
                CheatItem("何名様ですか\nなんめいさまですか", "How many in your party?", symbol: "person.2.fill"),
                CheatItem("こちらへどうぞ", "This way, please.", symbol: "arrow.forward"),
                CheatItem("ご注文はお決まりですか\nごちゅうもんはおきまりですか", "Are you ready to order?", symbol: "list.bullet.clipboard.fill"),
            ]),

            CheatSection(title: "What you say", columns: 2, items: [
                CheatItem("二人です\nふたりです", "Two of us"),
                CheatItem("すみません", "how you call a waiter over"),
                CheatItem("メニューをください", "The menu, please"),
                CheatItem("これをください", "This one, please — pointing works"),
                CheatItem("おすすめは何ですか", "What do you recommend?"),
                CheatItem("〜はありますか", "Do you have ~?"),
                CheatItem("お水をください\nおみずをください", "Water, please"),
                CheatItem("お会計をお願いします\nおかいけい", "The bill, please"),
                CheatItem("別々でお願いします\nべつべつ", "Separate bills, please"),
                CheatItem("カードは使えますか\nつかえますか", "Can I pay by card?"),
            ]),

            CheatSection(title: "On the menu", columns: 2, items: [
                CheatItem("定食\nていしょく", "a set meal — main, rice, soup, pickles"),
                CheatItem("大盛り\nおおもり", "large portion, usually free or cheap"),
                CheatItem("替え玉\nかえだま", "a second helping of noodles, ramen only"),
                CheatItem("食べ放題\nたべほうだい", "all you can eat"),
                CheatItem("飲み放題\nのみほうだい", "all you can drink"),
                CheatItem("おかわり", "a refill, or seconds"),
                CheatItem("お持ち帰り\nおもちかえり", "takeaway"),
                CheatItem("辛い\nからい", "spicy — worth knowing before you order"),
            ]),

            CheatSection(
                title: "Things that surprise people",
                columns: 1, items: [
                CheatItem("お通し  おとおし", "At an izakaya a small dish arrives that you didn't order, and it appears on the bill. It isn't a scam — it's effectively a seat charge, and refusing it is awkward.", symbol: "exclamationmark.circle.fill"),
                CheatItem("No tipping", "There is no tipping in Japan, in any restaurant. Leaving money on the table will get it chased down the street after you.", symbol: "yensign.circle.fill"),
                CheatItem("Pay at the register", "In most places you take the slip from your table to the till by the door rather than paying where you sat.", symbol: "creditcard.fill"),
                CheatItem("いただきます / ごちそうさまでした", "Said before and after eating. Not religious, and not optional in company — closer to \"right then\" and \"that was lovely\".", symbol: "hands.sparkles.fill"),
            ]),
        ])

    // MARK: Verb forms

    static let verbForms = CheatSheet(
        id: "verbforms", title: "Verb Forms at a Glance", subtitle: "ます, て, た, ない",
        icon: "arrow.triangle.branch", tintIndex: 8,
        keywords: ["conjugation", "godan", "ichidan", "te form", "ta form", "nai", "verb group"],
        sections: [
            CheatSection(title: "Group 2 — る-verbs (ichidan)",
                         note: "Drop る, add the ending. 食べる, 見る, 起きる.",
                         columns: 2, items: [
                CheatItem("食べる", "dictionary"), CheatItem("食べます", "polite"),
                CheatItem("食べて", "て-form"), CheatItem("食べた", "past"),
                CheatItem("食べない", "negative"), CheatItem("食べられる", "potential / passive"),
            ]),
            CheatSection(title: "Group 1 — う-verbs (godan)",
                         note: "The final kana shifts along its row. 書く → 書きます, 書いて.",
                         columns: 1, items: [
                CheatItem("〜う, つ, る  →  って", "買う → 買って · 待つ → 待って · 取る → 取って"),
                CheatItem("〜む, ぶ, ぬ  →  んで", "飲む → 飲んで · 遊ぶ → 遊んで · 死ぬ → 死んで"),
                CheatItem("〜く  →  いて", "書く → 書いて  (行く → 行って is the exception)"),
                CheatItem("〜ぐ  →  いで", "泳ぐ → 泳いで"),
                CheatItem("〜す  →  して", "話す → 話して"),
            ]),
            CheatSection(title: "Group 3 — the two irregulars", columns: 2, items: [
                CheatItem("する", "します · して · した · しない", irregular: true),
                CheatItem("来る", "きます · きて · きた · こない", irregular: true),
            ]),
        ])

    // MARK: Names

    /// Every name and reading below was checked against JMnedict (EDRDG's name
    /// dictionary) before shipping. Names are the one area where a plausible
    /// guess is worthless: 大和 is やまと and not だいわ, and no amount of knowing
    /// the on/kun readings will tell you that.
    static let names = CheatSheet(
        id: "names", title: "Japanese Names", subtitle: "Surnames, given names, and how to read them",
        icon: "person.text.rectangle.fill", tintIndex: 4,
        keywords: ["name", "names", "surname", "family name", "given name", "namae", "名前",
                   "myouji", "苗字", "nanori", "名乗り", "san", "kun", "chan", "sama", "honorific"],
        sections: [
            CheatSection(title: "How a name is built", columns: 1, items: [
                CheatItem("山田 太郎", "やまだ たろう — surname first, always. Japan's \"John Smith\"."),
                CheatItem("Address by surname", "山田さん. First names are for family and close friends."),
                CheatItem("Never 〜さん yourself", "You are just 山田です. Adding さん to your own name is the classic learner slip.", irregular: true),
            ]),
            CheatSection(title: "Honorifics", columns: 2, items: [
                CheatItem("〜さん", "the default, any adult, any gender"),
                CheatItem("〜さま", "customers, deities, addresses on envelopes"),
                CheatItem("〜くん", "boys, juniors at work"),
                CheatItem("〜ちゃん", "small children, close friends, pets"),
                CheatItem("〜先生", "teachers, doctors, lawyers — never with さん"),
                CheatItem("呼び捨て", "よびすて — no suffix at all. Intimate, or rude.", irregular: true),
            ]),
            CheatSection(title: "The twenty commonest surnames",
                         note: "Roughly in national order. Notice how many are simple geography — "
                             + "most Japanese surnames were only fixed in 1875, when ordinary "
                             + "families were made to register one and many named themselves "
                             + "after what they could see.",
                         columns: 2, items: [
                CheatItem("佐藤", "さとう · Fujiwara branch"),
                CheatItem("鈴木", "すずき · bell tree"),
                CheatItem("高橋", "たかはし · tall bridge"),
                CheatItem("田中", "たなか · middle of the rice field"),
                CheatItem("伊藤", "いとう · Fujiwara of Ise"),
                CheatItem("渡辺", "わたなべ · by the crossing"),
                CheatItem("山本", "やまもと · base of the mountain"),
                CheatItem("中村", "なかむら · middle village"),
                CheatItem("小林", "こばやし · small grove"),
                CheatItem("加藤", "かとう · Fujiwara of Kaga"),
                CheatItem("吉田", "よしだ · lucky field"),
                CheatItem("山田", "やまだ · mountain field"),
                CheatItem("佐々木", "ささき · bamboo-grass trees"),
                CheatItem("山口", "やまぐち · mouth of the mountain"),
                CheatItem("松本", "まつもと · base of the pine"),
                CheatItem("井上", "いのうえ · above the well"),
                CheatItem("木村", "きむら · tree village"),
                CheatItem("林", "はやし · grove"),
                CheatItem("清水", "しみず · clear water"),
                CheatItem("山崎", "やまざき · mountain cape"),
            ]),
            CheatSection(title: "The 藤 clue",
                         note: "藤 (fuji, wisteria) in a surname almost always means a branch of "
                             + "the Fujiwara — the family that ran the imperial court for "
                             + "centuries. Branches took a province name and bolted 藤 on the end, "
                             + "so the surname still says where they came from.",
                         columns: 2, items: [
                CheatItem("伊藤", "いとう · 伊勢 Ise + 藤"),
                CheatItem("加藤", "かとう · 加賀 Kaga + 藤"),
                CheatItem("近藤", "こんどう · 近江 Ōmi + 藤"),
                CheatItem("遠藤", "えんどう · 遠江 Tōtōmi + 藤"),
                CheatItem("後藤", "ごとう · 後 + 藤"),
                CheatItem("斎藤", "さいとう · 斎宮 + 藤"),
            ]),
            CheatSection(title: "More surnames you'll meet", columns: 2, items: [
                CheatItem("森", "もり"), CheatItem("池田", "いけだ"),
                CheatItem("橋本", "はしもと"), CheatItem("阿部", "あべ"),
                CheatItem("石川", "いしかわ"), CheatItem("山下", "やました"),
                CheatItem("中島", "なかじま"), CheatItem("石井", "いしい"),
                CheatItem("小川", "おがわ"), CheatItem("前田", "まえだ"),
                CheatItem("岡田", "おかだ"), CheatItem("長谷川", "はせがわ", irregular: true),
                CheatItem("藤田", "ふじた"), CheatItem("村上", "むらかみ"),
                CheatItem("青木", "あおき"), CheatItem("坂本", "さかもと"),
            ]),
            CheatSection(title: "Given names — masculine",
                         note: "The top of this list turns over fast. 太郎 and 一郎 are the "
                             + "storybook names now, roughly like Albert.",
                         columns: 2, items: [
                CheatItem("蓮", "れん"), CheatItem("湊", "みなと"),
                CheatItem("大翔", "ひろと"), CheatItem("陽翔", "はると"),
                CheatItem("悠真", "ゆうま"), CheatItem("大和", "やまと", irregular: true),
                CheatItem("翔太", "しょうた"), CheatItem("健太", "けんた"),
                CheatItem("拓也", "たくや"), CheatItem("直樹", "なおき"),
                CheatItem("太郎", "たろう · \"eldest son\""), CheatItem("一郎", "いちろう · \"first son\""),
            ]),
            CheatSection(title: "Given names — feminine", columns: 2, items: [
                CheatItem("葵", "あおい"), CheatItem("凛", "りん"),
                CheatItem("陽菜", "ひな"), CheatItem("結愛", "ゆあ"),
                CheatItem("結衣", "ゆい"), CheatItem("美咲", "みさき"),
                CheatItem("愛", "あい"), CheatItem("恵", "めぐみ"),
                CheatItem("百合", "ゆり · lily"), CheatItem("翠", "みどり"),
                CheatItem("優子", "ゆうこ"), CheatItem("陽子", "ようこ"),
                CheatItem("花子", "はなこ · the storybook girl's name"),
            ]),
            CheatSection(title: "Names that go either way",
                         note: "Not every name tells you a gender, and assuming can be worse "
                             + "than asking.",
                         columns: 2, items: [
                CheatItem("直美", "なおみ · either"),
                CheatItem("誠", "まこと · either"),
                CheatItem("樹", "いつき · either"),
                CheatItem("蓮", "れん · either"),
            ]),
            CheatSection(title: "Endings that give it away", columns: 2, items: [
                CheatItem("〜子", "こ · feminine. 陽子, 優子. Dated now — peaked mid-century."),
                CheatItem("〜美", "み · feminine. 直美, 恵美."),
                CheatItem("〜郎", "ろう · masculine, \"son\". 太郎, 一郎."),
                CheatItem("〜太", "た · masculine, \"big\". 健太, 翔太."),
            ]),
            CheatSection(title: "Why you can't sound names out",
                         note: "Names use 名乗り (nanori) — readings that exist only in names and "
                             + "appear in no dictionary entry for the word. This is the single "
                             + "reason Japanese business cards print furigana, and why asking "
                             + "how someone reads their own name is completely normal.",
                         columns: 1, items: [
                CheatItem("大和 → やまと", "Not だいわ. The reading has nothing to do with the characters.", irregular: true),
                CheatItem("長谷川 → はせがわ", "長谷 is はせ only in names.", irregular: true),
                CheatItem("一 in names", "かず as often as いち — 一郎 いちろう but 一美 かずみ.", irregular: true),
                CheatItem("Same sound, many spellings", "こうじ can be 浩二, 幸治, 康司, 光司 …"),
                CheatItem("Same spelling, many sounds", "和子 is かずこ or わこ; 洋子 ようこ or ひろこ."),
            ]),
            CheatSection(title: "Reading a card", columns: 1, items: [
                CheatItem("お名前は？", "おなまえは — \"your name?\" The polite お is part of it."),
                CheatItem("何とお読みしますか", "なんとおよみしますか — \"how is this read?\" Perfectly polite to ask."),
                CheatItem("苗字 / 名字", "みょうじ — surname. 名前 なまえ is the given name, or the full name."),
                CheatItem("ふりがな", "The kana printed above a name so you can read it at all."),
            ]),
        ])
}
