import SwiftUI

@main
struct JLPTStudyApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                // A day may have rolled over while the app was backgrounded, and the
                // practice nudge, if the user asked for one, is rewritten for the week.
                SRSStore.shared.rolloverDayIfNeeded()
                NotificationService.shared.refreshAuthorization()
            }
        }
    }
}
