import SwiftUI

// MARK: - Glowing secret title
//
// The home-screen title. Its letters glow in a hidden order (お→う→と→め→で)
// every ~30s; tapping them in that same order launches the easter-egg game.
// Pure SwiftUI + one timer — no assets.

struct GlowingTitle: View {
    var onUnlock: () -> Void

    private let letters = ["お", "め", "で", "と", "う"]   // indices 0…4
    private let secretOrder = [0, 4, 3, 1, 2]              // お → う → と → め → で

    @State private var glow: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var tapProgress = 0

    private let cycle = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(letters.indices, id: \.self) { i in
                Text(letters[i])
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.red)
                    .brightness(Double(glow[i]) * 0.25)
                    .shadow(color: .red.opacity(Double(glow[i])), radius: glow[i] * 18)
                    .shadow(color: .white.opacity(Double(glow[i]) * 0.6), radius: glow[i] * 5)
                    .contentShape(Rectangle())
                    .onTapGesture { registerTap(i) }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .onReceive(cycle) { _ in playGlow() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { playGlow() }
        }
    }

    /// Sweeps the glow through the secret order — whole sweep ≈ 2.4s.
    private func playGlow() {
        for (step, idx) in secretOrder.enumerated() {
            let start = Double(step) * 0.38
            DispatchQueue.main.asyncAfter(deadline: .now() + start) {
                withAnimation(.easeInOut(duration: 0.35)) { glow[idx] = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeInOut(duration: 0.5)) { glow[idx] = 0 }
                }
            }
        }
    }

    private func registerTap(_ i: Int) {
        if i == secretOrder[tapProgress] {
            tapProgress += 1
            if tapProgress == secretOrder.count {
                tapProgress = 0
                onUnlock()
            }
        } else {
            tapProgress = (i == secretOrder[0]) ? 1 : 0
        }
    }
}

// MARK: - Kanji Invaders (the easter egg)

struct KanjiInvadersGame: View {
    @Environment(\.dismiss) private var dismiss

    // Ten common kanji (no numbers) + the hiragana that spells each reading.
    private static let kanjiSet: [(kanji: String, reading: [String], color: Color)] = [
        ("川", ["か", "わ"],       .cyan),
        ("火", ["ひ"],             .orange),
        ("水", ["み", "ず"],       .blue),
        ("木", ["き"],             .green),
        ("空", ["そ", "ら"],       .teal),
        ("花", ["は", "な"],       .pink),
        ("犬", ["い", "ぬ"],       .brown),
        ("目", ["め"],             .purple),
        ("月", ["つ", "き"],       .yellow),
        ("魚", ["さ", "か", "な"], .mint),
    ]

    private struct Enemy: Identifiable {
        let id = UUID()
        var x: CGFloat; var y: CGFloat; var vx: CGFloat
        let kanji: String; let reading: [String]; let color: Color
    }
    private struct Bullet: Identifiable { let id = UUID(); var x: CGFloat; var y: CGFloat }
    private struct Particle: Identifiable {
        let id = UUID(); var x: CGFloat; var y: CGFloat
        var vx: CGFloat; var vy: CGFloat; let ch: String; var life: Double
    }

    @State private var size: CGSize = .zero
    @State private var shipX: CGFloat = 0
    @State private var dragStartX: CGFloat?
    @State private var bullets: [Bullet] = []
    @State private var enemies: [Enemy] = []
    @State private var particles: [Particle] = []
    @State private var score = 0
    @State private var lives = 3
    @State private var gameOver = false
    @State private var frame = 0

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()

                ForEach(enemies) { e in
                    Text(e.kanji)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(e.color)
                        .position(x: e.x, y: e.y)
                }
                ForEach(bullets) { b in
                    Capsule().fill(Color.red)
                        .frame(width: 3, height: 14)
                        .position(x: b.x, y: b.y)
                }
                ForEach(particles) { p in
                    Text(p.ch)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .opacity(p.life)
                        .position(x: p.x, y: p.y)
                }
                Text("山")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .position(x: shipX, y: geo.size.height - 54)

                // HUD
                HStack {
                    Text("SCORE \(score)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(repeating: "山 ", count: max(0, lives)))
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .frame(width: geo.size.width, alignment: .top)

                // Exit + hint
                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    Spacer()
                    if frame < 200 {
                        Text("slide to move")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.bottom, 6)
                    }
                }
                .padding(18)
                .frame(width: geo.size.width, height: geo.size.height)

                if gameOver {
                    ZStack {
                        Color.black.opacity(0.7).ignoresSafeArea()
                        VStack(spacing: 10) {
                            Text("ゲームオーバー")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                            Text("Score \(score)")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in
                        if dragStartX == nil { dragStartX = shipX }
                        shipX = min(max(24, (dragStartX ?? shipX) + v.translation.width),
                                    geo.size.width - 24)
                    }
                    .onEnded { _ in dragStartX = nil }
            )
            .onAppear { setup(geo.size) }
            .onChange(of: geo.size) { setup($0) }
        }
        .onReceive(tick) { _ in step() }
        .statusBarHidden(true)
    }

    // MARK: Game logic

    /// Runs once, the first time a valid (non-zero) size is available.
    private func setup(_ newSize: CGSize) {
        guard size == .zero, newSize != .zero else { return }
        size = newSize
        shipX = newSize.width / 2
        for _ in 0..<4 { spawnEnemy() }
    }

    private func spawnEnemy() {
        guard size != .zero else { return }
        let pick = Self.kanjiSet.randomElement()!
        // ~2/3 fall straight down from a random point along the top; the rest
        // drift side to side. The straight droppers force the player to move —
        // an idle, centred ship can't clear them on its own.
        let drifts = Int.random(in: 0..<3) == 0
        enemies.append(Enemy(
            x: .random(in: 30...(size.width - 30)),
            y: .random(in: -40 ... 10),
            vx: drifts ? (Bool.random() ? 1.2 : -1.2) : 0,
            kanji: pick.kanji, reading: pick.reading, color: pick.color))
    }

    private func step() {
        guard !gameOver, size != .zero else { return }
        frame += 1
        let seconds = Double(frame) / 60.0
        let speedUp = 1.0 + seconds * 0.015   // kanji gradually speed up over time

        // Auto-fire from the ship (slower still).
        if frame % 20 == 0 { bullets.append(Bullet(x: shipX, y: size.height - 76)) }

        for i in bullets.indices { bullets[i].y -= 9 }
        bullets.removeAll { $0.y < -20 }

        for i in enemies.indices {
            enemies[i].x += enemies[i].vx * speedUp
            if enemies[i].x < 24 || enemies[i].x > size.width - 24 { enemies[i].vx *= -1 }
            enemies[i].y += 0.8 * speedUp
        }
        // Spawn more often as time goes on (75 → 38 frames), and allow more on screen.
        let spawnEvery = max(38, 75 - Int(seconds))
        if frame % spawnEvery == 0 && enemies.count < 10 { spawnEnemy() }

        // Bullet ↔ enemy collisions: the kanji bursts into its hiragana.
        if !bullets.isEmpty && !enemies.isEmpty {
            var deadEnemies = Set<UUID>(), deadBullets = Set<UUID>()
            for e in enemies {
                for b in bullets where !deadBullets.contains(b.id) {
                    if abs(b.x - e.x) < 22 && abs(b.y - e.y) < 24 {
                        deadEnemies.insert(e.id); deadBullets.insert(b.id)
                        score += 10 * e.reading.count
                        for (k, ch) in e.reading.enumerated() {
                            particles.append(Particle(
                                x: e.x + CGFloat(k - e.reading.count / 2) * 8, y: e.y,
                                vx: .random(in: -2.2...2.2), vy: .random(in: -3.5 ... -1),
                                ch: ch, life: 1))
                        }
                        break
                    }
                }
            }
            if !deadBullets.isEmpty { bullets.removeAll { deadBullets.contains($0.id) } }
            if !deadEnemies.isEmpty { enemies.removeAll { deadEnemies.contains($0.id) } }
        }

        // An enemy reaching the ship line costs a life.
        let line = size.height - 54
        let breached = enemies.filter { $0.y >= line }
        if !breached.isEmpty {
            lives -= breached.count
            enemies.removeAll { $0.y >= line }
            if lives <= 0 { lives = 0; endGame() }
        }

        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].vy += 0.14
            particles[i].life -= 0.028
        }
        particles.removeAll { $0.life <= 0 }
    }

    private func endGame() {
        gameOver = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { dismiss() }
    }
}
