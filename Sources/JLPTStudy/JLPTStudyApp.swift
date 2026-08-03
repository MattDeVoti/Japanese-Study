import SwiftUI

@main
struct JLPTStudyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = CardStore()
    @StateObject private var kanjiFilter = KanjiFilter()
    @StateObject private var grammarFilter = GrammarFilter()
    @StateObject private var themeManager = ThemeManager()
    @State private var deepLink: WidgetDeepLink?

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
            .onOpenURL { url in deepLink = WidgetDeepLink(url: url) }
            .sheet(item: $deepLink) { link in
                NavigationStack { WidgetDeepLinkView(link: link) }
                    .environmentObject(store)
                    .environmentObject(kanjiFilter)
                    .environmentObject(grammarFilter)
                    .environmentObject(themeManager)
                    .environment(\.colorScheme, themeManager.current.colorScheme)
                    .preferredColorScheme(themeManager.current.colorScheme)
            }
            .onChange(of: themeManager.current.id) { _ in
                WidgetSnapshotWriter.refreshThemeOnly()
            }
            .onChange(of: scenePhase) { phase in
                // Leaving the app counts as leaving the page.
                if phase != .active { SpeechService.shared.stop() }
                guard phase == .active else { return }
                // A day may have rolled over while the app was backgrounded, and the
                // practice nudge, if the user asked for one, is rewritten for the week.
                SRSStore.shared.rolloverDayIfNeeded()
                NotificationService.shared.refreshAuthorization()
                // Republish what the widgets show, so a new install or new
                // content reaches the home screen without further prompting.
                WidgetSnapshotWriter.refresh(cardStore: store)
            }
        }
    }
}
