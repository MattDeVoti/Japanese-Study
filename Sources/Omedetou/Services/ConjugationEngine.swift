import Foundation

struct ConjugationSection {
    let title: String
    let rows: [ConjugationRow]
}

struct ConjugationRow {
    let label: String
    let value: String
    let alt: String?   // colloquial / alternative form shown in parentheses
}

enum ConjugationEngine {

    // MARK: - Public entry point

    static func conjugate(word: String, reading: String?, partsOfSpeech: [String]) -> [ConjugationSection]? {
        let r = (reading?.isEmpty == false) ? reading! : word
        let pos = Set(partsOfSpeech)

        if pos.contains("suru verb")   { return suruForms(word: word) }
        if pos.contains("kuru verb")   { return kuruForms(word: word) }
        if pos.contains("ichidan verb"){ return ichidanForms(word: word) }
        if pos.contains("godan verb")  {
            // ある is the one godan verb with a suppletive negative (ない, never あらない)
            // and no potential/passive/causative in ordinary use.
            if r == "ある" { return aruForms(word: word) }
            return godanForms(word: word, reading: r)
        }
        if pos.contains("i-adjective") { return iAdjForms(word: word) }
        if pos.contains("na-adjective"){ return naAdjForms(word: word) }
        return nil
    }

    // MARK: - Ichidan (Group 2 / る-verbs)

    private static func ichidanForms(word: String) -> [ConjugationSection] {
        let s = String(word.dropLast())  // drop る → stem (e.g. 見)

        return [
            section("Plain Positive", [
                row("Present",           word),
                row("Past",              s+"た"),
                row("-te",               s+"て"),
                row("-eba conditional",  s+"れば"),
                row("-tara conditional", s+"たら"),
                row("Potential",         s+"られる",  alt: s+"れる"),
                row("Passive",           s+"られる"),
                row("Causative",         s+"させる"),
                row("Imperative",        s+"ろ",      alt: s+"よ"),
                row("Volitional",        s+"よう"),
            ]),
            section("Plain Negative", [
                row("Present",           s+"ない"),
                row("Past",              s+"なかった"),
                row("-te",               s+"なくて"),
                row("-eba conditional",  s+"なければ"),
                row("-tara conditional", s+"なかったら"),
                row("Potential",         s+"られない", alt: s+"れない"),
                row("Passive",           s+"られない"),
                row("Causative",         s+"させない"),
                row("Imperative",        word+"な"),
            ]),
            section("Masu Positive", [
                row("Present",           s+"ます"),
                row("Past",              s+"ました"),
                row("-tara conditional", s+"ましたら"),
                row("Potential",         s+"られます", alt: s+"れます"),
                row("Passive",           s+"られます"),
                row("Causative",         s+"させます"),
                row("Volitional",        s+"ましょう"),
            ]),
            section("Masu Negative", [
                row("Present",           s+"ません"),
                row("Past",              s+"ませんでした"),
                row("-tara conditional", s+"ませんでしたら"),
                row("Potential",         s+"られません", alt: s+"れません"),
                row("Passive",           s+"られません"),
                row("Causative",         s+"させません"),
            ]),
        ]
    }

    // MARK: - Godan (Group 1 / う-verbs)

    private static func godanForms(word: String, reading: String) -> [ConjugationSection] {
        guard let last = reading.last else { return [] }
        let s = String(word.dropLast())   // kanji stem (e.g. 書 from 書く)

        struct Endings {
            let a: String   // mizen / negative base   (e.g. か for く)
            let i: String   // ren'yō / masu stem      (e.g. き for く)
            let e: String   // katei / potential base  (e.g. け for く)
            let o: String   // volitional base         (e.g. こ for く)
            let te: String  // て-form suffix
            let ta: String  // た-form suffix
        }

        let e: Endings
        switch last {
        case "う": e = Endings(a:"わ", i:"い", e:"え", o:"お", te:"って", ta:"った")
        case "く": e = Endings(a:"か", i:"き", e:"け", o:"こ", te:"いて", ta:"いた")
        case "ぐ": e = Endings(a:"が", i:"ぎ", e:"げ", o:"ご", te:"いで", ta:"いだ")
        case "す": e = Endings(a:"さ", i:"し", e:"せ", o:"そ", te:"して", ta:"した")
        case "つ": e = Endings(a:"た", i:"ち", e:"て", o:"と", te:"って", ta:"った")
        case "ぬ": e = Endings(a:"な", i:"に", e:"ね", o:"の", te:"んで", ta:"んだ")
        case "む": e = Endings(a:"ま", i:"み", e:"め", o:"も", te:"んで", ta:"んだ")
        case "ぶ": e = Endings(a:"ば", i:"び", e:"べ", o:"ぼ", te:"んで", ta:"んだ")
        case "る": e = Endings(a:"ら", i:"り", e:"れ", o:"ろ", te:"って", ta:"った")
        default:   return []
        }

        // 行く takes って rather than いて.
        // …and so do its compounds (持って行く, 連れて行く), which end the same way.
        let teE = (word.hasSuffix("行く") || reading.hasSuffix("いく")) ? "って" : e.te
        let taE = (word.hasSuffix("行く") || reading.hasSuffix("いく")) ? "った" : e.ta

        // The honorific -aru verbs are irregular in the ren'yō (masu) stem: they
        // take い, not り — いらっしゃいます, ございます, なさいます. Treating them
        // as regular godan produced いらっしゃります, which is simply wrong.
        let honorificAru = ["いらっしゃる", "おっしゃる", "くださる", "なさる", "ござる"]
        let iStem = honorificAru.contains(reading) ? "い" : e.i

        return [
            section("Plain Positive", [
                row("Present",           word),
                row("Past",              s+taE),
                row("-te",               s+teE),
                row("-eba conditional",  s+e.e+"ば"),
                row("-tara conditional", s+taE+"ら"),
                row("Potential",         s+e.e+"る"),
                row("Passive",           s+e.a+"れる"),
                row("Causative",         s+e.a+"せる"),
                // The same い-stem irregularity gives these verbs their imperative:
                // いらっしゃい / おっしゃい / ください / なさい, never いらっしゃれ.
                row("Imperative",        honorificAru.contains(reading) ? s+"い" : s+e.e),
                row("Volitional",        s+e.o+"う"),
            ]),
            section("Plain Negative", [
                row("Present",           s+e.a+"ない"),
                row("Past",              s+e.a+"なかった"),
                row("-te",               s+e.a+"なくて"),
                row("-eba conditional",  s+e.a+"なければ"),
                row("-tara conditional", s+e.a+"なかったら"),
                row("Potential",         s+e.e+"ない"),
                row("Passive",           s+e.a+"れない"),
                row("Causative",         s+e.a+"せない"),
                row("Imperative",        word+"な"),
            ]),
            section("Masu Positive", [
                row("Present",           s+iStem+"ます"),
                row("Past",              s+iStem+"ました"),
                row("-tara conditional", s+iStem+"ましたら"),
                row("Potential",         s+e.e+"ます"),
                row("Passive",           s+e.a+"れます"),
                row("Causative",         s+e.a+"せます"),
                row("Volitional",        s+iStem+"ましょう"),
            ]),
            section("Masu Negative", [
                row("Present",           s+iStem+"ません"),
                row("Past",              s+iStem+"ませんでした"),
                row("-tara conditional", s+iStem+"ませんでしたら"),
                row("Potential",         s+e.e+"ません"),
                row("Passive",           s+e.a+"れません"),
                row("Causative",         s+e.a+"せません"),
            ]),
        ]
    }

    // MARK: - する (suru) verbs

    private static func suruForms(word: String) -> [ConjugationSection] {
        // 勉強する → stem 勉強; bare 勉強 → stem 勉強; pure する → stem "".
        // The bare-noun case used to fall through to "", which silently dropped the
        // noun and made every する-noun in the drill conjugate as plain する.
        let s = word.hasSuffix("する") ? String(word.dropLast(2)) : word

        return [
            section("Plain Positive", [
                row("Present",           s+"する"),
                row("Past",              s+"した"),
                row("-te",               s+"して"),
                row("-eba conditional",  s+"すれば"),
                row("-tara conditional", s+"したら"),
                row("Potential",         s+"できる"),
                row("Passive",           s+"される"),
                row("Causative",         s+"させる"),
                row("Imperative",        s+"しろ",    alt: s+"せよ"),
                row("Volitional",        s+"しよう"),
            ]),
            section("Plain Negative", [
                row("Present",           s+"しない"),
                row("Past",              s+"しなかった"),
                row("-te",               s+"しなくて"),
                row("-eba conditional",  s+"しなければ"),
                row("-tara conditional", s+"しなかったら"),
                row("Potential",         s+"できない"),
                row("Passive",           s+"されない"),
                row("Causative",         s+"させない"),
                row("Imperative",        s+"するな"),
            ]),
            section("Masu Positive", [
                row("Present",           s+"します"),
                row("Past",              s+"しました"),
                row("-tara conditional", s+"しましたら"),
                row("Potential",         s+"できます"),
                row("Passive",           s+"されます"),
                row("Causative",         s+"させます"),
                row("Volitional",        s+"しましょう"),
            ]),
            section("Masu Negative", [
                row("Present",           s+"しません"),
                row("Past",              s+"しませんでした"),
                row("-tara conditional", s+"しませんでしたら"),
                row("Potential",         s+"できません"),
                row("Passive",           s+"されません"),
                row("Causative",         s+"させません"),
            ]),
        ]
    }

    // MARK: - ある

    /// ある conjugates as a regular godan verb everywhere except the negative,
    /// which is the bare adjective ない rather than あらない. It also has no
    /// potential, passive or causative in ordinary use, so those rows are left out.
    private static func aruForms(word: String) -> [ConjugationSection] {
        let s = String(word.dropLast())   // あ / 有 / 在
        return [
            section("Plain Positive", [
                row("Present",           word),
                row("Past",              s+"った"),
                row("-te",               s+"って"),
                row("-eba conditional",  s+"れば"),
                row("-tara conditional", s+"ったら"),
                row("Imperative",        s+"れ"),
                row("Volitional",        s+"ろう"),
            ]),
            section("Plain Negative", [
                row("Present",           "ない"),
                row("Past",              "なかった"),
                row("-te",               "なくて"),
                row("-eba conditional",  "なければ"),
                row("-tara conditional", "なかったら"),
                row("Imperative",        word+"な"),
            ]),
            section("Masu Positive", [
                row("Present",           s+"ります"),
                row("Past",              s+"りました"),
                row("-tara conditional", s+"りましたら"),
                row("Volitional",        s+"りましょう"),
            ]),
            section("Masu Negative", [
                row("Present",           s+"りません"),
                row("Past",              s+"りませんでした"),
                row("-tara conditional", s+"りませんでしたら"),
            ]),
        ]
    }

    // MARK: - 来る (kuru)

    private static func kuruForms(word: String) -> [ConjugationSection] {
        // Kanji form 来る: 来 is used as stem with different readings per form.
        // Kana-only form くる: hardcode each form explicitly.
        let isKanji = word.hasSuffix("来る")
        // Compounds (持って来る, 連れてくる) keep their prefix on every form; the
        // tables below are spelled from the bare verb, so it is re-attached here.
        let p = (word.hasSuffix("来る") || word.hasSuffix("くる")) ? String(word.dropLast(2)) : ""

        let present   = word
        let past      = p + (isKanji ? "来た"     : "きた")
        let te        = p + (isKanji ? "来て"     : "きて")
        let eba       = p + (isKanji ? "来れば"   : "くれば")
        let tara      = p + (isKanji ? "来たら"   : "きたら")
        let potential = p + (isKanji ? "来られる" : "こられる")
        let passive   = p + (isKanji ? "来られる" : "こられる")
        let causative = p + (isKanji ? "来させる" : "こさせる")
        let imp       = p + (isKanji ? "来い"     : "こい")
        let vol       = p + (isKanji ? "来よう"   : "こよう")

        let negPres   = p + (isKanji ? "来ない"       : "こない")
        let negPast   = p + (isKanji ? "来なかった"   : "こなかった")
        let negTe     = p + (isKanji ? "来なくて"     : "こなくて")
        let negEba    = p + (isKanji ? "来なければ"   : "こなければ")
        let negTara   = p + (isKanji ? "来なかったら" : "こなかったら")
        let negPot    = p + (isKanji ? "来られない"   : "こられない")

        let masuPres  = p + (isKanji ? "来ます"   : "きます")
        let masuPast  = p + (isKanji ? "来ました" : "きました")
        let masuTara  = p + (isKanji ? "来ましたら" : "きましたら")
        let masuPot   = p + (isKanji ? "来られます"   : "こられます")
        let masuVol   = p + (isKanji ? "来ましょう" : "きましょう")

        let mnPres    = p + (isKanji ? "来ません"         : "きません")
        let mnPast    = p + (isKanji ? "来ませんでした"   : "きませんでした")
        let mnTara    = p + (isKanji ? "来ませんでしたら" : "きませんでしたら")
        let mnPot     = p + (isKanji ? "来られません"     : "こられません")

        return [
            section("Plain Positive", [
                row("Present",           present),   row("Past",    past),
                row("-te",               te),        row("-eba conditional",  eba),
                row("-tara conditional", tara),      row("Potential",  potential),
                row("Passive",           passive),   row("Causative",  causative),
                row("Imperative",        imp),       row("Volitional", vol),
            ]),
            section("Plain Negative", [
                row("Present",           negPres),   row("Past",    negPast),
                row("-te",               negTe),     row("-eba conditional",  negEba),
                row("-tara conditional", negTara),   row("Potential",  negPot),
                row("Passive",           negPot),    row("Causative", p + (isKanji ? "来させない" : "こさせない")),
                row("Imperative",        present+"な"),
            ]),
            section("Masu Positive", [
                row("Present",           masuPres),  row("Past",    masuPast),   row("-tara conditional", masuTara),
                row("Potential",         masuPot),   row("Passive", masuPot),
                row("Causative",         p + (isKanji ? "来させます" : "こさせます")),
                row("Volitional",        masuVol),
            ]),
            section("Masu Negative", [
                row("Present",           mnPres),    row("Past",    mnPast),     row("-tara conditional", mnTara),
                row("Potential",         mnPot),     row("Passive", mnPot),
                row("Causative",         p + (isKanji ? "来させません" : "こさせません")),
            ]),
        ]
    }

    // MARK: - い-adjective

    private static func iAdjForms(word: String) -> [ConjugationSection] {
        // いい / 良い / よい are irregular: stem is よ (for kana-only) or 良 (for kanji)
        let isYoi = (word == "いい" || word == "よい")
        // Compounds built on いい swap to よ as well: かっこいい → かっこよかった.
        // (Not every word ending in いい — かわいい → かわいかった is regular.)
        let iiCompound = ["かっこいい", "かっこういい", "格好いい", "気持ちいい", "気持いい", "心地いい", "都合がいい", "仲がいい"]
            .first { word.hasSuffix($0) } != nil
        let s: String
        if isYoi {
            s = "よ"           // いい → よ stem for all conjugations
        } else if iiCompound {
            s = String(word.dropLast(2)) + "よ"   // かっこ + よ
        } else {
            s = String(word.dropLast())  // drop い
        }

        return [
            section("Positive", [
                row("Present",           word),
                row("Past",              s+"かった"),
                row("-te",               s+"くて"),
                row("-eba conditional",  s+"ければ"),
                row("-tara conditional", s+"かったら"),
            ]),
            section("Negative", [
                row("Present",           s+"くない"),
                row("Past",              s+"くなかった"),
                row("-te",               s+"くなくて"),
                row("-eba conditional",  s+"くなければ"),
                row("-tara conditional", s+"くなかったら"),
            ]),
        ]
    }

    // MARK: - な-adjective

    private static func naAdjForms(word: String) -> [ConjugationSection] {
        let w = word
        return [
            section("Positive", [
                row("Present",           w+"だ",         alt: w+"です"),
                row("Past",              w+"だった",     alt: w+"でした"),
                row("-te",               w+"で"),
                row("-eba conditional",  w+"なら",       alt: w+"であれば"),
                row("-tara conditional", w+"だったら",   alt: w+"でしたら"),
            ]),
            section("Negative", [
                row("Present",           w+"じゃない",       alt: w+"ではない"),
                row("Past",              w+"じゃなかった",   alt: w+"ではなかった"),
                row("-te",               w+"じゃなくて",     alt: w+"ではなくて"),
                row("-eba conditional",  w+"じゃなければ",   alt: w+"でなければ"),
                row("-tara conditional", w+"じゃなかったら", alt: w+"ではなかったら"),
            ]),
        ]
    }

    // MARK: - Helpers

    private static func section(_ title: String, _ rows: [ConjugationRow]) -> ConjugationSection {
        ConjugationSection(title: title, rows: rows)
    }

    private static func row(_ label: String, _ value: String, alt: String? = nil) -> ConjugationRow {
        ConjugationRow(label: label, value: value, alt: alt)
    }
}
