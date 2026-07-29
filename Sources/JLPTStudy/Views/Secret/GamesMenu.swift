import SwiftUI

// MARK: - The secret games catalogue
//
// Games stay hidden until the player stumbles on them. Once found, a game is
// remembered for good and shows up under the home screen's Games tile — which
// is itself locked ("???") until at least one game has been discovered.

enum SecretGameID: String, CaseIterable, Identifiable {
    case kanjiInvaders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kanjiInvaders: return "Kanji Invaders"
        }
    }
    var subtitle: String {
        switch self {
        case .kanjiInvaders: return "Shoot the falling kanji"
        }
    }
    var glyph: String {
        switch self {
        case .kanjiInvaders: return "侵"
        }
    }
    var icon: String {
        switch self {
        case .kanjiInvaders: return "gamecontroller.fill"
        }
    }
    var color: Color {
        switch self {
        case .kanjiInvaders: return .themeTile(9)
        }
    }
}

/// Which games the player has unlocked. Persisted, so a discovery sticks.
final class GameUnlocks: ObservableObject {
    static let shared = GameUnlocks()

    private let key = "UnlockedSecretGames"
    @Published private(set) var unlocked: Set<String>

    private init() {
        unlocked = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func isUnlocked(_ game: SecretGameID) -> Bool { unlocked.contains(game.rawValue) }

    /// True once anything at all has been found — gates the home screen tile.
    var hasAny: Bool { !unlocked.isEmpty }

    /// Everything found so far, in catalogue order.
    var discovered: [SecretGameID] { SecretGameID.allCases.filter(isUnlocked) }

    /// Re-locks everything, which also returns the home screen to its
    /// three-tile layout. Study data and high scores are untouched.
    func resetAll() {
        guard !unlocked.isEmpty else { return }
        unlocked.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }

    func unlock(_ game: SecretGameID) {
        guard !unlocked.contains(game.rawValue) else { return }
        unlocked.insert(game.rawValue)
        UserDefaults.standard.set(Array(unlocked), forKey: key)
    }
}

// MARK: - Game tile artwork

/// A miniature scene from the game rather than a flat colour tile. It's a
/// composed still, not a live game: everything is hand-placed in relative
/// coordinates so it scales with the tile, and the action sits right-of-centre
/// to leave the bottom-left clear for the label.
private struct GameSceneTile: View {
    let game: SecretGameID

    /// x, y (0…1 of the tile), glyph, colour, size.
    private let foes: [(x: CGFloat, y: CGFloat, ch: String, c: Color, s: CGFloat)] = [
        (0.40, 0.17, "火", .orange, 0.150),
        (0.76, 0.12, "空", .teal, 0.130),
        (0.57, 0.33, "水", Color(hex: "38BDF8"), 0.115),
        (0.26, 0.39, "花", .pink, 0.100),
    ]
    /// Star field — fixed positions so the tile is stable, not noisy.
    private let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, a: Double)] = [
        (0.10, 0.10, 1.6, 0.55), (0.22, 0.40, 1.2, 0.35), (0.40, 0.55, 1.8, 0.6),
        (0.66, 0.44, 1.3, 0.4),  (0.90, 0.12, 1.5, 0.5),  (0.76, 0.60, 1.1, 0.32),
        (0.16, 0.66, 1.4, 0.42), (0.94, 0.50, 1.2, 0.34), (0.55, 0.70, 1.5, 0.3),
        (0.34, 0.84, 1.2, 0.26), (0.68, 0.86, 1.3, 0.28), (0.06, 0.30, 1.2, 0.3),
    ]

    /// Where the ship sits — clear of the title, and everything else points at it.
    private let shipX: CGFloat = 0.76
    private let shipY: CGFloat = 0.55

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Deep space, warmed slightly toward the app's violet.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "160B33"), .black],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height

                ForEach(Array(stars.enumerated()), id: \.offset) { _, s in
                    Circle().fill(.white.opacity(s.a))
                        .frame(width: s.r, height: s.r)
                        .position(x: w * s.x, y: h * s.y)
                }

                ForEach(Array(foes.enumerated()), id: \.offset) { _, f in
                    Text(f.ch)
                        .font(.system(size: w * f.s, weight: .black))
                        .foregroundStyle(LinearGradient(
                            colors: [f.c.lightened(0.30), f.c.darkened(0.14)],
                            startPoint: .top, endPoint: .bottom))
                        .shadow(color: f.c.opacity(0.8), radius: w * 0.03)
                        .position(x: w * f.x, y: h * f.y)
                }

                // Two bolts climbing away from the ship toward the 空 above it.
                ForEach(Array([0.29, 0.40].enumerated()), id: \.offset) { _, y in
                    Capsule()
                        .fill(LinearGradient(colors: [.white, Color(hex: "F43F5E"),
                                                      Color(hex: "F43F5E").opacity(0.1)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.022, height: h * 0.085)
                        .shadow(color: Color(hex: "F43F5E").opacity(0.9), radius: w * 0.02)
                        .position(x: w * shipX, y: h * CGFloat(y))
                }

                // Exhaust, then the ship on top of it.
                Ellipse()
                    .fill(LinearGradient(colors: [.white, Color(hex: "38BDF8"),
                                                  Color(hex: "1D4ED8").opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.045, height: h * 0.10)
                    .shadow(color: Color(hex: "38BDF8").opacity(0.9), radius: w * 0.04)
                    .position(x: w * shipX, y: h * (shipY + 0.085))

                Text("山")
                    .font(.system(size: w * 0.20, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "7C3AED").lightened(0.30),
                                 Color(hex: "7C3AED").darkened(0.14)],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: "7C3AED").opacity(0.95), radius: w * 0.045)
                    .position(x: w * shipX, y: h * shipY)
            }

            // Scrim so the label always reads, whatever is behind it.
            LinearGradient(stops: [
                .init(color: .clear, location: 0.60),
                .init(color: .black.opacity(0.55), location: 0.78),
                .init(color: .black.opacity(0.92), location: 1.0),
            ], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: game.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.22)))

                Spacer(minLength: 6)

                Text(game.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                Text(game.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: game.color.opacity(0.38), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Games menu

struct GamesMenuView: View {
    @ObservedObject private var unlocks = GameUnlocks.shared
    @State private var playing: SecretGameID?

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        ZStack {
            PatternedBackground(.games)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading("Found", subtitle: "Games you've uncovered. There may be more hiding.")

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(unlocks.discovered) { game in
                            Button { playing = game } label: {
                                GameSceneTile(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .standardNavBar("Games")
        .fullScreenCover(item: $playing) { game in
            switch game {
            case .kanjiInvaders: KanjiInvadersGame()
            }
        }
    }
}
