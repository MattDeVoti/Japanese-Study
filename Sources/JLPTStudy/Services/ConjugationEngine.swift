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
        if pos.contains("godan verb")  { return godanForms(word: word, reading: r) }
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
                row("-eba conditional",  s+"ませば"),
                row("-tara conditional", s+"ましたら"),
                row("Potential",         s+"られます", alt: s+"れます"),
                row("Passive",           s+"られます"),
                row("Causative",         s+"させます"),
                row("Volitional",        s+"ましょう"),
            ]),
            section("Masu Negative", [
                row("Present",           s+"ません"),
                row("Past",              s+"ませんでした"),
                row("-eba conditional",  s+"ませんなら"),
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

        // 行く is the only irregular godan verb (te-form is 行って not 行いて)
        let teE = (word == "行く" || reading == "いく") ? "って" : e.te
        let taE = (word == "行く" || reading == "いく") ? "った" : e.ta

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
                row("Imperative",        s+e.e),
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
                row("Present",           s+e.i+"ます"),
                row("Past",              s+e.i+"ました"),
                row("-eba conditional",  s+e.i+"ませば"),
                row("-tara conditional", s+e.i+"ましたら"),
                row("Potential",         s+e.e+"ます"),
                row("Passive",           s+e.a+"れます"),
                row("Causative",         s+e.a+"せます"),
                row("Volitional",        s+e.i+"ましょう"),
            ]),
            section("Masu Negative", [
                row("Present",           s+e.i+"ません"),
                row("Past",              s+e.i+"ませんでした"),
                row("-eba conditional",  s+e.i+"ませんなら"),
                row("-tara conditional", s+e.i+"ませんでしたら"),
                row("Potential",         s+e.e+"ません"),
                row("Passive",           s+e.a+"れません"),
                row("Causative",         s+e.a+"せません"),
            ]),
        ]
    }

    // MARK: - する (suru) verbs

    private static func suruForms(word: String) -> [ConjugationSection] {
        // Compound: 勉強する → stem = 勉強; pure する → stem = ""
        let s = word.hasSuffix("する") ? String(word.dropLast(2)) : ""

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
                row("-eba conditional",  s+"しませば"),
                row("-tara conditional", s+"しましたら"),
                row("Potential",         s+"できます"),
                row("Passive",           s+"されます"),
                row("Causative",         s+"させます"),
                row("Volitional",        s+"しましょう"),
            ]),
            section("Masu Negative", [
                row("Present",           s+"しません"),
                row("Past",              s+"しませんでした"),
                row("-eba conditional",  s+"しませんなら"),
                row("-tara conditional", s+"しませんでしたら"),
                row("Potential",         s+"できません"),
                row("Passive",           s+"されません"),
                row("Causative",         s+"させません"),
            ]),
        ]
    }

    // MARK: - 来る (kuru)

    private static func kuruForms(word: String) -> [ConjugationSection] {
        // Kanji form 来る: 来 is used as stem with different readings per form.
        // Kana-only form くる: hardcode each form explicitly.
        let isKanji = word.contains("来")
        let k: (String) -> String = { suf in isKanji ? "来" + suf : suf }

        let present   = word
        let past      = isKanji ? "来た"     : "きた"
        let te        = isKanji ? "来て"     : "きて"
        let eba       = isKanji ? "来れば"   : "くれば"
        let tara      = isKanji ? "来たら"   : "きたら"
        let potential = isKanji ? "来られる" : "こられる"
        let passive   = isKanji ? "来られる" : "こられる"
        let causative = isKanji ? "来させる" : "こさせる"
        let imp       = isKanji ? "来い"     : "こい"
        let vol       = isKanji ? "来よう"   : "こよう"

        let negPres   = isKanji ? "来ない"       : "こない"
        let negPast   = isKanji ? "来なかった"   : "こなかった"
        let negTe     = isKanji ? "来なくて"     : "こなくて"
        let negEba    = isKanji ? "来なければ"   : "こなければ"
        let negTara   = isKanji ? "来なかったら" : "こなかったら"
        let negPot    = isKanji ? "来られない"   : "こられない"

        let masuPres  = isKanji ? "来ます"   : "きます"
        let masuPast  = isKanji ? "来ました" : "きました"
        let masuEba   = isKanji ? "来ませば" : "きませば"
        let masuTara  = isKanji ? "来ましたら" : "きましたら"
        let masuPot   = isKanji ? "来られます"   : "こられます"
        let masuVol   = isKanji ? "来ましょう" : "きましょう"

        let mnPres    = isKanji ? "来ません"         : "きません"
        let mnPast    = isKanji ? "来ませんでした"   : "きませんでした"
        let mnEba     = isKanji ? "来ませんなら"     : "きませんなら"
        let mnTara    = isKanji ? "来ませんでしたら" : "きませんでしたら"
        let mnPot     = isKanji ? "来られません"     : "こられません"

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
                row("Passive",           negPot),    row("Causative", isKanji ? "来させない" : "こさせない"),
                row("Imperative",        present+"な"),
            ]),
            section("Masu Positive", [
                row("Present",           masuPres),  row("Past",    masuPast),
                row("-eba conditional",  masuEba),   row("-tara conditional", masuTara),
                row("Potential",         masuPot),   row("Passive", masuPot),
                row("Causative",         isKanji ? "来させます" : "こさせます"),
                row("Volitional",        masuVol),
            ]),
            section("Masu Negative", [
                row("Present",           mnPres),    row("Past",    mnPast),
                row("-eba conditional",  mnEba),     row("-tara conditional", mnTara),
                row("Potential",         mnPot),     row("Passive", mnPot),
                row("Causative",         isKanji ? "来させません" : "こさせません"),
            ]),
        ]
    }

    // MARK: - い-adjective

    private static func iAdjForms(word: String) -> [ConjugationSection] {
        // いい / 良い / よい are irregular: stem is よ (for kana-only) or 良 (for kanji)
        let isYoi = (word == "いい" || word == "よい")
        let s: String
        if isYoi {
            s = "よ"           // いい → よ stem for all conjugations
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
                row("Volitional",        s+"かろう"),
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
