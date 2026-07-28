import SwiftUI
import UIKit

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

    /// An accent colour guaranteed to read against the current page background.
    static func readableOnBackground(_ accent: Color) -> Color {
        readable(accent, on: _currentAppTheme.background)
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

    // Kana level accent colors
    static let hiraganaColor = Color(hex: "DB2777")   // pink
    static let katakanaColor = Color(hex: "7C3AED")   // violet

    // Flashcard-deck / lesson-category accent colors. These three identify the
    // grammar / vocab / kanji categories everywhere: the checkmarks inside a
    // lesson and the progress badges on its row.
    static let grammarColor = Color(hex: "16A34A")    // green
    static let kanjiColor = Color(hex: "1D4ED8")      // blue
    static let vocabColor = Color(hex: "0D9488")      // teal

    // N-level accent colors
    static let n5Color = Color(hex: "2563EB")
    static let n4Color = Color(hex: "16A34A")
    static let n3Color = Color(hex: "D97706")
    static let n2Color = Color(hex: "7C3AED")
    static let n1Color = Color(hex: "DC2626")

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

// Friendly progression names shown to the user instead of JLPT codes:
// N5 → "Level 1", N4 → "Level 2", … N1 → "Level 5"  (Level = 6 − N).

/// The level number (1…5) for a JLPT level int (5…1).
func levelNumber(_ nLevel: Int) -> Int { 6 - nLevel }

/// Full display name for a JLPT level int, e.g. 5 → "Level 1".
func levelName(_ nLevel: Int) -> String { "Level \(levelNumber(nLevel))" }

/// Display name from a JLPT string ("N5" → "Level 1"). Non-JLPT labels
/// (e.g. "Hiragana", "Katakana") pass through unchanged.
func levelName(jlpt: String) -> String {
    guard jlpt.hasPrefix("N"), let n = Int(jlpt.dropFirst()) else { return jlpt }
    return levelName(n)
}

func nLevelColor(_ level: Int) -> Color {
    switch level {
    case 5: return .n5Color
    case 4: return .n4Color
    case 3: return .n3Color
    case 2: return .n2Color
    case 1: return .n1Color
    default: return .gray
    }
}

func levelAccentColor(_ jlptLevel: String) -> Color {
    switch jlptLevel {
    case "Hiragana": return .hiraganaColor
    case "Katakana": return .katakanaColor
    case SlangContent.levelId: return SlangContent.accent
    default: return nLevelColor(Int(jlptLevel.dropFirst()) ?? 5)
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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
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
                        .foregroundColor(.appNavBarText)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appNavBarText)
                }
            }
            .toolbarBackground(LinearGradient.appNavBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func standardNavBar(_ title: String) -> some View {
        modifier(StandardNavBar(title: title))
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
struct SectionHeading: View {
    let title: String
    var size: CGFloat = 20
    init(_ title: String, size: CGFloat = 20) {
        self.title = title
        self.size = size
    }

    var body: some View {
        Text(title)
            .font(.system(size: size, weight: .bold))
            .foregroundColor(.appText)
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
                .background(Circle().fill(accent.opacity(isPressed ? 0.18 : 0.08)))
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

/// The app's signature tile: gradient fill, oversized translucent glyph bleeding
/// off the bottom-right, a frosted icon, and a title/subtitle stack.
/// `aspect` of 1 gives the square Study-menu tile; pass nil for a flexible row.
struct AestheticTile: View {
    let title: String
    var subtitle: String? = nil
    /// Large watermark character (kana, kanji, or a number).
    var glyph: String? = nil
    /// SF Symbol shown in the frosted circle.
    var icon: String? = nil
    let color: Color
    var aspect: CGFloat? = 1
    var titleSize: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.badgeGradient)

            if let glyph {
                Text(glyph)
                    .font(.system(size: 92, weight: .black))
                    .foregroundColor(.white.opacity(0.18))
                    .offset(x: 12, y: 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            // Soft highlight sweep across the top-left
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                     startPoint: .topLeading, endPoint: .center))

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
        }
        .modifier(OptionalAspect(aspect: aspect))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.38), radius: 10, x: 0, y: 5)
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
            .frame(minWidth: 34)
            .background(Capsule().fill(color.opacity(0.16)))
            .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
        }
        .fixedSize()
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
