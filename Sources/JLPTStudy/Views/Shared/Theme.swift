import SwiftUI
import UIKit

// MARK: - Colors

extension Color {
    static var appBackground: Color { _currentAppTheme.background }
    static var appNavBar:     Color { _currentAppTheme.navBar }
    static var appNavBarText: Color { _currentAppTheme.navBarText }
    static let appText = Color.primary

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
    default: return nLevelColor(Int(jlptLevel.dropFirst()) ?? 5)
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
            .toolbarBackground(Color.appNavBar, for: .navigationBar)
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
                }, store: store)
            }
    }
}

extension View {
    func withOptions(filter: StudyFilter, store: CardStore, section: CardStore.CardSection, label: String = "") -> some View {
        modifier(OptionsButton(filter: filter, store: store, section: section))
    }
}

// MARK: - Image Loader

func loadCardImage(path: String) -> UIImage? {
    UIImage(contentsOfFile: path)
}
