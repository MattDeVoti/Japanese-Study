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
    static let nihon = AppTheme(
        id: "nihon",
        displayName: "日本",
        colorScheme: .light,
        background: Color(hex: "F7F7F2"),
        navBar: Color(hex: "2B2B2B"),
        navBarText: Color(hex: "F7F7F2")
    )
    static let darkNihon = AppTheme(
        id: "dark_nihon",
        displayName: "Dark 日本",
        colorScheme: .dark,
        background: Color(red: 0.11, green: 0.11, blue: 0.12),
        navBar: Color(hex: "2B2B2B"),
        navBarText: Color(hex: "F7F7F2")
    )
    static let sakura = AppTheme(
        id: "sakura",
        displayName: "桜",
        colorScheme: .light,
        background: Color(hex: "FDF0F3"),
        navBar: Color(hex: "7B3055"),
        navBarText: Color(hex: "FFE8F0")
    )
    static let washi = AppTheme(
        id: "washi",
        displayName: "和紙",
        colorScheme: .light,
        background: Color(hex: "FFF8EC"),
        navBar: Color(hex: "6A4830"),
        navBarText: Color(hex: "FFF2E0")
    )
    static let shinya = AppTheme(
        id: "shinya",
        displayName: "深夜",
        colorScheme: .dark,
        background: Color(hex: "0D1117"),
        navBar: Color(hex: "161B27"),
        navBarText: Color(hex: "C5D5FF")
    )
    static let take = AppTheme(
        id: "take",
        displayName: "竹",
        colorScheme: .dark,
        background: Color(hex: "0A1810"),
        navBar: Color(hex: "183020"),
        navBarText: Color(hex: "B0FFD0")
    )

    // ── Inspired themes ───────────────────────────────────────────────────

    // Mt Fuji — icy morning mist, Prussian cobalt nav (Hokusai blue silhouette)
    static let fujisan = AppTheme(
        id: "fujisan",
        displayName: "富士山",
        colorScheme: .light,
        background: Color(hex: "EBF3FA"),
        navBar: Color(hex: "1A3F6A"),
        navBarText: Color(hex: "D8EEFF")
    )
    // Shinto Temple — dark forest earth, vermillion torii-gate nav bar
    static let torii = AppTheme(
        id: "torii",
        displayName: "鳥居",
        colorScheme: .dark,
        background: Color(hex: "100D08"),
        navBar: Color(hex: "8C1F10"),
        navBarText: Color(hex: "FFE0D0")
    )
    // Great Wave — deep Prussian ocean, near-black hull nav, sea-foam text
    static let onami = AppTheme(
        id: "onami",
        displayName: "大波",
        colorScheme: .dark,
        background: Color(hex: "0C1E30"),
        navBar: Color(hex: "06101E"),
        navBarText: Color(hex: "B8D8F8")
    )
    // Night Cherry Blossoms — purple-black night sky, deep lantern-shadow nav, petal-pink text
    static let yozakura = AppTheme(
        id: "yozakura",
        displayName: "夜桜",
        colorScheme: .dark,
        background: Color(hex: "120A18"),
        navBar: Color(hex: "2E0A40"),
        navBarText: Color(hex: "FFB4CE")
    )
    // Tokyo — urban near-black, hot electric-red neon nav bar
    static let tokyo = AppTheme(
        id: "tokyo",
        displayName: "東京",
        colorScheme: .dark,
        background: Color(hex: "0A0812"),
        navBar: Color(hex: "B8002A"),
        navBarText: Color(hex: "FFE0EC")
    )

    static let all: [AppTheme] = [
        .nihon, .darkNihon,
        .fujisan, .torii, .onami, .yozakura, .tokyo,
        .sakura, .washi, .shinya, .take,
    ]
}

// Module-level variable read by Color.appBackground / appNavBar / appNavBarText.
// Updated synchronously by ThemeManager before objectWillChange fires, so views
// always read the correct value during their next render pass.
var _currentAppTheme: AppTheme = .nihon

final class ThemeManager: ObservableObject {
    @Published var current: AppTheme = .nihon {
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
