import SwiftUI
import UIKit

// MARK: - Colors

extension Color {
    static var appBackground: Color { _currentAppTheme.background }
    static var appNavBar:     Color { _currentAppTheme.navBar }
    static var appNavBarText: Color { _currentAppTheme.navBarText }
    // The theme's signature accent (its nav-bar hue) — used for the home title
    // so it always reads as part of the current palette instead of a fixed red.
    static var appAccent:     Color { _currentAppTheme.navBar }
    // Primary text derived from the THEME (not the device appearance), so it
    // always contrasts with the current theme's background regardless of
    // whether the device is in light or dark mode.
    static var appText: Color {
        _currentAppTheme.colorScheme == .dark ? Color(white: 0.96) : Color(white: 0.11)
    }

    /// Near-black or near-white — whichever contrasts better against `background`,
    /// by WCAG relative luminance. Use for text placed directly on a surface whose
    /// exact color you have in hand, so the two can never disagree (light or dark).
    static func contrastingText(on background: Color) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(background).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        let whiteContrast = 1.05 / (luminance + 0.05)
        let blackContrast = (luminance + 0.05) / 0.05
        return whiteContrast >= blackContrast ? Color(white: 0.96) : Color(white: 0.11)
    }

    // Kana level accent colors
    static let hiraganaColor = Color(hex: "DB2777")   // pink
    static let katakanaColor = Color(hex: "7C3AED")   // violet

    // Flashcard-deck accent colors
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
