import SwiftUI

// Bespoke tiles for the Study menu.
//
// Study covers pronunciation, flashcards, conjugation and reading — four quite
// different activities. Rendering them as identical gradient squares makes the
// screen read as one undifferentiated grid, so each gets artwork that depicts
// what it actually does, and several move. Motion is what makes a tile findable
// at a glance; a static icon still has to be read.
//
// The gradient square is kept for the graded level quizzes, where uniformity is
// the point: they're five instances of one thing.

// MARK: - Shared chrome

/// A darker card with a coloured wash, so the artwork carries the identity rather
/// than a flat gradient fill. Immediately distinguishable from `AestheticTile`.
private struct FeatureCard<Art: View>: View {
    let color: Color
    let title: String
    let subtitle: String
    var square: Bool = true
    @ViewBuilder let art: () -> Art

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appSurface)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.opacity(0.14))

            art()
                .padding(square ? 10 : 6)

            // Keeps the label readable whatever the artwork is doing behind it.
            LinearGradient(stops: [
                .init(color: .clear, location: 0.42),
                .init(color: Color.appSurface.opacity(0.82), location: 0.86),
                .init(color: Color.appSurface.opacity(0.95), location: 1),
            ], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: square ? 18 : 19, weight: .bold))
                    .foregroundColor(.appText)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
            .padding(14)
        }
        .modifier(SquareIf(square))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(color.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.22), radius: 8, x: 0, y: 4)
    }
}

private struct SquareIf: ViewModifier {
    let on: Bool
    init(_ on: Bool) { self.on = on }
    @ViewBuilder func body(content: Content) -> some View {
        if on { content.aspectRatio(1, contentMode: .fit) } else { content.frame(height: 104) }
    }
}

// MARK: - Kana pronunciation

/// A kana character with sound rippling off it.
struct KanaSoundTile: View {
    let character: String
    let title: String
    let color: Color

    @State private var pulse = false

    var body: some View {
        FeatureCard(color: color, title: title, subtitle: "Sounds & readings") {
            ZStack {
                // Three arcs leaving the character, staggered so it reads as a
                // travelling wave rather than three things blinking together.
                // Each arc sits a radius out from the group's centre, so the gap
                // to the character is the offset plus that radius — both are kept
                // small to keep the wave visibly attached to the kana.
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .trim(from: 0, to: 0.2)
                        .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-36))
                        .frame(width: 48 + CGFloat(i) * 24, height: 48 + CGFloat(i) * 24)
                        .opacity(pulse ? 0 : 0.85)
                        .scaleEffect(pulse ? 1.18 : 0.72)
                        .animation(.easeOut(duration: 2.1)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.6), value: pulse)
                }
                .offset(x: 8)

                Text(character)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundColor(color)
                    .offset(x: -14, y: -6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -8)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Flashcards

/// A fanned deck — cards are the thing, so show cards.
struct VocabDeckTile: View {
    let color: Color
    @State private var lift = false

    var body: some View {
        FeatureCard(color: color, title: "Vocab", subtitle: "Word flashcards") {
            ZStack {
                ForEach((0..<3).reversed(), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(color.opacity(i == 0 ? 0.95 : 0.35 - Double(i) * 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(color.opacity(0.7), lineWidth: 1)
                        )
                        .frame(width: 50, height: 66)
                        .overlay(
                            Group {
                                if i == 0 {
                                    Text("語")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(Color.appSurface)
                                }
                            }
                        )
                        .rotationEffect(.degrees(Double(i) * -9))
                        .offset(x: CGFloat(i) * -13, y: CGFloat(i) * 5 + (i == 0 && lift ? -7 : 0))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(x: 12, y: -10)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: lift)
        }
        .onAppear { lift = true }
    }
}

/// A single card turning over, front to meaning — what a kanji card actually does.
struct KanjiFlipTile: View {
    let color: Color
    @State private var flipped = false

    var body: some View {
        FeatureCard(color: color, title: "Kanji", subtitle: "Character flashcards") {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(color.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(color.opacity(0.8), lineWidth: 1)
                    )
                    .frame(width: 66, height: 82)
                    .overlay(
                        // The back reads mirrored unless it's flipped too.
                        Group {
                            if flipped {
                                Text("water")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appSurface)
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            } else {
                                Text("水")
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(Color.appSurface)
                            }
                        }
                    )
                    .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(1.1)) {
                flipped = true
            }
        }
    }
}

// MARK: - Conjugation

/// The stem holds while the ending cycles — the whole idea of conjugation in one
/// glance.
struct ConjugationTile: View {
    let color: Color

    private let stemPlain = "食べ"
    private let endings = ["る", "た", "ない", "れば", "させる", "ましょう"]
    @State private var index = 0

    private let tick = Timer.publish(every: 1.3, on: .main, in: .common).autoconnect()

    var body: some View {
        FeatureCard(color: color, title: "Conjugation",
                    subtitle: "Pick the right form", square: false) {
            HStack(spacing: 0) {
                Spacer()
                // Both sides are plain Text on a shared centre line. Baseline
                // alignment can't be used here: FuriganaText is a UIView wrapper
                // and reports no text baseline, so the ending floats away from
                // the stem.
                HStack(alignment: .center, spacing: 1) {
                    Text(stemPlain)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(color.opacity(0.85))

                    Text(endings[index])
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 92, height: 44, alignment: .leading)
                        .id(endings[index])
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)))
                        .clipped()
                }
                .padding(.trailing, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(tick) { _ in
            withAnimation(.easeInOut(duration: 0.32)) {
                index = (index + 1) % endings.count
            }
        }
    }
}

// MARK: - Reading

/// Lines of text creeping upward, then snapping back to the top — a page being
/// read, on a loop.
struct ReadingTile: View {
    let color: Color

    /// Relative line widths, so it reads as prose rather than a bar chart.
    private let widths: [CGFloat] = [1.0, 0.86, 0.94, 0.62, 0.98, 0.78, 0.9, 0.55]
    private let lineHeight: CGFloat = 7
    private let gap: CGFloat = 6
    /// The visible window has to be shorter than the card, or the block simply
    /// overflows instead of appearing to scroll through an opening.
    private let window: CGFloat = 66

    private var blockHeight: CGFloat { CGFloat(widths.count) * (lineHeight + gap) }

    var body: some View {
        FeatureCard(color: color, title: "Reading",
                    subtitle: "Passages & questions", square: false) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let cycle = 5.4
                let phase = t.truncatingRemainder(dividingBy: cycle) / cycle
                // Creep up for most of the cycle, then flick back to the top.
                let scrolled: CGFloat = phase < 0.86
                    ? CGFloat(phase / 0.86) * blockHeight
                    : blockHeight * CGFloat(1 - (phase - 0.86) / 0.14)

                VStack(alignment: .leading, spacing: gap) {
                    // Two copies so the wrap point never shows a gap.
                    ForEach(0..<2, id: \.self) { copy in
                        ForEach(Array(widths.enumerated()), id: \.offset) { _, frac in
                            Capsule()
                                .fill(color.opacity(copy == 0 ? 0.85 : 0.55))
                                .frame(width: 168 * frac, height: lineHeight)
                        }
                    }
                }
                .frame(width: 168, alignment: .leading)
                .offset(y: -scrolled)
                .frame(width: 168, height: window, alignment: .top)
                .clipped()
                // Fades at both ends, so it reads as a window onto a longer page.
                .mask(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.2),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
            }
        }
    }
}

// MARK: - Grammar quizzes

/// One bar per level, sized like Conjugation and Reading so the whole page reads
/// as one family.
///
/// The motion is a slow scan down the answer options. Each tile is given a phase
/// offset so the six never move together — synchronised motion across a stack
/// reads as one flashing block rather than six separate things.
struct LevelQuizTile: View {
    let title: String
    let subtitle: String
    /// The large mark: a level number, or 俗 for slang.
    let bigMark: String
    /// Optional smaller mark set beside it — the kanji numeral for levels.
    let smallMark: String?
    let color: Color
    /// Seconds of offset, so stacked tiles are out of step with each other.
    let phase: Double

    init(level: Int) {
        title = levelName(level)
        subtitle = "Test your knowledge of Level \(levelNumber(level)) Grammar"
        bigMark = "\(levelNumber(level))"
        smallMark = levelKanjiNumeral(level)
        color = nLevelColor(level)
        phase = Double(level) * 0.83
    }

    init(title: String, subtitle: String, bigMark: String, smallMark: String? = nil,
         color: Color, phase: Double) {
        self.title = title
        self.subtitle = subtitle
        self.bigMark = bigMark
        self.smallMark = smallMark
        self.color = color
        self.phase = phase
    }

    var body: some View {
        // Coarse tick: the highlight only changes every 2.4s, so there's no reason
        // to redraw at display rate.
        TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate + phase
            let step = Int((t / 2.4).rounded(.down)) % 3
            card(selected: step)
        }
    }

    private func card(selected: Int) -> some View {
        FeatureCard(color: color, title: title, subtitle: subtitle, square: false) {
            HStack(spacing: 16) {
                Spacer()

                // A stand-in for a multiple-choice question, the pick moving down.
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(i == selected ? color : Color.clear)
                                .overlay(Circle().strokeBorder(
                                    color.opacity(i == selected ? 0.9 : 0.4), lineWidth: 1.5))
                                .frame(width: 9, height: 9)
                                .scaleEffect(i == selected ? 1.18 : 1)
                            Capsule()
                                .fill(color.opacity(i == selected ? 0.8 : 0.28))
                                .frame(width: [40, 52, 32][i], height: 5)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.55), value: selected)

                // The level, set the way levels are marked everywhere else.
                // Centred rather than baseline-aligned: 一 / 二 / 三 are horizontal
                // strokes, and sitting them on the digit's baseline makes them read
                // as a dash or an equals sign.
                HStack(alignment: .center, spacing: 9) {
                    if let smallMark {
                        Text(smallMark)
                            .font(.system(size: 25, weight: .black))
                            .foregroundColor(color.opacity(0.45))
                    }
                    Text(bigMark)
                        .font(.system(size: bigMark.count > 1 ? 34 : 50, weight: .black))
                        .foregroundColor(color.opacity(0.92))
                }
                .padding(.trailing, 4)
            }
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
