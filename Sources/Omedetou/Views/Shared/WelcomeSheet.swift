import SwiftUI

// Shown once, on the very first launch.
//
// Three things, in the order they matter to someone who has just opened an
// unfamiliar app: what state it's in, how to complain about it, and what they get
// for putting up with that. Saying the app is unfinished first is the honest
// order — the free access reads as a thank-you that way round, and as a bribe the
// other.
//
// The third point is a promise while the beta is open, so it is backed by a
// record in BetaAccess rather than by this text alone. Once the beta closes that
// promise stops applying to new arrivals, and the slot says what is free instead
// — the one thing a sheet like this must never do is overstate what someone has.

struct WelcomeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 20) {
                        point("wrench.and.screwdriver.fill", "Still being polished",
                              "Omedetou is in beta. The lessons, readings and tests have all been checked over carefully — but there's a lot of material here, so the odd detail may still need tweaking. If something doesn't match your teacher or textbook, trust them over the app.")

                        point("envelope.fill", "Tell me what's broken",
                              "Tap the gear on the home screen and choose Send Feedback. If a translation looks wrong, or something doesn't work, that's the quickest way to get it fixed.")

                        if BetaAccess.periodIsOpen {
                            point("star.fill", "You're early, so it's yours",
                                  "Some features will cost money later on. Because you're here during the beta, you keep full access to all of them — permanently, at no charge. You will never be asked to pay.")
                        } else {
                            // The same slot, telling the truth to someone who
                            // arrived after the beta: what they have without
                            // paying, said plainly and before they hit a lock.
                            point("star.fill", "Free to start",
                                  "Both kana syllabaries, the first two chapters, the dictionary and the tests are free for good — no account, no time limit. The rest of the course is a subscription, and everything behind it is marked with a lock.")
                        }
                    }

                    startButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
        // Marked on appear, not on dismiss. Waiting for a dismissal means the flag
        // is missed whenever the app dies while the sheet is up — a force-quit, or
        // iOS reaping it after the user switches away for a moment — and the sheet
        // then greets them all over again on the next launch. Nothing is lost by
        // marking it early: enrolment is recorded at launch by BetaAccess, quite
        // separately from this, so the promise doesn't depend on how this closes.
        .onAppear { BetaAccess.markWelcomeSeen() }
    }

    /// Mirrors the home screen's treatment — accent sweep over a tracked, heavy
    /// caption — so the first thing a new user sees already looks like the app.
    private var header: some View {
        VStack(spacing: 6) {
            Text("ようこそ")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(LinearGradient.appAccentSweep)
            Text("WELCOME")
                .font(.system(size: 12.5, weight: .heavy))
                .tracking(5.5)
                .foregroundColor(.appTextSecondary)
        }
        .padding(.top, 8)
    }

    private func point(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.appAccent)
                .frame(width: 26)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appText)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    // Plain Text, so this is the ordinary "wrap, don't truncate"
                    // fix and not the greedy-width trap FuriganaText has.
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var startButton: some View {
        Button { dismiss() } label: {
            Text("Start studying")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appAccent))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}
