import SwiftUI
import StoreKit

// Shown when someone taps something they don't have yet.
//
// Reached only from `.locked(...)`, which only draws when `Entitlements.isPro` is
// false — so a beta member never sees it at all.
//
// Everything with a price on it comes from StoreKit rather than from this file.
// A hard-coded "$4.99" is wrong in every country but one, wrong again the moment
// a price changes in App Store Connect, and wrong a third time if an
// introductory offer is running — and App Review checks exactly that.

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreService.shared

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
                    restoreAndLegal

                    Button("Not now") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 26)
            }
        }
        .task { if store.state == .idle { await store.loadProducts() } }
        // Closing the moment access lands, rather than making someone find the
        // dismiss button to get to the thing they just paid for.
        .onChange(of: Entitlements.shared.isPro) { isPro in
            if isPro { dismiss() }
        }
        .alert("Purchase", isPresented: Binding(get: { store.lastError != nil },
                                                set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
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

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)

        case .failed:
            unavailable("The App Store couldn't be reached.",
                        detail: "Check your connection and try again — nothing has been charged.")

        case .loaded where store.availableProducts.isEmpty:
            // Products fetch fine and come back empty when the ids don't exist
            // yet, or aren't approved. Saying "try again" would be a lie.
            unavailable("Purchases aren't available right now.",
                        detail: "Everything free is still yours to use.")

        case .loaded:
            VStack(spacing: 10) {
                ForEach(store.availableProducts, id: \.id) { product in
                    planButton(product)
                }
                subscriptionTerms
            }
        }
    }

    private func planButton(_ product: Product) -> some View {
        // One plan is picked out, not "every subscription" — with two of them
        // highlighting both says nothing. The yearly is the one worth pointing
        // at: it's the cheapest way to have the whole thing for a year.
        let highlighted = product.id == StoreKitBridge.ProductID.yearly
        let busy = store.purchasing == product.id
        let otherBusy = store.purchasing != nil && !busy

        return Button {
            Task { await store.purchase(product) }
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 8) {
                    Text(planTitle(product))
                        .font(.system(size: 16, weight: .semibold))
                    // Only on the plan it applies to, and only when both prices
                    // are known — a saving worked out against a price that
                    // failed to load would be a made-up number.
                    if highlighted, let saving = store.yearlySavingPercent {
                        Text("SAVE \(saving)%")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.6)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.appAccent))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    if busy {
                        ProgressView()
                    } else {
                        Text(product.displayPrice)
                            .font(.system(size: 16, weight: .bold).monospacedDigit())
                    }
                }
                .foregroundColor(.appText)
                HStack {
                    Text(planNote(product))
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appSurface)
                    // A tint rather than a different surface colour, so the card
                    // still belongs to the set it's sitting in.
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(highlighted ? Color.appAccent.opacity(0.10) : .clear))
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(highlighted ? Color.appAccent.opacity(0.55) : Color.appHairline,
                              lineWidth: highlighted ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .disabled(busy || otherBusy)
        .opacity(otherBusy ? 0.5 : 1)
    }

    /// App Store Connect supplies the display name; these are the fallbacks for
    /// a product whose localisation hasn't been filled in yet, worked out from
    /// what the product *is* rather than assumed.
    private func planTitle(_ product: Product) -> String {
        if !product.displayName.isEmpty { return product.displayName }
        guard let period = product.periodDescription else { return "Full access" }
        switch period {
        case "month": return "Monthly"
        case "year":  return "Yearly"
        default:      return "Every \(period)"
        }
    }

    /// The line under each price. For a subscription this is not decoration —
    /// the period has to be stated next to the price.
    ///
    /// The yearly plan says what it works out to a month, because that is the
    /// comparison someone is actually making and the alternative is asking them
    /// to divide by twelve in their head.
    private func planNote(_ product: Product) -> String {
        if let intro = product.introductoryDescription { return intro }
        if product.id == StoreKitBridge.ProductID.yearly, let perMonth = store.yearlyPerMonth {
            return "about \(perMonth) a month, billed yearly · cancel any time"
        }
        if let period = product.periodDescription {
            return "per \(period), cancel any time"
        }
        return "one payment, yours for good"
    }

    /// The auto-renewal disclosure. Required wherever a subscription is sold,
    /// and it has to say how renewal stops.
    @ViewBuilder
    private var subscriptionTerms: some View {
        if store.monthly != nil || store.yearly != nil {
            Text("A subscription renews automatically until cancelled. "
                 + "Your Apple ID is charged at confirmation, and again at each renewal "
                 + "unless it's turned off at least 24 hours before the period ends. "
                 + "Manage or cancel it any time in Settings ▸ your name ▸ Subscriptions.")
                .font(.system(size: 11))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func unavailable(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appText)
            Text(detail)
                .font(.system(size: 13))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await store.loadProducts() } }
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Restore, terms, privacy

    /// Restoring has to be reachable — the one-time purchase has no other way
    /// back onto a new device — and the two links are what App Review looks for
    /// on any screen selling a subscription.
    private var restoreAndLegal: some View {
        VStack(spacing: 10) {
            Button {
                Task { await store.restore() }
            } label: {
                if store.restoring {
                    ProgressView()
                } else {
                    Text("Restore purchases")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .disabled(store.restoring)

            HStack(spacing: 14) {
                Link("Terms of Use", destination: LegalLinks.terms)
                Text("·").foregroundColor(.appTextSecondary)
                Link("Privacy Policy", destination: LegalLinks.privacy)
            }
            .font(.system(size: 12))
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var freeNote: some View {
        if BetaAccess.isMember {
            Label("You were here during the beta, so you already have all of this — permanently, at no charge.",
                  systemImage: "star.fill")
                .font(.system(size: 12.5))
                .foregroundColor(.appAccent)
        }
    }
}
