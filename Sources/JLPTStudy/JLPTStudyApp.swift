import SwiftUI

@main
struct JLPTStudyApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var kanjiFilter = KanjiFilter()
    @StateObject private var grammarFilter = GrammarFilter()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environment(\.colorScheme, themeManager.current.colorScheme)
            .preferredColorScheme(themeManager.current.colorScheme)
            .environmentObject(store)
            .environmentObject(kanjiFilter)
            .environmentObject(grammarFilter)
            .environmentObject(themeManager)
        }
    }
}
