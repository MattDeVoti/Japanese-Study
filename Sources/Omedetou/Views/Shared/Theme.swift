import SwiftUI
import UIKit
import CoreText

// MARK: - Colors

extension Color {
    static var appBackground: Color { _currentAppTheme.background }
    /// Bottom stop of the page gradient — equals `appBackground` on flat themes.
    static var appBackgroundEnd: Color { _currentAppTheme.backgroundEnd ?? _currentAppTheme.background }
    static var appNavBar:     Color { _currentAppTheme.navBar }
    static var appNavBarText: Color { _currentAppTheme.navBarText }
    // The theme's signature accent (its nav-bar hue) — used for the home title
    // so it always reads as part of the current palette instead of a fixed red.
    /// The theme's signature hue, nudged if needed so it always reads against
    /// the page background (some themes pair a nav bar close to their backdrop).
    static var appAccent: Color { readable(_currentAppTheme.navBar, on: _currentAppTheme.background) }
    // Primary text derived from the THEME (not the device appearance), so it
    // always contrasts with the current theme's background regardless of
    // whether the device is in light or dark mode.
    static var appText: Color {
        _currentAppTheme.colorScheme == .dark ? Color(white: 0.96) : Color(white: 0.11)
    }

    /// WCAG relative luminance (0 = black, 1 = white).
    static func relativeLuminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// WCAG contrast ratio between two colors (1 = identical, 21 = black on white).
    static func contrastRatio(_ a: Color, _ b: Color) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Near-black or near-white — whichever contrasts better against `background`,
    /// by WCAG relative luminance. Use for text placed directly on a surface whose
    /// exact color you have in hand, so the two can never disagree (light or dark).
    static func contrastingText(on background: Color) -> Color {
        relativeLuminance(background) < 0.45 ? Color(white: 0.96) : Color(white: 0.11)
    }

    /// Keeps a colour's character but guarantees it stays legible: if `color`
    /// doesn't contrast enough with `background`, it's pushed lighter (on dark
    /// backgrounds) or darker (on light ones) until it does. Falls back to plain
    /// contrasting text if even that isn't enough.
    static func readable(_ color: Color, on background: Color, minRatio: Double = 3.6) -> Color {
        guard contrastRatio(color, background) < minRatio else { return color }
        let goLighter = relativeLuminance(background) < 0.45
        var candidate = color
        for _ in 0..<10 {
            candidate = goLighter ? candidate.lightened(0.12) : candidate.darkened(0.12)
            if contrastRatio(candidate, background) >= minRatio { return candidate }
        }
        return contrastingText(on: background)
    }

    /// The same colour rotated around the wheel. Used to give each main page a
    /// sibling of the theme accent rather than an unrelated hue, so the four
    /// pages stay obviously part of one palette.
    func hueShifted(_ degrees: Double) -> Color {
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        var shifted = (Double(h) + degrees / 360.0).truncatingRemainder(dividingBy: 1.0)
        if shifted < 0 { shifted += 1 }
        return Color(hue: shifted, saturation: Double(sat), brightness: Double(b), opacity: Double(a))
    }

    /// The signature accent of a *given* theme. `appAccent` only answers for the
    /// active one, which is no use when previewing a theme you haven't picked.
    static func accent(of theme: AppTheme) -> Color {
        readable(theme.navBar, on: theme.background)
    }

    /// An accent colour guaranteed to read against the current page background.
    static func readableOnBackground(_ accent: Color) -> Color {
        readable(accent, on: _currentAppTheme.background)
    }

    /// Legible against *both* ends of the page gradient. `readableOnBackground`
    /// only measures the top stop, which is the wrong test for controls sitting
    /// low on the screen — down there the second stop is what's behind them.
    static func readableOnPage(_ color: Color, minRatio: Double = 3.6) -> Color {
        let top = _currentAppTheme.background
        let bottom = _currentAppTheme.backgroundEnd ?? top
        /// Contrast against the worse of the two stops.
        func worst(_ c: Color) -> Double {
            min(contrastRatio(c, top), contrastRatio(c, bottom))
        }
        guard worst(color) < minRatio else { return color }

        // The stops can pull opposite ways — a light top over a darker bottom
        // means lightening fixes one end and ruins the other. So try both
        // directions and keep whichever reads best against the pair.
        var best = color
        for towardWhite in [true, false] {
            var candidate = color
            for _ in 0..<12 {
                candidate = towardWhite ? candidate.lightened(0.10) : candidate.darkened(0.10)
                if worst(candidate) > worst(best) { best = candidate }
                if worst(candidate) >= minRatio { return candidate }
            }
        }
        // Nothing clears both; settle for plain near-white or near-black,
        // whichever survives the pair better. Never worse than we started.
        for fallback in [Color(white: 0.96), Color(white: 0.11)]
        where worst(fallback) > worst(best) { best = fallback }
        return best
    }

    /// Raises saturation to a floor, so hue rotation still reads on themes
    /// whose accent is nearly grey.
    func saturated(atLeast floor: Double) -> Color {
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: max(Double(sat), floor),
                     brightness: Double(b), opacity: Double(a))
    }

    /// Deepened until the white label an AestheticTile draws will still read.
    /// The tile's gradient lightens its top by 0.14, so that lightest point is
    /// what has to clear — testing the base colour would let pale tiles through.
    private static func labelSafe(_ c: Color) -> Color {
        var out = c
        for _ in 0..<16 {
            if contrastRatio(.white, out.lightened(0.14)) >= 3.1 { return out }
            out = out.darkened(0.08)
        }
        return out
    }

    /// How many distinct tile colours the palette offers before repeating.
    static let tilePaletteSize = 12

    /// One slot of a tile palette derived from the current theme. Hues fan out
    /// around the theme accent, so every coloured button on every page belongs
    /// to the same family and the whole app re-tints when the theme changes —
    /// while neighbouring tiles still read as clearly different colours.
    static func themeTile(_ slot: Int) -> Color {
        let n = tilePaletteSize
        let i = ((slot % n) + n) % n
        // A fan, not the whole wheel: go much wider and the far slots stop
        // looking related to the theme at all.
        let spread = 200.0
        // Slots don't take the fan in order. Stepping 5 at a time (coprime with
        // 12, so still a permutation) puts consecutive slot numbers ~5/12 of the
        // fan apart — otherwise neighbouring tiles like Level 5 and Slang land
        // one step apart in hue and read as the same colour.
        let position = (i * 5) % n
        let hue = (Double(position) / Double(n)) * spread - spread / 2

        // Built from the theme's own navBar hue rather than `appAccent`, and the
        // saturation floor is applied *before* the rotation. Both matter: the
        // accent is contrast-corrected against the page, and on themes like
        // Bubblegum that correction bottoms out at flat grey — grey has no hue
        // to rotate, so every slot would collapse onto a single colour. Tiles
        // carry their own white label, so they never needed that correction.
        var c = _currentAppTheme.navBar.saturated(atLeast: 0.55).hueShifted(hue)
        switch i % 3 {
        case 0:  c = c.darkened(0.12)
        case 2:  c = c.lightened(0.08)
        default: break
        }
        return labelSafe(c)
    }

    /// A colour sampled along the accent sweep (t: 0 = start … 1 = end). Lets a
    /// row of separate views share one gradient across the whole row, which a
    /// per-view `LinearGradient` can't do (each view resolves it in its own bounds).
    static func appAccentSweepSample(_ t: Double) -> Color {
        let base = appAccent
        let onDark = relativeLuminance(_currentAppTheme.background) < 0.45
        let far = onDark ? base.lightened(0.42) : base.darkened(0.34)
        let clamped = min(max(t, 0), 1)
        return onDark ? far.blended(toward: base, amount: clamped)
                      : base.blended(toward: far, amount: clamped)
    }

    /// Secondary text derived from the THEME's text colour (not the device
    /// appearance), so it stays legible on saturated theme backgrounds where
    /// SwiftUI's `.secondary` can wash out.
    static var appTextSecondary: Color { appText.opacity(0.68) }

    // Kana accents — theme-derived like every other coloured button.
    static var hiraganaColor: Color { themeTile(1) }
    static var katakanaColor: Color { themeTile(3) }

    // The three category colours, which identify grammar / vocab / kanji
    // everywhere they appear: the Study tiles, the three progress badges on a
    // chapter row, and the checkmarks inside a lesson. Vocab and Kanji reuse the
    // very slots their Study tiles use, so a category is one colour app-wide.
    // The three sit far apart in the palette because they're shown side by side.
    static var grammarColor: Color { themeTile(11) }
    static var vocabColor: Color   { themeTile(5) }
    static var kanjiColor: Color   { themeTile(7) }

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int>>8)*17, (int>>4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int>>16, int>>8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int>>24, int>>16 & 0xFF, int>>8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// Friendly progression names shown to the user instead of N-codes:
// N5 → "Level 1", N4 → "Level 2", … N1 → "Level 5"  (Level = 6 − N).

/// The level number (1…5) for an N-level int (5…1).
func levelNumber(_ nLevel: Int) -> Int { 6 - nLevel }

/// Full display name for an N-level int, e.g. 5 → "Level 1".
func levelName(_ nLevel: Int) -> String { "Level \(levelNumber(nLevel))" }

/// Display name from an N-level string ("N5" → "Level 1"). Other labels
/// (e.g. "Hiragana", "Katakana") pass through unchanged.
func levelName(jlpt: String) -> String {
    guard jlpt.hasPrefix("N"), let n = Int(jlpt.dropFirst()) else { return jlpt }
    return levelName(n)
}

/// Kanji numeral for an N-level int, matching the level number shown on the
/// tile (N5 → Level 1 → 一). Empty outside 1–5 so a sixth book degrades quietly.
func levelKanjiNumeral(_ nLevel: Int) -> String {
    let numerals = ["一", "二", "三", "四", "五"]
    let i = levelNumber(nLevel) - 1
    return numerals.indices.contains(i) ? numerals[i] : ""
}

/// Level 1…5 take evenly spaced slots, so the five books read as a run of
/// related colours rather than five unrelated ones.
func nLevelColor(_ level: Int) -> Color {
    let displayed = levelNumber(level)           // 1…5
    guard (1...5).contains(displayed) else { return Color.themeTile(0) }
    return Color.themeTile((displayed - 1) * 2)  // slots 0,2,4,6,8
}

func levelAccentColor(_ levelId: String) -> Color {
    switch levelId {
    case "Hiragana": return .hiraganaColor
    case "Katakana": return .katakanaColor
    case SlangContent.levelId: return SlangContent.accent
    default: return nLevelColor(Int(levelId.dropFirst()) ?? 5)
    }
}

// MARK: - Color math

extension Color {
    /// Linear interpolation toward another color by `amount` (0…1).
    func blended(toward other: Color, amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(max(0, min(1, amount)))
        return Color(.sRGB,
                     red: Double(r1 + (r2 - r1) * t),
                     green: Double(g1 + (g2 - g1) * t),
                     blue: Double(b1 + (b2 - b1) * t),
                     opacity: Double(a1 + (a2 - a1) * t))
    }
    func lightened(_ amount: Double) -> Color { blended(toward: .white, amount: amount) }
    func darkened(_ amount: Double) -> Color { blended(toward: .black, amount: amount) }
}

// MARK: - Derived surface / elevation tokens
//
// Cards used to share the background color with only a faint border, which read
// as flat. These tokens derive a layered surface + hairline + shadow from the
// current theme, so every theme (light or dark) gains depth automatically.

extension Color {
    private static var appIsDark: Bool { _currentAppTheme.colorScheme == .dark }

    /// Elevated card surface, one step above the app background.
    static var appSurface: Color {
        let bg = _currentAppTheme.background
        return appIsDark ? bg.lightened(0.06) : bg.blended(toward: .white, amount: 0.80)
    }

    /// Higher elevation — inputs, nested cells, selected states.
    static var appSurfaceHigh: Color {
        let bg = _currentAppTheme.background
        return appIsDark ? bg.lightened(0.11) : bg.blended(toward: .white, amount: 0.95)
    }

    /// Hairline border for cards and controls.
    static var appHairline: Color {
        appIsDark ? Color.white.opacity(0.09) : Color.black.opacity(0.07)
    }

    /// Divider / separator tint.
    static var appSeparator: Color {
        appIsDark ? Color.white.opacity(0.07) : Color.black.opacity(0.055)
    }

    /// Soft shadow color for elevated cards.
    static var appCardShadow: Color {
        appIsDark ? Color.black.opacity(0.30) : Color.black.opacity(0.09)
    }

    /// Subtle top-left sheen gradient for a colored badge / circle.
    var badgeGradient: LinearGradient {
        LinearGradient(colors: [lightened(0.14), darkened(0.06)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension LinearGradient {
    /// Accent sweep for display type. Both stops move *away* from the page
    /// background's luminance (lighter on dark themes, darker on light ones), so
    /// the gradient is never less legible than `appAccent` itself.
    static var appAccentSweep: LinearGradient {
        let base = Color.appAccent
        let onDark = Color.relativeLuminance(_currentAppTheme.background) < 0.45
        let far = onDark ? base.lightened(0.42) : base.darkened(0.34)
        return LinearGradient(colors: onDark ? [far, base] : [base, far],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Gentle vertical sheen for the nav bar, derived from the theme nav color.
    static var appNavBar: LinearGradient {
        let n = _currentAppTheme.navBar
        return LinearGradient(colors: [n.lightened(0.05), n.darkened(0.10)],
                              startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Card surface modifier

struct AppCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.appSurface)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.appHairline, lineWidth: 1)
            )
            .shadow(color: elevated ? Color.appCardShadow : .clear,
                    radius: elevated ? 10 : 0, x: 0, y: elevated ? 5 : 0)
    }
}

extension View {
    /// Elevated, hairline-bordered surface with soft shadow and continuous corners.
    func appCard(cornerRadius: CGFloat = 16, elevated: Bool = true) -> some View {
        modifier(AppCardStyle(cornerRadius: cornerRadius, elevated: elevated))
    }
}

// MARK: - Nav Bar Modifier

struct StandardNavBar: ViewModifier {
    let title: String
    /// nil follows the Appearance. A value pins the bar, for the few screens
    /// that keep a fixed look of their own.
    var background: LinearGradient? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            // Audio belongs to the page that started it. Every pushed screen wears
            // this modifier, so leaving one — backing out or pushing further in —
            // cuts the speech rather than leaving a voice reading a page that is no
            // longer on screen.
            .onDisappear { SpeechService.shared.stop() }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(background == nil ? .appNavBarText : .white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(background == nil ? .appNavBarText : .white)
                }
            }
            .toolbarBackground(background ?? LinearGradient.appNavBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func standardNavBar(_ title: String, background: LinearGradient? = nil) -> some View {
        modifier(StandardNavBar(title: title, background: background))
    }
}

// MARK: - Options Button Modifier

struct OptionsButton: ViewModifier {
    @ObservedObject var filter: StudyFilter
    @ObservedObject var store: CardStore
    let section: CardStore.CardSection
    @State private var showOptions = false
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showOptions = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.appNavBarText)
                    }
                }
            }
            .sheet(isPresented: $showOptions) {
                OptionsMenuView(filter: filter, onClearWeights: {
                    store.clearWeights(for: section)
                }, store: store,
                onClearExclusions: section == .kanji ? { store.clearKanjiExclusions() } : nil)
            }
    }
}

extension View {
    func withOptions(filter: StudyFilter, store: CardStore, section: CardStore.CardSection, label: String = "") -> some View {
        modifier(OptionsButton(filter: filter, store: store, section: section))
    }
}

// MARK: - Design system: headings & tiles
//
// The Study menu's look — big bold headings, saturated gradient tiles with an
// oversized watermark glyph and a frosted type icon — generalized so every
// screen can share it.

/// A large section heading. Replaces the old tiny uppercase labels.
/// Pass `subtitle` for a one-line orientation note underneath.
struct SectionHeading: View {
    let title: String
    var size: CGFloat = 20
    var subtitle: String? = nil

    init(_ title: String, size: CGFloat = 20, subtitle: String? = nil) {
        self.title = title
        self.size = size
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: size, weight: .bold))
                .foregroundColor(.appText)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// The flashcard reveal button: flat accent ring over a barely-there tint, with a
/// concentric hairline for a little structure. No gradient, no shadow — it should
/// read as drawn, not as an object sitting on the page.
/// Shared by the kanji and vocab decks so the two can never drift apart.
struct CheckButton: View {
    let action: () -> Void
    var diameter: CGFloat = 92

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        // Read through the environment object so the button re-renders on theme change.
        _ = themeManager.current
        // The interior is only lightly tinted, so the label effectively sits on the
        // page background — measure legibility against that, not against the fill.
        let accent = Color.readableOnBackground(.appAccent)

        return Button(action: action) {
            Text("Check")
                .font(.system(size: 16, weight: .bold))
                .tracking(0.4)
                .foregroundColor(accent)
                .frame(width: diameter, height: diameter)
                .background(
                    Circle().fill(accent.opacity(isPressed ? 0.18 : 0.08))
                        .overlay(TileTexture(seed: "check", opacity: 0.05, scale: 0.5).clipShape(Circle()))
                )
                .overlay(Circle().strokeBorder(accent, lineWidth: 2))
                // Concentric hairline — the one flourish, and it stays flat.
                .overlay(
                    Circle()
                        .strokeBorder(accent.opacity(0.28), lineWidth: 1)
                        .padding(5)
                )
                .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.14), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Check")
        .accessibilityHint("Reveals the answer")
    }
}

/// Wide action pill in the same ring-over-tint treatment as `CheckButton`, for
/// the primary action on a screen. Theme-coloured by default.
struct AccentActionButton: View {
    let title: String
    var icon: String? = nil
    var color: Color? = nil
    var width: CGFloat? = nil
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        _ = themeManager.current
        let accent = Color.readableOnBackground(color ?? .appAccent)

        return Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .tracking(0.3)
            }
            .foregroundColor(accent)
            .padding(.horizontal, 26)
            .padding(.vertical, 15)
            .frame(width: width)
            .background(
                Capsule().fill(accent.opacity(isPressed ? 0.18 : 0.08))
                    .overlay(TileTexture(seed: title, opacity: 0.05, scale: 0.5).clipShape(Capsule()))
            )
            .overlay(Capsule().strokeBorder(accent, lineWidth: 2))
            .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1).padding(5))
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.14), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// The app's signature tile. Two shapes from one component:
/// `aspect: 1` is the square used in grids; `aspect: nil` is a wide bar.
///
/// They are laid out differently on purpose. The square stacks icon → title at the
/// bottom-left with a huge glyph bleeding off the bottom-right, which only works
/// when the tile is tall. Stretched into a 95pt bar that same arrangement leaves a
/// dead gap under the icon and clips the glyph top *and* bottom, so the bar gets a
/// proper horizontal treatment instead.
struct AestheticTile: View {
    let title: String
    var subtitle: String? = nil
    /// Large watermark character (kana, kanji, or a number).
    var glyph: String? = nil
    /// Optional second watermark, paired with `glyph`. Used to set a level number
    /// beside its kanji numeral.
    var secondaryGlyph: String? = nil
    /// SF Symbol shown in the frosted circle.
    var icon: String? = nil
    let color: Color
    var aspect: CGFloat? = 1
    /// Forces the layout. Left nil, a tile with no aspect ratio uses the bar
    /// arrangement — but a grid tile sized by an explicit height still wants the
    /// square one, so it passes `wide: false`.
    var wide: Bool? = nil
    var titleSize: CGFloat = 20

    private var isBar: Bool { wide ?? (aspect == nil) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.badgeGradient)

            // Texture sits over the gradient but under everything else, so it
            // reads as a surface rather than as decoration.
            TileTexture(seed: title)

            if isBar { barContent } else { squareContent }

            // Soft highlight sweep across the top-left
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.18), .clear],
                                     startPoint: .topLeading, endPoint: .center))
                .allowsHitTesting(false)

            if isBar { barLabels } else { squareLabels }
        }
        .modifier(OptionalAspect(aspect: aspect))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.38), radius: 10, x: 0, y: 5)
    }

    // MARK: - Square

    private var squareContent: some View {
        ZStack {
            if let glyph {
                Text(glyph)
                    .font(.system(size: 92, weight: .black))
                    .foregroundColor(.white.opacity(0.18))
                    .offset(x: 12, y: 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            if let secondaryGlyph {
                Text(secondaryGlyph)
                    .font(.system(size: 46, weight: .black))
                    .foregroundColor(.white.opacity(0.20))
                    .offset(x: -14, y: 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
    }

    private var squareLabels: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.22)))
            }

            Spacer(minLength: 6)

            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.leading)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    // MARK: - Bar

    /// Watermarks sit whole at the trailing edge rather than bleeding off it. A
    /// square is tall enough for a cropped glyph to read as deliberate; in a 95pt
    /// bar the same crop just slices the character through the middle.
    ///
    /// The pair is set at clearly different sizes and well apart — at similar
    /// scale and close together, a kanji numeral beside its digit reads as a
    /// strikethrough (一1 in particular).
    private var barContent: some View {
        HStack(spacing: 18) {
            Spacer(minLength: 0)
            if let secondaryGlyph {
                Text(secondaryGlyph)
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(.white.opacity(0.15))
            }
            if let glyph {
                Text(glyph)
                    .font(.system(size: 66, weight: .black))
                    .foregroundColor(.white.opacity(0.17))
            }
        }
        .padding(.trailing, 20)
        .frame(maxHeight: .infinity)
    }

    private var barLabels: some View {
        HStack(spacing: 13) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.22)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Tile texture

/// A faint geometric weave over a tile's gradient. Four traditional motifs, picked
/// deterministically from the title so a tile always wears the same one but the
/// screen isn't uniform. Drawn in low-alpha white so it works on every theme
/// colour without being tuned per hue.
struct TileTexture: View {
    let seed: String
    /// Dialled down on darker or smaller surfaces so it stays a suggestion.
    var opacity: Double = 0.06
    /// Cell size multiplier. A small control needs a finer weave — at full scale a
    /// 50pt circle only fits two arcs, which reads as stray marks, not a pattern.
    var scale: CGFloat = 1

    private enum Motif: CaseIterable { case seigaiha, asanoha, kikko, rules }

    private var motif: Motif {
        // FNV-ish fold: stable across launches, unlike hashValue.
        var h: UInt64 = 5381
        for b in seed.utf8 { h = (h &* 33) &+ UInt64(b) }
        return Motif.allCases[Int(h % UInt64(Motif.allCases.count))]
    }

    var body: some View {
        Canvas { ctx, size in
            let ink = GraphicsContext.Shading.color(.white.opacity(opacity))
            switch motif {
            case .seigaiha: drawSeigaiha(&ctx, size, ink, scale)
            case .asanoha:  drawAsanoha(&ctx, size, ink, scale)
            case .kikko:    drawKikko(&ctx, size, ink, scale)
            case .rules:    drawRules(&ctx, size, ink, scale)
            }
        }
        .allowsHitTesting(false)
    }

    /// Overlapping concentric arcs — the classic wave.
    private func drawSeigaiha(_ ctx: inout GraphicsContext, _ size: CGSize,
                              _ ink: GraphicsContext.Shading, _ k: CGFloat) {
        let r: CGFloat = 26 * k
        let stepX = r, stepY = r * 0.62
        var row = 0
        var y = -r
        while y < size.height + r {
            var x = (row % 2 == 0) ? -r : -r + stepX / 2
            while x < size.width + r {
                for k in stride(from: r, through: r * 0.34, by: -r * 0.22) {
                    var p = Path()
                    p.addArc(center: CGPoint(x: x, y: y), radius: k,
                             startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                    ctx.stroke(p, with: ink, lineWidth: 1)
                }
                x += stepX
            }
            y += stepY
            row += 1
        }
    }

    /// Hemp leaf — a triangular star lattice.
    private func drawAsanoha(_ ctx: inout GraphicsContext, _ size: CGSize,
                             _ ink: GraphicsContext.Shading, _ k: CGFloat) {
        let s: CGFloat = 24 * k
        let h = s * 0.866
        var p = Path()
        var row = 0
        var y = -h
        while y < size.height + h {
            var x = (row % 2 == 0) ? -s : -s + s / 2
            while x < size.width + s {
                let c = CGPoint(x: x, y: y)
                for i in 0..<6 {
                    let a = Double(i) * Double.pi / 3
                    let tip = CGPoint(x: c.x + CGFloat(cos(a)) * s / 2,
                                      y: c.y + CGFloat(sin(a)) * s / 2)
                    p.move(to: c); p.addLine(to: tip)
                }
                x += s
            }
            y += h
            row += 1
        }
        ctx.stroke(p, with: ink, lineWidth: 0.9)
    }

    /// Tortoise shell — a hexagon grid.
    private func drawKikko(_ ctx: inout GraphicsContext, _ size: CGSize,
                           _ ink: GraphicsContext.Shading, _ k: CGFloat) {
        let r: CGFloat = 15 * k
        let w = r * 1.5, h = r * 1.732
        var p = Path()
        var col = 0
        var x = -r
        while x < size.width + r {
            var y = (col % 2 == 0) ? -h : -h + h / 2
            while y < size.height + h {
                var hex = Path()
                for i in 0..<6 {
                    let a = Double(i) * Double.pi / 3
                    let pt = CGPoint(x: x + CGFloat(cos(a)) * r, y: y + CGFloat(sin(a)) * r)
                    if i == 0 { hex.move(to: pt) } else { hex.addLine(to: pt) }
                }
                hex.closeSubpath()
                p.addPath(hex)
                y += h
            }
            x += w
            col += 1
        }
        ctx.stroke(p, with: ink, lineWidth: 0.9)
    }

    /// Fine diagonal rules, every fourth one doubled.
    private func drawRules(_ ctx: inout GraphicsContext, _ size: CGSize,
                           _ ink: GraphicsContext.Shading, _ k: CGFloat) {
        let gap: CGFloat = 13 * k
        var p = Path()
        var i = 0
        var x = -size.height
        while x < size.width + size.height {
            p.move(to: CGPoint(x: x, y: size.height))
            p.addLine(to: CGPoint(x: x + size.height, y: 0))
            if i % 4 == 0 {
                p.move(to: CGPoint(x: x + 2.5, y: size.height))
                p.addLine(to: CGPoint(x: x + 2.5 + size.height, y: 0))
            }
            x += gap
            i += 1
        }
        ctx.stroke(p, with: ink, lineWidth: 0.9)
    }
}

private struct OptionalAspect: ViewModifier {
    let aspect: CGFloat?
    @ViewBuilder
    func body(content: Content) -> some View {
        if let aspect { content.aspectRatio(aspect, contentMode: .fit) } else { content }
    }
}

// MARK: - Lesson progress

/// How much of a lesson's grammar / vocab / kanji has been checked off.
/// Grammar uses the per-point completion circles; vocab and kanji use their
/// green "checked off" marks (the same ones that retire a card from the decks).
struct ChapterProgress {
    var grammarDone = 0, grammarTotal = 0
    var vocabDone = 0,  vocabTotal = 0
    var kanjiDone = 0,  kanjiTotal = 0

    /// True when every category the chapter actually has is fully checked off.
    /// A chapter with no items at all is not "complete" — there is nothing to finish.
    var isComplete: Bool {
        let present = [(grammarDone, grammarTotal), (vocabDone, vocabTotal), (kanjiDone, kanjiTotal)]
            .filter { $0.1 > 0 }
        return !present.isEmpty && present.allSatisfy { $0.0 == $0.1 }
    }

    static func of(chapterId: String, cardStore: CardStore) -> ChapterProgress {
        var p = ChapterProgress()

        let pointIds = LessonsService.shared.pointIds(for: chapterId)
        p.grammarTotal = LessonsService.shared.pointCount(for: chapterId)
        p.grammarDone = LessonsProgressStore.shared.completedCount(chapterId: chapterId, among: pointIds)

        guard let chapter = LessonsService.shared.loadChapter(chapterId) else { return p }

        let words = chapter.vocab ?? []
        p.vocabTotal = words.count
        p.vocabDone = words.filter { VocabFlashcardsFilter.shared.isExcluded($0.id) }.count

        let kanjiCards = (chapter.kanji ?? []).compactMap { cardStore.kanjiCard(for: $0) }
        p.kanjiTotal = kanjiCards.count
        p.kanjiDone = kanjiCards.filter { cardStore.isKanjiExcluded($0.id) }.count

        return p
    }
}

/// One category's progress: a small label over a filled check when finished,
/// otherwise `done/total`.
struct ProgressBadge: View {
    let label: String
    let done: Int
    let total: Int
    let color: Color

    var body: some View {
        // Nudged if needed so the tint stays legible on every theme background.
        let tint = Color.readableOnBackground(color)
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(0.3)
                .foregroundColor(tint.opacity(0.9))

            // Nothing started yet reads as a bare grey dash — no capsule, so an
            // untouched category recedes instead of advertising a zero.
            if done == 0 {
                Text("–")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.appTextSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .frame(minWidth: 34, minHeight: 21)
            } else {
                Group {
                    if total > 0 && done == total {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                    } else {
                        Text("\(done)/\(total)")
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                    }
                }
                .foregroundColor(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .frame(minWidth: 34, minHeight: 21)
                .background(Capsule().fill(color.opacity(0.16)))
                .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
            }
        }
        .fixedSize()
    }
}

/// Shown in place of the three category badges once a whole chapter is finished.
/// One gold mark instead of three green ones, so a completed chapter is legible
/// at a glance while scanning a list.
struct ChapterCompleteBadge: View {
    /// The same gold the Favorites tile uses — deep enough to carry white.
    private let gold = Color(hex: "CA8A04")

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 17, weight: .black))
            .foregroundColor(Color.contrastingText(on: gold))
            .frame(width: 38, height: 38)
            .background(Circle().fill(gold))
            .overlay(Circle().strokeBorder(gold.opacity(0.35), lineWidth: 2).padding(-3))
            .accessibilityLabel("Chapter complete")
    }
}

// MARK: - Page background

/// The full-screen page background. Renders the theme's vertical gradient (or a
/// flat fill when the theme has no second stop). Use this instead of
/// `AppBackground()` so every screen picks up gradients.
struct AppBackground: View {
    // Observed so the background actually re-renders when the theme changes.
    // Without a dependency this view has no inputs, so SwiftUI memoizes it and
    // the page keeps the previous theme's colours.
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        LinearGradient(colors: [theme.background, theme.backgroundEnd ?? theme.background],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

/// Each main page wears its own paper. The motif says what the page is for,
/// and the ink is the theme accent rotated a fixed amount per page — so the
/// four read as relatives within whichever of the palettes is active, and they
/// all shift together when the theme changes.
enum PagePattern {
    case home, study, textbook, dictionary, games

    /// Thin sparse motifs need more ink than dense ones to read at all.
    var inkWeight: Double {
        switch self {
        case .home:       return 1.0
        case .study:      return 0.65  // seigaiha lays down a lot of line; ease off
        case .textbook:   return 1.7   // hairline rules disappear otherwise
        case .dictionary: return 1.0   // dense grid, already plenty
        case .games:      return 1.0
        }
    }

    /// Degrees around the wheel from the theme accent.
    var hueShift: Double {
        switch self {
        case .home:       return -18    // the root hue everything else orbits
        case .study:      return 0      // the accent itself
        case .textbook:   return 42
        case .dictionary: return -38
        case .games:      return 165    // near-complementary; games should feel apart
        }
    }
}

/// `ignoresSafeArea` only when this is a real page, not a preview swatch.
private struct FullBleed: ViewModifier {
    let active: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if active { content.ignoresSafeArea() } else { content }
    }
}

struct PatternedBackground: View {
    // Outline paths for the home sheet. Built once at a fixed size and scaled
    // per row — recomputing glyph outlines every redraw would be wasteful.
    fileprivate static let stencilBaseSize: CGFloat = 100
    fileprivate static let stencilGlyphs = [
        "あ", "い", "う", "え", "お", "か", "き", "く", "さ", "し", "た", "な",
        "は", "ま", "み", "も", "ら", "り", "ん", "ア", "イ", "カ", "サ", "ナ",
        "ハ", "マ", "ヤ", "ラ", "ン", "日", "月", "山", "川", "本", "語", "字",
        "学", "文", "空", "心", "音", "花", "海", "力", "手", "目",
    ]
    fileprivate static let stencilPaths: [String: Path] = {
        var out: [String: Path] = [:]
        for ch in stencilGlyphs { out[ch] = outlinePath(ch, size: stencilBaseSize) }
        return out
    }()

    /// How wide each outline actually draws at the base size. Japanese glyphs
    /// are nominally full-width, but their ink is not — spacing on the nominal
    /// size is what let the wide ones collide.
    fileprivate static let stencilWidths: [String: CGFloat] = {
        var out: [String: CGFloat] = [:]
        for (ch, path) in stencilPaths { out[ch] = path.boundingRect.width }
        return out
    }()

    /// The glyph's outline as a Path, centred on the origin. CoreText hands back
    /// y-up curves, so they're flipped to match SwiftUI's y-down space.
    private static func outlinePath(_ ch: String, size: CGFloat) -> Path {
        let font = UIFont.systemFont(ofSize: size, weight: .bold)
        let attributed = NSAttributedString(string: ch, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let combined = CGMutablePath()

        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return Path() }
        for run in runs {
            let attrs = CTRunGetAttributes(run) as NSDictionary
            guard let raw = attrs[kCTFontAttributeName as String] else { continue }
            let runFont = raw as! CTFont
            let n = CTRunGetGlyphCount(run)
            guard n > 0 else { continue }
            var glyphs = [CGGlyph](repeating: 0, count: n)
            var positions = [CGPoint](repeating: .zero, count: n)
            CTRunGetGlyphs(run, CFRange(location: 0, length: n), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: n), &positions)
            for i in 0..<n {
                guard let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }
                let move = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                combined.addPath(g, transform: move)
            }
        }

        let bounds = combined.boundingBox
        guard !bounds.isNull, bounds.width > 0 else { return Path() }
        var centre = CGAffineTransform(translationX: -bounds.midX, y: -bounds.midY)
        guard let centred = combined.copy(using: &centre) else { return Path(combined) }
        var flip = CGAffineTransform(scaleX: 1, y: -1)
        guard let flipped = centred.copy(using: &flip) else { return Path(centred) }
        return Path(flipped)
    }

    let page: PagePattern
    /// Render a specific theme rather than the active one — used by the picker.
    var preview: AppTheme?
    /// Shrinks the motif so it still reads at swatch size.
    var motifScale: CGFloat

    @EnvironmentObject private var themeManager: ThemeManager

    init(_ page: PagePattern, preview: AppTheme? = nil, motifScale: CGFloat = 1) {
        self.page = page
        self.preview = preview
        self.motifScale = motifScale
    }

    var body: some View {
        let theme = preview ?? themeManager.current
        let onDark = Color.relativeLuminance(theme.background) < 0.45
        let ink = Color.accent(of: theme).hueShifted(page.hueShift)
        let w = page.inkWeight
        let strong = ink.opacity(min(0.30, (onDark ? 0.20 : 0.14) * w))
        let faint  = ink.opacity(min(0.24, (onDark ? 0.14 : 0.10) * w))

        ZStack {
            // A real page bleeds into the safe area; a swatch must stay in its
            // own bounds. Inlined rather than using AppBackground, which always
            // ignores safe area and always reads the *active* theme.
            let gradient = LinearGradient(
                colors: [theme.background, theme.backgroundEnd ?? theme.background],
                startPoint: .top, endPoint: .bottom)
            if preview == nil { gradient.ignoresSafeArea() } else { gradient }

            Canvas { ctx, size in
                switch page {
                case .home:       drawStencilSheet(ctx, size, ink, onDark)
                case .study:      drawSeigaiha(ctx, size, strong, faint)
                case .textbook:   drawWaveRules(ctx, size, strong, faint)
                case .dictionary: drawPracticeGrid(ctx, size, strong, faint)
                case .games:      drawStarfield(ctx, size, ink, onDark)
                }
            }
            .modifier(FullBleed(active: preview == nil))
            .allowsHitTesting(false)
        }
    }

    // MARK: Motifs

    /// Hollow, stencil-cut characters set in stacked lines on a sheet that
    /// leans away from you: rows bunch together and shrink toward the top, and
    /// open out toward the bottom, so the near edge reads as closer. The whole
    /// sheet is skewed a few degrees off square.
    private func drawStencilSheet(_ ctx: GraphicsContext, _ size: CGSize,
                                  _ ink: Color, _ onDark: Bool) {
        let rows = motifScale < 1 ? 11 : 24
        var seed: UInt64 = 0xA24BAED4963EE407
        func next() -> Double {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Double(seed % 100_000) / 100_000.0
        }

        ctx.drawLayer { sheet in
            // Tilt the whole page a few degrees.
            sheet.translateBy(x: size.width / 2, y: size.height / 2)
            sheet.rotate(by: .degrees(-8))
            sheet.translateBy(x: -size.width / 2, y: -size.height / 2)

            for r in 0..<rows {
                let t = Double(r) / Double(rows - 1)
                // Squaring the step is what creates the recession: rows crowd
                // together far away and open up as they come toward you.
                let depth = pow(t, 1.95)
                let y = -size.height * 0.16 + depth * size.height * 1.34
                let scale = 0.30 + depth * 1.15
                let glyph = 74 * scale * motifScale
                let k = glyph / Self.stencilBaseSize
                // Constant gap between neighbours, with a little extra for the
                // stroke itself, which sits half outside the outline's bounds.
                let gap = glyph * 0.15 + 3.0 * k
                // Nearer rows sit a touch heavier, as if better lit.
                let alpha = (onDark ? 0.085 : 0.062) + depth * (onDark ? 0.105 : 0.078)

                // Compose the row from real ink widths rather than a fixed pitch,
                // so every pair ends up with the same visual space between them.
                var run: [(ch: String, width: CGFloat)] = []
                var total: CGFloat = 0
                let target = size.width * 1.45
                while total < target {
                    let ch = Self.stencilGlyphs[
                        min(Int(next() * Double(Self.stencilGlyphs.count)),
                            Self.stencilGlyphs.count - 1)]
                    let w = (Self.stencilWidths[ch] ?? Self.stencilBaseSize) * k
                    run.append((ch, w))
                    total += w + gap
                }

                var x = size.width / 2 - (total - gap) / 2
                for item in run {
                    if let path = Self.stencilPaths[item.ch] {
                        let centreX = x + item.width / 2
                        sheet.drawLayer { g in
                            g.translateBy(x: centreX, y: y)
                            g.scaleBy(x: k, y: k)
                            // Stroke width lives in path space, so it thickens with
                            // the glyph — which is exactly right for perspective.
                            g.stroke(path, with: .color(ink.opacity(alpha)),
                                     lineWidth: 3.0 / max(motifScale, 0.3))
                        }
                    }
                    x += item.width + gap
                }
            }
        }
    }

    /// 漢字練習帳 — the squared practice paper kanji is drilled on, cross-hair
    /// guides and all. Now the Dictionary's page: looking a word up and writing
    /// it out are two halves of the same habit.
    private func drawPracticeGrid(_ ctx: GraphicsContext, _ size: CGSize,
                                  _ box: Color, _ guideColor: Color) {
        let cell: CGFloat = 46, inset: CGFloat = 4
        let dashed = StrokeStyle(lineWidth: 1, dash: [3, 4])
        var y = -cell
        while y < size.height + cell {
            var x = -cell
            while x < size.width + cell {
                let r = CGRect(x: x + inset, y: y + inset,
                               width: cell - inset * 2, height: cell - inset * 2)
                ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(box), lineWidth: 1)
                var cross = Path()
                cross.move(to: CGPoint(x: r.midX, y: r.minY)); cross.addLine(to: CGPoint(x: r.midX, y: r.maxY))
                cross.move(to: CGPoint(x: r.minX, y: r.midY)); cross.addLine(to: CGPoint(x: r.maxX, y: r.midY))
                ctx.stroke(cross, with: .color(guideColor), style: dashed)
                x += cell
            }
            y += cell
        }
    }

    /// Diagonal rules that break into sound-wave bursts. The displacement is a
    /// function of distance *along* a rule and nothing else, so every line
    /// carries the identical wave — crests land directly alongside their
    /// neighbours' crests instead of drifting out of step.
    private func drawWaveRules(_ ctx: GraphicsContext, _ size: CGSize,
                               _ rule: Color, _ hair: Color) {
        let span = max(size.width, size.height) * 1.7

        /// Quiet for most of a cycle, then a short burst that fades in and out.
        func wave(_ t: CGFloat) -> CGFloat {
            let period: CGFloat = 330
            let phase = t / period - floor(t / period)
            guard phase < 0.45 else { return 0 }
            let u = phase / 0.45
            return sin(u * .pi) * 14 * sin(u * .pi * 4)
        }

        ctx.drawLayer { layer in
            layer.translateBy(x: size.width / 2, y: size.height / 2)
            layer.rotate(by: .degrees(-26))
            layer.translateBy(x: -span / 2, y: -span / 2)

            let column: CGFloat = 40
            var x: CGFloat = 0
            var i = 0
            while x < span {
                var path = Path()
                path.move(to: CGPoint(x: x + wave(0), y: 0))
                var t: CGFloat = 0
                while t <= span {
                    path.addLine(to: CGPoint(x: x + wave(t), y: t))
                    t += 5
                }
                // Every third rule is heavier, so the page has some rhythm.
                layer.stroke(path, with: .color(i % 3 == 0 ? rule : hair),
                             lineWidth: i % 3 == 0 ? 1.4 : 1)
                x += column
                i += 1
            }
        }
    }

    /// 青海波 (seigaiha) — the traditional overlapping wave-crest pattern, drawn
    /// as ranks of concentric half-arcs. Rank after identical rank suits the
    /// Study page, where the work is repetition.
    private func drawSeigaiha(_ ctx: GraphicsContext, _ size: CGSize,
                              _ crest: Color, _ inner: Color) {
        // Larger scales and one fewer band keep it calm at this line density.
        let r: CGFloat = 46
        let stepX = r
        let stepY = r * 0.5
        var y = -r
        var row = 0
        while y < size.height + r {
            var x = -r + (row.isMultiple(of: 2) ? 0 : stepX / 2)
            while x < size.width + r {
                // Three concentric arcs per scale, outermost strongest.
                for band in stride(from: 3, through: 1, by: -1) {
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: x, y: y),
                               radius: r * CGFloat(band) / 3,
                               startAngle: .degrees(180), endAngle: .degrees(360),
                               clockwise: false)
                    ctx.stroke(arc, with: .color(band == 3 ? crest : inner), lineWidth: 1)
                }
                x += stepX
            }
            y += stepY
            row += 1
        }
    }

    /// A starfield, echoing Kanji Invaders. Deterministic from a fixed seed so
    /// it never shimmers between redraws.
    private func drawStarfield(_ ctx: GraphicsContext, _ size: CGSize,
                               _ ink: Color, _ onDark: Bool) {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Double {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Double(seed % 100_000) / 100_000.0
        }
        for _ in 0..<190 {
            let x = next() * Double(size.width)
            let y = next() * Double(size.height)
            let r = 1.1 + next() * 2.4
            let a = (onDark ? 0.22 : 0.16) + next() * (onDark ? 0.40 : 0.28)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                     with: .color(ink.opacity(a)))
        }
    }
}

// MARK: - Confident checkmark pop
//
// Brief green-checkmark animation shown over a flashcard when the user taps
// "Confident" (which also activates that card's checkmark), before the next
// card appears. Insert it into a ZStack gated by a Bool and toggle that Bool
// inside `withAnimation`.

struct ConfidentCheckPop: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.green)
            .font(.system(size: 104, weight: .bold))
            .shadow(color: Color.green.opacity(0.45), radius: 18, x: 0, y: 6)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}

// MARK: - Image Loader

func loadCardImage(path: String) -> UIImage? {
    UIImage(contentsOfFile: path)
}
