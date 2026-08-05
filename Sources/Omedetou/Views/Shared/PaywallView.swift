import SwiftUI

// Shown when someone taps something they don't have yet.
//
// Reached only from `.locked(...)`, which only draws when `Entitlements.isPro` is
// false — so while the beta is open this screen is unreachable. That matters for
// App Review: an app that advertises a subscription it cannot sell gets rejected,
// and this cannot be reached until StoreKitBridge is real.

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    /// What the person was reaching for, so the screen can name it instead of
    /// opening with a price. "Chapter 3 is part of the full course" lands better
    /// than "$4.99/month".
    var feature: String? = nil

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 22) {
                    header

                    VStack(alignment: .leading, spacing: 16) {
                        point("books.vertical.fill", "Every chapter",
                              "All fifty grammar chapters from N5 to N1, plus counters, slang and the reading passages.")
                        point("rectangle.stack.fill", "The full study set",
                              "Vocabulary and kanji flashcards, conjugation drills, custom lessons and the cheat sheets.")
                        point("paintbrush.fill", "Every appearance",
                              "All forty-two themes, light and dark.")
                    }

                    plans
                    freeNote

                    Button("Not now") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 26)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.appAccent)
            Text(feature.map { "\($0) is part of the full course" } ?? "Unlock the full course")
                .font(.system(size: 21, weight: .heavy))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)
            Text("Kana, the first two chapters, the dictionary and the tests stay free forever.")
                .font(.system(size: 13))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private func point(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appAccent)
                .frame(width: 24)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appText)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var plans: some View {
        VStack(spacing: 10) {
            plan(title: "Monthly", price: "$4.99", note: "per month, cancel any time")
            plan(title: "Full access", price: "$99.99", note: "one payment, yours for good")
        }
    }

    private func plan(title: String, price: String, note: String) -> some View {
        // Deliberately not a purchase button yet. StoreKitBridge is a stub and no
        // products exist, so a tappable "Subscribe" here would either do nothing
        // or fail — both worse than saying so plainly.
        VStack(spacing: 3) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(price).font(.system(size: 16, weight: .bold).monospacedDigit())
            }
            .foregroundColor(.appText)
            HStack {
                Text(note).font(.system(size: 12)).foregroundColor(.appTextSecondary)
                Spacer()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.appHairline, lineWidth: 1))
    }

    @ViewBuilder
    private var freeNote: some View {
        if BetaAccess.isMember {
            Label("You were here during the beta, so you already have all of this — permanently, at no charge.",
                  systemImage: "star.fill")
                .font(.system(size: 12.5))
                .foregroundColor(.appAccent)
        } else {
            Text("Purchases aren't available in this build yet.")
                .font(.system(size: 12.5))
                .foregroundColor(.appTextSecondary)
        }
    }
}
