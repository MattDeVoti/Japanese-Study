import SwiftUI

// MARK: - The secret games catalogue
//
// Games stay hidden until the player stumbles on them. Once found, a game is
// remembered for good and shows up under the home screen's Games tile — which
// is itself locked ("???") until at least one game has been discovered.

enum SecretGameID: String, CaseIterable, Identifiable {
    case kanjiInvaders
    case shiritori
    case kotoba
    case sudoku

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kanjiInvaders: return "Kanji Invaders"
        case .shiritori:     return "しりとり"
        case .kotoba:        return "ことばパズル"
        case .sudoku:        return "数独"
        }
    }
    var subtitle: String {
        switch self {
        case .kanjiInvaders: return "Shoot the falling kanji"
        case .shiritori:     return "Chain words, never end in ん"
        case .kotoba:        return "Guess the five-kana word"
        case .sudoku:        return "Sudoku in kanji numerals"
        }
    }
    /// How to play, in the order a new player needs it.
    var rules: [(icon: String, tint: Color?, text: String)] {
        switch self {
        case .kanjiInvaders:
            return [
                ("hand.draw", nil, "Slide anywhere on screen to fly. You fire on your own."),
                ("target", nil, "Shoot the falling kanji before they reach the bottom."),
                ("bolt.fill", nil, "Pick up power-ups as they drop. They stack while they last."),
            ]
        case .shiritori:
            return [
                ("link", nil, "Answer with a word starting on the last kana of the word before it — さくら → らくだ → だんご."),
                ("xmark.octagon.fill", Color(hex: "EF4444"), "A word ending in ん loses the round. That is the whole danger."),
                ("timer", nil, "Fifteen seconds a turn. The clock resets every time you play a word."),
                ("keyboard", nil, "Type in hiragana. It has to be a word the app's dictionary knows, and no word can be used twice."),
                ("character.book.closed", nil, "A trailing ー doesn't count — the kana before it does. A small kana (ゃ ゅ ょ っ) counts as its full-size form."),
            ]
        case .kotoba:
            return [
                ("square.grid.3x3.fill", nil, "Guess a five-kana word in six tries."),
                ("square.fill", KotobaTheme.correct, "Green — right kana, right place."),
                ("square.fill", KotobaTheme.present, "Yellow — that kana is in the word, but somewhere else."),
                ("square.fill", KotobaTheme.absent, "Grey — that kana isn't in the word at all."),
                ("textformat.abc", nil, "Answers are five full morae, never small kana or ー. Tap ゛゜ to reach voiced kana like が and ぱ."),
            ]
        case .sudoku:
            return [
                ("number.square", nil, "Fill the grid so 一 to 九 each appear once in every row, every column and every 3×3 box."),
                ("hand.tap", nil, "Tap a square to select it, then tap a number. Tapping the same number again clears it. Selecting a square tints its row, column and box so a clash stands out."),
                ("square.and.pencil", nil, "Notes writes small numbers instead of filling the square — the maybes you're keeping track of."),
                ("wand.and.stars", nil, "Auto notes fills in every number a square isn't directly blocked from having. It does no further reasoning: narrowing those down is your job."),
                ("exclamationmark.triangle.fill", Color(hex: "C0392B"), "A number that doesn't belong turns red."),
                ("checkmark.seal", nil, "Every puzzle is generated on your phone and has exactly one solution, so it can always be finished by reasoning."),
            ]
        }
    }

    var glyph: String {
        switch self {
        case .kanjiInvaders: return "侵"
        case .shiritori:     return "尻"
        case .kotoba:        return "言"
        case .sudoku:        return "数"
        }
    }
    var icon: String {
        switch self {
        case .kanjiInvaders: return "gamecontroller.fill"
        case .shiritori:     return "link"
        case .kotoba:        return "square.grid.3x3.fill"
        case .sudoku:        return "number.square.fill"
        }
    }
    var color: Color {
        switch self {
        case .kanjiInvaders: return .themeTile(9)
        case .shiritori:     return .themeTile(3)
        case .kotoba:        return .themeTile(6)
        case .sudoku:        return .themeTile(4)
        }
    }
}

/// Which games the player has unlocked. Persisted, so a discovery sticks.
final class GameUnlocks: ObservableObject {
    static let shared = GameUnlocks()

    private let key = "UnlockedSecretGames"
    @Published private(set) var unlocked: Set<String>

    private init() {
        unlocked = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func isUnlocked(_ game: SecretGameID) -> Bool { unlocked.contains(game.rawValue) }

    /// True once anything at all has been found — gates the home screen tile.
    var hasAny: Bool { !discovered.isEmpty }

    /// Everything found so far, in catalogue order.
    var discovered: [SecretGameID] { SecretGameID.allCases.filter(isUnlocked) }

    /// Re-locks everything, which also returns the home screen to its
    /// three-tile layout. Study data and high scores are untouched.
    func resetAll() {
        guard !unlocked.isEmpty else { return }
        unlocked.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Settings arriving from another device land in UserDefaults directly, so
    /// the published set has to be re-read for the UI to notice.
    func reloadFromDefaults() {
        let stored = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        if stored != unlocked { unlocked = stored }
    }

    func unlock(_ game: SecretGameID) {
        // The guard is what makes this the right place for the sound. Callers
        // fire on the triggering action, not on the transition — opening the
        // しりとり entry calls this every time — so only a genuinely new unlock
        // gets past here. `reloadFromDefaults` sets the set directly and so
        // stays silent, which is right: a game unlocked on an iPad shouldn't
        // announce itself when this device syncs.
        guard !unlocked.contains(game.rawValue) else { return }
        unlocked.insert(game.rawValue)
        UserDefaults.standard.set(Array(unlocked), forKey: key)
        FeedbackSounds.shared.play(.unlock)
    }
}

// MARK: - The ことばパズル palette

/// ことばパズル is a board game, and a board doesn't change colour because the
/// app's Appearance did. These are fixed, and both the game and its tile — which
/// is a picture of that board — read from here so the two can never drift.
enum KotobaTheme {
    static let backdrop = [Color(hex: "1D2634"), Color(hex: "0A0E15")]
    static let text     = Color(hex: "E8EAED")
    static let dim      = Color(hex: "9AA3AF")
    static let correct  = Color(hex: "3B9A55")
    static let present  = Color(hex: "D9A400")
    static let absent   = Color(hex: "5A5F66")
    static let surface  = Color.white.opacity(0.10)
    static let outline  = Color.white.opacity(0.38)
    static let active   = Color(hex: "3E4C63")

    static var background: LinearGradient {
        LinearGradient(colors: backdrop, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let navBar = LinearGradient(colors: [Color(hex: "27354A"), Color(hex: "141D29")],
                                       startPoint: .top, endPoint: .bottom)
}

/// A button in a board's own palette, for the screens that don't follow the
/// app's Appearance and so can't use AccentActionButton.
struct BoardButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = KotobaTheme.text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                }
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(tint)
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - The しりとり palette

/// Same principle as `KotobaTheme`: the chain keeps the colours of its tile —
/// deep green ground, cream words, gold on the kana being handed over — whatever
/// Appearance the app is set to. The tile and the game both read from here.
enum ShiritoriTheme {
    static let backdrop = [Color(hex: "0C3D34"), Color(hex: "04150F")]
    static let text     = Color(hex: "F7F0E4")
    static let dim      = Color(hex: "A9C4B8")
    static let gold     = Color(hex: "F2C14E")
    static let chip     = Color(hex: "17564A")
    static let hairline = Color.white.opacity(0.20)
    static let danger   = Color(hex: "EF4444")

    static var background: LinearGradient {
        LinearGradient(colors: backdrop, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let navBar = LinearGradient(colors: [Color(hex: "115A4C"), Color(hex: "07281F")],
                                       startPoint: .top, endPoint: .bottom)
}

// MARK: - Game tile artwork
//
// Each tile is a miniature still of its own game rather than a flat colour
// swatch — you should be able to tell what you're about to play without reading
// the label. Everything is hand-placed in fractions of the tile so it scales,
// and every scene keeps its action right-of-centre and above the waist to leave
// the bottom-left clear for the title.

/// 侵略 — falling kanji over a star field, with the ship firing back.
private struct InvadersScene: View {
    /// x, y (0…1 of the tile), glyph, colour, size.
    private let foes: [(x: CGFloat, y: CGFloat, ch: String, c: Color, s: CGFloat)] = [
        (0.40, 0.17, "火", .orange, 0.150),
        (0.76, 0.12, "空", .teal, 0.130),
        (0.57, 0.33, "水", Color(hex: "38BDF8"), 0.115),
        (0.26, 0.39, "花", .pink, 0.100),
    ]
    /// Star field — fixed positions so the tile is stable, not noisy.
    private let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, a: Double)] = [
        (0.10, 0.10, 1.6, 0.55), (0.22, 0.40, 1.2, 0.35), (0.40, 0.55, 1.8, 0.6),
        (0.66, 0.44, 1.3, 0.4),  (0.90, 0.12, 1.5, 0.5),  (0.76, 0.60, 1.1, 0.32),
        (0.16, 0.66, 1.4, 0.42), (0.94, 0.50, 1.2, 0.34), (0.55, 0.70, 1.5, 0.3),
        (0.34, 0.84, 1.2, 0.26), (0.68, 0.86, 1.3, 0.28), (0.06, 0.30, 1.2, 0.3),
    ]

    /// Where the ship sits — clear of the title, and everything else points at it.
    private let shipX: CGFloat = 0.76
    private let shipY: CGFloat = 0.55

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height

            ForEach(Array(stars.enumerated()), id: \.offset) { _, s in
                Circle().fill(.white.opacity(s.a))
                    .frame(width: s.r, height: s.r)
                    .position(x: w * s.x, y: h * s.y)
            }

            ForEach(Array(foes.enumerated()), id: \.offset) { _, f in
                Text(f.ch)
                    .font(.system(size: w * f.s, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [f.c.lightened(0.30), f.c.darkened(0.14)],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: f.c.opacity(0.8), radius: w * 0.03)
                    .position(x: w * f.x, y: h * f.y)
            }

            // Two bolts climbing away from the ship toward the 空 above it.
            ForEach(Array([0.29, 0.40].enumerated()), id: \.offset) { _, y in
                Capsule()
                    .fill(LinearGradient(colors: [.white, Color(hex: "F43F5E"),
                                                  Color(hex: "F43F5E").opacity(0.1)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.022, height: h * 0.085)
                    .shadow(color: Color(hex: "F43F5E").opacity(0.9), radius: w * 0.02)
                    .position(x: w * shipX, y: h * CGFloat(y))
            }

            // Exhaust, then the ship on top of it.
            Ellipse()
                .fill(LinearGradient(colors: [.white, Color(hex: "38BDF8"),
                                              Color(hex: "1D4ED8").opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.045, height: h * 0.10)
                .shadow(color: Color(hex: "38BDF8").opacity(0.9), radius: w * 0.04)
                .position(x: w * shipX, y: h * (shipY + 0.085))

            Text("山")
                .font(.system(size: w * 0.20, weight: .black))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "7C3AED").lightened(0.30),
                             Color(hex: "7C3AED").darkened(0.14)],
                    startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(hex: "7C3AED").opacity(0.95), radius: w * 0.045)
                .position(x: w * shipX, y: h * shipY)
        }
    }
}

/// しりとり — a real chain, さくら → らくだ → だんご, with the handed-over kana
/// picked out in gold so the rule of the game is visible at a glance.
private struct ShiritoriScene: View {
    private let gold = ShiritoriTheme.gold
    private let cream = ShiritoriTheme.text

    private let chips: [(word: String, x: CGFloat, y: CGFloat)] = [
        ("さくら", 0.47, 0.14),
        ("らくだ", 0.66, 0.31),
        ("だんご", 0.51, 0.48),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Drawn first so it sits behind the chips it joins.
                Path { p in
                    p.move(to: CGPoint(x: w * chips[0].x, y: h * chips[0].y))
                    p.addLine(to: CGPoint(x: w * chips[1].x, y: h * chips[1].y))
                    p.addLine(to: CGPoint(x: w * chips[2].x, y: h * chips[2].y))
                }
                .stroke(gold.opacity(0.5),
                        style: StrokeStyle(lineWidth: w * 0.016, lineCap: .round,
                                           lineJoin: .round))

                ForEach(Array(chips.enumerated()), id: \.offset) { i, c in
                    chip(c.word, litHead: i > 0, litTail: i < chips.count - 1, w: w)
                        .position(x: w * c.x, y: h * c.y)
                }
            }
        }
    }

    private func chip(_ word: String, litHead: Bool, litTail: Bool, w: CGFloat) -> some View {
        let chars = Array(word)
        return HStack(spacing: 0) {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .foregroundColor((i == 0 && litHead) || (i == chars.count - 1 && litTail)
                                     ? gold : cream)
            }
        }
        .font(.system(size: w * 0.090, weight: .bold))
        .padding(.horizontal, w * 0.05)
        .padding(.vertical, w * 0.032)
        .background(Capsule().fill(ShiritoriTheme.chip))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.26), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: w * 0.02, y: w * 0.008)
    }
}

/// ことばパズル — a genuine board. The answer is ひとやすみ; たまごやき and
/// ひとりごと score exactly as drawn, and the third row is mid-typing.
private struct KotobaScene: View {
    private enum Mk { case correct, present, absent, typed }
    private struct Cell { let r: Int; let c: Int; let ch: String; let m: Mk }

    private let cells: [Cell] = [
        Cell(r: 0, c: 0, ch: "た", m: .absent),  Cell(r: 0, c: 1, ch: "ま", m: .absent),
        Cell(r: 0, c: 2, ch: "ご", m: .absent),  Cell(r: 0, c: 3, ch: "や", m: .present),
        Cell(r: 0, c: 4, ch: "き", m: .absent),
        Cell(r: 1, c: 0, ch: "ひ", m: .correct), Cell(r: 1, c: 1, ch: "と", m: .correct),
        Cell(r: 1, c: 2, ch: "り", m: .absent),  Cell(r: 1, c: 3, ch: "ご", m: .absent),
        Cell(r: 1, c: 4, ch: "と", m: .absent),
        Cell(r: 2, c: 0, ch: "ひ", m: .typed),   Cell(r: 2, c: 1, ch: "と", m: .typed),
        Cell(r: 2, c: 2, ch: "や", m: .typed),   Cell(r: 2, c: 3, ch: "",   m: .typed),
        Cell(r: 2, c: 4, ch: "",   m: .typed),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let gap = w * 0.020
            let side = (w * 0.66 - gap * 4) / 5
            let originX = w * 0.30, originY = w * 0.09
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                tile(cell, side: side)
                    .position(x: originX + CGFloat(cell.c) * (side + gap) + side / 2,
                              y: originY + CGFloat(cell.r) * (side + gap) + side / 2)
            }
        }
    }

    private func tile(_ cell: Cell, side: CGFloat) -> some View {
        Text(cell.ch)
            .font(.system(size: side * 0.56, weight: .bold))
            .foregroundColor(cell.m == .typed ? KotobaTheme.text : .white)
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: side * 0.20).fill(fill(cell.m)))
            .overlay(RoundedRectangle(cornerRadius: side * 0.20)
                .strokeBorder(cell.m == .typed ? Color.white.opacity(0.38) : .clear,
                              lineWidth: 1.2))
    }

    private func fill(_ m: Mk) -> Color {
        switch m {
        case .correct: return KotobaTheme.correct
        case .present: return KotobaTheme.present
        case .absent:  return KotobaTheme.absent
        case .typed:   return .white.opacity(0.06)
        }
    }
}

/// 数独 — a corner of the real board, washi and all.
private struct SudokuScene: View {
    /// A genuine, legal arrangement: no number repeats in any row, column or box
    /// of the 9×9 this is a window onto. 0 is an empty square.
    private let shown: [Int] = [
        5, 3, 0, 0, 7, 0, 0, 0, 0,
        6, 0, 0, 1, 9, 5, 0, 0, 0,
        0, 9, 8, 0, 0, 0, 0, 6, 0,
        8, 0, 0, 0, 6, 0, 0, 0, 3,
        4, 0, 0, 8, 0, 3, 0, 0, 1,
        7, 0, 0, 0, 2, 0, 0, 0, 6,
        0, 6, 0, 0, 0, 0, 2, 8, 0,
        0, 0, 0, 4, 1, 9, 0, 0, 5,
        0, 0, 0, 0, 8, 0, 0, 7, 9,
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let side = w * 0.74
            let cell = side / 9
            let x0 = w * 0.24, y0 = w * 0.06

            ZStack(alignment: .topLeading) {
                Rectangle().fill(SudokuTheme.paper)
                    .frame(width: side, height: side)
                    .offset(x: x0, y: y0)

                ForEach(0..<81, id: \.self) { i in
                    if shown[i] != 0 {
                        Text(sudokuKanji[shown[i]])
                            .font(.system(size: cell * 0.66, weight: .semibold))
                            .foregroundColor(i % 7 == 3 ? SudokuTheme.pencil : SudokuTheme.ink)
                            .position(x: x0 + cell * (CGFloat(i % 9) + 0.5),
                                      y: y0 + cell * (CGFloat(i / 9) + 0.5))
                    }
                }

                Path { p in
                    for k in 1..<9 where k % 3 != 0 {
                        let o = cell * CGFloat(k)
                        p.move(to: CGPoint(x: x0 + o, y: y0))
                        p.addLine(to: CGPoint(x: x0 + o, y: y0 + side))
                        p.move(to: CGPoint(x: x0, y: y0 + o))
                        p.addLine(to: CGPoint(x: x0 + side, y: y0 + o))
                    }
                }
                .stroke(SudokuTheme.line, lineWidth: 0.7)

                Path { p in
                    for k in [0, 3, 6, 9] {
                        let o = cell * CGFloat(k)
                        p.move(to: CGPoint(x: x0 + o, y: y0))
                        p.addLine(to: CGPoint(x: x0 + o, y: y0 + side))
                        p.move(to: CGPoint(x: x0, y: y0 + o))
                        p.addLine(to: CGPoint(x: x0 + side, y: y0 + o))
                    }
                }
                .stroke(SudokuTheme.heavy, lineWidth: 1.6)
            }
        }
    }
}

/// The tile itself: scene, scrim, label. Only the scene changes per game.
private struct GameSceneTile: View {
    let game: SecretGameID

    private var backdrop: [Color] {
        switch game {
        case .kanjiInvaders: return [Color(hex: "160B33"), .black]
        case .shiritori:     return ShiritoriTheme.backdrop
        case .kotoba:        return KotobaTheme.backdrop
        case .sudoku:        return [Color(hex: "8A7551"), Color(hex: "4A3C2A")]
        }
    }

    @ViewBuilder private var scene: some View {
        switch game {
        case .kanjiInvaders: InvadersScene()
        case .shiritori:     ShiritoriScene()
        case .kotoba:        KotobaScene()
        case .sudoku:        SudokuScene()
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: backdrop,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

            scene

            // Scrim so the label always reads, whatever is behind it.
            LinearGradient(stops: [
                .init(color: .clear, location: 0.60),
                .init(color: .black.opacity(0.55), location: 0.78),
                .init(color: .black.opacity(0.92), location: 1.0),
            ], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: game.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.22)))

                Spacer(minLength: 6)

                Text(game.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                Text(game.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: game.color.opacity(0.38), radius: 10, x: 0, y: 5)
    }
}

// MARK: - How to play

/// The rules, shared by the sheet and by しりとり's start screen so the two can
/// never drift apart.
struct GameRulesList: View {
    let game: SecretGameID
    var textColor: Color = .appText
    var defaultIconTint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(game.rules.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: r.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(r.tint ?? defaultIconTint
                                         ?? Color.readableOnPage(game.color))
                        .frame(width: 20, height: 20)
                    Text(r.text)
                        .font(.system(size: 14))
                        .foregroundColor(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// Reachable from the ⓘ in either word game's header.
struct GameRulesSheet: View {
    let game: SecretGameID
    @Environment(\.dismiss) private var dismiss

    /// Both word games keep their board colours everywhere they go, rules
    /// included. Invaders has no board of its own and follows the app.
    private var board: (bg: LinearGradient, text: Color, dim: Color,
                        card: Color, hairline: Color, tint: Color)? {
        switch game {
        case .kotoba:
            return (KotobaTheme.background, KotobaTheme.text, KotobaTheme.dim,
                    .white.opacity(0.06), .white.opacity(0.16), KotobaTheme.text)
        case .shiritori:
            return (ShiritoriTheme.background, ShiritoriTheme.text, ShiritoriTheme.dim,
                    .white.opacity(0.07), ShiritoriTheme.hairline, ShiritoriTheme.gold)
        case .sudoku:
            return (SudokuTheme.background, SudokuTheme.ink, SudokuTheme.dim,
                    SudokuTheme.paper, SudokuTheme.paperEdge, SudokuTheme.ink)
        case .kanjiInvaders:
            return nil
        }
    }

    var body: some View {
        ZStack {
            if let b = board { b.bg.ignoresSafeArea() } else { AppBackground() }
            VStack(spacing: 0) {
                Text(game.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(board?.text ?? .appText)
                Text("How to play")
                    .font(.system(size: 13))
                    .foregroundColor(board?.dim ?? .appTextSecondary)

                ScrollView {
                    GameRulesList(game: game,
                                  textColor: board?.text ?? .appText,
                                  defaultIconTint: board?.dim)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(board?.card ?? Color.appSurface))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(board?.hairline ?? Color.appHairline,
                                          lineWidth: 1))
                        .padding(.top, 18)

                    if let b = board {
                        BoardButton(title: "Got it", icon: "checkmark", tint: b.tint) { dismiss() }
                            .padding(.top, 18)
                    } else {
                        AccentActionButton(title: "Got it", icon: "checkmark") { dismiss() }
                            .padding(.top, 18)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Games menu

struct GamesMenuView: View {
    @ObservedObject private var unlocks = GameUnlocks.shared
    @State private var playing: SecretGameID?

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        ZStack {
            PatternedBackground(.games)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading("Found", subtitle: "Games you've uncovered. There may be more hiding.")

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(unlocks.discovered) { game in
                            Button { playing = game } label: {
                                GameSceneTile(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .standardNavBar("Games")
        .fullScreenCover(item: $playing) { game in
            switch game {
            case .kanjiInvaders: KanjiInvadersGame()
            // Both wear standardNavBar, whose Back button lives in a toolbar —
            // without a NavigationStack there is no toolbar and no way out.
            case .shiritori:     NavigationStack { ShiritoriGame() }
            case .kotoba:        NavigationStack { KotobaGame() }
            case .sudoku:        NavigationStack { SudokuGame() }
            }
        }
    }
}


