import SwiftUI

// Hand-drawn SwiftUI diagrams for the handful of grammar points that are far
// clearer as a picture than as prose. Curation (which point → which diagram)
// lives in `GrammarVisual.forPoint`, so no lesson JSON has to change.

enum GrammarVisual {
    case givingReceiving
    case kosoado
    case comparison
    case location
    case conditionals
    case transitiveIntransitive
    case passive
    case causative
    case teForm
    case particles
    case adjectives
    case counters
    case tellingTime
    case politeness

    /// The grammar points that get a visual aid, keyed by their stable point id.
    static func forPoint(_ id: String) -> GrammarVisual? {
        switch id {
        case "ageru-kureru-morau", "te-ageru-kureru-morau":            return .givingReceiving
        case "ko-so-a-do-mono", "ko-so-a-do-noun", "ko-so-a-do-place": return .kosoado
        case "te-form":                                                return .teForm
        case "wa-particle", "wo-particle", "de-particle", "ni-time":   return .particles
        case "i-adjectives", "na-adjectives":                          return .adjectives
        case "counters-common", "counters-tsu",
             "counting-people", "counters-frequency-age":              return .counters
        case "telling-time":                                           return .tellingTime
        case "sonkeigo-verbs", "kensongo":                             return .politeness
        case "yori", "hou-ga", "ichiban":                              return .comparison
        case "location-words":                                         return .location
        case "to-conditional", "tara-conditional", "ba-conditional", "nara": return .conditionals
        case "transitive-intransitive":                                return .transitiveIntransitive
        case "passive":                                                return .passive
        case "causative":                                              return .causative
        default:                                                       return nil
        }
    }

    @ViewBuilder
    func view(accent: Color) -> some View {
        switch self {
        case .givingReceiving:        GivingReceivingDiagram(accent: accent)
        case .kosoado:                KosoadoDiagram(accent: accent)
        case .comparison:             ComparisonDiagram(accent: accent)
        case .location:               LocationDiagram(accent: accent)
        case .conditionals:           ConditionalsDiagram(accent: accent)
        case .transitiveIntransitive: TransIntransDiagram(accent: accent)
        case .passive:                PassiveDiagram(accent: accent)
        case .causative:              CausativeDiagram(accent: accent)
        case .teForm:                 TeFormDiagram(accent: accent)
        case .particles:              ParticlesDiagram(accent: accent)
        case .adjectives:             AdjectivesDiagram(accent: accent)
        case .counters:               CountersDiagram(accent: accent)
        case .tellingTime:            TellingTimeDiagram(accent: accent)
        case .politeness:             PolitenessDiagram(accent: accent)
        }
    }
}

// MARK: - Shared bits

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A horizontal arrow that fills its width, pointing left or right.
private struct FlowArrow: View {
    enum Direction { case left, right }
    let direction: Direction
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            if direction == .left {
                Triangle().fill(color).frame(width: 9, height: 11).rotationEffect(.degrees(180))
            }
            Capsule().fill(color).frame(height: 3).frame(maxWidth: .infinity)
            if direction == .right {
                Triangle().fill(color).frame(width: 9, height: 11)
            }
        }
    }
}

/// Small rounded container the diagrams sit in.
private func diagramPanel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurfaceHigh))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.appHairline, lineWidth: 1))
}

// MARK: - Giving & receiving (あげる・くれる・もらう)

private struct GivingReceivingDiagram: View {
    let accent: Color

    var body: some View {
        diagramPanel {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    party(title: "わたし", subtitle: "you / in-group", icon: "house.fill", highlighted: true)

                    VStack(spacing: 12) {
                        arrow(.right, verb: "あげる", gloss: "give — flows away", color: Color(hex: "EA580C"))
                        arrow(.left,  verb: "くれる", gloss: "they give to you", color: Color(hex: "16A34A"))
                        arrow(.left,  verb: "もらう", gloss: "you receive", color: Color(hex: "0D9488"))
                    }
                    .frame(maxWidth: .infinity)

                    party(title: "あいて", subtitle: "someone else", icon: "person.fill", highlighted: false)
                }

                Text("Pick the verb by direction relative to you — the speaker at the center.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func party(title: String, subtitle: String, icon: String, highlighted: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(highlighted ? accent : .secondary)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appText)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 74)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(highlighted ? accent.opacity(0.12) : Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(highlighted ? accent.opacity(0.5) : Color.appHairline, lineWidth: 1))
    }

    private func arrow(_ dir: FlowArrow.Direction, verb: String, gloss: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(verb)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            FlowArrow(direction: dir, color: color)
            Text(gloss)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - こそあど demonstratives

private struct KosoadoDiagram: View {
    let accent: Color

    private struct Zone { let letter, distance, words: String; let color: Color }
    private let zones = [
        Zone(letter: "こ", distance: "near you", words: "これ・この\nここ・こっち", color: Color(hex: "2563EB")),
        Zone(letter: "そ", distance: "near them", words: "それ・その\nそこ・そっち", color: Color(hex: "16A34A")),
        Zone(letter: "あ", distance: "far away", words: "あれ・あの\nあそこ・あっち", color: Color(hex: "DC2626")),
    ]

    var body: some View {
        diagramPanel {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(zones.enumerated()), id: \.offset) { _, z in
                        VStack(spacing: 5) {
                            Text(z.letter)
                                .font(.system(size: 26, weight: .heavy))
                                .foregroundColor(z.color)
                            Text(z.distance)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(z.words)
                                .font(.system(size: 12))
                                .foregroundColor(.appText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(z.color.opacity(0.10)))
                    }
                }

                // Distance scale under the zones
                HStack {
                    Text("closest").font(.system(size: 9)).foregroundColor(.secondary)
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(hex: "2563EB"), Color(hex: "16A34A"), Color(hex: "DC2626")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 3)
                        .clipShape(Capsule())
                    Text("farthest").font(.system(size: 9)).foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    Text("ど")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(accent)
                    Text("どれ・どの・どこ・どっち — the question set (which? where?)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Comparisons (より・のほうが・いちばん)

private struct ComparisonDiagram: View {
    let accent: Color

    var body: some View {
        diagramPanel {
            VStack(spacing: 12) {
                HStack(alignment: .bottom, spacing: 16) {
                    bar(label: "A", heightFactor: 0.45, crown: false, color: .secondary)
                    bar(label: "B", heightFactor: 0.72, crown: false, color: accent.opacity(0.75))
                    bar(label: "C", heightFactor: 1.0, crown: true, color: accent)
                }
                .frame(height: 96)

                VStack(spacing: 5) {
                    captionRow("A より B のほうが たかい", "B is taller than A")
                    captionRow("A・B・C の中で C が いちばん たかい", "C is the tallest of all")
                }
            }
        }
    }

    private func bar(label: String, heightFactor: CGFloat, crown: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            if crown {
                HStack(spacing: 3) {
                    Image(systemName: "crown.fill").font(.system(size: 10))
                    Text("いちばん").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(accent)
            } else {
                Spacer().frame(height: 14)
            }
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 42, height: max(14, 82 * heightFactor))
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.appText)
        }
    }

    private func captionRow(_ jp: String, _ en: String) -> some View {
        VStack(spacing: 1) {
            Text(jp).font(.system(size: 12, weight: .medium)).foregroundColor(.appText)
            Text(en).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Location words (うえ・した・まえ・うしろ・なか…)

private struct LocationDiagram: View {
    let accent: Color

    var body: some View {
        diagramPanel {
            VStack(spacing: 10) {
                VStack(spacing: 6) {
                    chip("うえ", "above")
                    HStack(spacing: 6) {
                        chip("ひだり", "left")
                        VStack(spacing: 1) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 20))
                                .foregroundColor(accent)
                            Text("なか").font(.system(size: 12, weight: .bold)).foregroundColor(.appText)
                            Text("inside").font(.system(size: 9)).foregroundColor(.secondary)
                        }
                        .frame(width: 88, height: 66)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.4), lineWidth: 1))
                        chip("みぎ", "right")
                    }
                    chip("した", "below")
                }

                HStack(spacing: 6) {
                    smallChip("まえ", "in front")
                    smallChip("うしろ", "behind")
                    smallChip("となり", "next to")
                }
            }
        }
    }

    private func chip(_ jp: String, _ en: String) -> some View {
        VStack(spacing: 0) {
            Text(jp).font(.system(size: 13, weight: .semibold)).foregroundColor(.appText)
            Text(en).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .frame(width: 66, height: 40)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.appHairline, lineWidth: 1))
    }

    private func smallChip(_ jp: String, _ en: String) -> some View {
        HStack(spacing: 4) {
            Text(jp).font(.system(size: 12, weight: .semibold)).foregroundColor(.appText)
            Text(en).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.appSurface))
        .overlay(Capsule().strokeBorder(Color.appHairline, lineWidth: 1))
    }
}

// MARK: - て-form conversion

private struct TeFormDiagram: View {
    let accent: Color
    private struct Row { let endings, result, example: String; let color: Color }
    private let g1: [Row] = [
        Row(endings: "う・つ・る", result: "って", example: "買[か]う → 買[か]って", color: Color(hex: "DC2626")),
        Row(endings: "む・ぶ・ぬ", result: "んで", example: "飲[の]む → 飲[の]んで", color: Color(hex: "2563EB")),
        Row(endings: "く",        result: "いて", example: "書[か]く → 書[か]いて", color: Color(hex: "D97706")),
        Row(endings: "ぐ",        result: "いで", example: "泳[およ]ぐ → 泳[およ]いで", color: Color(hex: "0D9488")),
        Row(endings: "す",        result: "して", example: "話[はな]す → 話[はな]して", color: Color(hex: "7C3AED")),
    ]

    var body: some View {
        diagramPanel {
            VStack(alignment: .leading, spacing: 10) {
                groupHeader("Group 2 (る-verbs)", "drop る, add て")
                FuriganaText(text: "食[た]べる → 食[た]べて", fontSize: 13, color: .appText, weight: .medium)

                Divider()
                groupHeader("Group 1 (う-verbs)", "the last sound decides")
                VStack(spacing: 6) {
                    ForEach(Array(g1.enumerated()), id: \.offset) { _, r in
                        HStack(spacing: 8) {
                            Text(r.endings)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(r.color)
                                .frame(width: 72, alignment: .leading)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.appTextSecondary)
                            Text(r.result)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(r.color)
                                .frame(width: 38, alignment: .leading)
                            FuriganaText(text: r.example, fontSize: 11, color: .appTextSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(r.color.opacity(0.09)))
                    }
                }

                Divider()
                groupHeader("Irregular", "just memorise these")
                FuriganaText(text: "する → して　　くる → きて　　行[い]く → 行[い]って",
                             fontSize: 12, color: .appText, weight: .medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func groupHeader(_ title: String, _ sub: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.appText)
            Text(sub).font(.system(size: 10)).foregroundColor(.appTextSecondary)
        }
    }
}

// MARK: - Particle roles in a sentence

private struct ParticlesDiagram: View {
    let accent: Color
    private struct Part { let jp, particle, role: String; let color: Color }
    private let parts: [Part] = [
        Part(jp: "私[わたし]", particle: "は", role: "topic", color: Color(hex: "DC2626")),
        Part(jp: "カフェ",     particle: "で", role: "where", color: Color(hex: "0D9488")),
        Part(jp: "コーヒー",   particle: "を", role: "object", color: Color(hex: "2563EB")),
        Part(jp: "飲[の]む",   particle: "",   role: "verb",  color: Color(hex: "7C3AED")),
    ]

    var body: some View {
        diagramPanel {
            VStack(spacing: 12) {
                Text("Particles tag each word's job — that's why word order can move.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                        VStack(spacing: 5) {
                            HStack(spacing: 1) {
                                FuriganaText(text: p.jp, fontSize: 14, color: .appText, weight: .semibold)
                                if !p.particle.isEmpty {
                                    Text(p.particle)
                                        .font(.system(size: 15, weight: .heavy))
                                        .foregroundColor(p.color)
                                }
                            }
                            Rectangle().fill(p.color).frame(height: 2).cornerRadius(1)
                            Text(p.role)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(p.color)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    legend("は", "the topic — what the sentence is about", Color(hex: "DC2626"))
                    legend("を", "the direct object of the verb", Color(hex: "2563EB"))
                    legend("で", "where the action happens (also by what means)", Color(hex: "0D9488"))
                    legend("に", "a point in time, or a destination", Color(hex: "D97706"))
                }
            }
        }
    }

    private func legend(_ particle: String, _ text: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(particle)
                .font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(color))
            Text(text)
                .font(.system(size: 11)).foregroundColor(.appText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - い vs な adjective conjugation

private struct AdjectivesDiagram: View {
    let accent: Color
    private let iColor = Color(hex: "2563EB")
    private let naColor = Color(hex: "D97706")
    private let rows: [(String, String, String)] = [
        ("now",       "高[たか]い",          "静[しず]かだ"),
        ("not",       "高[たか]くない",      "静[しず]かじゃない"),
        ("was",       "高[たか]かった",      "静[しず]かだった"),
        ("wasn't",    "高[たか]くなかった",  "静[しず]かじゃなかった"),
    ]

    var body: some View {
        diagramPanel {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("").frame(width: 44)
                    header("い-adj", "高[たか]い", iColor)
                    header("な-adj", "静[しず]か", naColor)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    HStack(spacing: 8) {
                        Text(r.0)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appTextSecondary)
                            .frame(width: 44, alignment: .leading)
                        cell(r.1, iColor)
                        cell(r.2, naColor)
                    }
                }
                Text("い-adjectives change their own ending; な-adjectives just swap だ.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    private func header(_ title: String, _ example: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            FuriganaText(text: example, fontSize: 10, color: .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(color))
    }

    private func cell(_ text: String, _ color: Color) -> some View {
        FuriganaText(text: text, fontSize: 12, color: .appText, weight: .medium)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10)))
    }
}

// MARK: - Counters

private struct CountersDiagram: View {
    let accent: Color
    private struct C { let counter, reading, what, icon: String; let color: Color }
    private let items: [C] = [
        C(counter: "枚", reading: "まい", what: "flat things", icon: "doc", color: Color(hex: "2563EB")),
        C(counter: "本", reading: "ほん", what: "long things", icon: "pencil", color: Color(hex: "DC2626")),
        C(counter: "匹", reading: "ひき", what: "small animals", icon: "pawprint.fill", color: Color(hex: "16A34A")),
        C(counter: "台", reading: "だい", what: "machines", icon: "car.fill", color: Color(hex: "D97706")),
        C(counter: "冊", reading: "さつ", what: "books", icon: "book.fill", color: Color(hex: "7C3AED")),
        C(counter: "杯", reading: "はい", what: "cupfuls", icon: "cup.and.saucer.fill", color: Color(hex: "0D9488")),
        C(counter: "人", reading: "にん", what: "people", icon: "person.fill", color: Color(hex: "DB2777")),
        C(counter: "個", reading: "こ", what: "anything small", icon: "circle.fill", color: Color(hex: "6366F1")),
    ]

    var body: some View {
        diagramPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pick the counter by the shape or kind of thing.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, c in
                        HStack(spacing: 8) {
                            Image(systemName: c.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(c.color))
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 3) {
                                    Text(c.counter).font(.system(size: 14, weight: .bold)).foregroundColor(.appText)
                                    Text(c.reading).font(.system(size: 9)).foregroundColor(.appTextSecondary)
                                }
                                Text(c.what).font(.system(size: 9)).foregroundColor(.appTextSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 9).fill(c.color.opacity(0.09)))
                    }
                }

                Divider()
                FuriganaText(text: "Watch the sound changes: 一本[いっぽん]・三本[さんぼん]・六本[ろっぽん]。枚[まい] and 台[だい] never change.",
                             fontSize: 10, color: .appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Telling time

private struct TellingTimeDiagram: View {
    let accent: Color
    private let hourColor = Color(hex: "DC2626")
    private let minColor = Color(hex: "2563EB")

    var body: some View {
        diagramPanel {
            VStack(spacing: 12) {
                HStack(spacing: 18) {
                    clock
                    VStack(alignment: .leading, spacing: 10) {
                        part("時", "じ", "hour", hourColor)
                        part("分", "ふん / ぷん", "minute", minColor)
                        HStack(spacing: 4) {
                            Text("4:30 =").font(.system(size: 11)).foregroundColor(.appTextSecondary)
                            FuriganaText(text: "四時[よじ]半[はん]", fontSize: 13, color: .appText, weight: .semibold)
                        }
                    }
                }
                Divider()
                FuriganaText(text: "Irregular readings: 四時[よじ]・七時[しちじ]・九時[くじ]、一分[いっぷん]・三分[さんぷん]・六分[ろっぷん]。",
                             fontSize: 10, color: .appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var clock: some View {
        ZStack {
            Circle().strokeBorder(Color.appHairline, lineWidth: 2).frame(width: 92, height: 92)
            ForEach(0..<12, id: \.self) { i in
                Rectangle()
                    .fill(Color.appTextSecondary.opacity(0.5))
                    .frame(width: 2, height: 6)
                    .offset(y: -40)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            // hour hand → 4, minute hand → 30
            Capsule().fill(hourColor).frame(width: 4, height: 26)
                .offset(y: -13).rotationEffect(.degrees(120))
            Capsule().fill(minColor).frame(width: 3, height: 36)
                .offset(y: -18).rotationEffect(.degrees(180))
            Circle().fill(Color.appText).frame(width: 7, height: 7)
        }
        .frame(width: 96, height: 96)
    }

    private func part(_ kanji: String, _ reading: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 7) {
            Text(kanji)
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(color))
            VStack(alignment: .leading, spacing: 0) {
                Text(reading).font(.system(size: 11, weight: .semibold)).foregroundColor(.appText)
                Text(label).font(.system(size: 9)).foregroundColor(.appTextSecondary)
            }
        }
    }
}

// MARK: - Politeness levels

private struct PolitenessDiagram: View {
    let accent: Color
    private struct Level { let name, jp, example, note: String; let color: Color }
    private let levels: [Level] = [
        Level(name: "Humble", jp: "謙譲語[けんじょうご]", example: "参[まい]ります",
              note: "lowers YOU — your own actions", color: Color(hex: "7C3AED")),
        Level(name: "Respectful", jp: "尊敬語[そんけいご]", example: "いらっしゃいます",
              note: "raises THEM — their actions", color: Color(hex: "DC2626")),
        Level(name: "Polite", jp: "丁寧語[ていねいご]", example: "行[い]きます",
              note: "the safe everyday default", color: Color(hex: "2563EB")),
        Level(name: "Casual", jp: "ふつう", example: "行[い]く",
              note: "friends and family", color: Color(hex: "16A34A")),
    ]

    var body: some View {
        diagramPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Same action, four registers — pick by who you're talking to.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)

                ForEach(Array(levels.enumerated()), id: \.offset) { i, l in
                    HStack(spacing: 10) {
                        // Ladder rung: wider bar = more formal
                        RoundedRectangle(cornerRadius: 2)
                            .fill(l.color)
                            .frame(width: CGFloat(26 - i * 5), height: 4)
                            .frame(width: 28, alignment: .leading)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(l.name).font(.system(size: 12, weight: .bold)).foregroundColor(l.color)
                                FuriganaText(text: l.jp, fontSize: 10, color: .appTextSecondary)
                            }
                            HStack(spacing: 6) {
                                FuriganaText(text: l.example, fontSize: 12, color: .appText, weight: .semibold)
                                Text("· \(l.note)").font(.system(size: 9)).foregroundColor(.appTextSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 9).fill(l.color.opacity(0.09)))
                }

                Text("Respectful and humble both sound formal — the difference is whose action it is.")
                    .font(.system(size: 10)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Conditionals (と・たら・ば・なら)

private struct ConditionalsDiagram: View {
    let accent: Color

    private struct Cond { let kana, nuance, en, example, icon: String; let color: Color }
    private let items = [
        Cond(kana: "と",   nuance: "automatic result", en: "always / naturally true",
             example: "押[お]すと開[あ]く", icon: "gearshape.fill", color: Color(hex: "2563EB")),
        Cond(kana: "たら", nuance: "when / after", en: "one event, then the next",
             example: "着[つ]いたら電話[でんわ]", icon: "clock.fill", color: Color(hex: "16A34A")),
        Cond(kana: "ば",   nuance: "logical if / advice", en: "general cause → effect",
             example: "急[いそ]げば間[ま]に合[あ]う", icon: "arrow.triangle.branch", color: Color(hex: "D97706")),
        Cond(kana: "なら", nuance: "in that case", en: "responds to context",
             example: "寿司[すし]なら銀座[ぎんざ]", icon: "bubble.left.fill", color: Color(hex: "7C3AED")),
    ]

    var body: some View {
        diagramPanel {
            VStack(spacing: 10) {
                Text("Four “if”s — the difference is what kind of condition.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, c in cell(c) }
                }
            }
        }
    }

    private func cell(_ c: Cond) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(c.kana).font(.system(size: 19, weight: .heavy)).foregroundColor(c.color)
                Spacer()
                Image(systemName: c.icon).font(.system(size: 11)).foregroundColor(c.color)
            }
            Text(c.nuance).font(.system(size: 11, weight: .semibold)).foregroundColor(.appText)
            Text(c.en).font(.system(size: 9)).foregroundColor(.secondary)
            FuriganaText(text: c.example, fontSize: 11, color: c.color, weight: .medium)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 9).fill(c.color.opacity(0.09)))
    }
}

// MARK: - Transitive vs intransitive (他動詞・自動詞)

private struct TransIntransDiagram: View {
    let accent: Color
    private let transColor = Color(hex: "2563EB")
    private let intransColor = Color(hex: "16A34A")

    var body: some View {
        diagramPanel {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    panel(title: "他動詞", tag: "transitive", color: transColor,
                          formula: "人[ひと]が ドアを 開[あ]ける",
                          particle: "を", particleGloss: "object", gloss: "someone opens it") {
                        HStack(spacing: 6) {
                            iconNode("person.fill", transColor)
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundColor(transColor)
                            iconNode("rectangle.portrait.fill", .secondary)
                        }
                    }
                    panel(title: "自動詞", tag: "intransitive", color: intransColor,
                          formula: "ドアが 開[ひら]く",
                          particle: "が", particleGloss: "subject", gloss: "it opens by itself") {
                        HStack(spacing: 6) {
                            iconNode("rectangle.portrait.fill", intransColor)
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 13, weight: .bold)).foregroundColor(intransColor)
                        }
                    }
                }
                Text("Many verbs come in pairs — one you do, one that just happens.")
                    .font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    private func panel<Scene: View>(title: String, tag: String, color: Color, formula: String,
                                    particle: String, particleGloss: String, gloss: String,
                                    @ViewBuilder scene: () -> Scene) -> some View {
        VStack(spacing: 6) {
            VStack(spacing: 0) {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(color)
                Text(tag).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
            }
            scene().frame(height: 30)
            FuriganaText(text: formula, fontSize: 12, color: .appText, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 3) {
                Text(particle).font(.system(size: 11, weight: .heavy)).foregroundColor(color)
                Text("= \(particleGloss)").font(.system(size: 9)).foregroundColor(.secondary)
            }
            Text(gloss).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    private func iconNode(_ icon: String, _ color: Color) -> some View {
        Image(systemName: icon).font(.system(size: 17)).foregroundColor(color)
    }
}

// MARK: - Passive (〜られる)

private struct PassiveDiagram: View {
    let accent: Color
    private let doerColor = Color(hex: "DC2626")
    private let subjColor = Color(hex: "2563EB")

    var body: some View {
        diagramPanel {
            VStack(spacing: 10) {
                // Active
                rowLabel("ACTIVE")
                HStack(spacing: 8) {
                    chip("先生[せんせい]", "doer", color: doerColor, filled: true)
                    arrowWithVerb("褒[ほ]める", .right, color: .secondary)
                    chip("私[わたし]", "receiver", color: .secondary, filled: false)
                }

                Image(systemName: "arrow.down").font(.system(size: 13, weight: .bold)).foregroundColor(accent)

                // Passive
                rowLabel("PASSIVE")
                HStack(spacing: 8) {
                    chip("私[わたし]", "subject", color: subjColor, filled: true)
                    VStack(spacing: 1) {
                        HStack(spacing: 1) {
                            FuriganaText(text: "先生[せんせい]", fontSize: 11, color: doerColor, weight: .semibold)
                            Text("に").font(.system(size: 11, weight: .heavy)).foregroundColor(doerColor)
                        }
                        Image(systemName: "arrow.left").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                    }
                    FuriganaText(text: "褒[ほ]められる", fontSize: 13, color: .appText, weight: .bold)
                }

                Text("The receiver becomes the subject; the doer takes に.")
                    .font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    private func rowLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ jp: String, _ role: String, color: Color, filled: Bool) -> some View {
        VStack(spacing: 1) {
            FuriganaText(text: jp, fontSize: 13, color: filled ? color : .appText, weight: .bold)
            Text(role).font(.system(size: 8)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(filled ? color.opacity(0.14) : Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(filled ? color.opacity(0.5) : Color.appHairline, lineWidth: 1))
    }

    private func arrowWithVerb(_ verb: String, _ dir: FlowArrow.Direction, color: Color) -> some View {
        VStack(spacing: 1) {
            FuriganaText(text: verb, fontSize: 11, color: .appText, weight: .medium)
            Image(systemName: dir == .right ? "arrow.right" : "arrow.left")
                .font(.system(size: 11, weight: .bold)).foregroundColor(color)
        }
    }
}

// MARK: - Causative (〜させる)

private struct CausativeDiagram: View {
    let accent: Color
    private let causerColor = Color(hex: "7C3AED")
    private let causeeColor = Color(hex: "0D9488")

    var body: some View {
        diagramPanel {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    node("先生[せんせい]", "causer", color: causerColor)
                    arrow("させる", "make / let")
                    node("生徒[せいと]", "causee ・に", color: causeeColor)
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    node("宿題[しゅくだい]", "action", color: .secondary)
                }
                Text("A makes or lets B do something — B takes に when the verb is transitive.")
                    .font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    private func node(_ jp: String, _ role: String, color: Color) -> some View {
        VStack(spacing: 1) {
            FuriganaText(text: jp, fontSize: 12, color: color, weight: .bold)
            Text(role).font(.system(size: 8)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 7).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    private func arrow(_ verb: String, _ gloss: String) -> some View {
        VStack(spacing: 1) {
            Text(verb).font(.system(size: 11, weight: .bold)).foregroundColor(causerColor)
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundColor(causerColor)
            Text(gloss).font(.system(size: 8)).foregroundColor(.secondary)
        }
    }
}
