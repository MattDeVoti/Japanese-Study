import Foundation

/// Ready-made custom lessons, seeded once on first launch. Each one gathers a
/// cluster of concepts learners routinely mix up, so they can be drilled side by
/// side instead of chapters apart.
///
/// They are ordinary custom lessons after seeding — renameable, editable and
/// deletable — and the seed runs only once, so deleting one keeps it gone.
enum CustomLessonPresets {

    struct Preset {
        let name: String
        var grammar: [(chapter: String, point: String)] = []
        var vocabIds: [String] = []
        var kanji: [String] = []
    }

    static let all: [Preset] = [
        Preset(
            name: "The Four “If”s",
            grammar: [("ch16", "to-conditional"), ("ch16", "tara-conditional"),
                      ("ch22", "ba-conditional"), ("ch13", "nara")]
        ),
        Preset(
            name: "Giving & Receiving",
            grammar: [("ch14", "ageru-kureru-morau"), ("ch14", "te-ageru-kureru-morau")],
            vocabIds: ["ch06_v30", "ch06_v31"]          // 貸す / 借りる
        ),
        Preset(
            name: "られる: Passive・Potential・Causative",
            grammar: [("ch21", "passive"), ("ch13", "potential"), ("ch22", "causative")]
        ),
        Preset(
            name: "Seems & Apparently",
            grammar: [("ch13", "sou-desu-appearance"), ("ch22", "you-da"),
                      ("ch17", "mitai-da"), ("ch26", "rashii")]
        ),
        Preset(
            name: "Comparing Things",
            grammar: [("ch10", "yori"), ("ch10", "hou-ga"), ("ch10", "ichiban")]
        ),
        Preset(
            name: "こそあど: This, That, That Over There",
            grammar: [("ch02", "ko-so-a-do-mono"), ("ch02", "ko-so-a-do-noun"),
                      ("ch02", "ko-so-a-do-place")]
        ),
        Preset(
            name: "Doing vs Happening",
            grammar: [("ch18", "transitive-intransitive"), ("ch06", "te-iru"), ("ch18", "te-aru")],
            vocabIds: ["ch03_v24", "ch03_v25", "ch03_v26", "ch03_v27"]   // 開ける 閉める 入る 出る
        ),
        Preset(
            name: "Easily Confused Verbs",
            vocabIds: ["ch06_v30", "ch06_v31",   // 貸す / 借りる
                       "ch03_v39", "ch06_v26",   // 教える / 習う
                       "ch24_v33", "ch24_v35",   // 着る / 履く
                       "ch03_v08", "ch03_v09",   // 行く / 来る
                       "ch03_v37", "ch03_v36"]   // 知る / 分かる
        ),
        Preset(
            name: "Look-alike Kanji",
            kanji: ["人", "入", "大", "犬", "太", "未", "末",
                    "王", "玉", "千", "干", "目", "日", "休", "体"]
        ),
    ]
}
