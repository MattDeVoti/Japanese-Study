import Foundation
import SwiftUI

struct AppTheme: Identifiable {
    let id: String
    let displayName: String
    let colorScheme: ColorScheme
    let background: Color
    let navBar: Color
    let navBarText: Color
}

extension AppTheme {
    // Backgrounds stay clearly light or clearly dark so the theme-derived text
    // always contrasts (stays readable); nav bars are saturated for a fun pop.

    // ── Bright & saturated ────────────────────────────────────────────────
    // Vivid, high-value backgrounds (dark text) or deep neons (white text).
    static let sunburst = AppTheme(id: "sunburst", displayName: "Sunburst", colorScheme: .light,
        background: Color(hex: "FFD500"), navBar: Color(hex: "E8362E"), navBarText: Color(hex: "FFFFFF"))
    static let lime = AppTheme(id: "lime", displayName: "Lime", colorScheme: .light,
        background: Color(hex: "B4EC0A"), navBar: Color(hex: "7A2FE0"), navBarText: Color(hex: "FFFFFF"))
    static let aqua = AppTheme(id: "aqua", displayName: "Aqua", colorScheme: .light,
        background: Color(hex: "15DCE6"), navBar: Color(hex: "E8195E"), navBarText: Color(hex: "FFFFFF"))
    static let bubblegum = AppTheme(id: "bubblegum", displayName: "Bubblegum", colorScheme: .light,
        background: Color(hex: "FF7EC8"), navBar: Color(hex: "6E2FD8"), navBarText: Color(hex: "FFFFFF"))
    static let electric = AppTheme(id: "electric", displayName: "Electric", colorScheme: .dark,
        background: Color(hex: "1E3AF0"), navBar: Color(hex: "00C2FF"), navBarText: Color(hex: "042038"))
    static let volt = AppTheme(id: "volt", displayName: "Volt", colorScheme: .dark,
        background: Color(hex: "6612E8"), navBar: Color(hex: "E0157F"), navBarText: Color(hex: "FFE4F2"))

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
        background: Color(hex: "FBEFD8"), navBar: Color(hex: "D9402A"), navBarText: Color(hex: "FFE8DC"))
    static let suika = AppTheme(id: "suika", displayName: "Watermelon", colorScheme: .light,
        background: Color(hex: "E9FBEE"), navBar: Color(hex: "E5385A"), navBarText: Color(hex: "FFE2E8"))

    // ── Deep / neon dark ──────────────────────────────────────────────────
    static let neonTokyo = AppTheme(id: "neon_tokyo", displayName: "Neon Tokyo", colorScheme: .dark,
        background: Color(hex: "140A22"), navBar: Color(hex: "C81D6B"), navBarText: Color(hex: "FFD6EC"))
    static let arcade = AppTheme(id: "arcade", displayName: "Arcade", colorScheme: .dark,
        background: Color(hex: "0E0A1C"), navBar: Color(hex: "7C2FF0"), navBarText: Color(hex: "E6DAFF"))
    static let cyber = AppTheme(id: "cyber", displayName: "Cyber", colorScheme: .dark,
        background: Color(hex: "06120E"), navBar: Color(hex: "0C7A5A"), navBarText: Color(hex: "C7FFEC"))
    static let deepSea = AppTheme(id: "deep_sea", displayName: "Deep Sea", colorScheme: .dark,
        background: Color(hex: "08142E"), navBar: Color(hex: "1E56A8"), navBarText: Color(hex: "CFE4FF"))
    static let flame = AppTheme(id: "flame", displayName: "Flame", colorScheme: .dark,
        background: Color(hex: "1C0A08"), navBar: Color(hex: "C43A20"), navBarText: Color(hex: "FFDCC8"))
    static let yozakura = AppTheme(id: "yozakura", displayName: "Night Bloom", colorScheme: .dark,
        background: Color(hex: "180A18"), navBar: Color(hex: "A02468"), navBarText: Color(hex: "FFD4EA"))
    static let cosmos = AppTheme(id: "cosmos", displayName: "Cosmos", colorScheme: .dark,
        background: Color(hex: "0C0A24"), navBar: Color(hex: "5232AE"), navBarText: Color(hex: "DDD6FF"))
    static let goldDusk = AppTheme(id: "gold", displayName: "Dusk", colorScheme: .dark,
        background: Color(hex: "17120A"), navBar: Color(hex: "B37A1E"), navBarText: Color(hex: "FFEAC6"))

    static let all: [AppTheme] = [
        .sunburst, .lime, .aqua, .bubblegum, .electric, .volt,
        .sakura, .mahou, .sora, .matcha, .mikan,
        .cream, .mint, .fuji, .coral, .grape,
        .pop, .retro, .suika,
        .neonTokyo, .arcade, .cyber, .deepSea, .flame, .yozakura, .cosmos, .goldDusk,
    ]

    static let fallback = AppTheme.sakura
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
