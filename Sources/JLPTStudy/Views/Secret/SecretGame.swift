import SwiftUI

// MARK: - Glowing secret title
//
// The home-screen title. Its letters glow in a hidden order (お→う→と→め→で)
// every ~30s; tapping them in that same order launches the easter-egg game.
// Pure SwiftUI + one timer — no assets.

struct GlowingTitle: View {
    var onUnlock: () -> Void

    // Observing the theme guarantees the title re-renders (and re-reads the
    // theme-derived .appAccent color) whenever the palette changes.
    @EnvironmentObject private var themeManager: ThemeManager

    private let letters = ["お", "め", "で", "と", "う"]   // indices 0…4
    private let secretOrder = [0, 4, 3, 1, 2]              // お → う → と → め → で

    @State private var glow: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var tapProgress = 0

    private let cycle = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(letters.indices, id: \.self) { i in
                Text(letters[i])
                    .font(.system(size: 62, weight: .heavy))
                    // Each letter takes its slice of one gradient, so the sweep
                    // runs across the whole word.
                    .foregroundColor(Color.appAccentSweepSample(
                        Double(i) / Double(max(letters.count - 1, 1))))
                    // Resting glow keeps the type feeling lit; the sweep below
                    // lifts each letter in turn.
                    .shadow(color: Color.appAccent.opacity(0.28), radius: 12, y: 4)
                    .brightness(Double(glow[i]) * 0.30)
                    .shadow(color: Color.appAccent.opacity(Double(glow[i]) * 0.95), radius: glow[i] * 20)
                    .shadow(color: .white.opacity(Double(glow[i]) * 0.55), radius: glow[i] * 6)
                    .scaleEffect(1 + glow[i] * 0.06)
                    .contentShape(Rectangle())
                    .onTapGesture { registerTap(i) }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .onReceive(cycle) { _ in playGlow() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { playGlow() }
        }
    }

    /// Sweeps the glow through the secret order — whole sweep ≈ 2.4s.
    private func playGlow() {
        for (step, idx) in secretOrder.enumerated() {
            let start = Double(step) * 0.38
            DispatchQueue.main.asyncAfter(deadline: .now() + start) {
                // Springy rise so the letter pops, then a soft fade back down.
                withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) { glow[idx] = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                    withAnimation(.easeOut(duration: 0.55)) { glow[idx] = 0 }
                }
            }
        }
    }

    private func registerTap(_ i: Int) {
        if i == secretOrder[tapProgress] {
            tapProgress += 1
            if tapProgress == secretOrder.count {
                tapProgress = 0
                onUnlock()
            }
        } else {
            tapProgress = (i == secretOrder[0]) ? 1 : 0
        }
    }
}

// MARK: - Kanji Invaders (the easter egg)

struct KanjiInvadersGame: View {
    @Environment(\.dismiss) private var dismiss

    /// A kanji foe: the character, the kana that spells its reading, and a colour.
    /// Readings are written as one string and split on use, which keeps the table
    /// readable at this length. 山 is deliberately absent — that's the ship.
    private struct Foe { let kanji: String; let reading: String; let color: Color }

    private static let kanjiSet: [Foe] = [
        // Nature
        Foe(kanji: "川", reading: "かわ",   color: .cyan),
        Foe(kanji: "火", reading: "ひ",     color: .orange),
        Foe(kanji: "水", reading: "みず",   color: .blue),
        Foe(kanji: "木", reading: "き",     color: .green),
        Foe(kanji: "空", reading: "そら",   color: .teal),
        Foe(kanji: "花", reading: "はな",   color: .pink),
        Foe(kanji: "海", reading: "うみ",   color: .blue),
        Foe(kanji: "星", reading: "ほし",   color: .yellow),
        Foe(kanji: "雨", reading: "あめ",   color: .cyan),
        Foe(kanji: "雪", reading: "ゆき",   color: .white),
        Foe(kanji: "風", reading: "かぜ",   color: .mint),
        Foe(kanji: "雲", reading: "くも",   color: .gray),
        Foe(kanji: "森", reading: "もり",   color: .green),
        Foe(kanji: "林", reading: "はやし", color: .green),
        Foe(kanji: "草", reading: "くさ",   color: .mint),
        Foe(kanji: "石", reading: "いし",   color: .gray),
        Foe(kanji: "田", reading: "た",     color: .yellow),
        Foe(kanji: "竹", reading: "たけ",   color: .green),
        Foe(kanji: "島", reading: "しま",   color: .teal),
        Foe(kanji: "池", reading: "いけ",   color: .blue),
        // Sky & time
        Foe(kanji: "月", reading: "つき",   color: .yellow),
        Foe(kanji: "日", reading: "ひ",     color: .orange),
        Foe(kanji: "朝", reading: "あさ",   color: .orange),
        Foe(kanji: "夜", reading: "よる",   color: .indigo),
        Foe(kanji: "冬", reading: "ふゆ",   color: .cyan),
        Foe(kanji: "夏", reading: "なつ",   color: .red),
        Foe(kanji: "春", reading: "はる",   color: .pink),
        Foe(kanji: "秋", reading: "あき",   color: .orange),
        // Creatures
        Foe(kanji: "犬", reading: "いぬ",   color: .brown),
        Foe(kanji: "猫", reading: "ねこ",   color: .orange),
        Foe(kanji: "魚", reading: "さかな", color: .mint),
        Foe(kanji: "鳥", reading: "とり",   color: .cyan),
        Foe(kanji: "馬", reading: "うま",   color: .brown),
        Foe(kanji: "牛", reading: "うし",   color: .brown),
        Foe(kanji: "虫", reading: "むし",   color: .green),
        Foe(kanji: "貝", reading: "かい",   color: .pink),
        // Body
        Foe(kanji: "目", reading: "め",     color: .purple),
        Foe(kanji: "口", reading: "くち",   color: .red),
        Foe(kanji: "手", reading: "て",     color: .orange),
        Foe(kanji: "足", reading: "あし",   color: .brown),
        Foe(kanji: "耳", reading: "みみ",   color: .pink),
        Foe(kanji: "心", reading: "こころ", color: .red),
        Foe(kanji: "体", reading: "からだ", color: .orange),
        // Everyday
        Foe(kanji: "人", reading: "ひと",   color: .white),
        Foe(kanji: "本", reading: "ほん",   color: .indigo),
        Foe(kanji: "車", reading: "くるま", color: .red),
        Foe(kanji: "門", reading: "もん",   color: .brown),
        Foe(kanji: "町", reading: "まち",   color: .yellow),
        Foe(kanji: "道", reading: "みち",   color: .gray),
        Foe(kanji: "音", reading: "おと",   color: .purple),
        Foe(kanji: "色", reading: "いろ",   color: .pink),
        Foe(kanji: "光", reading: "ひかり", color: .yellow),
        Foe(kanji: "力", reading: "ちから", color: .red),
        Foe(kanji: "金", reading: "かね",   color: .yellow),
        Foe(kanji: "米", reading: "こめ",   color: .white),
        // More weather & landscape
        Foe(kanji: "天", reading: "てん",   color: .cyan),
        Foe(kanji: "地", reading: "ち",     color: .brown),
        Foe(kanji: "雷", reading: "かみなり", color: .yellow),
        Foe(kanji: "氷", reading: "こおり", color: .cyan),
        Foe(kanji: "谷", reading: "たに",   color: .brown),
        Foe(kanji: "岩", reading: "いわ",   color: .gray),
        Foe(kanji: "泉", reading: "いずみ", color: .blue),
        // More creatures
        Foe(kanji: "猿", reading: "さる",   color: .brown),
        Foe(kanji: "熊", reading: "くま",   color: .brown),
        Foe(kanji: "狐", reading: "きつね", color: .orange),
        Foe(kanji: "兎", reading: "うさぎ", color: .pink),
        Foe(kanji: "亀", reading: "かめ",   color: .green),
        Foe(kanji: "蛇", reading: "へび",   color: .green),
        Foe(kanji: "象", reading: "ぞう",   color: .gray),
        Foe(kanji: "羊", reading: "ひつじ", color: .white),
        Foe(kanji: "豚", reading: "ぶた",   color: .pink),
        // More body
        Foe(kanji: "毛", reading: "け",     color: .brown),
        Foe(kanji: "歯", reading: "は",     color: .white),
        Foe(kanji: "首", reading: "くび",   color: .orange),
        Foe(kanji: "指", reading: "ゆび",   color: .pink),
        Foe(kanji: "顔", reading: "かお",   color: .orange),
        Foe(kanji: "頭", reading: "あたま", color: .red),
        // People
        Foe(kanji: "父", reading: "ちち",   color: .indigo),
        Foe(kanji: "母", reading: "はは",   color: .pink),
        Foe(kanji: "兄", reading: "あに",   color: .blue),
        Foe(kanji: "姉", reading: "あね",   color: .pink),
        Foe(kanji: "友", reading: "とも",   color: .green),
        Foe(kanji: "男", reading: "おとこ", color: .blue),
        Foe(kanji: "女", reading: "おんな", color: .pink),
        Foe(kanji: "子", reading: "こ",     color: .yellow),
        Foe(kanji: "王", reading: "おう",   color: .yellow),
        Foe(kanji: "神", reading: "かみ",   color: .white),
        // Places & things
        Foe(kanji: "家", reading: "いえ",   color: .brown),
        Foe(kanji: "店", reading: "みせ",   color: .orange),
        Foe(kanji: "駅", reading: "えき",   color: .indigo),
        Foe(kanji: "橋", reading: "はし",   color: .gray),
        Foe(kanji: "窓", reading: "まど",   color: .cyan),
        Foe(kanji: "机", reading: "つくえ", color: .brown),
        Foe(kanji: "紙", reading: "かみ",   color: .white),
        Foe(kanji: "傘", reading: "かさ",   color: .indigo),
        Foe(kanji: "靴", reading: "くつ",   color: .brown),
        Foe(kanji: "服", reading: "ふく",   color: .purple),
        Foe(kanji: "糸", reading: "いと",   color: .white),
        Foe(kanji: "刀", reading: "かたな", color: .gray),
        Foe(kanji: "弓", reading: "ゆみ",   color: .brown),
        Foe(kanji: "矢", reading: "や",     color: .orange),
        Foe(kanji: "舟", reading: "ふね",   color: .teal),
        Foe(kanji: "皿", reading: "さら",   color: .white),
        Foe(kanji: "玉", reading: "たま",   color: .cyan),
        // Food & drink
        Foe(kanji: "茶", reading: "ちゃ",   color: .green),
        Foe(kanji: "酒", reading: "さけ",   color: .yellow),
        Foe(kanji: "肉", reading: "にく",   color: .red),
        Foe(kanji: "卵", reading: "たまご", color: .yellow),
        Foe(kanji: "塩", reading: "しお",   color: .white),
        Foe(kanji: "豆", reading: "まめ",   color: .green),
        Foe(kanji: "麦", reading: "むぎ",   color: .yellow),
        // Direction & position
        Foe(kanji: "北", reading: "きた",   color: .cyan),
        Foe(kanji: "南", reading: "みなみ", color: .orange),
        Foe(kanji: "東", reading: "ひがし", color: .yellow),
        Foe(kanji: "西", reading: "にし",   color: .purple),
        Foe(kanji: "上", reading: "うえ",   color: .mint),
        Foe(kanji: "下", reading: "した",   color: .mint),
        Foe(kanji: "中", reading: "なか",   color: .teal),
        Foe(kanji: "外", reading: "そと",   color: .teal),
        Foe(kanji: "右", reading: "みぎ",   color: .indigo),
        Foe(kanji: "左", reading: "ひだり", color: .indigo),
        // Colours
        Foe(kanji: "赤", reading: "あか",   color: .red),
        Foe(kanji: "青", reading: "あお",   color: .blue),
        Foe(kanji: "白", reading: "しろ",   color: .white),
        Foe(kanji: "黒", reading: "くろ",   color: .gray),
        Foe(kanji: "緑", reading: "みどり", color: .green),
        // Abstract & language
        Foe(kanji: "夢", reading: "ゆめ",   color: .purple),
        Foe(kanji: "愛", reading: "あい",   color: .pink),
        Foe(kanji: "年", reading: "とし",   color: .orange),
        Foe(kanji: "時", reading: "とき",   color: .cyan),
        Foe(kanji: "声", reading: "こえ",   color: .yellow),
        Foe(kanji: "歌", reading: "うた",   color: .pink),
        Foe(kanji: "話", reading: "はなし", color: .teal),
        Foe(kanji: "字", reading: "じ",     color: .white),
        Foe(kanji: "名", reading: "な",     color: .mint),
        Foe(kanji: "絵", reading: "え",     color: .purple),
    ]

    // MARK: Power-ups

    /// Dropped by defeated kanji. Nothing here is on a timer — every pickup is a
    /// permanent upgrade that stacks for the rest of the run, so a long run
    /// visibly snowballs. Kept visually distinct from the foes above: none of
    /// these characters appear in `kanjiSet`.
    private enum Power: CaseIterable {
        /// Levelled upgrades — each pickup raises the level.
        case rapid, spread, pierce, magnet, score, slow, luck
        /// Stockpiled resources — each pickup adds a usable charge.
        case shield, life
        /// Deployable: drops a row of standing barriers in front of the ship.
        case barrier

        var symbol: String {
            switch self {
            case .rapid:  return "速"   // fast
            case .spread: return "散"   // scatter
            case .pierce: return "貫"   // pierce
            case .magnet: return "磁"   // magnet
            case .score:  return "倍"   // multiply
            case .slow:   return "遅"   // slow
            case .luck:   return "幸"   // fortune
            case .shield: return "盾"   // shield
            case .life:   return "命"   // life
            case .barrier: return "壁"  // wall
            }
        }
        var color: Color {
            switch self {
            case .rapid:  return .yellow
            case .spread: return .cyan
            case .pierce: return .orange
            case .magnet: return .mint
            case .score:  return .green
            case .slow:   return .purple
            case .luck:   return .pink
            case .shield: return .blue
            case .life:   return .red
            case .barrier: return Color(hex: "E2E8F0")
            }
        }
        var blurb: String {
            switch self {
            case .rapid:  return "FIRE RATE UP"
            case .spread: return "EXTRA BARREL"
            case .pierce: return "PIERCING"
            case .magnet: return "MAGNET UP"
            case .score:  return "SCORE UP"
            case .slow:   return "ENEMIES SLOWER"
            case .luck:   return "MORE DROPS"
            case .shield: return "+1 SHIELD"
            case .life:   return "+1 LIFE"
            case .barrier: return "BARRIERS UP"
            }
        }
        /// True for the two that bank charges rather than levelling a stat.
        var isCharge: Bool { self == .shield || self == .life || self == .barrier }

        /// How long this power sits out after dropping. Barriers are strong
        /// enough to warrant a full minute rather than the usual ten seconds.
        var respawnFrames: Int { self == .barrier ? 60 * 60 : 10 * 60 }

        /// Barriers stay out of the pool until the run is three minutes deep.
        var unlockSeconds: Double { self == .barrier ? 180 : 0 }

        /// Ceiling for this power. Once reached it stops dropping entirely, so
        /// late-run pickups are always something the player can still use.
        var maxLevel: Int {
            switch self {
            case .rapid:  return 5    // fire gap bottoms out at 10 frames
            case .spread: return 4    // 5 streams
            case .pierce: return 5
            case .magnet: return 5
            case .score:  return 8
            case .slow:   return 8    // swarm speed bottoms out at 50%
            case .luck:   return 6
            case .shield: return 3
            case .life:   return 4
            case .barrier: return 1   // unused — barriers are never "maxed"
            }
        }

        /// Relative drop weight — lives and barrels stay the rarest.
        var weight: Int {
            switch self {
            case .rapid:  return 16
            case .spread: return 16   // extra cannons matter, so they come early
            case .shield: return 15
            case .life:   return 13   // and so does the wingman
            case .score:  return 11
            case .pierce: return 10
            case .magnet: return 9
            case .slow:   return 8
            case .luck:   return 7
            case .barrier: return 7
            }
        }
    }

    private struct Enemy: Identifiable {
        let id = UUID()
        var x: CGFloat; var y: CGFloat; var vx: CGFloat
        let kanji: String; let reading: [String]; let color: Color
        /// Late-game armour, in layers. Each layer soaks one shot outright —
        /// including piercing shots, which armour stops dead.
        var shields = 0
    }
    private struct Bullet: Identifiable {
        let id = UUID(); var x: CGFloat; var y: CGFloat; var vx: CGFloat = 0
        /// How many enemies this shot has already punched through (see 貫).
        var pierced = 0
        /// Wingman shots are tinted differently so its work is visible.
        var fromEscort = false
    }
    private struct Particle: Identifiable {
        let id = UUID(); var x: CGFloat; var y: CGFloat
        var vx: CGFloat; var vy: CGFloat; let ch: String; var life: Double
    }
    /// The wingman craft. Hunts the nearest kanji and plinks single shots at it.
    private struct Escort { var x: CGFloat; var y: CGFloat }
    /// Return fire — enemies start shooting back late in a run.
    private struct FoeShot: Identifiable {
        let id = UUID(); var x: CGFloat; var y: CGFloat
        /// Non-zero only for the late-game scatter bursts.
        var vx: CGFloat = 0
    }
    /// A standing barrier: blocks the swarm and its fire, but the player's own
    /// shots pass straight through so it never gets in your way.
    private struct Barrier: Identifiable {
        let id = UUID(); var x: CGFloat; var y: CGFloat
        var hits = Barrier.maxHits
        static let maxHits = 5
    }
    private struct Drop: Identifiable {
        let id = UUID(); var x: CGFloat; var y: CGFloat; let power: Power
    }
    /// Background star. Drawn in a Canvas rather than as views — there are far too
    /// many for SwiftUI to diff one by one at 60fps.
    private struct Star { var x: CGFloat; var y: CGFloat; var speed: CGFloat; var r: CGFloat; var alpha: Double }

    @State private var size: CGSize = .zero
    @State private var shipX: CGFloat = 0
    @State private var dragStartX: CGFloat?
    @State private var bullets: [Bullet] = []
    @State private var enemies: [Enemy] = []
    @State private var particles: [Particle] = []
    @State private var drops: [Drop] = []
    @State private var foeShots: [FoeShot] = []
    @State private var barriers: [Barrier] = []
    @State private var stars: [Star] = []
    /// Best score across runs, persisted in UserDefaults. 0 until one is set.
    @AppStorage("KanjiInvadersHighScore") private var highScore = 0
    /// Set at game over if this run beat the stored best.
    @State private var isNewBest = false
    @State private var score = 0
    @State private var lives = 2
    @State private var gameOver = false
    @State private var frame = 0

    /// Permanent upgrade levels, one entry per levelled Power.
    @State private var lvl: [Power: Int] = [:]
    @State private var shields = 0
    /// Counts volleys so a half-finished barrel pair can alternate sides.
    @State private var volley = 0
    /// The wingman: a separate craft that hunts on its own for 10 seconds.
    @State private var escort: Escort? = nil
    @State private var escortUntil = 0
    /// Earliest frame another wingman may be summoned.
    @State private var escortReadyAt = 0
    /// Frame of the last drop, so a dry spell can be topped up (see `step`).
    @State private var lastDropFrame = 0
    /// Running count of kanji spawned — drives the armour cadence.
    @State private var spawnCount = 0
    /// Running count of enemy shots — every 50th becomes a scatter burst.
    @State private var foeShotCount = 0
    /// Frame each power last dropped — each one then sits out for 10 seconds,
    /// which stops one lucky power from monopolising a run.
    @State private var lastSpawn: [Power: Int] = [:]

    private var escortOn: Bool { frame < escortUntil }
    private static let escortFrames = 10 * 60      // wingman lasts 10 seconds
    private static let escortCooldown = 60 * 60    // …then a minute before the next
    /// Brief banner shown when a power-up is collected.
    @State private var pickupNote: (text: String, color: Color, frame: Int)?

    private func level(_ p: Power) -> Int { lvl[p] ?? 0 }

    // Derived stats. Each is clamped so a very long run can't reach an absurd
    // value — the upgrades keep mattering, but they never fully break the game.
    private var fireInterval: Int   { max(4, 20 - 2 * level(.rapid)) }
    private var pierceCount: Int    { level(.pierce) }
    /// Base one-in-eight, widened by 幸.
    private var dropChance: Double  { min(0.24, 0.062 + 0.028 * Double(level(.luck))) }
    /// Longest the player can go without a drop before the next kill guarantees one.
    private static let pityFrames = 15 * 60
    /// How long a given power sits out after dropping.
    private static let respawnFrames = 10 * 60

    // The swarm's escalation clock, each stage 30s after the last.
    private static let foeFireStart   = 120.0   // they start shooting back
    private static let foeShieldStart = 150.0   // occasional single-layer armour
    private static let foeShieldTier2 = 180.0   // single every 5th, double every 10th
    private static let foeShieldTier3 = 210.0   // single baseline, double 5th, triple 10th
    private static let foeShieldTier4 = 240.0   // triple every 5th, double for the rest
    private static let foeShieldTier5 = 270.0   // everything triple-plated
    private static let foeSprayStart  = 330.0   // a minute later: scatter bursts
    private static let foeSprayFast   = 390.0   // and a minute after that, twice as often

    /// Armour on the `n`-th kanji spawned, at `seconds` into the run.
    private func shieldLayers(spawnIndex n: Int, seconds: Double) -> Int {
        if seconds > Self.foeShieldTier5 { return 3 }
        if seconds > Self.foeShieldTier4 { return n % 5 == 0 ? 3 : 2 }
        if seconds > Self.foeShieldTier3 {
            if n % 10 == 0 { return 3 }
            if n % 5  == 0 { return 2 }
            return 1
        }
        if seconds > Self.foeShieldTier2 {
            if n % 10 == 0 { return 2 }
            if n % 5  == 0 { return 1 }
            return 0
        }
        // First stage stays occasional rather than on a strict count.
        if seconds > Self.foeShieldStart { return Int.random(in: 0..<7) == 0 ? 1 : 0 }
        return 0
    }

    private func onCooldown(_ p: Power) -> Bool {
        guard let last = lastSpawn[p] else { return false }
        return frame - last < p.respawnFrames
    }

    /// Some powers only enter the pool once the run is far enough along.
    private func unlocked(_ p: Power) -> Bool {
        Double(frame) / 60.0 >= p.unlockSeconds
    }
    private var scoreMultiplier: Double { 1 + 0.5 * Double(level(.score)) }
    private var magnetRadius: CGFloat {
        level(.magnet) == 0 ? 0 : CGFloat(70 + 45 * level(.magnet))
    }
    private var enemyDrag: CGFloat { max(0.5, 1 - 0.06 * CGFloat(level(.slow))) }
    /// Top-lit gradient in the same spirit as the app's badgeGradient, so the
    /// glyphs here read as part of the same design language rather than flat text.
    private func glyphGradient(_ c: Color) -> LinearGradient {
        LinearGradient(colors: [c.lightened(0.30), c.darkened(0.14)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// The ship's dark purple.
    private static let shipColor = Color(hex: "7C3AED")

    /// Blue exhaust behind the ship. Two out-of-phase sines give it an
    /// irregular flicker, and it's driven off `frame` so it costs nothing beyond
    /// the redraw the game loop already does.
    private var exhaust: some View {
        let flicker = sin(Double(frame) * 0.42) * 0.6 + sin(Double(frame) * 0.97) * 0.4
        let len = 32 + flicker * 9
        return ZStack {
            // soft halo
            Ellipse()
                .fill(RadialGradient(colors: [Color.cyan.opacity(0.40), .clear],
                                     center: .top, startRadius: 2, endRadius: 42))
                .frame(width: 50, height: len + 30)
            // body of the flame
            Ellipse()
                .fill(LinearGradient(colors: [.white, Color(hex: "38BDF8"), Color(hex: "1D4ED8").opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 21, height: len)
            // white-hot core
            Ellipse()
                .fill(LinearGradient(colors: [.white, .white.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 9, height: len * 0.55)
        }
        .offset(y: len / 2 + 15)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    private var bulletColor: Color {
        if pierceCount > 0 { return .orange }
        if level(.spread) > 0 { return .cyan }
        return .red
    }

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()

                // Starfield — one Canvas pass for the whole field.
                Canvas { ctx, _ in
                    for s in stars {
                        ctx.fill(Path(ellipseIn: CGRect(x: s.x, y: s.y, width: s.r, height: s.r)),
                                 with: .color(.white.opacity(s.alpha)))
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ForEach(enemies) { e in
                    ZStack {
                        ForEach(0..<e.shields, id: \.self) { i in
                            Circle()
                                .strokeBorder(.white.opacity(0.85 - Double(i) * 0.16), lineWidth: 2)
                                .frame(width: 48 + CGFloat(i) * 10, height: 48 + CGFloat(i) * 10)
                                .shadow(color: .white.opacity(0.5), radius: 5)
                        }
                        Text(e.kanji)
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(glyphGradient(e.color))
                            .shadow(color: e.color.opacity(0.75), radius: 9)
                    }
                    .position(x: e.x, y: e.y)
                }
                ForEach(drops) { d in
                    Text(d.power.symbol)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(glyphGradient(.black.opacity(0.9)))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(d.power.color))
                        .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                        .shadow(color: d.power.color.opacity(0.9), radius: 10)
                        .position(x: d.x, y: d.y)
                }
                // Shots recolour as they're upgraded, so the build is readable in
                // play. Each bolt is a white-hot head fading into a coloured tail,
                // with a glow — one shape per bullet, so it stays cheap at 60fps.
                ForEach(bullets) { b in
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.white,
                                     b.fromEscort ? .indigo : bulletColor,
                                     (b.fromEscort ? .indigo : bulletColor).opacity(0.15)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: pierceCount > 0 && !b.fromEscort ? 5 : 4, height: 22)
                        .shadow(color: (b.fromEscort ? .indigo : bulletColor).opacity(0.9), radius: 5)
                        .position(x: b.x, y: b.y)
                }
                ForEach(particles) { p in
                    Text(p.ch)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(glyphGradient(.white))
                        .shadow(color: .white.opacity(0.45 * p.life), radius: 6)
                        .opacity(p.life)
                        .position(x: p.x, y: p.y)
                }

                // Standing barriers. They shrink and dim as they're chewed through.
                ForEach(barriers) { b in
                    let f = CGFloat(b.hits) / CGFloat(Barrier.maxHits)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.95),
                                                      Color(hex: "64748B").opacity(0.8)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 26 + 46 * f, height: 10)
                        .opacity(0.35 + 0.65 * Double(f))
                        .shadow(color: .white.opacity(0.55 * Double(f)), radius: 6)
                        .position(x: b.x, y: b.y)
                }

                // Return fire from the swarm — blue, white-hot at the leading (lower) end.
                ForEach(foeShots) { f in
                    Capsule()
                        .fill(LinearGradient(colors: [Color.cyan.opacity(0.12), .cyan, .white],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 4, height: 20)
                        .shadow(color: .cyan.opacity(0.9), radius: 5)
                        .position(x: f.x, y: f.y)
                }

                // The wingman flies its own patrol.
                if let e = escort, escortOn {
                    Text("山")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(glyphGradient(.indigo))
                        .shadow(color: .indigo.opacity(0.95), radius: 11)
                        .position(x: e.x, y: e.y)
                }

                // Ship, wearing up to three rings for banked shields (the HUD
                // carries the exact count once they stack past that).
                ZStack {
                    exhaust

                    ForEach(0..<min(shields, 3), id: \.self) { i in
                        Circle()
                            .strokeBorder(Color.blue.opacity(0.9 - Double(i) * 0.25), lineWidth: 2)
                            .frame(width: 58 + CGFloat(i) * 12, height: 58 + CGFloat(i) * 12)
                            .shadow(color: .blue.opacity(0.6), radius: 8)
                    }
                    Text("山")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(glyphGradient(Self.shipColor))
                        .shadow(color: Self.shipColor.opacity(0.95), radius: 12)

                }
                .position(x: shipX, y: geo.size.height - 54)

                // HUD
                VStack(spacing: 6) {
                    ZStack {
                        // Centred in the screen, not between the two side items —
                        // their widths change as the score and lives do.
                        Text("BEST \(highScore)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(score > highScore
                                             ? Color(hex: "FBBF24")     // beating it
                                             : .white.opacity(0.45))
                            .frame(maxWidth: .infinity)

                        HStack {
                            Text("SCORE \(score)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(repeating: "山 ", count: max(0, lives)))
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                // Keeps the lives clear of the close button.
                                .padding(.trailing, 34)
                        }
                    }
                    // Everything earned so far. Levelled upgrades show ".N",
                    // banked charges show "×N".
                    HStack(spacing: 4) {
                        ForEach(Power.allCases.filter { badgeCount($0) > 0 }, id: \.self) { p in
                            Text("\(p.symbol)\(p.isCharge ? "×" : ".")\(badgeCount(p))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5).padding(.vertical, 3)
                                .background(Capsule().fill(
                                    isMaxed(p) ? p.color : p.color.opacity(0.85)))
                                // A maxed power gets a ring so you know to stop hoping for it.
                                .overlay(Capsule().strokeBorder(
                                    isMaxed(p) ? Color.white : .clear, lineWidth: 1))
                        }
                        if escortOn {
                            Text("僚 \(max(0, (escortUntil - frame) / 60 + 1))s")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 3)
                                .background(Capsule().fill(Color.indigo))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .frame(width: geo.size.width, alignment: .top)

                // Pickup banner
                if let note = pickupNote, frame - note.frame < 70 {
                    Text(note.text)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(note.color)
                        .shadow(color: note.color.opacity(0.9), radius: 12)
                        .frame(width: geo.size.width)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                        .allowsHitTesting(false)
                }

                // Exit + hint
                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    Spacer()
                    if frame < 200 {
                        Text("slide to move")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.bottom, 6)
                    }
                }
                .padding(18)
                .frame(width: geo.size.width, height: geo.size.height)

                if gameOver {
                    ZStack {
                        Color.black.opacity(0.7).ignoresSafeArea()
                        VStack(spacing: 10) {
                            Text("ゲームオーバー")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                            Text("Score \(score)")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.85))
                            if isNewBest {
                                Text("ハイスコア!")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color(hex: "FBBF24"))
                                    .shadow(color: Color(hex: "FBBF24").opacity(0.8), radius: 10)
                            } else {
                                Text("Best \(highScore)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in
                        if dragStartX == nil { dragStartX = shipX }
                        shipX = min(max(24, (dragStartX ?? shipX) + v.translation.width),
                                    geo.size.width - 24)
                    }
                    .onEnded { _ in dragStartX = nil }
            )
            .onAppear { setup(geo.size) }
            .onChange(of: geo.size) { setup($0) }
        }
        .onReceive(tick) { _ in step() }
        .statusBarHidden(true)
    }

    // MARK: Game logic

    /// What the HUD shows for a power: banked charges, or upgrade level.
    private func badgeCount(_ p: Power) -> Int {
        switch p {
        case .shield: return shields
        case .barrier: return barriers.count
        case .life:   return 0        // lives already have their own 山 readout
        default:      return level(p)
        }
    }

    /// Runs once, the first time a valid (non-zero) size is available.
    private func setup(_ newSize: CGSize) {
        guard size == .zero, newSize != .zero else { return }
        size = newSize
        shipX = newSize.width / 2
        // Three depth layers: far stars are small, dim and slow.
        stars = (0..<90).map { _ in
            let depth = Double.random(in: 0...1)
            return Star(x: .random(in: 0...newSize.width),
                        y: .random(in: 0...newSize.height),
                        speed: CGFloat(0.35 + depth * 1.9),
                        r: CGFloat(1.0 + depth * 1.6),
                        alpha: 0.22 + depth * 0.6)
        }
        for _ in 0..<4 { spawnEnemy() }
    }

    private func spawnEnemy() {
        guard size != .zero else { return }
        let pick = Self.kanjiSet.randomElement()!
        // ~60% fall straight down from a random point along the top; the rest
        // drift side to side (faster now). The straight droppers force the player
        // to move — an idle, centred ship can't clear them on its own.
        let drifts = Int.random(in: 0..<5) < 2
        spawnCount += 1
        let armour = shieldLayers(spawnIndex: spawnCount, seconds: Double(frame) / 60.0)
        enemies.append(Enemy(
            x: .random(in: 30...(size.width - 30)),
            y: .random(in: -40 ... 10),
            vx: drifts ? (Bool.random() ? 1.9 : -1.9) : 0,
            kanji: pick.kanji,
            reading: pick.reading.map(String.init),
            color: pick.color,
            shields: armour))
    }

    /// Five streams at most: the centre line, an outer pair, and finally an
    /// inner pair that fills the gap between them. A half-finished pair
    /// alternates sides volley to volley rather than straddling the centre, so
    /// the shot directly under the ship is never split.
    ///
    ///   level 0 → ·   ·   ●   ·   ·      1 stream
    ///   level 1 → ◐   ·   ●   ·   ◑      2  (outer, alternating)
    ///   level 2 → ◯   ·   ●   ·   ◯      3  (outer pair)
    ///   level 3 → ◯   ◐   ●   ◑   ◯      4  (+ inner, alternating)
    ///   level 4 → ◯   ◯   ●   ◯   ◯      5  (inner pair)
    private func fire() {
        let y = size.height - 76
        let l = level(.spread)

        addStream(vx: 0, y: y)                                  // centre, always
        addPair(spread: 4.6, filled: min(l, 2), y: y)           // outer pair
        addPair(spread: 2.3, filled: max(0, l - 2), y: y)       // inner pair, between
        volley += 1
    }

    private func addStream(vx: CGFloat, y: CGFloat) {
        bullets.append(Bullet(x: shipX, y: y, vx: vx))
    }

    /// `filled` of 2 fires both sides; 1 alternates side by volley; 0 fires none.
    private func addPair(spread: CGFloat, filled: Int, y: CGFloat) {
        switch filled {
        case 2...:
            addStream(vx: -spread, y: y)
            addStream(vx:  spread, y: y)
        case 1:
            addStream(vx: (volley % 2 == 0 ? -spread : spread), y: y)
        default:
            break
        }
    }

    /// True once a power can't be improved any further.
    /// 命 is never "maxed": at full lives it summons the escort ship instead,
    /// so it always stays worth picking up.
    private func isMaxed(_ p: Power) -> Bool {
        switch p {
        // Full on lives and the wingman still cooling down — nothing left to give.
        case .life:   return lives >= p.maxLevel && frame < escortReadyAt
        // Always worth taking — it re-lays the whole row.
        case .barrier: return false
        case .shield: return shields >= p.maxLevel
        default:      return level(p) >= p.maxLevel
        }
    }

    /// Weighted pick that skips anything already maxed out, so a drop is never
    /// wasted on an upgrade the player can't take. Nil when everything is maxed.
    private func randomDrop() -> Power? {
        let pool = Power.allCases.filter { !isMaxed($0) && !onCooldown($0) && unlocked($0) }
        guard !pool.isEmpty else { return nil }
        let total = pool.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<total)
        for p in pool {
            roll -= p.weight
            if roll < 0 { return p }
        }
        return pool.last
    }

    private func collect(_ p: Power) {
        switch p {
        case .barrier:
            // Three plates, spread across the lane in front of the ship.
            let y = size.height - 210
            barriers = [0.25, 0.5, 0.75].map { Barrier(x: size.width * $0, y: y) }
        case .shield:
            shields = min(shields + 1, p.maxLevel)
        case .life:
            // Past the life cap the pickup scrambles a wingman instead — but only
            // if one isn't already out or cooling down.
            if lives < p.maxLevel {
                lives += 1
            } else {
                escort = Escort(x: shipX, y: size.height * 0.62)
                escortUntil = frame + Self.escortFrames
                escortReadyAt = frame + Self.escortCooldown
                pickupNote = ("WINGMAN", .indigo, frame)
                return
            }
        default:
            lvl[p] = min(level(p) + 1, p.maxLevel)
        }
        pickupNote = (p.blurb, p.color, frame)
    }

    private func step() {
        guard !gameOver, size != .zero else { return }
        frame += 1
        let seconds = Double(frame) / 60.0
        // 0 at the start, 1 once the run is fully wound up (~2½ minutes in).
        // Squared, so the opening stays calm and the pressure arrives late
        // rather than immediately.
        let t = min(1.0, seconds / 112.0)
        // Once the curve tops out the swarm keeps escalating: three more
        // step-ups, 60s apart, each adding speed, spawn rate and headcount.
        let extraSteps = max(0, min(3, Int((seconds - 120) / 60)))
        let speedUp = 1.0 + 1.42 * t * t + 0.22 * Double(extraSteps)

        // Starfield drifts down behind everything and wraps around.
        for i in stars.indices {
            stars[i].y += stars[i].speed
            if stars[i].y > size.height {
                stars[i].y = -2
                stars[i].x = .random(in: 0...size.width)
            }
        }

        // Auto-fire from the ship; 速 levels shorten the gap between volleys.
        if frame % fireInterval == 0 { fire() }

        for i in bullets.indices {
            bullets[i].y -= 9
            bullets[i].x += bullets[i].vx
        }
        bullets.removeAll { $0.y < -20 || $0.x < -20 || $0.x > size.width + 20 }

        // Each 遅 level shaves a little off the swarm's speed, permanently.
        let drag = enemyDrag
        for i in enemies.indices {
            enemies[i].x += enemies[i].vx * speedUp * drag
            if enemies[i].x < 24 || enemies[i].x > size.width - 24 { enemies[i].vx *= -1 }
            enemies[i].y += 1.5 * speedUp * drag
        }

        // Wingman: drift toward the nearest kanji and plink at it.
        if escortOn {
            if escort == nil { escort = Escort(x: shipX, y: size.height * 0.62) }
            if var e = escort {
                if let target = enemies.min(by: {
                    abs($0.x - e.x) + abs($0.y - e.y) < abs($1.x - e.x) + abs($1.y - e.y)
                }) {
                    e.x += max(-3.4, min(3.4, (target.x - e.x) * 0.09))
                    e.y += max(-1.6, min(1.6, (target.y + 150 - e.y) * 0.03))
                }
                e.x = min(max(22, e.x), size.width - 22)
                e.y = min(max(size.height * 0.3, e.y), size.height - 130)
                escort = e
                if frame % 15 == 0 { bullets.append(Bullet(x: e.x, y: e.y - 20, fromEscort: true)) }
            }
        } else if escort != nil {
            escort = nil
        }

        // Past two minutes the swarm starts shooting back, and gradually more often.
        if seconds > 120, !enemies.isEmpty {
            // Three step-ups, 30s apart, then it holds: 36 → 29 → 22 → 15 frames.
            let steps = min(3, Int((seconds - 120) / 30))
            let every = 36 - steps * 7
            if frame % every == 0,
               let shooter = enemies.filter({ $0.y > 0 && $0.y < size.height * 0.72 }).randomElement() {
                foeShotCount += 1
                // Last escalation of all: occasionally the shot is a fan of five.
                let sprayEvery = seconds > Self.foeSprayFast ? 25 : 50
                if seconds > Self.foeSprayStart && foeShotCount % sprayEvery == 0 {
                    for k in -2...2 {
                        foeShots.append(FoeShot(x: shooter.x, y: shooter.y + 24,
                                                vx: CGFloat(k) * 1.35))
                    }
                } else {
                    foeShots.append(FoeShot(x: shooter.x, y: shooter.y + 24))
                }
            }
        }
        for i in foeShots.indices {
            foeShots[i].y += 5.4
            foeShots[i].x += foeShots[i].vx
        }
        foeShots.removeAll { $0.y > size.height + 24 || $0.x < -24 || $0.x > size.width + 24 }

        // Drops fall; 磁 levels widen the radius inside which they home in.
        let shipY = size.height - 54
        let pull = magnetRadius
        for i in drops.indices {
            drops[i].y += 2.2
            if pull > 0 {
                let dx = shipX - drops[i].x, dy = shipY - drops[i].y
                let dist = max(sqrt(dx * dx + dy * dy), 0.001)
                if dist < pull {
                    drops[i].x += dx / dist * 3.4
                    drops[i].y += dy / dist * 3.4
                }
            }
        }
        let caught = drops.filter { abs($0.x - shipX) < 32 && abs($0.y - shipY) < 32 }
        for d in caught { collect(d.power) }
        if !caught.isEmpty {
            let ids = Set(caught.map(\.id))
            drops.removeAll { ids.contains($0.id) }
        }
        drops.removeAll { $0.y > size.height + 30 }
        // Spawn aggressively and ramp fast (52 → 17 frames), allowing a big swarm.
        // At the floor (~17) the spawn rate outpaces the ship's fire rate, so a run
        // will eventually be overwhelmed — the game is now a score chase, not survivable.
        // Spawn gap 70 → 14 frames, and the swarm is allowed to grow 8 → 24,
        // then the extra steps push both further still.
        let spawnEvery = max(9, Int(70 - 56 * pow(t, 1.1)) - 2 * extraSteps)
        let swarmCap = 8 + Int(16 * t) + 3 * extraSteps
        if frame % spawnEvery == 0 && enemies.count < swarmCap { spawnEnemy() }

        // Bullet ↔ enemy collisions: the kanji bursts into its hiragana.
        // Bullet-major so a 貫-upgraded shot can carry on into whatever is behind.
        if !bullets.isEmpty && !enemies.isEmpty {
            var deadEnemies = Set<UUID>(), deadBullets = Set<UUID>()
            let allowedPierce = pierceCount
            for bi in bullets.indices {
                let bulletId = bullets[bi].id
                if deadBullets.contains(bulletId) { continue }
                for ei in enemies.indices where !deadEnemies.contains(enemies[ei].id) {
                    let e = enemies[ei]
                    guard abs(bullets[bi].x - e.x) < 22,
                          abs(bullets[bi].y - e.y) < 24 else { continue }

                    // Armour strips one layer and stops the shot dead — piercing
                    // buys you nothing against a shielded kanji.
                    if e.shields > 0 {
                        enemies[ei].shields -= 1
                        particles.append(Particle(
                            x: e.x, y: e.y,
                            vx: .random(in: -1.6...1.6), vy: .random(in: -2.4 ... -0.6),
                            ch: "・", life: 0.7))
                        deadBullets.insert(bulletId)
                        break
                    }

                    deadEnemies.insert(e.id)
                    score += Int((Double(10 * e.reading.count) * scoreMultiplier).rounded())
                    for (k, ch) in e.reading.enumerated() {
                        particles.append(Particle(
                            x: e.x + CGFloat(k - e.reading.count / 2) * 8, y: e.y,
                            vx: .random(in: -2.2...2.2), vy: .random(in: -3.5 ... -1),
                            ch: ch, life: 1))
                    }
                    // Normally a random drop, but a long dry spell guarantees the
                    // next one — so upgrades keep arriving even on a cold streak.
                    let overdue = frame - lastDropFrame > Self.pityFrames
                    if overdue || Double.random(in: 0..<1) < dropChance,
                       let p = randomDrop() {
                        drops.append(Drop(x: e.x, y: e.y, power: p))
                        lastDropFrame = frame
                        lastSpawn[p] = frame
                    }

                    if bullets[bi].pierced < allowedPierce {
                        bullets[bi].pierced += 1     // keeps flying
                    } else {
                        deadBullets.insert(bulletId)
                        break
                    }
                }
            }
            if !deadBullets.isEmpty { bullets.removeAll { deadBullets.contains($0.id) } }
            if !deadEnemies.isEmpty { enemies.removeAll { deadEnemies.contains($0.id) } }
        }

        // Barriers eat incoming fire. Player shots are deliberately not checked
        // here — they pass straight through and cost the barrier nothing.
        if !barriers.isEmpty && !foeShots.isEmpty {
            var spent = Set<UUID>()
            for bi in barriers.indices {
                let b = barriers[bi]
                for shot in foeShots where !spent.contains(shot.id) {
                    guard abs(shot.x - b.x) < (13 + 23 * CGFloat(b.hits) / CGFloat(Barrier.maxHits)),
                          abs(shot.y - b.y) < 12 else { continue }
                    spent.insert(shot.id)
                    barriers[bi].hits -= 1
                    if barriers[bi].hits <= 0 { break }
                }
            }
            if !spent.isEmpty { foeShots.removeAll { spent.contains($0.id) } }
            barriers.removeAll { $0.hits <= 0 }
        }

        // A kanji running into a barrier is destroyed by it, at the cost of a hit.
        // No score: the barrier did the work, not the player.
        if !barriers.isEmpty && !enemies.isEmpty {
            var stopped = Set<UUID>()
            for bi in barriers.indices {
                let b = barriers[bi]
                for e in enemies where !stopped.contains(e.id) {
                    guard abs(e.x - b.x) < (18 + 23 * CGFloat(b.hits) / CGFloat(Barrier.maxHits)),
                          abs(e.y - b.y) < 24 else { continue }
                    stopped.insert(e.id)
                    for (k, ch) in e.reading.enumerated() {
                        particles.append(Particle(
                            x: e.x + CGFloat(k - e.reading.count / 2) * 8, y: e.y,
                            vx: .random(in: -2.0...2.0), vy: .random(in: -3.0 ... -0.8),
                            ch: ch, life: 1))
                    }
                    barriers[bi].hits -= 1
                    if barriers[bi].hits <= 0 { break }
                }
            }
            if !stopped.isEmpty { enemies.removeAll { stopped.contains($0.id) } }
            barriers.removeAll { $0.hits <= 0 }
        }

        // A blue laser landing on the ship costs the same as a breach.
        let struckBy = foeShots.filter { abs($0.x - shipX) < 24 && abs($0.y - shipY) < 26 }
        if !struckBy.isEmpty {
            let ids = Set(struckBy.map(\.id))
            foeShots.removeAll { ids.contains($0.id) }
            applyDamage(struckBy.count)
        }

        // An enemy reaching the ship line costs a life — unless a 盾 eats it first.
        let line = size.height - 54
        let breached = enemies.filter { $0.y >= line }
        if !breached.isEmpty {
            enemies.removeAll { $0.y >= line }
            applyDamage(breached.count)
        }

        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].vy += 0.14
            particles[i].life -= 0.028
        }
        particles.removeAll { $0.life <= 0 }
    }

    /// Shields soak hits first, then lives. Shared by breaches and return fire.
    private func applyDamage(_ hits: Int) {
        var damage = hits
        let absorbed = min(shields, damage)
        shields -= absorbed
        damage -= absorbed
        guard damage > 0 else { return }
        lives -= damage
        if lives <= 0 { lives = 0; endGame() }
    }

    private func endGame() {
        gameOver = true
        // Committed only here, so BEST shows the target to chase during play
        // rather than just mirroring the current score.
        if score > highScore {
            isNewBest = true
            highScore = score
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { dismiss() }
    }
}
