import SwiftUI

// Diagrams for the cheat sheets whose information is inherently spatial or scalar.
// A position word only means something relative to a reference point, and a
// frequency adverb only means something relative to the others — a list flattens
// exactly the relationship you need. These are here for those cases, not to
// decorate the sheets that a table already serves well.

// MARK: - Position

/// 上・下・前・後ろ・右・左・中 arranged where they actually are, around a box.
struct PositionDiagram: View {
    let tint: Color

    private struct Slot {
        let word: String, reading: String, col: Int, row: Int
    }
    private let slots: [Slot] = [
        Slot(word: "上",   reading: "うえ",   col: 1, row: 0),
        Slot(word: "左",   reading: "ひだり", col: 0, row: 1),
        Slot(word: "中",   reading: "なか",   col: 1, row: 1),
        Slot(word: "右",   reading: "みぎ",   col: 2, row: 1),
        Slot(word: "下",   reading: "した",   col: 1, row: 2),
    ]

    var body: some View {
        VStack(spacing: 10) {
            // The three-by-three: the box sits in the middle, each word where it
            // points.
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { col in
                            if let s = slots.first(where: { $0.col == col && $0.row == row }) {
                                cell(s.word, s.reading, centre: col == 1 && row == 1)
                            } else {
                                Color.clear.frame(height: 54)
                            }
                        }
                    }
                }
            }

            // 前 and 後ろ are depth, not height — they can't sit on the same plane
            // as the others without lying about the geometry.
            HStack(spacing: 8) {
                depthCell("前", "まえ", "in front", "arrow.down.forward")
                depthCell("後ろ", "うしろ", "behind", "arrow.up.backward")
                depthCell("外", "そと", "outside", "arrow.up.left.and.arrow.down.right")
            }
        }
    }

    private func cell(_ word: String, _ reading: String, centre: Bool) -> some View {
        VStack(spacing: 1) {
            Text(word)
                .font(.system(size: centre ? 20 : 18, weight: .bold))
                .foregroundColor(centre ? .white : Color.readableOnPage(tint))
            Text(reading)
                .font(.system(size: 10))
                .foregroundColor(centre ? .white.opacity(0.9) : .appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(centre ? AnyShapeStyle(tint.badgeGradient)
                             : AnyShapeStyle(tint.opacity(0.13)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(centre ? Color.clear : tint.opacity(0.45), lineWidth: 1)
        )
    }

    private func depthCell(_ word: String, _ reading: String,
                           _ gloss: String, _ icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.readableOnPage(tint))
            Text(word)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.appText)
            Text("\(reading) · \(gloss)")
                .font(.system(size: 9))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.appSurface.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.appHairline, lineWidth: 1))
    }
}

// MARK: - こそあど distance

/// The こそあど series is about distance from the two speakers, so it's drawn as
/// distance: near me, near you, away from both.
struct DistanceDiagram: View {
    let tint: Color

    private let zones: [(String, String, String, String)] = [
        ("こ", "これ · この · ここ", "Near me", "person.fill"),
        ("そ", "それ · その · そこ", "Near you", "person.2.fill"),
        ("あ", "あれ · あの · あそこ", "Away from both", "mountain.2.fill"),
        ("ど", "どれ · どの · どこ", "Which? / where?", "questionmark"),
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(zones.enumerated()), id: \.offset) { idx, z in
                HStack(spacing: 10) {
                    Text(z.0)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(tint.badgeGradient))
                        // Distance from the speaker, drawn as distance across the row.
                        .padding(.leading, CGFloat(idx == 3 ? 0 : idx) * 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(z.1)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appText)
                        Text(z.2)
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: z.3)
                        .font(.system(size: 13))
                        .foregroundColor(tint.opacity(0.8))
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appSurface.opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.appHairline, lineWidth: 1))
            }
        }
    }
}

// MARK: - Frequency

/// Frequency adverbs only mean anything relative to each other, so they're drawn
/// on one scale rather than listed.
struct FrequencyScale: View {
    let tint: Color

    private let steps: [(String, String, Double, Bool)] = [
        ("いつも",    "always",       1.00, false),
        ("たいてい",  "usually",      0.82, false),
        ("よく",      "often",        0.66, false),
        ("ときどき",  "sometimes",    0.46, false),
        ("たまに",    "occasionally", 0.30, false),
        ("あまり",    "not much",     0.16, true),
        ("めったに",  "rarely",       0.08, true),
        ("ぜんぜん",  "not at all",   0.02, true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, s in
                HStack(spacing: 8) {
                    Text(s.0)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appText)
                        .frame(width: 74, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.appText.opacity(0.06))
                            Capsule()
                                .fill(tint.opacity(s.3 ? 0.35 : 0.75))
                                .frame(width: max(6, geo.size.width * s.2))
                        }
                    }
                    .frame(height: 14)
                    Text(s.1)
                        .font(.system(size: 10))
                        .foregroundColor(.appTextSecondary)
                        .frame(width: 78, alignment: .leading)
                }
            }
            Text("The faded three require a negative verb: あまり行きません.")
                .font(.system(size: 11))
                .foregroundColor(.appTextSecondary)
                .padding(.top, 2)
        }
    }
}

// MARK: - Clock

/// The twelve hours where they sit on a dial, with the three irregular readings
/// picked out.
struct ClockFace: View {
    let tint: Color

    private let readings = ["いちじ", "にじ", "さんじ", "よじ", "ごじ", "ろくじ",
                            "しちじ", "はちじ", "くじ", "じゅうじ",
                            "じゅういちじ", "じゅうにじ"]
    /// How the hour is actually written. The numeral tells you where you are on
    /// the dial; this is what you'd meet on a timetable or a shop sign.
    private let written = ["一時", "二時", "三時", "四時", "五時", "六時",
                           "七時", "八時", "九時", "十時", "十一時", "十二時"]
    /// 4, 7 and 9 don't take the reading you'd predict from the number.
    private let irregular: Set<Int> = [4, 7, 9]

    /// The hands are parked at half past four, which is doing two jobs: 4時 is the
    /// most-mistaken hour (よじ, never しじ), and 半 is how you say the half hour.
    /// A dial with no hands is just numbers arranged in a circle.
    private let showHour = 4
    private let showMinute = 30

    private func angle(_ turns: Double) -> Double { turns * 2 * .pi - .pi / 2 }

    var body: some View {
        VStack(spacing: 10) {
            dial
            // What the hands actually say — the point of drawing them at all.
            HStack(spacing: 6) {
                Text("4時半").font(.system(size: 15, weight: .bold)).foregroundColor(.appText)
                Text("よじはん").font(.system(size: 12)).foregroundColor(.appTextSecondary)
                Text("· half past four").font(.system(size: 12)).foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.14)))
        }
    }

    private var dial: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: side / 2)
            let ring = side / 2 - 6          // the face itself
            let numberRing = ring - 34       // labels sit well inside the stroke
            let minuteHand = ring - 62
            let hourHand = ring - 82

            ZStack {
                Circle()
                    .fill(tint.opacity(0.06))
                    .frame(width: ring * 2, height: ring * 2)
                    .position(c)
                Circle()
                    .strokeBorder(tint.opacity(0.40), lineWidth: 2)
                    .frame(width: ring * 2, height: ring * 2)
                    .position(c)

                // Sixty ticks, with the twelve hour marks drawn longer and darker,
                // so the eye can count minutes as well as hours.
                ForEach(0..<60, id: \.self) { i in
                    let isHour = i % 5 == 0
                    let a = angle(Double(i) / 60)
                    let outer = ring - 3
                    let inner = ring - (isHour ? 12 : 6)
                    Path { p in
                        p.move(to: CGPoint(x: c.x + cos(a) * outer, y: c.y + sin(a) * outer))
                        p.addLine(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                    }
                    .stroke(tint.opacity(isHour ? 0.55 : 0.22),
                            lineWidth: isHour ? 2 : 1)
                }

                // Hands, stopping short of the numbers so nothing is obscured.
                let hourAngle = angle((Double(showHour) + Double(showMinute) / 60) / 12)
                let minuteAngle = angle(Double(showMinute) / 60)
                Path { p in
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + cos(hourAngle) * hourHand,
                                          y: c.y + sin(hourAngle) * hourHand))
                }
                .stroke(Color.readableOnPage(tint), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                Path { p in
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + cos(minuteAngle) * minuteHand,
                                          y: c.y + sin(minuteAngle) * minuteHand))
                }
                .stroke(Color.readableOnPage(tint), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Circle()
                    .fill(Color.appBackground)
                    .overlay(Circle().strokeBorder(Color.readableOnPage(tint), lineWidth: 3))
                    .frame(width: 11, height: 11)
                    .position(c)

                // Hours. 12 at the top, clockwise.
                ForEach(1...12, id: \.self) { h in
                    let a = angle(Double(h) / 12)
                    let odd = irregular.contains(h)
                    VStack(spacing: -1) {
                        Text("\(h)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(odd ? .white : .appText)
                        Text(written[h - 1])
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(odd ? .white : .appText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(readings[h - 1])
                            .font(.system(size: 7, weight: odd ? .bold : .regular))
                            .foregroundColor(odd ? .white : .appTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                    .frame(width: 52, height: 44)
                    .background(
                        Capsule().fill(odd ? Color.readableOnPage(tint) : .clear)
                    )
                    .position(x: c.x + cos(a) * numberRing,
                              y: c.y + sin(a) * numberRing)
                }
            }
        }
        .frame(height: 320)
    }
}

struct CompassRose: View {
    let tint: Color

    private struct Point {
        let kanji: String, reading: String, degrees: Double, cardinal: Bool
    }
    // 0° is up (north), running clockwise.
    private let points: [Point] = [
        Point(kanji: "北",   reading: "きた",     degrees: 0,   cardinal: true),
        Point(kanji: "北東", reading: "ほくとう", degrees: 45,  cardinal: false),
        Point(kanji: "東",   reading: "ひがし",   degrees: 90,  cardinal: true),
        Point(kanji: "南東", reading: "なんとう", degrees: 135, cardinal: false),
        Point(kanji: "南",   reading: "みなみ",   degrees: 180, cardinal: true),
        Point(kanji: "南西", reading: "なんせい", degrees: 225, cardinal: false),
        Point(kanji: "西",   reading: "にし",     degrees: 270, cardinal: true),
        Point(kanji: "北西", reading: "ほくせい", degrees: 315, cardinal: false),
    ]

    var body: some View {
        VStack(spacing: 10) {
            dial
            // Which way is up — the convention the whole rose depends on.
            HStack(spacing: 6) {
                Text("北").font(.system(size: 15, weight: .bold)).foregroundColor(.appText)
                Text("きた").font(.system(size: 12)).foregroundColor(.appTextSecondary)
                Text("· north is at the top").font(.system(size: 12)).foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.14)))
        }
    }

    private var dial: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: side / 2)
            let ring = side / 2 - 40

            ZStack {
                // Dial: the two axes drawn strongly, the diagonals faintly, so the
                // cardinal directions are the structure and the ordinals hang off it.
                Path { p in
                    p.move(to: CGPoint(x: c.x, y: c.y - ring)); p.addLine(to: CGPoint(x: c.x, y: c.y + ring))
                    p.move(to: CGPoint(x: c.x - ring, y: c.y)); p.addLine(to: CGPoint(x: c.x + ring, y: c.y))
                }
                .stroke(tint.opacity(0.45), lineWidth: 1.5)

                Path { p in
                    for deg in [45.0, 135.0] {
                        let a = deg * .pi / 180
                        let dx = CGFloat(sin(a)) * ring, dy = CGFloat(cos(a)) * ring
                        p.move(to: CGPoint(x: c.x - dx, y: c.y + dy))
                        p.addLine(to: CGPoint(x: c.x + dx, y: c.y - dy))
                    }
                }
                .stroke(tint.opacity(0.18), lineWidth: 1)

                // Radius matches where the ordinals sit, so the ring passes through
                // 北東・南東・南西・北西 and the cardinals stand outside it.
                Circle()
                    .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                    .frame(width: ring * 1.72, height: ring * 1.72)
                    .position(c)

                Circle()
                    .fill(tint.opacity(0.7))
                    .frame(width: 7, height: 7)
                    .position(c)

                ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                    let a = pt.degrees * .pi / 180
                    let r = pt.cardinal ? ring : ring * 0.86
                    VStack(spacing: 0) {
                        Text(pt.kanji)
                            .font(.system(size: pt.cardinal ? 22 : 13,
                                          weight: pt.cardinal ? .black : .semibold))
                            .foregroundColor(pt.cardinal ? Color.readableOnPage(tint)
                                                         : .appTextSecondary)
                        Text(pt.reading)
                            .font(.system(size: pt.cardinal ? 10 : 8))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.horizontal, pt.cardinal ? 6 : 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(pt.cardinal ? tint.opacity(0.14) : Color.clear)
                    )
                    .position(x: c.x + CGFloat(sin(a)) * r,
                              y: c.y - CGFloat(cos(a)) * r)
                }
            }
        }
        .frame(height: 300)
    }
}

// MARK: - Body

/// The body parts, split into two halves because the information splits that way.
///
/// Whole-body parts hang off a `figure.stand` silhouette with leader lines, since
/// where they are is the point. Facial features get icon cards instead: SF Symbols
/// ships dedicated `eye`, `ear`, `nose` and `mouth` glyphs, and one of those next
/// to the word says more than a leader line to a head 20 points across.
struct BodyDiagram: View {
    let tint: Color

    private struct Label {
        let word: String, reading: String, english: String, symbol: String?
        /// Anchor on the silhouette: `ax` in units of half its width, `ay` as a
        /// fraction of its height from the top.
        let ax: CGFloat, ay: CGFloat
        let left: Bool
    }

    // Anchors are fractions of the silhouette's frame: x from its centre, y from
    // its top. Tuned against the rendered glyph.
    private let labels: [Label] = [
        Label(word: "頭",   reading: "あたま", english: "head",     symbol: "brain.head.profile",
              ax:  0.00, ay: 0.092, left: true),
        Label(word: "首",   reading: "くび",   english: "neck",     symbol: nil,
              ax:  0.00, ay: 0.210, left: true),
        Label(word: "肩",   reading: "かた",   english: "shoulder", symbol: nil,
              ax: -0.73, ay: 0.280, left: true),
        Label(word: "手",   reading: "て",     english: "hand",     symbol: "hand.raised.fill",
              ax: -0.81, ay: 0.560, left: true),
        Label(word: "胸",   reading: "むね",   english: "chest",    symbol: nil,
              ax:  0.19, ay: 0.360, left: false),
        Label(word: "腕",   reading: "うで",   english: "arm",      symbol: nil,
              ax:  0.81, ay: 0.465, left: false),
        Label(word: "お腹", reading: "おなか", english: "stomach",  symbol: nil,
              ax:  0.10, ay: 0.520, left: false),
        Label(word: "足",   reading: "あし",   english: "leg, foot", symbol: "shoeprints.fill",
              ax:  0.44, ay: 0.840, left: false),
    ]

    /// `figure.stand` is far narrower than it is tall, so horizontal anchors have
    /// to scale by the glyph's own width — scaling them by the height, which is
    /// what a square diagram would do, throws the shoulder and hand off the body.
    private static let glyphAspect: CGFloat = 0.42

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let figH = h * 0.94
            let cx = w / 2, top = (h - figH) / 2

            ZStack {
                let halfW = figH * Self.glyphAspect / 2
                Path { p in
                    for (i, l) in labels.enumerated() {
                        let a = CGPoint(x: cx + l.ax * halfW, y: top + l.ay * figH)
                        p.move(to: CGPoint(x: l.left ? w * 0.30 : w * 0.70, y: ys(h)[i]))
                        p.addLine(to: a)
                    }
                }
                .stroke(tint.opacity(0.38), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(tint.opacity(0.5))
                    .frame(height: figH)
                    .position(x: cx, y: h / 2)

                ForEach(Array(labels.enumerated()), id: \.offset) { _, l in
                    Circle().fill(tint)
                        .frame(width: 5, height: 5)
                        .position(x: cx + l.ax * halfW, y: top + l.ay * figH)
                }
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    box(l).position(x: l.left ? w * 0.15 : w * 0.85, y: ys(h)[i])
                }
            }
        }
        .frame(height: 430)
    }

    /// Labels start level with their anchor, then get pushed apart so two on the
    /// same side can't overlap.
    private func ys(_ h: CGFloat) -> [CGFloat] {
        var out = labels.map { $0.ay * h * 0.94 + h * 0.03 }
        let gap: CGFloat = 64
        for side in [true, false] {
            let idx = labels.indices.filter { labels[$0].left == side }
            for k in 1..<idx.count where out[idx[k]] - out[idx[k - 1]] < gap {
                out[idx[k]] = out[idx[k - 1]] + gap
            }
        }
        return out.map { min(max($0, 24), h - 24) }
    }

    private func box(_ l: Label) -> some View {
        HStack(spacing: 5) {
            if let sym = l.symbol {
                Image(systemName: sym)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.readableOnPage(tint))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(l.word)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.appText)
                Text(l.reading)
                    .font(.system(size: 9))
                    .foregroundColor(.appTextSecondary)
                Text(l.english)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.readableOnPage(tint).opacity(0.85))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(tint.opacity(0.5), lineWidth: 1))
    }
}

/// The face, as icon cards. Each part has its own glyph, so the icon does the
/// pointing that a leader line would have to do on a tiny head.
struct FaceIcons: View {
    let tint: Color

    private let parts: [(String, String, String, String)] = [
        ("顔", "かお",   "face",   "face.smiling"),
        ("目", "め",     "eye",    "eye.fill"),
        ("耳", "みみ",   "ear",    "ear.fill"),
        ("鼻", "はな",   "nose",   "nose.fill"),
        ("口", "くち",   "mouth",  "mouth.fill"),
        ("髪", "かみ",   "hair",   "comb.fill"),
    ]

    private let columns = [GridItem(.flexible(), spacing: 8),
                           GridItem(.flexible(), spacing: 8),
                           GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                VStack(spacing: 4) {
                    Image(systemName: p.3)
                        .font(.system(size: 22))
                        .foregroundColor(Color.readableOnPage(tint))
                        .frame(height: 26)
                    Text(p.0)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.appText)
                    Text("\(p.1) — \(p.2)")
                        .font(.system(size: 10))
                        .foregroundColor(.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appSurface.opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1))
            }
        }
    }
}

// MARK: - Family tree

/// Five generations, drawn to make the one thing English speakers keep tripping
/// over impossible to miss: Japanese splits siblings by age. There is no word for
/// "brother" — only 兄 and 弟 — so the middle row puts older on the left, you in
/// the centre, and younger on the right.
///
/// These are the plain forms, the ones you use about your own family. The polite
/// forms for someone else's are the table underneath.
struct FamilyTree: View {
    let tint: Color

    private struct Node: View {
        let kanji: String
        let kana: String
        let english: String
        let tint: Color
        var emphasised: Bool = false

        var body: some View {
            VStack(spacing: 1) {
                Text(kanji)
                    .font(.system(size: 16, weight: emphasised ? .heavy : .semibold))
                    .foregroundColor(.appText)
                Text(kana)
                    .font(.system(size: 9.5))
                    .foregroundColor(.appTextSecondary)
                Text(english)
                    .font(.system(size: 8.5))
                    .foregroundColor(.appTextSecondary.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(emphasised ? 0.26 : 0.12))
            )
        }
    }

    /// The vertical thread between generations.
    private var link: some View {
        Rectangle()
            .fill(tint.opacity(0.35))
            .frame(width: 2, height: 12)
    }

    /// A labelled pair — used for the sibling groups, where the grouping *is* the
    /// lesson: two words on one side of you, two on the other.
    private func group(_ label: String, _ nodes: [Node]) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) { ForEach(0..<nodes.count, id: \.self) { nodes[$0] } }
            Text(label)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundColor(tint)
                .textCase(.uppercase)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Node(kanji: "祖父", kana: "そふ", english: "grandfather", tint: tint)
                Node(kanji: "祖母", kana: "そぼ", english: "grandmother", tint: tint)
            }
            link

            HStack(spacing: 5) {
                Node(kanji: "おじ", kana: "伯父・叔父", english: "uncle", tint: tint)
                Node(kanji: "父", kana: "ちち", english: "father", tint: tint)
                Node(kanji: "母", kana: "はは", english: "mother", tint: tint)
                Node(kanji: "おば", kana: "伯母・叔母", english: "aunt", tint: tint)
            }
            link

            HStack(alignment: .top, spacing: 6) {
                group("older", [Node(kanji: "兄", kana: "あに", english: "big brother", tint: tint),
                                Node(kanji: "姉", kana: "あね", english: "big sister", tint: tint)])
                VStack(spacing: 3) {
                    Node(kanji: "私", kana: "わたし", english: "me", tint: tint, emphasised: true)
                    Text(" ").font(.system(size: 8.5))
                }
                .frame(width: 62)
                group("younger", [Node(kanji: "弟", kana: "おとうと", english: "lil brother", tint: tint),
                                  Node(kanji: "妹", kana: "いもうと", english: "lil sister", tint: tint)])
            }
            link

            HStack(spacing: 6) {
                Node(kanji: "息子", kana: "むすこ", english: "son", tint: tint)
                Node(kanji: "娘", kana: "むすめ", english: "daughter", tint: tint)
                Node(kanji: "甥", kana: "おい", english: "nephew", tint: tint)
                Node(kanji: "姪", kana: "めい", english: "niece", tint: tint)
            }
            link

            Node(kanji: "孫", kana: "まご", english: "grandchild", tint: tint)
                .frame(width: 96)
        }
        .padding(.vertical, 4)
    }
}
