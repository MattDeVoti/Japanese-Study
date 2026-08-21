import SwiftUI

// MARK: - Motion
//
// One place for the app's movement, so screens feel like they belong to the same
// product rather than each animating however its author felt that day.
//
// The brief was "modern and fresh", and the thing that actually reads as modern
// is restraint: motion that acknowledges a touch and settles content as a screen
// arrives, then gets out of the way. Anything you consciously notice on the
// second viewing is too much — this is scenery, not choreography.
//
// Two ideas, deliberately only two:
//
//   • **Press.** A control dips very slightly under the finger and springs back.
//     It costs nothing, happens on every tap, and is most of why a well-built app
//     feels responsive rather than static.
//   • **Settle.** When a screen appears, its content rises a few points and fades
//     in, each row a beat behind the one above. It gives a page a direction of
//     arrival instead of snapping into place fully formed.
//
//
// ## Reduce Motion
//
// Everything here is routed through `Motion.enabled`, which is false when the
// system's Reduce Motion switch is on. That setting exists for people who get
// motion sickness or vestibular symptoms from animated interfaces, and the app
// had no handling for it at all before this. Views still appear and controls
// still respond — they simply arrive without travelling.
enum Motion {
    /// A screen's content settling in.
    static let settle = Animation.easeOut(duration: 0.34)
    /// A control reacting to a finger.
    static let press = Animation.spring(response: 0.26, dampingFraction: 0.72)

    /// How far content travels as it settles. Small on purpose — this should read
    /// as the page composing itself, not as things flying in.
    static let settleOffset: CGFloat = 8
    /// Gap between one row's entrance and the next.
    static let stagger: Double = 0.035
    /// Rows past this all start together. Without a cap, the twentieth row of a
    /// long chapter list would sit blank for the better part of a second, which
    /// reads as the app being slow rather than considered.
    static let maxStaggered = 7

    static func delay(_ index: Int) -> Double {
        Double(min(max(index, 0), maxStaggered)) * stagger
    }
}

// MARK: - Press

/// The app's standard tap feedback: a slight dip, and a spring back.
///
/// Replaces `.buttonStyle(.plain)` on things that navigate. Plain is the right
/// *look* — the system's default tint and dimming are wrong for these tiles — but
/// it also means a tap produces no acknowledgement whatsoever until the next
/// screen arrives.
struct PressableButtonStyle: ButtonStyle {
    /// How far to dip. Cards can take a touch more than small controls.
    var scale: CGFloat = 0.975
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(Motion.press, value: configuration.isPressed)
            // Clicks on the way down, where a click belongs — waiting for the
            // finger to lift, or for the pushed screen to arrive, puts the sound
            // noticeably behind the tap. `playNavigate` suppresses the second
            // one when the arriving screen sounds its own.
            .onChange(of: configuration.isPressed) { pressed in
                if pressed { FeedbackSounds.shared.playNavigate() }
            }
    }
}

extension View {
    /// Tap feedback for anything that navigates or acts. See `PressableButtonStyle`.
    func pressable(scale: CGFloat = 0.975) -> some View {
        buttonStyle(PressableButtonStyle(scale: scale))
    }
}

// MARK: - Settle

/// Rises and fades its content in when the screen appears.
///
/// **Only for screens that appear without a push.** A navigation push already
/// animates the whole screen in from the right, and fading content on top of
/// that looks broken rather than graceful: mid-slide the content is still
/// part-transparent, so saturated tiles go muddy against the patterned
/// background and anything still waiting its turn in the stagger is simply a
/// blank region of page. Both were tried on the Textbook and chapter screens
/// and both looked worse than the plain push. The push is the entrance; this
/// is for when there isn't one.
///
/// Deliberately one-shot: it runs on first appearance and never again, so
/// scrolling a list doesn't re-animate rows and returning to a screen doesn't
/// replay the entrance. `index` staggers rows down a page.
private struct SettleIn: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : Motion.settleOffset)
            .onAppear {
                guard !shown else { return }
                // Reduce Motion still needs the content *visible* — it only skips
                // the travel, so the view is simply switched on.
                guard !reduceMotion else { shown = true; return }
                withAnimation(Motion.settle.delay(Motion.delay(index))) { shown = true }
            }
    }
}

extension View {
    /// One row of a screen settling into place. Pass its position for the stagger.
    func settleIn(_ index: Int = 0) -> some View {
        modifier(SettleIn(index: index))
    }
}
