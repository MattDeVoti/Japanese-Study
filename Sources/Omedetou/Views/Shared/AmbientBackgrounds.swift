import SwiftUI

// MARK: - Ambient page backdrops
//
// Three moving backdrops, one per page, built the same way the textbook's
// falling characters are: everything on screen is a *pure function of time*,
// with no stored per-particle state. That is what lets each of them be drawn in
// one `Canvas` at a low frame rate, resume in register after being scrolled off
// screen, and cost nothing when Reduce Motion is on.
//
// The shared rules, so they read as one family rather than three effects:
//
//   • The theme accent, hue-shifted per page, is the only colour used.
//   • Nothing is ever fully opaque — a backdrop that competes with the content
//     in front of it is a bug, not a feature.
//   • Reduce Motion gets a still frame of the same thing, never a blank page.

/// Small deterministic generator. The same one the falling-kana field uses, kept
/// separate so neither file has to be the other's dependency.
private struct AmbientRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next01() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 100_000) / 100_000
    }
    mutating func pick<T>(_ xs: [T]) -> T { xs[Int(next01() * CGFloat(xs.count)) % xs.count] }
}

/// Smooth 0→1, so things swell in rather than ramping linearly.
private func ambientEase(_ x: Double) -> Double {
    let t = max(0, min(1, x))
    return t * t * (3 - 2 * t)
}

// MARK: - Extras: drifting kaomoji

/// Kaomoji drifting up the Extras page.
///
/// Structurally the falling-kana field, with two differences that matter:
///
///   • A kaomoji is several glyphs wide, and the widths differ wildly, so they
///     are scaled to fit a box rather than set at a font size — sizing on a
///     nominal point size would make `(＾ω＾)` dwarf `^_^`.
///   • They are outlined once into paths at load, like the kana, because these
///     are long strings and re-shaping five or six glyphs per face per frame is
///     exactly the cost this approach exists to avoid.
struct KaomojiField: View {
    let tint: Color
    var boost: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var live = false

    /// How many faces exist at once. Fewer than the textbook's characters: a
    /// face is much wider, so the same count would read as a crowd.
    private static let slots = 14

    private static let fadeIn: Double = 2
    private static let hold: Double = 1.6
    private static let fadeOut: Double = 2
    private static let rest: Double = 2.2
    private static var lifetime: Double { fadeIn + hold + fadeOut + rest }

    private static let settleDelay: Double = 0.5
    private static var screen: CGSize { UIScreen.main.bounds.size }

    /// The faces themselves. Kept to shapes that stay legible small and read as
    /// friendly rather than as punctuation soup.
    private static let pool: [String] = [
        "^ - ^", "^_^", "＾＾", "(^｡^)", "（＾ω＾）", "（＾ν＾）", "(^.^)",
        "(・_・)", "(^o^)", "(≧▽≦)", "(*^^*)", "(´｡• ᵕ •｡`)", "(＾▽＾)",
        "(・ω・)", "(￣▽￣)", "(＠＾０＾)", "(•‿•)", "ヽ(^o^)ノ", "(⌒‿⌒)",
        "(￣ω￣)", "(°▽°)", "(＾◇＾)",
    ]

    /// Outlined once at this size, then scaled per face.
    private static let outlineSize: CGFloat = 60

    private static let paths: [String: Path] = {
        var out: [String: Path] = [:]
        for face in Set(pool) { out[face] = PatternedBackground.outlinePath(face, size: outlineSize) }
        return out
    }()

    /// Drawn width of each face at `outlineSize`, so a face can be scaled to a
    /// target width instead of a nominal point size.
    private static let widths: [String: CGFloat] = {
        var out: [String: CGFloat] = [:]
        for (face, path) in paths { out[face] = max(path.boundingRect.width, 1) }
        return out
    }()

    /// Everything about the face in slot `i` on its `n`th life — a pure function
    /// of those two numbers, so every frame agrees without storing anything.
    private static func spawn(slot i: Int, life n: Int)
        -> (face: String, x: CGFloat, y: CGFloat, width: CGFloat, speed: CGFloat, opacity: Double) {
        var rng = AmbientRNG(seed: UInt64(bitPattern: Int64(i &* 40_503 ^ n &* 92_837_111)))
        _ = rng.next01()                       // discard: the seed leaks into the first draw
        let face = rng.pick(pool)
        let x = 0.06 + rng.next01() * 0.88
        let y = -0.05 + rng.next01() * 1.10
        let depth = rng.next01()               // 0 far, 1 near — size, speed and ink all follow
        return (face, x, y,
                76 + depth * 88,
                7 + depth * 13,
                0.14 + Double(depth) * 0.14)
    }

    private func onScreen(_ geo: GeometryProxy) -> Bool {
        let f = geo.frame(in: .global)
        guard f.height > 0 else { return false }
        return f.intersects(CGRect(origin: .zero, size: UIScreen.main.bounds.size))
    }

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            if reduceMotion {
                Canvas { ctx, size in
                    Self.draw(&ctx, size, origin: origin, t: 0, tint: tint, boost: boost)
                }
            } else if live, onScreen(geo) {
                // Same 16fps the textbook settled on: these drift a point or so
                // per frame, and the cost is rasterised area × frame rate.
                TimelineView(.animation(minimumInterval: 1.0 / 16.0)) { tl in
                    Canvas { ctx, size in
                        Self.draw(&ctx, size, origin: origin,
                                  t: tl.date.timeIntervalSinceReferenceDate,
                                  tint: tint, boost: boost)
                    }
                }
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion, !live else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) {
                withAnimation(.easeIn(duration: 0.4)) { live = true }
            }
        }
    }

    private static func draw(_ ctx: inout GraphicsContext, _ size: CGSize,
                             origin: CGPoint, t: TimeInterval,
                             tint: Color, boost: Double) {
        let scr = screen
        for i in 0..<slots {
            let phase = t + Double(i) * lifetime / Double(slots)
            let life = Int(floor(phase / lifetime))
            let age = phase - Double(life) * lifetime

            let alpha: Double
            if age < fadeIn {
                alpha = ambientEase(age / fadeIn)
            } else if age < fadeIn + hold {
                alpha = 1
            } else if age < fadeIn + hold + fadeOut {
                alpha = ambientEase(1 - (age - fadeIn - hold) / fadeOut)
            } else {
                continue                        // resting between faces
            }
            guard alpha > 0.01 else { continue }

            let c = spawn(slot: i, life: life)
            let sy = c.y * scr.height - CGFloat(age) * c.speed
            let sx = c.x * scr.width
            let y = sy - origin.y
            let x = sx - origin.x

            guard let face = paths[c.face], let drawnWidth = widths[c.face] else { continue }
            // Scaled to fit a box rather than to a width: the faces range from
            // three narrow characters to seven full-width ones, and sizing on
            // width alone makes the short ones tower over the long ones.
            let drawnHeight = max(face.boundingRect.height, 1)
            let k = min(c.width / drawnWidth, (c.width * 0.42) / drawnHeight)
            let h = drawnHeight * k
            guard y > -h, y < size.height + h,
                  x > -c.width, x < size.width + c.width else { continue }

            let placed = face.applying(CGAffineTransform(scaleX: k, y: k)
                .concatenating(CGAffineTransform(translationX: x, y: y)))
            ctx.fill(placed, with: .color(tint.opacity(min(0.6, c.opacity * boost * alpha))))
        }
    }
}

/// The Extras page: the theme gradient with drifting faces over it, and no
/// static motif underneath — the faces *are* the pattern.
///
/// The gradient is the same one every page uses, but the patterned pages lay a
/// whole sheet of ink over it, and losing that left Extras looking washed out
/// beside them. A flat wash of the page's own hue puts the depth back without
/// bringing a static motif with it.
struct KaomojiBackground: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        // The home screen's own hue, deliberately: a wash covers the whole page,
        // and rotating it far from the theme (as the per-page motif inks do)
        // turns the paper a different colour instead of deepening it.
        let ink = Color.accent(of: themeManager.current).hueShifted(-18)
        let onDark = Color.relativeLuminance(themeManager.current.background) < 0.45

        ZStack {
            AppBackground()
            // Deeper on light themes, where the bare gradient is palest; a dark
            // theme is already deep and would only go muddy. Laid on as a
            // gradient rather than a flat fill so the page keeps its own
            // top-to-bottom fall of light instead of being levelled by it.
            LinearGradient(colors: [ink.opacity(onDark ? 0.03 : 0.06),
                                    ink.opacity(onDark ? 0.06 : 0.12)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            KaomojiField(tint: ink)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Study: pool light

/// Caustics — the net of light on the bottom of a pool.
///
/// Drawn as a few dozen soft, wavy strokes rather than as a simulation: each is
/// a horizontal line whose vertical position wanders with two sine terms of
/// different periods, which is enough to give the wandering, folding look
/// without anything to solve. Lines brighten and fade on their own clocks, so
/// the net keeps re-forming instead of pulsing as one.
///
/// Every stroke is drawn twice — wide and faint for the halo, narrow and bright
/// for the core — which is what makes it read as light rather than as string.
struct PoolLightField: View {
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var live = false

    /// Strokes on screen. Enough to interlock, few enough to stay cheap — this
    /// is a full-screen canvas, so every one of these is paid for on every frame.
    private static let lines = 20
    /// Seconds for one full brighten-and-fade of a single stroke.
    private static let breath: Double = 6.5
    private static let settleDelay: Double = 0.4

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                Canvas { ctx, size in Self.draw(&ctx, size, t: 0, tint: tint) }
            } else if live {
                // 14fps: the shapes are large and soft, and the motion is a slow
                // wander — the frames in between genuinely aren't visible, and
                // this is a full-screen canvas.
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { tl in
                    Canvas { ctx, size in
                        Self.draw(&ctx, size, t: tl.date.timeIntervalSinceReferenceDate, tint: tint)
                    }
                }
                .transition(.opacity)
            }
            // `geo` is only here so the canvas gets a real size before it draws.
            let _ = geo
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion, !live else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) {
                withAnimation(.easeIn(duration: 0.5)) { live = true }
            }
        }
    }

    private static func draw(_ ctx: inout GraphicsContext, _ size: CGSize,
                             t: TimeInterval, tint: Color) {
        guard size.width > 0, size.height > 0 else { return }
        // Sampled finely enough that the folds stay smooth — at a coarse step
        // the straight segments between samples turn a fold into a zigzag — but
        // no finer, because every sample is a line segment to stroke twice.
        let step: CGFloat = 12
        let span = size.width + step

        for i in 0..<lines {
            var rng = AmbientRNG(seed: UInt64(i &* 2_654_435_761))
            _ = rng.next01()

            // Two families crossing at shallow opposite angles. That crossing is
            // what makes a net rather than a set of stripes, and the net is the
            // thing that reads as light on water.
            let leftward = i % 2 == 0
            let tilt: CGFloat = (leftward ? 1 : -1) * (0.20 + rng.next01() * 0.16)
            let baseY = rng.next01() * 1.5 - 0.25
            // Long, shallow folds: amplitude well under the period, or the line
            // doubles back on itself and stops looking like a caustic.
            let amp1 = 16 + rng.next01() * 22
            let amp2 = 5 + rng.next01() * 9
            let period1 = 260 + rng.next01() * 260
            let period2 = 110 + rng.next01() * 120
            let drift = 5 + rng.next01() * 13
            let bob = 4 + rng.next01() * 9
            let thickness = 1.2 + rng.next01() * 2.0
            let phase = rng.next01() * breath

            // Each filament brightens and fades on its own clock, squared so it
            // spends more of its life dim: the net keeps re-forming somewhere
            // else instead of the whole page pulsing together.
            let cycle = ((t + phase) / breath).truncatingRemainder(dividingBy: 1)
            let swell = pow(sin(cycle * .pi), 2)
            guard swell > 0.03 else { continue }

            let travel = CGFloat(t) * drift
            var path = Path()
            var x = -step
            var first = true
            while x < span {
                let along = x + travel
                let y = baseY * size.height
                    + sin(along / period1 * 2 * .pi) * amp1
                    + sin(along / period2 * 2 * .pi + Double(i)) * amp2
                    + sin(CGFloat(t) * 0.25 + CGFloat(i)) * bob
                    + x * tilt
                let p = CGPoint(x: x, y: y)
                if first { path.move(to: p); first = false } else { path.addLine(to: p) }
                x += step
            }

            // Bright patches travelling along the filament, done as a gradient
            // rather than as separate segments: one stroke call either way, and
            // this is the part that sells it as light rather than as wire.
            let slide = ((t * 0.06 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1))
            var stops: [Gradient.Stop] = []
            let nodes = 3
            for n in 0...(nodes * 2) {
                let at = CGFloat(n) / CGFloat(nodes * 2)
                let lit = n % 2 == 1
                let shifted = (at + CGFloat(slide)).truncatingRemainder(dividingBy: 1)
                stops.append(.init(color: tint.opacity((lit ? 0.20 : 0.05) * swell),
                                   location: shifted))
            }
            stops.sort { $0.location < $1.location }
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(stops: stops),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0))

            // Halo first, then the core over it.
            ctx.stroke(path, with: .color(tint.opacity(0.035 * swell)),
                       style: StrokeStyle(lineWidth: thickness * 7, lineCap: .round, lineJoin: .round))
            ctx.stroke(path, with: shading,
                       style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
        }
    }
}

/// The Study page: the theme gradient with pool light moving over it.
struct PoolLightBackground: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            AppBackground()
            PoolLightField(tint: Color.accent(of: themeManager.current).hueShifted(0))
                .ignoresSafeArea()
        }
    }
}

// MARK: - Dictionary: lighting up cells of the grid

/// A mask that lights individual cells of the dictionary's practice grid.
///
/// Only the mask moves: the grid behind it is drawn once, and a second heavier
/// copy shows through wherever this is white — the same trick the home screen's
/// glow wave uses. Which cells light, and when, is a pure function of the cell's
/// coordinates, so the pattern is stable while the page scrolls and needs no
/// state.
struct GridCellGlowMask: View {
    /// Must match `PatternedBackground.drawPracticeGrid`, or the lit squares
    /// won't sit on the drawn ones.
    static let cell: CGFloat = 46

    /// One cell's full cycle: dark, glow up, hold, fade, dark again.
    private static let period: Double = 5.5
    /// How much of the grid is lit at any moment, roughly.
    private static let litFraction: CGFloat = 0.10

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let cols = Int(ceil(size.width / Self.cell)) + 1
                let rows = Int(ceil(size.height / Self.cell)) + 1
                for r in 0..<rows {
                    for c in 0..<cols {
                        // Each cell gets its own start time and its own turn.
                        var rng = AmbientRNG(seed: UInt64(bitPattern: Int64(r &* 73_856_093 ^ c &* 19_349_663)))
                        _ = rng.next01()
                        guard rng.next01() < Self.litFraction * 8 else { continue }
                        let offset = Double(rng.next01()) * Self.period * 8

                        let cycle = ((t + offset) / (Self.period * 8)).truncatingRemainder(dividingBy: 1)
                        // Lit for one period in eight, so most cells are dark at
                        // any moment and the ones that aren't feel picked out.
                        guard cycle < 1.0 / 8.0 else { continue }
                        let u = cycle * 8
                        let alpha = u < 0.35 ? ambientEase(u / 0.35)
                                             : ambientEase(1 - (u - 0.35) / 0.65)
                        guard alpha > 0.02 else { continue }

                        let rect = CGRect(x: CGFloat(c) * Self.cell, y: CGFloat(r) * Self.cell,
                                          width: Self.cell, height: Self.cell)
                        // Soft-edged rather than a hard square: a crisp edge
                        // reads as a rectangle drawn on the page, not as light.
                        ctx.fill(Path(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 6),
                                 with: .color(.white.opacity(alpha)))
                    }
                }
            }
            .blur(radius: 7)
        }
        .allowsHitTesting(false)
    }
}
