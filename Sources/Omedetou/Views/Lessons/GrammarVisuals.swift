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
    case timeSequence
    case obligation
    case certainty
    case teHelpers
    case frequency
    case degree
    case plainPolite
    case dates
    case aruIru
    case neYo
    case questionWords
    case listing
    case preference
    case justDid

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
        case "toki", "mae-ni", "te-kara", "aida-ni", "nagara":         return .timeSequence
        case "te-mo-ii", "te-wa-ikenai", "nakucha", "nakute-mo-ii":    return .obligation
        case "desho", "kamoshiremasen", "hazu-da", "ni-chigai-nai":    return .certainty
        case "te-iru", "te-oku", "te-shimau", "te-aru",
             "te-miru", "te-iku-te-kuru":                              return .teHelpers
        case "frequency-adverbs":                                      return .frequency
        case "totemo-sukoshi":                                         return .degree
        case "plain-forms", "masu-form", "past-masu":                  return .plainPolite
        case "dates-months":                                           return .dates
        case "aru-iru":                                                return .aruIru
        case "ne-yo":                                                  return .neYo
        case "nanika-nanimo":                                          return .questionWords
        case "ya-list", "to-and":                                      return .listing
        case "suki-kirai", "jouzu-heta":                               return .preference
        case "ta-tokoro", "ta-bakari":                                 return .justDid
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
        case .timeSequence:           TimeSequenceDiagram(accent: accent)
        case .obligation:             ObligationDiagram(accent: accent)
        case .certainty:              CertaintyDiagram(accent: accent)
        case .teHelpers:              TeHelpersDiagram(accent: accent)
        case .frequency:              FrequencyDiagram(accent: accent)
        case .degree:                 DegreeDiagram(accent: accent)
        case .plainPolite:            PlainPoliteDiagram(accent: accent)
        case .dates:                  DatesDiagram(accent: accent)
        case .aruIru:                 AruIruDiagram(accent: accent)
        case .neYo:                   NeYoDiagram(accent: accent)
        case .questionWords:          QuestionWordsDiagram(accent: accent)
        case .listing:                ListingDiagram(accent: accent)
        case .preference:             PreferenceDiagram(accent: accent)
        case .justDid:                JustDidDiagram(accent: accent)
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

// MARK: - Shared: a ranked scale
//
// Several points are really "here are N expressions along one axis" — how often,
// how much, how certain, how much you like it. They all render the same way.

private struct ScaleStrip: View {
    struct Step { let jp: String; let en: String }
    let caption: String
    let topLabel: String
    let bottomLabel: String
    /// Ordered strongest → weakest.
    let steps: [Step]
    let color: Color
    var note: String? = nil

    var body: some View {
        diagramPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text(caption)
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 10) {
                    // Gradient spine, strongest at the top
                    VStack(spacing: 0) {
                        Text(topLabel)
                            .font(.system(size: 8, weight: .bold)).foregroundColor(color)
                        LinearGradient(colors: [color, color.opacity(0.18)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(width: 5)
                            .clipShape(Capsule())
                            .padding(.vertical, 3)
                        Text(bottomLabel)
                            .font(.system(size: 8, weight: .bold)).foregroundColor(color.opacity(0.55))
                    }
                    .frame(width: 42)

                    VStack(spacing: 5) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                            let strength = 1.0 - (Double(i) / Double(max(steps.count - 1, 1))) * 0.75
                            HStack(spacing: 8) {
                                // Give FuriganaText an explicit width — it expands to fill
                                // whatever it's offered, which would strand the gloss right.
                                FuriganaText(text: s.jp, fontSize: 13, color: .appText, weight: .bold)
                                    .frame(width: 124)
                                Text(s.en)
                                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.05 + 0.13 * strength)))
                        }
                    }
                }

                if let note {
                    // FuriganaText, not Text — notes may carry 漢字[かんじ] markup.
                    FuriganaText(text: note, fontSize: 10, color: .appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Frequency adverbs

private struct FrequencyDiagram: View {
    let accent: Color
    var body: some View {
        ScaleStrip(
            caption: "How often — these adverbs sit on one scale.",
            topLabel: "ALWAYS", bottomLabel: "NEVER",
            steps: [
                .init(jp: "いつも", en: "always"),
                .init(jp: "よく", en: "often"),
                .init(jp: "ときどき", en: "sometimes"),
                .init(jp: "あまり〜ない", en: "not very often"),
                .init(jp: "ぜんぜん〜ない", en: "never at all"),
            ],
            color: Color(hex: "2563EB"),
            note: "あまり and ぜんぜん must finish with a negative verb.")
    }
}

// MARK: - Degree adverbs

private struct DegreeDiagram: View {
    let accent: Color
    var body: some View {
        ScaleStrip(
            caption: "How much — the same idea, applied to degree.",
            topLabel: "VERY", bottomLabel: "NOT AT ALL",
            steps: [
                .init(jp: "とても", en: "very"),
                .init(jp: "すこし / ちょっと", en: "a little"),
                .init(jp: "あまり〜ない", en: "not very"),
                .init(jp: "ぜんぜん〜ない", en: "not at all"),
            ],
            color: Color(hex: "0D9488"),
            note: "ちょっと is the softer, more conversational すこし.")
    }
}

// MARK: - Certainty

private struct CertaintyDiagram: View {
    let accent: Color
    var body: some View {
        ScaleStrip(
            caption: "How sure you are — pick the expression that matches your confidence.",
            topLabel: "CERTAIN", bottomLabel: "UNSURE",
            steps: [
                .init(jp: "〜にちがいない", en: "must be — I'm convinced"),
                .init(jp: "〜はずだ", en: "should be — it follows logically"),
                .init(jp: "〜でしょう", en: "probably"),
                .init(jp: "〜かもしれない", en: "might be — could go either way"),
            ],
            color: Color(hex: "7C3AED"),
            note: "はずだ is about expectation from evidence; にちがいない is personal conviction.")
    }
}

// MARK: - Liking & skill

private struct PreferenceDiagram: View {
    let accent: Color
    var body: some View {
        ScaleStrip(
            caption: "Liking and ability both use が, not を.",
            topLabel: "LOVE", bottomLabel: "HATE",
            steps: [
                .init(jp: "大好[だいす]き", en: "love it"),
                .init(jp: "好[す]き", en: "like it"),
                .init(jp: "きらい", en: "dislike it"),
                .init(jp: "大[だい]きらい", en: "hate it"),
            ],
            color: Color(hex: "DB2777"),
            note: "Skill works the same way: 上手[じょうず] (good at) ・ 下手[へた] (bad at) — and 得意[とくい]／苦手[にがて] are the modest versions you use about yourself.")
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
        FuriganaText(text: text, fontSize: 12, color: .appText, weight: .medium, alignment: .center)
            .frame(maxWidth: .infinity)
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
                          formula: "ドアが 開[あ]く",
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

// MARK: - When things happen (とき・まえに・てから・あいだに・ながら)

private struct TimeSequenceDiagram: View {
    let accent: Color
    private let refColor = Color(hex: "94A3B8")
    private let mainColor = Color(hex: "2563EB")

    private struct Row {
        let jp, gloss: String
        // Fractions of the track: 0 = earliest, 1 = latest.
        let refStart, refWidth, mainStart, mainWidth: CGFloat
    }

    private let rows: [Row] = [
        Row(jp: "〜まえに",   gloss: "before it happens",
            refStart: 0.60, refWidth: 0.38, mainStart: 0.04, mainWidth: 0.26),
        Row(jp: "〜てから",   gloss: "after it finishes",
            refStart: 0.02, refWidth: 0.38, mainStart: 0.64, mainWidth: 0.30),
        Row(jp: "〜とき",     gloss: "at that time",
            refStart: 0.20, refWidth: 0.60, mainStart: 0.38, mainWidth: 0.22),
        Row(jp: "〜あいだに", gloss: "at some point during",
            refStart: 0.02, refWidth: 0.96, mainStart: 0.52, mainWidth: 0.17),
        Row(jp: "〜ながら",   gloss: "both at the same time",
            refStart: 0.06, refWidth: 0.88, mainStart: 0.06, mainWidth: 0.88),
    ]

    var body: some View {
        diagramPanel {
            VStack(alignment: .leading, spacing: 9) {
                Text("Each pattern pins your action to a different moment.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)

                // Legend
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        Capsule().fill(refColor.opacity(0.35)).frame(width: 18, height: 12)
                        Text("the 〜 clause").font(.system(size: 9)).foregroundColor(.appTextSecondary)
                    }
                    HStack(spacing: 5) {
                        Capsule().fill(mainColor).frame(width: 18, height: 7)
                        Text("your action").font(.system(size: 9)).foregroundColor(.appTextSecondary)
                    }
                    Spacer(minLength: 0)
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(r.jp).font(.system(size: 12, weight: .bold)).foregroundColor(.appText)
                            Text(r.gloss).font(.system(size: 8)).foregroundColor(.appTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 92, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.appText.opacity(0.05)).frame(height: 16)
                                Capsule().fill(refColor.opacity(0.35))
                                    .frame(width: max(geo.size.width * r.refWidth, 8), height: 16)
                                    .offset(x: geo.size.width * r.refStart)
                                Capsule().fill(mainColor)
                                    .frame(width: max(geo.size.width * r.mainWidth, 8), height: 7)
                                    .offset(x: geo.size.width * r.mainStart)
                            }
                            .frame(height: 16)
                        }
                        .frame(height: 16)
                    }
                }

                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Text("time").font(.system(size: 8, weight: .bold)).foregroundColor(.appTextSecondary)
                    Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold))
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
    }
}

// MARK: - Permission & obligation (てもいい・てはいけない・なくちゃ・なくてもいい)

private struct ObligationDiagram: View {
    let accent: Color
    private let okColor = Color(hex: "16A34A")
    private let noColor = Color(hex: "DC2626")

    var body: some View {
        diagramPanel {
            VStack(spacing: 8) {
                Text("Two questions: are you doing it or not — and is that acceptable?")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Column headers
                HStack(spacing: 7) {
                    Text("").frame(width: 52)
                    columnHeader("that's OK", okColor)
                    columnHeader("that's not OK", noColor)
                }

                HStack(spacing: 7) {
                    rowHeader("DO it")
                    cell("〜てもいい", "you may", okColor)
                    cell("〜てはいけない", "you must not", noColor)
                }
                HStack(spacing: 7) {
                    rowHeader("DON'T")
                    cell("〜なくてもいい", "you don't have to", okColor)
                    cell("〜なくちゃいけない", "you have to", noColor)
                }

                Text("The right column is the strict one — “not OK to skip it” is exactly how Japanese says “you must.”")
                    .font(.system(size: 10)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }

    private func columnHeader(_ t: String, _ c: Color) -> some View {
        Text(t)
            .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(c))
    }

    private func rowHeader(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 10, weight: .bold)).foregroundColor(.appTextSecondary)
            .frame(width: 52, alignment: .leading)
    }

    private func cell(_ jp: String, _ en: String, _ c: Color) -> some View {
        VStack(spacing: 1) {
            Text(jp).font(.system(size: 12, weight: .bold)).foregroundColor(.appText)
                .minimumScaleFactor(0.75).lineLimit(1)
            Text(en).font(.system(size: 9)).foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9).fill(c.opacity(0.11)))
    }
}

// MARK: - て + helper verbs

private struct TeHelpersDiagram: View {
    let accent: Color
    private struct H { let helper, meaning, example: String; let icon: String; let color: Color }
    private let items: [H] = [
        H(helper: "〜ている", meaning: "happening now, or an ongoing state",
          example: "食[た]べている — is eating", icon: "hourglass", color: Color(hex: "2563EB")),
        H(helper: "〜てある", meaning: "left prepared — someone did it on purpose",
          example: "書[か]いてある — it's been written", icon: "checkmark.seal.fill", color: Color(hex: "0D9488")),
        H(helper: "〜ておく", meaning: "do it ahead of time, in preparation",
          example: "買[か]っておく — buy it in advance", icon: "shippingbox.fill", color: Color(hex: "D97706")),
        H(helper: "〜てしまう", meaning: "finish it off — or do it by accident",
          example: "忘[わす]れてしまった — I went and forgot", icon: "exclamationmark.triangle.fill", color: Color(hex: "DC2626")),
        H(helper: "〜てみる", meaning: "try it and see how it goes",
          example: "食[た]べてみる — give it a taste", icon: "eye.fill", color: Color(hex: "7C3AED")),
        H(helper: "〜ていく・〜てくる", meaning: "heading away from / toward you in space or time",
          example: "増[ふ]えてきた — it's been increasing", icon: "arrow.left.arrow.right", color: Color(hex: "DB2777")),
    ]

    var body: some View {
        diagramPanel {
            VStack(alignment: .leading, spacing: 9) {
                // The shared stem all of these hang off
                HStack(spacing: 6) {
                    // Explicit width keeps FuriganaText from stretching and orphaning the て.
                    FuriganaText(text: "食[た]べ", fontSize: 13, color: .appText, weight: .bold)
                        .frame(width: 40)
                    Text("て")
                        .font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(accent))
                    Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundColor(.appTextSecondary)
                    Text("a helper verb")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.appTextSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 1)

                Text("The て-form is a connector. Whatever you attach to it colors the meaning:")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(items.enumerated()), id: \.offset) { _, h in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: h.icon)
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(h.color))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(h.helper).font(.system(size: 12, weight: .bold)).foregroundColor(.appText)
                            Text(h.meaning).font(.system(size: 9)).foregroundColor(.appTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            FuriganaText(text: h.example, fontSize: 9, color: h.color)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 9).fill(h.color.opacity(0.07)))
                }
            }
        }
    }
}

// MARK: - Plain vs polite

private struct PlainPoliteDiagram: View {
    let accent: Color
    private let plainColor = Color(hex: "7C3AED")
    private let politeColor = Color(hex: "2563EB")
    private let rows: [(String, String, String)] = [
        ("do",       "食[た]べる",         "食[た]べます"),
        ("don't",    "食[た]べない",       "食[た]べません"),
        ("did",      "食[た]べた",         "食[た]べました"),
        ("didn't",   "食[た]べなかった",   "食[た]べませんでした"),
    ]

    var body: some View {
        diagramPanel {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("").frame(width: 46)
                    header("plain", "friends, family", plainColor)
                    header("polite", "everyone else", politeColor)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    HStack(spacing: 8) {
                        Text(r.0)
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.appTextSecondary)
                            .frame(width: 46, alignment: .leading)
                        cell(r.1, plainColor)
                        cell(r.2, politeColor)
                    }
                }
                Text("Same four meanings, two registers. Only the very end of the verb changes — so learn one column and you can convert.")
                    .font(.system(size: 10)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }

    private func header(_ t: String, _ sub: String, _ c: Color) -> some View {
        VStack(spacing: 0) {
            Text(t).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            Text(sub).font(.system(size: 8)).foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(c))
    }

    private func cell(_ t: String, _ c: Color) -> some View {
        FuriganaText(text: t, fontSize: 11, color: .appText, weight: .medium, alignment: .center)
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(c.opacity(0.10)))
    }
}

// MARK: - Dates

private struct DatesDiagram: View {
    let accent: Color
    private let dayColor = Color(hex: "DC2626")
    private let monthColor = Color(hex: "2563EB")

    private let days: [(String, String)] = [
        ("1日", "ついたち"), ("2日", "ふつか"), ("3日", "みっか"), ("4日", "よっか"), ("5日", "いつか"),
        ("6日", "むいか"), ("7日", "なのか"), ("8日", "ようか"), ("9日", "ここのか"), ("10日", "とおか"),
    ]
    private let strays: [(String, String)] = [
        ("14日", "じゅうよっか"), ("20日", "はつか"), ("24日", "にじゅうよっか"),
    ]

    var body: some View {
        diagramPanel {
            VStack(alignment: .leading, spacing: 9) {
                // Months first — the easy half
                HStack(spacing: 6) {
                    Text("MONTHS").font(.system(size: 9, weight: .bold)).foregroundColor(monthColor)
                    FuriganaText(text: "number + 月[がつ]", fontSize: 11, color: .appText, weight: .semibold)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 5) {
                    ForEach(["4月 しがつ", "7月 しちがつ", "9月 くがつ"], id: \.self) { m in
                        Text(m)
                            .font(.system(size: 10, weight: .semibold)).foregroundColor(.appText)
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 7).fill(monthColor.opacity(0.13)))
                    }
                }
                Text("Only those three break the pattern — never よんがつ, なながつ or きゅうがつ.")
                    .font(.system(size: 9)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().padding(.vertical, 1)

                // Days — the hard half
                HStack(spacing: 6) {
                    Text("DAYS 1–10").font(.system(size: 9, weight: .bold)).foregroundColor(dayColor)
                    Text("every one is irregular — memorize them")
                        .font(.system(size: 10)).foregroundColor(.appTextSecondary)
                    Spacer(minLength: 0)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 5), spacing: 5) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                        VStack(spacing: 1) {
                            Text(d.0).font(.system(size: 12, weight: .bold)).foregroundColor(.appText)
                            Text(d.1).font(.system(size: 8)).foregroundColor(.appTextSecondary)
                                .minimumScaleFactor(0.7).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(dayColor.opacity(0.10)))
                    }
                }

                Text("From 11 on it's just the number + にち — except these three:")
                    .font(.system(size: 10)).foregroundColor(.appTextSecondary)
                HStack(spacing: 5) {
                    ForEach(Array(strays.enumerated()), id: \.offset) { _, d in
                        VStack(spacing: 1) {
                            Text(d.0).font(.system(size: 12, weight: .bold)).foregroundColor(.appText)
                            Text(d.1).font(.system(size: 8)).foregroundColor(.appTextSecondary)
                                .minimumScaleFactor(0.7).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(dayColor.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(dayColor.opacity(0.45), lineWidth: 1))
                    }
                }
            }
        }
    }
}

// MARK: - ある vs いる

private struct AruIruDiagram: View {
    let accent: Color
    private let iruColor = Color(hex: "16A34A")
    private let aruColor = Color(hex: "D97706")

    var body: some View {
        diagramPanel {
            VStack(spacing: 9) {
                Text("Both mean “there is” — the split is whether it decides to move on its own.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 8) {
                    side(word: "いる", rule: "moves under its own will",
                         icons: ["person.fill", "dog.fill", "bird.fill", "ant.fill"],
                         examples: "people ・ animals ・ insects ・ fish",
                         negative: "いない", color: iruColor)
                    side(word: "ある", rule: "doesn't decide anything",
                         icons: ["book.closed.fill", "leaf.fill", "building.2.fill", "calendar"],
                         examples: "objects ・ plants ・ buildings ・ events",
                         negative: "ない", color: aruColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    FuriganaText(text: "⚠︎ 車[くるま]・電車[でんしゃ] and other vehicles take ある — they move, but they don't choose to.",
                                 fontSize: 10, color: .appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Watch the negatives: ある becomes ない, not あらない.")
                        .font(.system(size: 10)).foregroundColor(.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func side(word: String, rule: String, icons: [String], examples: String,
                      negative: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(word)
                .font(.system(size: 17, weight: .heavy)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 9).fill(color))
            Text(rule)
                .font(.system(size: 9, weight: .semibold)).foregroundColor(color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                ForEach(icons, id: \.self) { i in
                    Image(systemName: i).font(.system(size: 13)).foregroundColor(color)
                }
            }
            Text(examples)
                .font(.system(size: 9)).foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("neg. \(negative)")
                .font(.system(size: 9, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 11).fill(color.opacity(0.09)))
    }
}

// MARK: - ね vs よ

private struct NeYoDiagram: View {
    let accent: Color
    private let neColor = Color(hex: "0D9488")
    private let yoColor = Color(hex: "DC2626")

    var body: some View {
        diagramPanel {
            VStack(spacing: 11) {
                Text("Both go on the end of a sentence — they aim it in opposite directions.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                scene(particle: "よ", headline: "I know this, you don't",
                      caption: "Pushes new information across. Can sound pushy if you overuse it.",
                      example: "雨[あめ]ですよ — heads up, it's raining",
                      direction: .right, color: yoColor)

                scene(particle: "ね", headline: "we both know this",
                      caption: "Reaches for agreement. The everyday softener in Japanese conversation.",
                      example: "いい天気[てんき]ですね — lovely weather, isn't it",
                      direction: .left, color: neColor)
            }
        }
    }

    private func scene(particle: String, headline: String, caption: String, example: String,
                       direction: FlowArrow.Direction, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                person(icon: "person.fill", label: "you", color: color)
                VStack(spacing: 2) {
                    Text(particle)
                        .font(.system(size: 15, weight: .heavy)).foregroundColor(color)
                    FlowArrow(direction: direction, color: color)
                    Text(headline)
                        .font(.system(size: 9, weight: .semibold)).foregroundColor(.appTextSecondary)
                }
                person(icon: "person.2.fill", label: "them", color: color.opacity(0.55))
            }
            FuriganaText(text: example, fontSize: 10, color: .appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(caption)
                .font(.system(size: 9)).foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 11).fill(color.opacity(0.08)))
    }

    private func person(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(color))
            Text(label).font(.system(size: 8)).foregroundColor(.appTextSecondary)
        }
    }
}

// MARK: - Question words + か / も

private struct QuestionWordsDiagram: View {
    let accent: Color
    private let baseColor = Color(hex: "64748B")
    private let kaColor = Color(hex: "2563EB")
    private let moColor = Color(hex: "DC2626")

    private let rows: [(String, String, String, String)] = [
        ("何[なに]",  "what",  "何[なに]か・something",  "何[なに]も・nothing"),
        ("誰[だれ]",  "who",   "誰[だれ]か・someone",    "誰[だれ]も・no one"),
        ("どこ",      "where", "どこか・somewhere",      "どこも・nowhere"),
    ]

    var body: some View {
        diagramPanel {
            VStack(spacing: 8) {
                Text("Take a question word and bolt a particle on — you get its “some” and “no” versions for free.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 7) {
                    Text("").frame(width: 52)
                    header("+ か", "some‑", kaColor)
                    header("+ も + neg.", "no‑", moColor)
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    HStack(spacing: 7) {
                        VStack(alignment: .leading, spacing: 0) {
                            FuriganaText(text: r.0, fontSize: 12, color: .appText, weight: .bold)
                            Text(r.1).font(.system(size: 8)).foregroundColor(.appTextSecondary)
                        }
                        .frame(width: 52, alignment: .leading)
                        cell(r.2, kaColor)
                        cell(r.3, moColor)
                    }
                }

                FuriganaText(text: "The も column needs a negative verb — 誰[だれ]も来[こ]なかった, “nobody came.”",
                             fontSize: 10, color: .appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10)).foregroundColor(Color(hex: "D97706"))
                    FuriganaText(text: "いつ works too — いつか is “someday” — but いつも isn’t a “no-” word: on its own it means “always” (for “never” use 一度[いちど]も〜ない or 決[けっ]して〜ない).",
                                 fontSize: 10, color: .appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "D97706").opacity(0.10)))
            }
        }
    }

    private func header(_ t: String, _ sub: String, _ c: Color) -> some View {
        VStack(spacing: 0) {
            Text(t).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            Text(sub).font(.system(size: 8)).foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(c))
    }

    private func cell(_ t: String, _ c: Color) -> some View {
        let parts = t.components(separatedBy: "・")
        return VStack(spacing: 0) {
            FuriganaText(text: parts.first ?? t, fontSize: 12, color: .appText,
                         weight: .semibold, alignment: .center)
            Text(parts.count > 1 ? parts[1] : "")
                .font(.system(size: 8)).foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(c.opacity(0.11)))
    }
}

// MARK: - Listing things (と vs や)

private struct ListingDiagram: View {
    let accent: Color
    private let toColor = Color(hex: "2563EB")
    private let yaColor = Color(hex: "D97706")

    var body: some View {
        diagramPanel {
            VStack(spacing: 9) {
                Text("Same three things in the bag — the particle says whether that's the whole bag.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 8) {
                    bag(particle: "と", headline: "the complete list",
                        caption: "Exactly these, nothing else.",
                        showsMore: false, color: toColor)
                    bag(particle: "や", headline: "a few examples",
                        caption: "These and others like them.",
                        showsMore: true, color: yaColor)
                }

                FuriganaText(text: "パンと卵[たまご]を買[か]った — I bought bread and eggs (that's all).",
                             fontSize: 10, color: toColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                FuriganaText(text: "パンや卵[たまご]を買[か]った — I bought bread, eggs, that sort of thing.",
                             fontSize: 10, color: yaColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("や often finishes with など to make the “and so on” explicit.")
                    .font(.system(size: 10)).foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func bag(particle: String, headline: String, caption: String,
                     showsMore: Bool, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(particle)
                .font(.system(size: 20, weight: .heavy)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 9).fill(color))
            Text(headline)
                .font(.system(size: 10, weight: .bold)).foregroundColor(color)

            HStack(spacing: 4) {
                ForEach(["A", "B", "C"], id: \.self) { t in
                    Text(t)
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(color))
                }
                if showsMore {
                    ForEach(0..<2, id: \.self) { _ in
                        Circle().strokeBorder(color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: 20, height: 20)
                    }
                }
            }

            Text(caption)
                .font(.system(size: 9)).foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 11).fill(color.opacity(0.09)))
    }
}

// MARK: - Just about to / just did (ところ・たばかり)

private struct JustDidDiagram: View {
    let accent: Color
    private let color = Color(hex: "7C3AED")
    private let stages: [(String, String, String)] = [
        ("〜るところ",     "about to",       "hasn't started"),
        ("〜ているところ", "right now",      "in the middle"),
        ("〜たところ",     "just finished",  "seconds ago"),
    ]

    var body: some View {
        diagramPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("ところ marks exactly where you are in an action.")
                    .font(.system(size: 11)).foregroundColor(.appTextSecondary)

                // The action bar the three stages point at
                HStack(spacing: 0) {
                    Capsule().fill(color.opacity(0.22)).frame(height: 14)
                }
                .overlay(alignment: .center) {
                    Text("the action").font(.system(size: 9, weight: .semibold)).foregroundColor(color)
                }

                HStack(alignment: .top, spacing: 6) {
                    ForEach(Array(stages.enumerated()), id: \.offset) { i, s in
                        VStack(spacing: 3) {
                            Image(systemName: i == 0 ? "arrow.down.to.line" : (i == 1 ? "hourglass" : "checkmark"))
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(color.opacity(0.55 + 0.15 * Double(i))))
                            Text(s.0).font(.system(size: 10, weight: .bold)).foregroundColor(.appText)
                                .minimumScaleFactor(0.75).lineLimit(1)
                            Text(s.1).font(.system(size: 9, weight: .semibold)).foregroundColor(color)
                            Text(s.2).font(.system(size: 8)).foregroundColor(.appTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.08)))
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("〜たところ").font(.system(size: 11, weight: .bold)).foregroundColor(.appText)
                        Text("clock time — it genuinely just ended")
                            .font(.system(size: 9)).foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("〜たばかり").font(.system(size: 11, weight: .bold)).foregroundColor(.appText)
                        Text("felt time — “only just,” even months later")
                            .font(.system(size: 9)).foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                FuriganaText(text: "去年[きょねん]日本[にほん]に来[き]たばかりです is fine; 来[き]たところ would not be.",
                             fontSize: 10, color: .appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
