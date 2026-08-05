import SwiftUI

@main
struct OmedetouApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = CardStore()
    @StateObject private var kanjiFilter = KanjiFilter()
    @StateObject private var grammarFilter = GrammarFilter()
    @StateObject private var themeManager = ThemeManager()
    @State private var deepLink: WidgetDeepLink?
    @StateObject private var cloud = CloudSyncService.shared

    init() {
        // Before the first view body, so anyone who opens the app during the beta
        // is on the record even if they never reach the welcome sheet.
        BetaAccess.enrolIfNeeded()
    }

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
            .environmentObject(cloud)
            .onOpenURL { url in
                deepLink = WidgetDeepLink(url: url)
            }
            .task {
                // Settings arrive over the key-value store on their own; progress
                // is pulled once at launch and again whenever the app comes back,
                // which is exactly when you've picked up the other device.
                SettingsSync.shared.start()
                CloudSyncService.shared.syncInBackground()
            }
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
                // Picking the other device up is exactly a foreground, and putting
                // this one down is the moment to push what just happened.
                if phase == .active || phase == .background {
                    CloudSyncService.shared.syncInBackground()
                }
                // Leaving the app counts as leaving the page — and a microphone
                // left live behind a backgrounded app is worse than rude.
                if phase != .active {
                    SpeechService.shared.stop()
                    DictationService.shared.stop()
                }
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
