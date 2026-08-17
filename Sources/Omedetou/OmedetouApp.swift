import SwiftUI

@main
struct OmedetouApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = CardStore()
    @StateObject private var kanjiFilter = KanjiFilter()
    @StateObject private var grammarFilter = GrammarFilter()
    @StateObject private var themeManager = ThemeManager()
    @State private var deepLink: WidgetDeepLink?
    @ObservedObject private var reminders = NotificationService.shared
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
            // A tapped reminder opens the chapter its test covers. Presented the
            // same way as a widget tap: a sheet over wherever the user already
            // was, rather than rearranging their navigation under them.
            .sheet(item: Binding(get: { reminders.tappedChapterId.map(TappedChapter.init) },
                                 set: { if $0 == nil { reminders.tappedChapterId = nil } })) { tapped in
                NavigationStack {
                    if let summary = LessonsService.shared.chapterSummary(for: tapped.id) {
                        ChapterDetailView(summary: summary,
                                          accentColor: levelAccentColor(
                                            LessonsService.shared.levelId(for: tapped.id) ?? "N5"))
                    }
                }
                .environmentObject(store)
                .environmentObject(kanjiFilter)
                .environmentObject(grammarFilter)
                .environmentObject(themeManager)
                .environment(\.colorScheme, themeManager.current.colorScheme)
                .preferredColorScheme(themeManager.current.colorScheme)
            }
            .task {
                // Settings arrive over the key-value store on their own; progress
                // is pulled once at launch and again whenever the app comes back,
                // which is exactly when you've picked up the other device.
                SettingsSync.shared.start()
                CloudSyncService.shared.syncInBackground()
                NotificationService.shared.registerAsDelegate()
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
                //
                // The exception is a hands-free study run, which exists to be
                // listened to with the screen off. Silencing it here would make
                // the mode useless the moment the phone locked.
                if phase != .active {
                    if !VocalStudySettings.shared.handsFreeRunning {
                        SpeechService.shared.stop()
                    }
                    DictationService.shared.stop()
                    VocalAnswerListener.shared.cancel()
                }
                guard phase == .active else { return }
                // A day may have rolled over while the app was backgrounded, and the
                // practice nudge, if the user asked for one, is rewritten for the week.
                NotificationService.shared.refreshAuthorization()
                // Republish what the widgets show, so a new install or new
                // content reaches the home screen without further prompting.
                WidgetSnapshotWriter.refresh(cardStore: store)
            }
        }
    }
}

/// Wraps the chapter id a tapped reminder resolved to, so it can drive a
/// `sheet(item:)`.
private struct TappedChapter: Identifiable {
    let id: String
}
