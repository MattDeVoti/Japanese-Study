import SwiftUI
import WidgetKit

struct HomeView: View {
    @ObservedObject private var gameUnlocks = GameUnlocks.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showOptions = false
    @State private var showHelp = false
    @State private var showGame = false
    @State private var showWelcome = false

    /// Main tiles are drawn at 85% of their old height to give the screen some air.
    private static let tileScale: CGFloat = 0.85
    private static let rowSpacing: CGFloat = 12

    /// Two rows of tiles fill the same height the three full-width slabs used to,
    /// so the screen keeps its proportions. Slightly wider than tall, which fills
    /// the row better than a square did.
    private var gridTileHeight: CGFloat {
        let slab = (112 * Self.tileScale).rounded()
        return (slab * 3 + Self.rowSpacing * 2 - Self.rowSpacing) / 2
    }

    var body: some View {
        ZStack {
            PatternedBackground(.home)

            VStack(spacing: 0) {
                // Capped, so the title sits a little below the status bar without
                // the whole surplus piling up above it.
                Spacer().frame(maxHeight: 48)

                VStack(spacing: 4) {
                    // No .secretHint here: GlowingTitle already sweeps its own
                    // letters in the secret order, which is the better hint —
                    // it teaches the sequence. A second glow around the whole
                    // word only smothered it.
                    GlowingTitle {
                        GameUnlocks.shared.unlock(.kanjiInvaders)
                        showGame = true
                    }
                    Text("OMEDETOU")
                        .font(.system(size: 16.5, weight: .heavy))
                        .tracking(6.6)
                        .foregroundStyle(LinearGradient.appAccentSweep)
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

                // The only uncapped gap on the screen: spare height collects here,
                // under the title, while the spacers above and below it are capped.
                Spacer(minLength: 24)

                // The graded track is the headline; reviews sit under it as the
                // tool you use to prepare, not as an obligation of their own.
                VStack(spacing: 8) {
                    ExamHomeCard()
                    ReviewHomeCard()
                }
                // Match the tiles exactly. The square grid carries an extra inset,
                // so without this the bars overhang the buttons they sit above.
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Main navigation. Four destinations always, so the 2×2 grid is
                // the permanent layout — Extras is no longer the reward for
                // finding a game, it just holds one.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Self.rowSpacing),
                                    GridItem(.flexible(), spacing: Self.rowSpacing)],
                          spacing: Self.rowSpacing) {
                    HomeNavTile(label: "Textbook", subtitle: "Lessons & chapters", glyph: "本",
                                icon: "books.vertical.fill", color: .themeTile(0),
                                square: true, height: gridTileHeight) { LessonsView() }
                    HomeNavTile(label: "Study", subtitle: "Drills & flashcards", glyph: "習",
                                icon: "brain.head.profile", color: .themeTile(3),
                                square: true, height: gridTileHeight) { GrammarMenuView() }
                    HomeNavTile(label: "Dictionary", subtitle: "Look anything up", glyph: "辞",
                                icon: "magnifyingglass", color: .themeTile(6),
                                square: true, height: gridTileHeight) { DictionaryView() }
                    HomeNavTile(label: "Extras", subtitle: "Cheat sheets & more", glyph: "他",
                                icon: "sparkles", color: .themeTile(9),
                                square: true, height: gridTileHeight) { ExtrasView() }
                }
                .padding(.horizontal, 24)

                Spacer().frame(minHeight: 18, maxHeight: 40)

                // Particles + the three chart shortcuts. All four wear the Check
                // button's treatment — accent ring over a barely-there tint with a
                // concentric hairline — so the row reads as one family.
                // The accent is passed down rather than read inside each button:
                // these views have no other inputs, and SwiftUI would otherwise
                // memoize them and keep the previous theme's colour.
                let chip = Color.readableOnPage(.appAccent)

                HStack(spacing: 24) {
                    NavigationLink {
                        KanaChartView(isHiragana: true)
                    } label: {
                        AccentGlyphButton(glyph: "あ", caption: "Hiragana", accent: chip)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        KanjiListView()
                    } label: {
                        AccentGlyphButton(glyph: "漢", caption: "Kanji", accent: chip)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        KanaChartView(isHiragana: false)
                    } label: {
                        AccentGlyphButton(glyph: "ア", caption: "Katakana", accent: chip)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 18)

                // Help and options ride the Particles line rather than taking a row
                // of their own. The pill is narrow and that row was mostly empty
                // margin, so this costs no height and keeps the two utility buttons
                // out of the kana shortcuts' way.
                HStack(spacing: 0) {
                    Button { showHelp = true } label: {
                        HomeCornerButton(icon: "questionmark", accent: chip)
                            .frame(width: 46, height: 46)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("How to use the app")

                    Spacer(minLength: 12)

                    NavigationLink {
                        ParticlesView()
                    } label: {
                        AccentPill(title: "Particles", accent: chip)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 12)

                    Button { showOptions = true } label: {
                        HomeCornerButton(icon: "gearshape.fill", accent: chip)
                            .frame(width: 46, height: 46)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Options")
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 22)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showOptions) {
            HomeOptionsSheet()
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .fullScreenCover(isPresented: $showGame) {
            KanjiInvadersGame()
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeSheet()
        }
        // Fires again whenever Home is returned to, which is harmless: the sheet
        // marks itself seen as it goes, so the condition is already false by then.
        .onAppear {
            if BetaAccess.shouldShowWelcome { showWelcome = true }
        }
    }
}

/// The two circular corner buttons, so help and options stay identical twins.
/// Same treatment as the Particles pill and the kana glyph buttons — accent fill,
/// double stroke, accent icon. A faint tint of `appText` used to vanish on the
/// darker themes; `readableOnPage` is measured against both ends of the page
/// gradient, so these stay visible whatever the appearance.
private struct HomeCornerButton: View {
    let icon: String
    /// Passed in rather than read inside: a view with no inputs gets memoized and
    /// keeps the previous theme's colour after an appearance change.
    let accent: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(accent)
            .frame(width: 40, height: 40)
            .background(ButtonFill(accent: accent, seed: icon).clipShape(Circle()))
            .overlay(Circle().strokeBorder(accent, lineWidth: 2))
            .overlay(Circle().strokeBorder(accent.opacity(0.28), lineWidth: 1).padding(3))
    }
}

// MARK: - Home options sheet

struct HomeOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var weightSettings = StudyWeightSettings.shared
    @ObservedObject private var unlocks = GameUnlocks.shared
    @ObservedObject private var cloud = CloudSyncService.shared
    @ObservedObject private var speech = SpeechService.shared
    @ObservedObject private var srs = SRSStore.shared
    @ObservedObject private var reminders = NotificationService.shared
    @ObservedObject private var textSize = TextSizeSettings.shared
    @ObservedObject private var exams = ExamStore.shared
    @ObservedObject private var entitlements = Entitlements.shared
    @State private var showResetConfirm = false

    /// Says how the current access was come by, since the tier name alone doesn't
    /// distinguish "you bought this" from "you were here first".
    private var planFootnote: String {
        switch entitlements.source {
        case .beta:
            return "You were using Omedetou during the beta, so you keep full access to everything — permanently, and at no charge. You will never be asked to pay."
        case .purchase:
            return "Thank you for supporting Omedetou. Subscriptions are managed in your Apple ID settings."
        case .none:
            return "Everything is available right now. Some features will need a subscription in a future release."
        }
    }

    /// The platform rate band is non-linear, so describe it rather than showing a
    /// meaningless percentage.
    private var speedLabel: String {
        switch speech.rate {
        case ..<0.25:  return "Very slow"
        case ..<0.42:  return "Slow"
        case ..<0.58:  return "Normal"
        case ..<0.78:  return "Brisk"
        default:       return "Fast"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AppearancePicker()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush.fill")
                    }
                    NavigationLink {
                        BackupView()
                    } label: {
                        Label("Backup & Restore", systemImage: "externaldrive.fill")
                    }
                    NavigationLink {
                        FeedbackView()
                    } label: {
                        Label("Send Feedback", systemImage: "envelope.fill")
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About & Sources", systemImage: "info.circle.fill")
                    }
                }
                Section {
                    HStack {
                        Label("Plan", systemImage: entitlements.isPro ? "star.fill" : "star")
                            .foregroundColor(.appText)
                        Spacer()
                        Text(entitlements.tier.displayName)
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                    }
                } header: {
                    Label("Access", systemImage: "key.fill")
                } footer: {
                    Text(planFootnote)
                }
                Section {
                    HStack {
                        Label("iCloud", systemImage: cloudIcon)
                            .foregroundColor(.appText)
                        Spacer()
                        Text(cloudLabel)
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                    Button {
                        Task { await CloudSyncService.shared.sync() }
                    } label: {
                        Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(cloud.status.isBusy || cloud.status == .unavailable)
                } header: {
                    Label("Sync", systemImage: "icloud")
                } footer: {
                    Text(cloud.status == .unavailable
                         ? "Sync is built in but switched off in this build, because signing the iCloud capability needs a paid Apple Developer account. Everything is saved on this device as usual, and Backup & Restore still moves it between devices."
                         : "Your progress is kept on this device and copied to your own iCloud account, so picking up another iPhone or iPad carries on where you left off. Work done on two devices at once is merged rather than overwritten. Nothing is sent anywhere else, and the app works normally without iCloud.")
                }
                Section {
                    Picker("Priority", selection: $weightSettings.mode) {
                        Text("No Priority").tag(WeightMode.none)
                        Text("Prioritize Needs Work").tag(WeightMode.needsWork)
                    }
                    .pickerStyle(.segmented)

                    if weightSettings.mode == .needsWork {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Priority Level")
                                Spacer()
                                Text("\(Int((weightSettings.strength * 100).rounded()))%")
                                    .foregroundColor(.appTextSecondary)
                            }
                            Slider(value: $weightSettings.strength, in: 0.05...1.0)
                                .tint(.orange)
                        }
                    }
                } header: {
                    Label("Flashcard Priority", systemImage: "rectangle.stack.fill")
                } footer: {
                    Text("Applies to every flashcard deck. No Priority shuffles evenly and hides cards you’ve checked off; Prioritize Needs Work keeps every card in rotation but shows ones you’ve marked “Needs Work” more often.")
                }

                Section {
                    Toggle(isOn: $reminders.isEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Offer me a daily practice round")
                            Text("Off unless you want it")
                                .font(.system(size: 12))
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                    if reminders.isEnabled {
                        DatePicker("Remind me at",
                                   selection: Binding(
                                    get: {
                                        var c = DateComponents()
                                        c.hour = reminders.reminderMinutes / 60
                                        c.minute = reminders.reminderMinutes % 60
                                        return Calendar.current.date(from: c) ?? Date()
                                    },
                                    set: { newValue in
                                        let c = Calendar.current.dateComponents([.hour, .minute],
                                                                               from: newValue)
                                        reminders.reminderMinutes = (c.hour ?? 19) * 60 + (c.minute ?? 0)
                                    }),
                                   displayedComponents: .hourAndMinute)
                        if reminders.authorization == .denied {
                            Text("Notifications are turned off for Omedetou in iOS Settings.")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }

                    if srs.enrolledCount > 0 {
                        HStack {
                            Text("Items in rotation")
                            Spacer()
                            Text("\(srs.enrolledCount)")
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                } header: {
                    Label("Practice", systemImage: "bolt.fill")
                } footer: {
                    Text("A practice round is a handful of cards drawn from the grammar, words and kanji you’ve been getting wrong — the app keeps track quietly and picks for you. Turn the nudge on if a daily prompt helps; it never counts anything at you, and practice is there whenever you want it either way.")
                }

                Section {
                    Picker("New word every", selection: Binding(
                        get: { WidgetShared.refreshMinutes },
                        set: { WidgetShared.setRefreshMinutes($0); WidgetCenter.shared.reloadAllTimelines() }
                    )) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("3 hours").tag(180)
                        Text("6 hours").tag(360)
                        Text("Once a day").tag(1440)
                    }
                } header: {
                    Label("Widgets", systemImage: "square.grid.2x2.fill")
                } footer: {
                    Text("Add the Word of the Moment widget from the home screen, then choose how often it rotates. It mixes kanji example words with vocabulary from your lessons, and tapping it opens that card in the app. iOS decides exactly when a widget refreshes, so this is a target rather than a guarantee.")
                }

                Section {
                    Stepper(value: $exams.intervalDays, in: 1...21) {
                        HStack {
                            Text("Days to finish a test")
                            Spacer()
                            Text("\(exams.intervalDays)")
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                    NavigationLink {
                        ReportCardView()
                    } label: {
                        Label("Report card", systemImage: "list.clipboard.fill")
                    }
                } header: {
                    Label("Tests", systemImage: "graduationcap.fill")
                } footer: {
                    Text("Each test is due this many days after you finish the previous one — so sitting one early moves the next deadline earlier too. Miss a deadline and that test scores 0 until you take it. Each syllabary can also be cleared in one go with its full test.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Japanese text size")
                            Spacer()
                            Text(textSize.label)
                                .foregroundColor(.appTextSecondary)
                        }
                        Slider(value: $textSize.scale, in: TextSizeSettings.range)
                            .tint(.appAccent)
                        FuriganaText(text: "日本語[にほんご]の文字[もじ]の大[おお]きさ",
                                     fontSize: 17, color: .appText)
                            .frame(height: 34 * textSize.scale + 10)
                    }
                } header: {
                    Label("Reading", systemImage: "textformat.size")
                } footer: {
                    Text("Furigana is drawn at about half the size of the text it sits above, so this is the setting that makes readings legible. It applies everywhere Japanese appears.")
                }

                Section {
                    Toggle(isOn: $speech.isEnabled) {
                        Text("Japanese Audio")
                    }
                    if speech.isEnabled && speech.isAvailable {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Speed")
                                Spacer()
                                Text(speedLabel)
                                    .foregroundColor(.appTextSecondary)
                            }
                            Slider(value: $speech.rate, in: 0...1)
                                .tint(.appAccent)
                        }
                        HStack {
                            Text("Voice")
                            Spacer()
                            Text(speech.voiceName)
                                .foregroundColor(.appTextSecondary)
                        }
                        Button {
                            speech.speak("日本語[にほんご]を勉強[べんきょう]しましょう。", id: "options-sample")
                        } label: {
                            Label("Play sample", systemImage: "speaker.wave.2.fill")
                        }
                    }
                } header: {
                    Label("Audio", systemImage: "speaker.wave.2.fill")
                } footer: {
                    if speech.isAvailable {
                        Text("Reads words and example sentences aloud using the system Japanese voice, guided by the app's own furigana so readings are correct in context. For a better voice, add a Japanese Siri voice in Settings ▸ Accessibility ▸ Spoken Content ▸ Voices.")
                    } else {
                        Text("No Japanese voice is installed on this device. Add one in Settings ▸ Accessibility ▸ Spoken Content ▸ Voices ▸ Japanese.")
                    }
                }

                // Only shown once something has actually been found — listing it
                // beforehand would give away that there are games to look for.
                if unlocks.hasAny {
                    Section {
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Label("Reset Games", systemImage: "arrow.counterclockwise")
                        }
                    } footer: {
                        Text("Re-locks every game you've found, and the Games section disappears from Extras until you find one again. Your study progress and high scores are kept.")
                    }
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Reset games?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Re-lock every game", role: .destructive) {
                    unlocks.resetAll()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every game goes back to being hidden, and you'll have to find them again.")
            }
        }
    }
}

private struct AppearancePicker: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(AppTheme.all) { theme in
                    ThemeSwatch(
                        theme: theme,
                        isSelected: theme.id == themeManager.current.id
                    ) {
                        themeManager.current = theme
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A miniature of the actual home screen: the theme's gradient, its stencil
/// pattern, the title and the secondary buttons — every element whose colour
/// the theme actually decides. The four main tiles are deliberately absent;
/// their colours are fixed, so including them told you nothing about the theme
/// and just crowded the preview.
private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        // Everything below is drawn from `theme`, never the active one.
        let accent = Color.accent(of: theme)
        let ink: Color = theme.colorScheme == .dark ? Color(white: 0.96) : Color(white: 0.11)

        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    PatternedBackground(.home, preview: theme, motifScale: 0.42)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        Text("おめでとう")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("OMEDETOU")
                            .font(.system(size: 6, weight: .heavy))
                            .tracking(2.4)
                            .foregroundColor(accent.opacity(0.85))

                        Spacer(minLength: 0)

                        // The secondary buttons, which do take the theme's accent.
                        Text("Particles")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(accent)
                            .padding(.vertical, 3).padding(.horizontal, 10)
                            .background(Capsule().fill(accent.opacity(0.08)))
                            .overlay(Capsule().strokeBorder(accent, lineWidth: 1))

                        HStack(spacing: 8) {
                            ForEach(["あ", "漢", "ア"], id: \.self) { g in
                                Text(g)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(accent)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(accent.opacity(0.08)))
                                    .overlay(Circle().strokeBorder(accent, lineWidth: 1))
                            }
                        }
                        .padding(.top, 6)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)

                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(ink.opacity(isSelected ? 0 : 0.12), lineWidth: 1)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.accentColor)
                                    .background(Circle().fill(Color(uiColor: .systemGroupedBackground)).padding(2))
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(theme.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// The fill behind both button shapes: a scrim of the page's lower gradient
/// stop to hold back the stencil characters, with the accent tint over it.
private struct ButtonFill: View {
    let accent: Color
    /// Varies the weave between the four buttons in the row.
    var seed: String = "fill"

    var body: some View {
        ZStack {
            // Matches what's actually behind these buttons — they sit low on the
            // page, where the gradient's second stop is what shows through.
            Color.appBackgroundEnd.opacity(0.66)
            accent.opacity(0.16)
            TileTexture(seed: seed, opacity: 0.05, scale: 0.45)
        }
    }
}

/// Pill version of the Check button's look.
private struct AccentPill: View {
    let title: String
    let accent: Color
    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(accent)
            .padding(.vertical, 9)
            .padding(.horizontal, 26)
            .background(ButtonFill(accent: accent, seed: title).clipShape(Capsule()))
            .overlay(Capsule().strokeBorder(accent, lineWidth: 2))
            .overlay(Capsule().strokeBorder(accent.opacity(0.28), lineWidth: 1).padding(4))
    }
}

/// Circular version, with its caption underneath.
private struct AccentGlyphButton: View {
    let glyph: String
    let caption: String
    let accent: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(glyph)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 50, height: 50)
                .background(ButtonFill(accent: accent, seed: caption).clipShape(Circle()))
                .overlay(Circle().strokeBorder(accent, lineWidth: 2))
                .overlay(Circle().strokeBorder(accent.opacity(0.28), lineWidth: 1).padding(4))
            Text(caption)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(accent)
        }
    }
}

// MARK: - Home nav button

private struct HomeNavTile<Destination: View>: View {
    let label: String
    let subtitle: String
    let glyph: String
    let icon: String
    let color: Color
    /// Square for the 2×2 grid; otherwise a full-width slab.
    var square: Bool = false
    /// Slab height. Ignored by the square variant, which is sized by the grid.
    var height: CGFloat = 112
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            if square {
                // aspect: nil so the height governs, wide: false so it keeps the
                // square arrangement rather than flipping to the bar layout.
                AestheticTile(title: label, subtitle: subtitle, glyph: glyph,
                              icon: icon, color: color, aspect: nil, wide: false)
                    .frame(height: height)
            } else {
                // aspect: nil frees the tile from its square ratio; the fixed
                // height gives the wide version, unchanged otherwise.
                AestheticTile(title: label, subtitle: subtitle, glyph: glyph,
                              icon: icon, color: color, aspect: nil)
                    .frame(height: height)
            }
        }
        .buttonStyle(.plain)
    }
}
private extension HomeOptionsSheet {
    static let clock: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var cloudIcon: String {
        switch cloud.status {
        case .syncing:            return "arrow.triangle.2.circlepath.icloud"
        case .ok:                 return "checkmark.icloud"
        case .noAccount, .failed: return "exclamationmark.icloud"
        case .unavailable:        return "icloud.slash"
        case .idle:               return "icloud"
        }
    }

    var cloudLabel: String {
        switch cloud.status {
        case .idle:        return "Not synced yet"
        case .syncing:     return "Syncing…"
        case .ok(let at):  return "Synced " + Self.clock.string(from: at)
        case .noAccount:   return "Sign in to iCloud in Settings"
        case .unavailable: return "Not enabled in this build"
        case .failed(let why): return why
        }
    }
}




