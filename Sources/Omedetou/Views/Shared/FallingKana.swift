import SwiftUI

// MARK: - Falling kana
//
// A slow drift of kana and kanji up the textbook, in place of the wave rules
// the other pages use.
//
// There is exactly ONE field of characters and it is pinned to the screen, not
// to any view. It gets drawn more than once — once as the page itself, and once
// more inside every bar — but each drawing is the same field seen through a
// different window, so a character is at the same screen position in all of
// them. That is the whole trick: because the bar's copy lines up with the
// page's copy to the pixel, a character crossing a bar's edge doesn't hand off
// between two animations, it simply continues, and the bar reads as something
// the character is passing through rather than a separate thing that also has
// characters in it. Falling out of the bottom of one bar and arriving at the
// top of the next comes out of the same arrangement for free.
//
// Each window finds its own place in the field from its global frame, so this
// keeps working while the page scrolls and needs nothing passed down to it.

/// Small deterministic generator: the field has to be identical in every window
/// and across launches, which `Int.random` and `hashValue` cannot promise.
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next01() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 100_000) / 100_000
    }
    mutating func pick<T>(_ xs: [T]) -> T { xs[Int(next01() * CGFloat(xs.count)) % xs.count] }
}

/// A window onto the shared field.
///
/// Used full-bleed for the page, and again inside each bar with the bar's own
/// colour. `boost` lifts the characters a little where they need to read
/// against a card rather than against the page.
struct FallingKanaField: View {
    let tint: Color
    var boost: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// False until the screen that owns this has finished arriving. A textbook
    /// page builds about a dozen of these, and starting them all mid-push means
    /// a dozen canvases redrawing while the navigation transition is trying to
    /// run — which showed up as the whole screen arriving in fits.
    @State private var live = false

    /// How many characters exist at once. Each is a slot that is continually
    /// refilled: one lives, fades away, is destroyed, and the slot immediately
    /// takes a new character somewhere else at some other size.
    private static let slots = 11

    /// One character's life, in seconds.
    private static let fadeIn:  Double = 2
    private static let hold:    Double = 1.5
    private static let fadeOut: Double = 2
    /// Dead time before the slot spawns its next character, so the screen
    /// breathes instead of holding a constant population.
    private static let rest:    Double = 2
    private static var lifetime: Double { fadeIn + hold + fadeOut + rest }

    private static var screen: CGSize { UIScreen.main.bounds.size }

    private static let pool: [String] = [
        "あ","い","う","え","お","か","き","く","さ","し","す","な","に","は","ひ","ふ","ま","み","ら","り","れ","ん",
        "ア","イ","ウ","カ","キ","ク","サ","シ","ス","ナ","ニ","ハ","ヒ","フ","マ","ミ","ラ","リ","レ","ン",
        "日","月","火","水","木","金","土","山","川","田","人","口","目","手","力","文","字","本","学","語","花","雨","空","海",
    ]

    /// How long to stay out of the way before starting. Comfortably past a
    /// navigation push, so opening the textbook is never competing with this.
    private static let settleDelay: Double = 0.5

    /// Outlines are built at this size once and scaled per character.
    private static let outlineSize: CGFloat = 100

    /// Every glyph in the pool, shaped once for the life of the app. Centred on
    /// the origin, so placing one is a scale and a translate.
    private static let paths: [String: Path] = {
        var out: [String: Path] = [:]
        for ch in Set(pool) { out[ch] = PatternedBackground.outlinePath(ch, size: outlineSize) }
        return out
    }()

    /// Everything about the character in slot `i` on its `n`th life. It is a
    /// pure function of those two numbers, which is what lets every window —
    /// the page and each bar — agree on the field without sharing any state
    /// between them. Nothing is stored, so nothing can drift out of register.
    private static func spawn(slot i: Int, life n: Int)
        -> (char: String, x: CGFloat, y: CGFloat, size: CGFloat, speed: CGFloat, opacity: Double) {
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(i &* 73_856_093 ^ n &* 19_349_663)))
        _ = rng.next01()                        // discard the first draw; the seed leaks into it
        let ch = rng.pick(pool)
        let x = 0.03 + rng.next01() * 0.94
        let y = -0.05 + rng.next01() * 1.10     // anywhere down the screen, a little past both ends
        // Depth: 0 far, 1 near. Size, speed and opacity all follow from it, so a
        // small character is also slow and faint — the cues agree rather than fight.
        let depth = rng.next01()
        return (ch, x, y,
                39 + depth * 54,
                6 + depth * 14.4,
                0.07 + Double(depth) * 0.09)
    }

    /// Whether this window is anywhere on screen.
    ///
    /// The textbook is a plain (non-lazy) stack, so every bar exists whether or
    /// not it has been scrolled to — and each one was animating regardless. The
    /// geometry updates as the page scrolls, so this costs nothing to ask and
    /// stops perhaps half the bars from drawing at all. A bar coming back into
    /// view resumes in register, because the field is a function of absolute
    /// time and holds no state of its own.
    private func onScreen(_ geo: GeometryProxy) -> Bool {
        let f = geo.frame(in: .global)
        guard f.height > 0 else { return false }
        return f.intersects(CGRect(origin: .zero, size: UIScreen.main.bounds.size))
    }

    var body: some View {
        GeometryReader { geo in
            // Where this window sits on the screen. Everything is drawn in
            // screen space and then shifted by this, which is what keeps every
            // copy of the field in register.
            let origin = geo.frame(in: .global).origin
            if reduceMotion {
                // Still a backdrop, just not a moving one.
                Canvas { ctx, size in
                    Self.draw(&ctx, size, origin: origin, t: 0, tint: tint, boost: boost)
                }
            } else if live, onScreen(geo) {
                // 15fps. Cost here is rasterised area times frame rate — the
                // full-screen page copy alone measured about the same as all
                // eleven bar copies together — and at 6-20pt/s a character
                // covers under a point per frame even at this rate. Dropping
                // from 30 to 20 is invisible and takes a third off the bill.
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
            // Slots are spread across the cycle so they aren't all breathing
            // together; each is somewhere different in its own character's life.
            let phase = t + Double(i) * lifetime / Double(slots)
            let life = Int(floor(phase / lifetime))     // which character this slot is on
            let age = phase - Double(life) * lifetime   // how far into that character's life

            // Fade up, hold, fade away, then nothing at all until the next one.
            let alpha: Double
            if age < fadeIn {
                alpha = ease(age / fadeIn)
            } else if age < fadeIn + hold {
                alpha = 1
            } else if age < fadeIn + hold + fadeOut {
                alpha = ease(1 - (age - fadeIn - hold) / fadeOut)
            } else {
                continue                                 // destroyed; the slot is resting
            }
            guard alpha > 0.01 else { continue }

            let c = spawn(slot: i, life: life)
            // Drifts upward over its life, from wherever it was born.
            let sy = c.y * scr.height - CGFloat(age) * c.speed
            let sx = c.x * scr.width

            // …into this window's own coordinates.
            let y = sy - origin.y
            let x = sx - origin.x

            // Filling a cached outline is much cheaper than resolving Text, but
            // still worth skipping entirely for anything outside this window.
            guard y > -c.size, y < size.height + c.size,
                  x > -c.size, x < size.width + c.size else { continue }

            guard let glyph = paths[c.char] else { continue }
            let k = c.size / outlineSize
            let placed = glyph.applying(CGAffineTransform(scaleX: k, y: k)
                .concatenating(CGAffineTransform(translationX: x, y: y)))
            ctx.fill(placed, with: .color(tint.opacity(min(0.5, c.opacity * boost * alpha))))
        }
    }

    /// Smooth 0→1, so a character swells into view rather than ramping linearly.
    private static func ease(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }
}

/// The textbook's page: the theme's gradient with the falling characters over
/// it, in place of the wave rules `PatternedBackground(.textbook)` draws.
struct FallingKanaBackground: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            AppBackground()
            // Same hue the textbook's wave rules used, so the page still reads
            // as the textbook's page and not as a different screen.
            // Full bleed, like the page patterns it replaced. Confined to the
            // safe area the field stops dead at the nav bar, and since the
            // characters travel upward they were being sliced flat along that
            // edge instead of sliding away under the bar.
            FallingKanaField(tint: Color.accent(of: themeManager.current).hueShifted(42))
                .ignoresSafeArea()
        }
    }
}

extension FallingKanaField {
    /// The in-bar window, ready to hand to `AestheticTile` as its backdrop.
    /// Lifted a little: the same ink that reads correctly on the page would
    /// disappear against a card that already carries a wash of its own colour.
    static func backdrop(tint: Color) -> AnyView {
        AnyView(FallingKanaField(tint: tint, boost: 1.6))
    }
}
