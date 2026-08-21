import SwiftUI

// Everything that isn't the graded track or the reference material: quick-reference
// charts now, and whatever else earns a place later.
//
// Games live here as the last section and only once one has been found — the
// discovery is the reward, so an empty "Games" row sitting here permanently would
// give away that there is something to find.

struct ExtrasView: View {
    @ObservedObject private var unlocks = GameUnlocks.shared

    var body: some View {
        ZStack {
            KaomojiBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section(header: "Reference") {
                        NavigationLink {
                            CheatSheetListView()
                        } label: {
                            ExtrasRow(
                                title: "Cheat Sheet",
                                subtitle: "Time, dates, counters, keigo — at a glance",
                                icon: "tablecells.fill",
                                tint: .themeTile(0))
                        }
                        .pressable()
                        .locked(true, feature: "The cheat sheets")
                    }

                    if unlocks.hasAny {
                        section(header: "Games") {
                            NavigationLink {
                                GamesMenuView()
                            } label: {
                                ExtrasRow(
                                    title: "Games",
                                    subtitle: gamesSubtitle,
                                    icon: "gamecontroller.fill",
                                    tint: .themeTile(9))
                            }
                            .pressable()
                        }
                    }
                }
                .padding(20)
            }
        }
        .standardNavBar("Extras")
    }

    private var gamesSubtitle: String {
        let n = unlocks.discovered.count
        return n == 1 ? "1 secret found" : "\(n) secrets found"
    }

    private func section<C: View>(header: String,
                                  @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(header)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.appText)
                .padding(.horizontal, 2)
            content()
        }
    }
}

struct ExtrasRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tint.badgeGradient))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.appText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.appTextSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Same chrome as the Study cards and the tiles: a pale surface carrying
        // a wash of the row's own colour, edged in it rather than in a neutral
        // hairline. A plain grey card next to those now looks like a different
        // app's screen.
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.appSurface)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint.opacity(0.14))
                TileTexture(seed: title, opacity: 0.05, ink: tint)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(tint.opacity(0.45), lineWidth: 1))
        .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 4)
    }
}
