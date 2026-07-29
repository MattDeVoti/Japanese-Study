import Foundation
import SwiftUI

struct AppTheme: Identifiable {
    let id: String
    let displayName: String
    let colorScheme: ColorScheme
    let background: Color
    /// Second stop for the page gradient. When nil the background is flat.
    var backgroundEnd: Color? = nil
    let navBar: Color
    let navBarText: Color
}

extension AppTheme {
    // Backgrounds stay clearly light or clearly dark so the theme-derived text
    // always contrasts (stays readable); nav bars are saturated for a fun pop.
    // `backgroundEnd` adds a vertical gradient — the top colour still drives the
    // derived surface/hairline tokens, so cards keep working everywhere.

    // ── Gradient showpieces ───────────────────────────────────────────────
    static let sunset = AppTheme(id: "sunset", displayName: "Sunset", colorScheme: .light,
        background: Color(hex: "FFE9D6"), backgroundEnd: Color(hex: "FFD6E6"),
        navBar: Color(hex: "E0574F"), navBarText: Color(hex: "FFECE4"))
    static let cottonCandy = AppTheme(id: "cotton_candy", displayName: "Cotton Candy", colorScheme: .light,
        background: Color(hex: "E6F2FF"), backgroundEnd: Color(hex: "FFE4F2"),
        navBar: Color(hex: "C2489B"), navBarText: Color(hex: "FFE6F5"))
    static let lavenderFields = AppTheme(id: "lavender_fields", displayName: "Lavender Fields", colorScheme: .light,
        background: Color(hex: "F0E8FF"), backgroundEnd: Color(hex: "FFE9F4"),
        navBar: Color(hex: "7A4FD0"), navBarText: Color(hex: "F0E8FF"))
    static let oceanBreeze = AppTheme(id: "ocean_breeze", displayName: "Ocean Breeze", colorScheme: .light,
        background: Color(hex: "E4F8FF"), backgroundEnd: Color(hex: "E2EAFF"),
        navBar: Color(hex: "0E7FA8"), navBarText: Color(hex: "DFF6FF"))
    static let peachFuzz = AppTheme(id: "peach_fuzz", displayName: "Peach", colorScheme: .light,
        background: Color(hex: "FFF4E8"), backgroundEnd: Color(hex: "FFDFCB"),
        navBar: Color(hex: "D66A3C"), navBarText: Color(hex: "FFEEE2"))
    static let meadow = AppTheme(id: "meadow", displayName: "Meadow", colorScheme: .light,
        background: Color(hex: "FAFBE6"), backgroundEnd: Color(hex: "DFF4E6"),
        navBar: Color(hex: "3F8F52"), navBarText: Color(hex: "E8FBEE"))
    static let sencha = AppTheme(id: "sencha", displayName: "Sencha", colorScheme: .light,
        background: Color(hex: "EAF6E0"), backgroundEnd: Color(hex: "FBF4DC"),
        navBar: Color(hex: "5E8C2E"), navBarText: Color(hex: "F0FBE2"))
    static let koi = AppTheme(id: "koi", displayName: "Koi Pond", colorScheme: .light,
        background: Color(hex: "E2F5F0"), backgroundEnd: Color(hex: "FFEFE0"),
        navBar: Color(hex: "D95F3E"), navBarText: Color(hex: "FFEBE0"))

    // ── Dark gradients ────────────────────────────────────────────────────
    static let midnightDrift = AppTheme(id: "midnight_drift", displayName: "Midnight Drift", colorScheme: .dark,
        background: Color(hex: "0A1230"), backgroundEnd: Color(hex: "1C0E36"),
        navBar: Color(hex: "3B6FD4"), navBarText: Color(hex: "D8E6FF"))
    static let ember = AppTheme(id: "ember", displayName: "Ember", colorScheme: .dark,
        background: Color(hex: "150A0A"), backgroundEnd: Color(hex: "2E1012"),
        navBar: Color(hex: "D2502A"), navBarText: Color(hex: "FFDFD0"))
    static let aurora = AppTheme(id: "aurora", displayName: "Aurora", colorScheme: .dark,
        background: Color(hex: "04201E"), backgroundEnd: Color(hex: "0E1038"),
        navBar: Color(hex: "17A88A"), navBarText: Color(hex: "CFFFF2"))
    static let vaporwave = AppTheme(id: "vaporwave", displayName: "Vaporwave", colorScheme: .dark,
        background: Color(hex: "1A0A2E"), backgroundEnd: Color(hex: "300A2A"),
        navBar: Color(hex: "E0369B"), navBarText: Color(hex: "FFD9EE"))
    static let forestNight = AppTheme(id: "forest_night", displayName: "Forest Night", colorScheme: .dark,
        background: Color(hex: "0A1A12"), backgroundEnd: Color(hex: "060E18"),
        navBar: Color(hex: "2E8B57"), navBarText: Color(hex: "D6FFE8"))
    static let nebula = AppTheme(id: "nebula", displayName: "Nebula", colorScheme: .dark,
        background: Color(hex: "0D0A2A"), backgroundEnd: Color(hex: "260C38"),
        navBar: Color(hex: "6A45D9"), navBarText: Color(hex: "E2D8FF"))
    static let inkwash = AppTheme(id: "inkwash", displayName: "Sumi Ink", colorScheme: .dark,
        background: Color(hex: "14161A"), backgroundEnd: Color(hex: "1F2429"),
        navBar: Color(hex: "5B6B7A"), navBarText: Color(hex: "E8EEF4"))

    // ── Bright & saturated ────────────────────────────────────────────────
    static let sunburst = AppTheme(id: "sunburst", displayName: "Sunburst", colorScheme: .light,
        background: Color(hex: "FFD500"), backgroundEnd: Color(hex: "FFA62B"),
        navBar: Color(hex: "E8362E"), navBarText: Color(hex: "FFFFFF"))
    static let lime = AppTheme(id: "lime", displayName: "Lime", colorScheme: .light,
        background: Color(hex: "B4EC0A"), backgroundEnd: Color(hex: "5FD98C"),
        navBar: Color(hex: "7A2FE0"), navBarText: Color(hex: "FFFFFF"))
    static let aqua = AppTheme(id: "aqua", displayName: "Aqua", colorScheme: .light,
        background: Color(hex: "15DCE6"), backgroundEnd: Color(hex: "4FA8F0"),
        navBar: Color(hex: "E8195E"), navBarText: Color(hex: "FFFFFF"))
    static let bubblegum = AppTheme(id: "bubblegum", displayName: "Bubblegum", colorScheme: .light,
        background: Color(hex: "FF7EC8"), backgroundEnd: Color(hex: "FFB08A"),
        navBar: Color(hex: "6E2FD8"), navBarText: Color(hex: "FFFFFF"))
    static let electric = AppTheme(id: "electric", displayName: "Electric", colorScheme: .dark,
        background: Color(hex: "1E3AF0"), backgroundEnd: Color(hex: "6A18C8"),
        navBar: Color(hex: "00C2FF"), navBarText: Color(hex: "042038"))
    static let volt = AppTheme(id: "volt", displayName: "Volt", colorScheme: .dark,
        background: Color(hex: "6612E8"), backgroundEnd: Color(hex: "B01274"),
        navBar: Color(hex: "E0157F"), navBarText: Color(hex: "FFE4F2"))

    // ── Soft pastel ───────────────────────────────────────────────────────
    static let sakura = AppTheme(id: "sakura", displayName: "Sakura", colorScheme: .light,
        background: Color(hex: "FFECF2"), navBar: Color(hex: "D63B72"), navBarText: Color(hex: "FFE6EE"))
    static let mahou = AppTheme(id: "mahou", displayName: "Magic", colorScheme: .light,
        background: Color(hex: "FBEAFF"), navBar: Color(hex: "B02AA8"), navBarText: Color(hex: "FFE6FB"))
    static let sora = AppTheme(id: "sora", displayName: "Sky", colorScheme: .light,
        background: Color(hex: "E7F3FF"), navBar: Color(hex: "1E6FD0"), navBarText: Color(hex: "E4F1FF"))
    static let matcha = AppTheme(id: "matcha", displayName: "Matcha", colorScheme: .light,
        background: Color(hex: "ECF6E4"), navBar: Color(hex: "3E8A3A"), navBarText: Color(hex: "EAFFDE"))
    static let mikan = AppTheme(id: "mikan", displayName: "Tangerine", colorScheme: .light,
        background: Color(hex: "FFF1E2"), navBar: Color(hex: "D2600F"), navBarText: Color(hex: "FFEBD9"))
    static let cream = AppTheme(id: "cream", displayName: "Cream", colorScheme: .light,
        background: Color(hex: "FFF7D6"), navBar: Color(hex: "C4881A"), navBarText: Color(hex: "FFF4D8"))
    static let mint = AppTheme(id: "mint", displayName: "Mint", colorScheme: .light,
        background: Color(hex: "E2F7EF"), navBar: Color(hex: "17A386"), navBarText: Color(hex: "E0FFF6"))
    static let fuji = AppTheme(id: "fuji", displayName: "Wisteria", colorScheme: .light,
        background: Color(hex: "ECEBFF"), navBar: Color(hex: "6C5CE0"), navBarText: Color(hex: "EAE6FF"))
    static let coral = AppTheme(id: "coral", displayName: "Coral", colorScheme: .light,
        background: Color(hex: "FFEDE7"), navBar: Color(hex: "D9543C"), navBarText: Color(hex: "FFE8E0"))
    static let grape = AppTheme(id: "grape", displayName: "Grape", colorScheme: .light,
        background: Color(hex: "F3E9FB"), navBar: Color(hex: "8B45BE"), navBarText: Color(hex: "F3E6FF"))

    // ── Cartoony / pop ────────────────────────────────────────────────────
    static let pop = AppTheme(id: "pop", displayName: "Pop", colorScheme: .light,
        background: Color(hex: "FFFBE8"), navBar: Color(hex: "ED3A90"), navBarText: Color(hex: "FFE4F1"))
    static let retro = AppTheme(id: "retro", displayName: "Retro", colorScheme: .light,
        background: Color(hex: "FBEFD8"), backgroundEnd: Color(hex: "F6DCC0"),
        navBar: Color(hex: "D9402A"), navBarText: Color(hex: "FFE8DC"))
    static let suika = AppTheme(id: "suika", displayName: "Watermelon", colorScheme: .light,
        background: Color(hex: "E9FBEE"), backgroundEnd: Color(hex: "FFE4E9"),
        navBar: Color(hex: "E5385A"), navBarText: Color(hex: "FFE2E8"))

    // ── Deep / neon dark ──────────────────────────────────────────────────
    static let neonTokyo = AppTheme(id: "neon_tokyo", displayName: "Neon Tokyo", colorScheme: .dark,
        background: Color(hex: "140A22"), backgroundEnd: Color(hex: "2A0A24"),
        navBar: Color(hex: "C81D6B"), navBarText: Color(hex: "FFD6EC"))
    static let arcade = AppTheme(id: "arcade", displayName: "Arcade", colorScheme: .dark,
        background: Color(hex: "0E0A1C"), backgroundEnd: Color(hex: "1C0E32"),
        navBar: Color(hex: "7C2FF0"), navBarText: Color(hex: "E6DAFF"))
    static let cyber = AppTheme(id: "cyber", displayName: "Cyber", colorScheme: .dark,
        background: Color(hex: "06120E"), backgroundEnd: Color(hex: "071A1E"),
        navBar: Color(hex: "0C7A5A"), navBarText: Color(hex: "C7FFEC"))
    static let deepSea = AppTheme(id: "deep_sea", displayName: "Deep Sea", colorScheme: .dark,
        background: Color(hex: "08142E"), backgroundEnd: Color(hex: "061F30"),
        navBar: Color(hex: "1E56A8"), navBarText: Color(hex: "CFE4FF"))
    static let flame = AppTheme(id: "flame", displayName: "Flame", colorScheme: .dark,
        background: Color(hex: "1C0A08"), navBar: Color(hex: "C43A20"), navBarText: Color(hex: "FFDCC8"))
    static let yozakura = AppTheme(id: "yozakura", displayName: "Night Bloom", colorScheme: .dark,
        background: Color(hex: "180A18"), backgroundEnd: Color(hex: "260C1E"),
        navBar: Color(hex: "A02468"), navBarText: Color(hex: "FFD4EA"))
    static let cosmos = AppTheme(id: "cosmos", displayName: "Cosmos", colorScheme: .dark,
        background: Color(hex: "0C0A24"), navBar: Color(hex: "5232AE"), navBarText: Color(hex: "DDD6FF"))
    static let goldDusk = AppTheme(id: "gold", displayName: "Dusk", colorScheme: .dark,
        background: Color(hex: "17120A"), backgroundEnd: Color(hex: "241A0C"),
        navBar: Color(hex: "B37A1E"), navBarText: Color(hex: "FFEAC6"))

    /// Pinned to the front of the picker, in this order. Everything else keeps
    /// its catalogue order behind them — the sort below is stable, so adding a
    /// theme to `catalogue` needs no change here, and an id that doesn't match
    /// simply isn't pinned rather than dropping the theme.
    private static let pinnedIds = [
        "vaporwave", "aurora", "ember", "volt", "nebula", "sunset",
        "cotton_candy", "bubblegum", "electric", "inkwash", "koi",
        "sunburst", "lime", "aqua", "sakura", "neon_tokyo",
        "pop", "suika", "deep_sea", "gold",
    ]

    static let all: [AppTheme] = {
        let rank = Dictionary(uniqueKeysWithValues: pinnedIds.enumerated().map { ($1, $0) })
        return catalogue.enumerated()
            .sorted { a, b in
                let ra = rank[a.element.id] ?? Int.max
                let rb = rank[b.element.id] ?? Int.max
                return ra == rb ? a.offset < b.offset : ra < rb
            }
            .map(\.element)
    }()

    /// Every theme, grouped by character. Display order comes from `all`.
    private static let catalogue: [AppTheme] = [
        // Gradients
        .sunset, .cottonCandy, .lavenderFields, .oceanBreeze,
        .peachFuzz, .meadow, .sencha, .koi,
        .midnightDrift, .ember, .aurora, .vaporwave, .forestNight, .nebula, .inkwash,
        // Bright & saturated
        .sunburst, .lime, .aqua, .bubblegum, .electric, .volt,
        // Soft pastel
        .sakura, .mahou, .sora, .matcha, .mikan,
        .cream, .mint, .fuji, .coral, .grape,
        // Cartoony / pop
        .pop, .retro, .suika,
        // Deep / neon dark
        .neonTokyo, .arcade, .cyber, .deepSea, .flame, .yozakura, .cosmos, .goldDusk,
    ]

    /// What a brand-new install opens with, before any theme has been chosen.
    static let fallback = AppTheme.neonTokyo
}

// Module-level variable read by Color.appBackground / appNavBar / appNavBarText.
// Updated synchronously by ThemeManager before objectWillChange fires, so views
// always read the correct value during their next render pass.
var _currentAppTheme: AppTheme = .fallback

final class ThemeManager: ObservableObject {
    @Published var current: AppTheme = .fallback {
        didSet {
            _currentAppTheme = current
            UserDefaults.standard.set(current.id, forKey: "selectedThemeId")
        }
    }

    init() {
        if let id = UserDefaults.standard.string(forKey: "selectedThemeId"),
           let saved = AppTheme.all.first(where: { $0.id == id }) {
            current = saved
            _currentAppTheme = saved
        }
    }
}
