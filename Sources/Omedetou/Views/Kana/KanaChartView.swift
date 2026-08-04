import SwiftUI

struct KanaChartView: View {
    let isHiragana: Bool

    // Tapping the five vowels in gojūon order opens a five-kana word puzzle.
    // Five taps, five cells — the secret rhymes with the game it opens.
    @State private var vowelProgress = 0
    @State private var foundKotoba = false
    private let vowels = ["あ", "い", "う", "え", "お"]
    @ObservedObject private var unlocks = GameUnlocks.shared

    /// Only the hiragana chart hides anything, and only until it's found.
    private func hintOrder(_ kana: String) -> Int? {
        guard isHiragana, !unlocks.isUnlocked(.kotoba) else { return nil }
        return vowels.firstIndex(of: kana)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ChartSection(title: "Basic",
                                 rows: isHiragana ? hiraganaBasic : katakanaBasic,
                                 onTap: noteTap, hintOrder: hintOrder)
                    ChartSection(title: "Voiced & Semi-voiced",
                                 rows: isHiragana ? hiraganaDakuten : katakanaDakuten,
                                 onTap: noteTap, hintOrder: hintOrder)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .fullScreenCover(isPresented: $foundKotoba) {
            NavigationStack { KotobaGame() }
        }
        .standardNavBar(isHiragana ? "Hiragana" : "Katakana")
    }
}

// MARK: - Section

private struct ChartSection: View {
    let title: String
    let rows: [[(String, String)?]]
    var onTap: (String) -> Void = { _ in }
    var hintOrder: (String) -> Int? = { _ in nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 2)
            KanaGrid(rows: rows, onTap: onTap, hintOrder: hintOrder)
        }
    }
}

// MARK: - Grid

private struct KanaGrid: View {
    let rows: [[(String, String)?]]
    var onTap: (String) -> Void = { _ in }
    var hintOrder: (String) -> Int? = { _ in nil }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { c in
                        if let (kana, romaji) = rows[r][c] {
                            KanaCellView(kana: kana, romaji: romaji, onTap: onTap,
                                         hintOrder: hintOrder(kana))
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Cell

private struct KanaCellView: View {
    let kana: String
    let romaji: String
    var onTap: (String) -> Void = { _ in }
    var hintOrder: Int? = nil

    var body: some View {
        VStack(spacing: 3) {
            Text(kana)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.appText)
            Text(romaji)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(Color.appText.opacity(0.05))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture { onTap(kana) }
        .secretHint(hintOrder != nil, order: hintOrder ?? 0, corner: 8)
    }
}

private extension KanaChartView {
    /// Only the hiragana chart carries the secret, and only in order.
    func noteTap(_ kana: String) {
        guard isHiragana else { return }
        if kana == vowels[vowelProgress] {
            vowelProgress += 1
            if vowelProgress == vowels.count {
                vowelProgress = 0
                GameUnlocks.shared.unlock(.kotoba)
                foundKotoba = true
            }
        } else {
            vowelProgress = (kana == vowels[0]) ? 1 : 0
        }
    }
}

// MARK: - Hiragana data

private let hiraganaBasic: [[(String, String)?]] = [
    [("あ","a"),   ("い","i"),   ("う","u"),   ("え","e"),   ("お","o")  ],
    [("か","ka"),  ("き","ki"),  ("く","ku"),  ("け","ke"),  ("こ","ko") ],
    [("さ","sa"),  ("し","shi"), ("す","su"),  ("せ","se"),  ("そ","so") ],
    [("た","ta"),  ("ち","chi"), ("つ","tsu"), ("て","te"),  ("と","to") ],
    [("な","na"),  ("に","ni"),  ("ぬ","nu"),  ("ね","ne"),  ("の","no") ],
    [("は","ha"),  ("ひ","hi"),  ("ふ","fu"),  ("へ","he"),  ("ほ","ho") ],
    [("ま","ma"),  ("み","mi"),  ("む","mu"),  ("め","me"),  ("も","mo") ],
    [("や","ya"),  nil,          ("ゆ","yu"),  nil,          ("よ","yo") ],
    [("ら","ra"),  ("り","ri"),  ("る","ru"),  ("れ","re"),  ("ろ","ro") ],
    [("わ","wa"),  nil,          nil,          nil,          ("を","wo") ],
    [("ん","n"),   nil,          nil,          nil,          nil         ],
]

private let hiraganaDakuten: [[(String, String)?]] = [
    [("が","ga"),  ("ぎ","gi"),  ("ぐ","gu"),  ("げ","ge"),  ("ご","go") ],
    [("ざ","za"),  ("じ","ji"),  ("ず","zu"),  ("ぜ","ze"),  ("ぞ","zo") ],
    [("だ","da"),  ("ぢ","ji"),  ("づ","zu"),  ("で","de"),  ("ど","do") ],
    [("ば","ba"),  ("び","bi"),  ("ぶ","bu"),  ("べ","be"),  ("ぼ","bo") ],
    [("ぱ","pa"),  ("ぴ","pi"),  ("ぷ","pu"),  ("ぺ","pe"),  ("ぽ","po") ],
]

// MARK: - Katakana data

private let katakanaBasic: [[(String, String)?]] = [
    [("ア","a"),   ("イ","i"),   ("ウ","u"),   ("エ","e"),   ("オ","o")  ],
    [("カ","ka"),  ("キ","ki"),  ("ク","ku"),  ("ケ","ke"),  ("コ","ko") ],
    [("サ","sa"),  ("シ","shi"), ("ス","su"),  ("セ","se"),  ("ソ","so") ],
    [("タ","ta"),  ("チ","chi"), ("ツ","tsu"), ("テ","te"),  ("ト","to") ],
    [("ナ","na"),  ("ニ","ni"),  ("ヌ","nu"),  ("ネ","ne"),  ("ノ","no") ],
    [("ハ","ha"),  ("ヒ","hi"),  ("フ","fu"),  ("ヘ","he"),  ("ホ","ho") ],
    [("マ","ma"),  ("ミ","mi"),  ("ム","mu"),  ("メ","me"),  ("モ","mo") ],
    [("ヤ","ya"),  nil,          ("ユ","yu"),  nil,          ("ヨ","yo") ],
    [("ラ","ra"),  ("リ","ri"),  ("ル","ru"),  ("レ","re"),  ("ロ","ro") ],
    [("ワ","wa"),  nil,          nil,          nil,          ("ヲ","wo") ],
    [("ン","n"),   nil,          nil,          nil,          nil         ],
]

private let katakanaDakuten: [[(String, String)?]] = [
    [("ガ","ga"),  ("ギ","gi"),  ("グ","gu"),  ("ゲ","ge"),  ("ゴ","go") ],
    [("ザ","za"),  ("ジ","ji"),  ("ズ","zu"),  ("ゼ","ze"),  ("ゾ","zo") ],
    [("ダ","da"),  ("ヂ","ji"),  ("ヅ","zu"),  ("デ","de"),  ("ド","do") ],
    [("バ","ba"),  ("ビ","bi"),  ("ブ","bu"),  ("ベ","be"),  ("ボ","bo") ],
    [("パ","pa"),  ("ピ","pi"),  ("プ","pu"),  ("ペ","pe"),  ("ポ","po") ],
]
