import SwiftUI

// A page that's hiding a game gives itself away — shortly after you arrive, and
// every thirty seconds you stay.
//
// The things you have to touch light up one after another, in the order you have
// to touch them — so the hint teaches the sequence, not just the location. Once
// the game behind it has been found the page goes quiet for good.

struct SecretHint: ViewModifier {
    /// False once the game is unlocked — a found secret stops advertising.
    let active: Bool
    /// Position in the sequence, so the glow travels in the right order.
    let order: Int
    var tint: Color = Color(hex: "F2C14E")
    var corner: CGFloat = 10

    @State private var lit = false

    /// Long enough for a push transition to settle before anything lights up.
    private static let leadIn: Double = 1.2
    /// Between one item lighting and the next.
    private static let gap: Double = 0.34
    /// How long a single item stays lit.
    private static let hold: Double = 0.7
    private static let period: Double = 30

    func body(content: Content) -> some View {
        content
            .scaleEffect(lit ? 1.07 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(tint, lineWidth: 2.5)
                    .shadow(color: tint.opacity(0.9), radius: 7)
                    .opacity(lit ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .animation(.easeInOut(duration: 0.32), value: lit)
            // Anchored to the moment the page appeared, not to the wall clock.
            //
            // The cadence used to come off a shared 1s heartbeat gated on
            // `now % 30 == 0`, which does fire — but only ever at :00 and :30.
            // Arriving just after one went by bought a 29-second wait on a page
            // most people glance at for five, so the hint was very nearly
            // invisible. Every item starts its own clock on appear; they're
            // dealt within the same frame, so they stay in step, and each one's
            // period is measured flash-to-flash rather than accumulated.
            //
            // Keyed on `active` so unlocking the game cancels the loop outright.
            .task(id: active) {
                guard active else { return }
                await sleep(Self.leadIn + Double(order) * Self.gap)
                while !Task.isCancelled {
                    lit = true
                    await sleep(Self.hold)
                    lit = false
                    await sleep(Self.period - Self.hold)
                }
            }
            .onDisappear { lit = false }
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

extension View {
    /// `order` is the item's place in the sequence the player has to perform.
    func secretHint(_ active: Bool, order: Int = 0,
                    tint: Color = Color(hex: "F2C14E"),
                    corner: CGFloat = 10) -> some View {
        modifier(SecretHint(active: active, order: order, tint: tint, corner: corner))
    }
}
