import SwiftUI

// Every thirty seconds, a page that's hiding a game gives itself away.
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

    /// One shared heartbeat. Each hint deriving its own 30-second timer would
    /// let them drift apart, and the sequence only reads if they're in step, so
    /// the cadence comes off the wall clock instead.
    private static let beat = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var gap: Double { 0.34 }

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
            .onReceive(Self.beat) { now in
                guard active, Int(now.timeIntervalSince1970) % 30 == 0 else { return }
                flash()
            }
            .onDisappear { lit = false }
    }

    private func flash() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(order) * gap) {
            guard active else { return }
            lit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { lit = false }
        }
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
