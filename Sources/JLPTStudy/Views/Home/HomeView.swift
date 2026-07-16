import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showThemePicker = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App title (Japanese + romaji)
                VStack(spacing: 6) {
                    Text("おめでとう")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("Omedetou")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 64)

                // Main navigation buttons
                VStack(spacing: 4) {
                    HomeNavButton(label: "Lessons",    destination: LessonsView())
                    HomeNavButton(label: "Study",      destination: GrammarMenuView())
                    HomeNavButton(label: "Dictionary", destination: DictionaryView())
                }
                .padding(.horizontal, 40)

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
                                .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 36)
            }

            // Paintbrush theme button — top right
            VStack {
                HStack {
                    Spacer()
                    Button { showThemePicker = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color.appText.opacity(0.08))
                                .frame(width: 40, height: 40)
                            Circle()
                                .stroke(Color.appText.opacity(0.18), lineWidth: 1)
                                .frame(width: 40, height: 40)
                            Image(systemName: "paintbrush.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.appText)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 60)
                }
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showThemePicker) {
            ThemePickerSheet()
        }
    }
}

// MARK: - Theme Picker Sheet

struct ThemePickerSheet: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
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
                    // Card body
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.background)
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

private struct HomeNavButton<Destination: View>: View {
    let label: String
    let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            Text(label)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.appText)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .appCard(cornerRadius: 18, elevated: false)
        }
        .buttonStyle(.plain)
    }
}
