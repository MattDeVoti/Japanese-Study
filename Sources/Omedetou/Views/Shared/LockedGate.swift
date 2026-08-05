import SwiftUI

// Puts a lock on something and answers the tap with the paywall.
//
// One modifier for every gated control, so a locked chapter, a locked theme and a
// locked drill all look and behave the same way. Call it with the *reason* the
// thing is locked, not with a tier:
//
//     ChapterRow(...)
//         .locked(!FreeTier.isFree(chapter: id))
//
// `.locked(false)` is free of charge — it returns the content untouched, with no
// overlay, no gesture and no sheet — so it can sit on every row in a list without
// costing anything for the rows that aren't locked.

extension View {
    /// - Parameters:
    ///   - condition: whether this thing is *behind* the paywall at all. The
    ///     modifier decides on its own whether the current user has paid.
    ///   - feature: what to name on the paywall, e.g. "Chapter 3".
    func locked(_ condition: Bool, feature: String? = nil, corner: CGFloat = 14) -> some View {
        modifier(LockedGate(gated: condition, feature: feature, corner: corner))
    }
}

private struct LockedGate: ViewModifier {
    let gated: Bool
    let feature: String?
    let corner: CGFloat

    @ObservedObject private var entitlements = Entitlements.shared
    @State private var showPaywall = false

    /// Gated *and* not paid for. While the beta is open `isPro` is true for
    /// everyone, so this is false everywhere and the app looks exactly as it did.
    private var isLocked: Bool { gated && !entitlements.isPro }

    func body(content: Content) -> some View {
        if isLocked {
            content
                // Kills the underlying control — a locked NavigationLink must not
                // navigate — while the overlay below takes the tap instead.
                .disabled(true)
                .opacity(0.5)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.appAccent))
                        .padding(6)
                        .allowsHitTesting(false)
                }
                .overlay {
                    // A nearly-invisible plate rather than `Color.clear`: a fully
                    // clear view doesn't reliably take a tap on its own.
                    Color.black.opacity(0.001)
                        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                        .onTapGesture { showPaywall = true }
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView(feature: feature)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Locked. Part of the full course.")
        } else {
            content
        }
    }
}
