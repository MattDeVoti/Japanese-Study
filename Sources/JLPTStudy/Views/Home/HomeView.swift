import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    // Observed so the locked "???" tile flips to Games the moment one is found.
    @ObservedObject private var unlocks = GameUnlocks.shared
    @State private var showOptions = false
    @State private var showGame = false

    var body: some View {
        ZStack {
            AppBackground()

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
                                        icon: "books.vertical.fill", color: Color(hex: "DC2626"),
                                        square: true) { LessonsView() }
                            HomeNavTile(label: "Study", subtitle: "Drills & flashcards", glyph: "習",
                                        icon: "brain.head.profile", color: Color(hex: "2563EB"),
                                        square: true) { GrammarMenuView() }
                            HomeNavTile(label: "Dictionary", subtitle: "Look anything up", glyph: "辞",
                                        icon: "magnifyingglass", color: Color(hex: "7C3AED"),
                                        square: true) { DictionaryView() }
                            HomeNavTile(label: "Games", subtitle: "Secrets you've found", glyph: "遊",
                                        icon: "gamecontroller.fill", color: Color(hex: "4C1D95"),
                                        square: true) { GamesMenuView() }
                        }
                    } else {
                        VStack(spacing: 12) {
                            HomeNavTile(label: "Textbook", subtitle: "Lessons & chapters", glyph: "本",
                                        icon: "books.vertical.fill", color: Color(hex: "DC2626")) { LessonsView() }
                            HomeNavTile(label: "Study", subtitle: "Drills & flashcards", glyph: "習",
                                        icon: "brain.head.profile", color: Color(hex: "2563EB")) { GrammarMenuView() }
                            HomeNavTile(label: "Dictionary", subtitle: "Look anything up", glyph: "辞",
                                        icon: "magnifyingglass", color: Color(hex: "7C3AED")) { DictionaryView() }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Particles row
                NavigationLink {
                    ParticlesView()
                } label: {
                    Text("Particles")
                        .font(.system(size: 15))
                        .foregroundColor(.appText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(Capsule().fill(Color.appSurfaceHigh))
                        .overlay(Capsule().strokeBorder(Color.appHairline, lineWidth: 1))
                }
                .padding(.bottom, 16)

                // Bottom row: Hiragana ○ · Kanji ○ · Katakana ○
                HStack(spacing: 24) {
                    NavigationLink {
                        KanaChartView(isHiragana: true)
                    } label: {
                        VStack(spacing: 5) {
                            Text("あ")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.appText)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.appSurfaceHigh))
                                .overlay(Circle().strokeBorder(Color.appHairline, lineWidth: 1))
                                .shadow(color: Color.appCardShadow, radius: 4, x: 0, y: 2)
                            Text("Hiragana")
                                .font(.system(size: 10))
                                .foregroundColor(.appTextSecondary)
                        }
                    }

                    NavigationLink {
                        KanjiListView()
                    } label: {
                        VStack(spacing: 5) {
                            Text("漢")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.appText)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.appSurfaceHigh))
                                .overlay(Circle().strokeBorder(Color.appHairline, lineWidth: 1))
                                .shadow(color: Color.appCardShadow, radius: 4, x: 0, y: 2)
                            Text("Kanji")
                                .font(.system(size: 10))
                                .foregroundColor(.appTextSecondary)
                        }
                    }

                    NavigationLink {
                        KanaChartView(isHiragana: false)
                    } label: {
                        VStack(spacing: 5) {
                            Text("ア")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.appText)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.appSurfaceHigh))
                                .overlay(Circle().strokeBorder(Color.appHairline, lineWidth: 1))
                                .shadow(color: Color.appCardShadow, radius: 4, x: 0, y: 2)
                            Text("Katakana")
                                .font(.system(size: 10))
                                .foregroundColor(.appTextSecondary)
                        }
                    }
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

private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    // Card body — previews the theme's gradient (or flat fill)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [theme.background, theme.backgroundEnd ?? theme.background],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: 100)

                    // Nav bar strip at top
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(theme.navBar)
                            .frame(height: 22)
                            .overlay(alignment: .leading) {
                                // Simulated nav bar text pill
                                Capsule()
                                    .fill(theme.navBarText.opacity(0.5))
                                    .frame(width: 36, height: 6)
                                    .padding(.leading, 10)
                            }
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Simulated content lines
                    VStack(alignment: .leading, spacing: 5) {
                        Spacer().frame(height: 32)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colorScheme == .dark
                                  ? Color.white.opacity(0.22)
                                  : Color.black.opacity(0.13))
                            .frame(width: 60, height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colorScheme == .dark
                                  ? Color.white.opacity(0.13)
                                  : Color.black.opacity(0.08))
                            .frame(width: 44, height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.colorScheme == .dark
                                  ? Color.white.opacity(0.09)
                                  : Color.black.opacity(0.06))
                            .frame(width: 52, height: 5)
                        Spacer()
                    }
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Always-visible card border so dark themes don't blend into sheet bg
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.1), lineWidth: 1)

                    // Selection ring
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.accentColor)
                                    .background(
                                        Circle()
                                            .fill(Color(uiColor: .systemGroupedBackground))
                                            .padding(2)
                                    )
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }

                Text(theme.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
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
