import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    // Observed so the locked "???" tile flips to Games the moment one is found.
    @ObservedObject private var unlocks = GameUnlocks.shared
    @State private var showOptions = false
    @State private var showGame = false

    var body: some View {
        ZStack {
            PatternedBackground(.home)

            VStack(spacing: 0) {
                Spacer()

                // App title (Japanese + romaji)
                VStack(spacing: 4) {
                    GlowingTitle {
                        GameUnlocks.shared.unlock(.kanjiInvaders)
                        showGame = true
                    }
                    Text("OMEDETOU")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(6)
                        .foregroundStyle(LinearGradient.appAccentSweep)
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 40)

                // Main navigation — the signature gradient tiles, stacked full-width.
                // (Journey is intentionally not surfaced here for now; JourneyView
                // and its progress store are untouched.)
                // Three full-width slabs normally. Finding a game adds a fourth
                // destination, and the whole stack becomes a 2×2 grid of squares
                // to make room — the new layout is itself part of the reward.
                Group {
                    if unlocks.hasAny {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            HomeNavTile(label: "Textbook", subtitle: "Lessons & chapters", glyph: "本",
                                        icon: "books.vertical.fill", color: .themeTile(0),
                                        square: true) { LessonsView() }
                            HomeNavTile(label: "Study", subtitle: "Drills & flashcards", glyph: "習",
                                        icon: "brain.head.profile", color: .themeTile(3),
                                        square: true) { GrammarMenuView() }
                            HomeNavTile(label: "Dictionary", subtitle: "Look anything up", glyph: "辞",
                                        icon: "magnifyingglass", color: .themeTile(6),
                                        square: true) { DictionaryView() }
                            HomeNavTile(label: "Games", subtitle: "Secrets you've found", glyph: "遊",
                                        icon: "gamecontroller.fill", color: .themeTile(9),
                                        square: true) { GamesMenuView() }
                        }
                    } else {
                        VStack(spacing: 12) {
                            HomeNavTile(label: "Textbook", subtitle: "Lessons & chapters", glyph: "本",
                                        icon: "books.vertical.fill", color: .themeTile(0)) { LessonsView() }
                            HomeNavTile(label: "Study", subtitle: "Drills & flashcards", glyph: "習",
                                        icon: "brain.head.profile", color: .themeTile(3)) { GrammarMenuView() }
                            HomeNavTile(label: "Dictionary", subtitle: "Look anything up", glyph: "辞",
                                        icon: "magnifyingglass", color: .themeTile(6)) { DictionaryView() }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Particles + the three chart shortcuts. All four wear the Check
                // button's treatment — accent ring over a barely-there tint with a
                // concentric hairline — so the row reads as one family.
                // The accent is passed down rather than read inside each button:
                // these views have no other inputs, and SwiftUI would otherwise
                // memoize them and keep the previous theme's colour.
                let chip = Color.readableOnPage(.appAccent)

                NavigationLink {
                    ParticlesView()
                } label: {
                    AccentPill(title: "Particles", accent: chip)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)

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
                .padding(.bottom, 36)
            }

            // Options button — top right (appearance + reset journey)
            VStack {
                HStack {
                    Spacer()
                    Button { showOptions = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color.appText.opacity(0.08))
                                .frame(width: 40, height: 40)
                            Circle()
                                .stroke(Color.appText.opacity(0.18), lineWidth: 1)
                                .frame(width: 40, height: 40)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.appText)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 40)
                    .padding(.top, 10)
                }
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showOptions) {
            HomeOptionsSheet()
        }
        .fullScreenCover(isPresented: $showGame) {
            KanjiInvadersGame()
        }
    }
}

// MARK: - Home options sheet

struct HomeOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var weightSettings = StudyWeightSettings.shared
    @ObservedObject private var unlocks = GameUnlocks.shared
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AppearancePicker()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush.fill")
                    }
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
                        Text("Re-locks every game you've found and returns the home screen to its three tiles. Your study progress and high scores are kept.")
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

    var body: some View {
        ZStack {
            // Matches what's actually behind these buttons — they sit low on the
            // page, where the gradient's second stop is what shows through.
            Color.appBackgroundEnd.opacity(0.66)
            accent.opacity(0.16)
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
            .background(ButtonFill(accent: accent).clipShape(Capsule()))
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
                .background(ButtonFill(accent: accent).clipShape(Circle()))
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
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            if square {
                AestheticTile(title: label, subtitle: subtitle, glyph: glyph,
                              icon: icon, color: color)
            } else {
                // aspect: nil frees the tile from its square ratio; the fixed
                // height gives the wide version, unchanged otherwise.
                AestheticTile(title: label, subtitle: subtitle, glyph: glyph,
                              icon: icon, color: color, aspect: nil)
                    .frame(height: 112)
            }
        }
        .buttonStyle(.plain)
    }
}
