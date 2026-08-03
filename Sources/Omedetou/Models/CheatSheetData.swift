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
    case none, positionMap, distanceMap, frequencyScale, clock, compass, body, face
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
    static let all: [CheatSheet] = {
        var out: [CheatSheet] = []
        // Reached for constantly, from day one.
        out += [particles, time, numbers, verbForms, adjectives]
        // Needed as soon as you start arranging your life in Japanese.
        out += [counters, weekdays, dates, months, relativeTime]
        // The everyday closed sets.
        out += [questionWords, kosoado, greetings, directions, colours]
        // Useful, but looked up less often.
        out += [family, transitivity, adverbs, connectors]
        // Specialist or late-stage.
        out += [weather, body, keigo]
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
        keywords: ["family", "ちち", "はは", "おとうさん", "brother", "sister", "parents"],
        sections: [
            CheatSection(note: "Left: talking about your own family. "
                             + "Right: talking about someone else's — also what you call "
                             + "your own relatives to their face.",
                         columns: 2, items: [
                CheatItem("父 — ちち", "お父さん — おとうさん (father)"),
                CheatItem("母 — はは", "お母さん — おかあさん (mother)"),
                CheatItem("兄 — あに", "お兄さん — おにいさん (older brother)"),
                CheatItem("姉 — あね", "お姉さん — おねえさん (older sister)"),
                CheatItem("弟 — おとうと", "弟さん — おとうとさん (younger brother)"),
                CheatItem("妹 — いもうと", "妹さん — いもうとさん (younger sister)"),
                CheatItem("祖父 — そふ", "おじいさん (grandfather)"),
                CheatItem("祖母 — そぼ", "おばあさん (grandmother)"),
                CheatItem("妻 — つま", "奥さん — おくさん (wife)"),
                CheatItem("夫 — おっと", "ご主人 — ごしゅじん (husband)"),
                CheatItem("息子 — むすこ", "息子さん — むすこさん (son)"),
                CheatItem("娘 — むすめ", "娘さん — むすめさん (daughter)"),
                CheatItem("家族 — かぞく", "ご家族 — ごかぞく (family)"),
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
}
