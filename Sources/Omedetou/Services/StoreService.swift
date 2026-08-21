import Foundation
import StoreKit

// Talking to the App Store.
//
// Everything StoreKit-shaped lives here and nowhere else. The rest of the app
// asks `Entitlements.isPro`, which reads a tier this file keeps up to date — so
// adding a product, a trial or a second subscription group is a change here and
// in App Store Connect, and in no view.
//
// Three things have to be true for a purchase to be honoured, and each one is a
// separate failure people actually hit:
//
// • The transaction has to be *verified*. An unverified one is discarded rather
//   than trusted; StoreKit signs these, and an unsigned one is either a bug or
//   an attack.
// • It has to be *finished*. An unfinished transaction is replayed on every
//   launch forever, and — worse — Apple keeps refunding it as undelivered.
// • It has to be picked up when it lands *outside* a purchase call: Ask to Buy
//   approvals, a purchase made on another device, a subscription renewing, a
//   refund being granted. That's what `Transaction.updates` is for, and why the
//   listener starts at launch rather than when the paywall opens.

@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        /// Nothing came back. Worth distinguishing from `loaded` with no
        /// products: the first is a network or configuration problem worth
        /// retrying, and the second means the ids don't exist.
        case failed(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var monthly: Product?
    @Published private(set) var yearly: Product?
    @Published private(set) var full: Product?

    /// The id of the product being bought, so its button can show a spinner
    /// while the others go quiet.
    @Published private(set) var purchasing: String?

    /// Set when something went wrong in a way the person should hear about.
    /// A cancelled purchase is not one of those — that was their decision.
    @Published var lastError: String?

    /// True while the App Store is being asked to hand back past purchases.
    @Published private(set) var restoring = false

    /// Whether a first-time subscriber would get an introductory offer. Read
    /// once, when products load, because it takes a round trip.
    @Published private(set) var offersIntroductoryPeriod = false

    /// What this Apple ID currently holds, cached so `Entitlements` — which is
    /// synchronous, and called from view bodies — has something to read.
    /// `nil` means "nothing bought", not "not checked yet"; `hasChecked`
    /// separates those.
    private(set) var entitledTier: Tier?
    private(set) var hasChecked = false

    /// Whether a subscription is still running, *regardless* of what tier the
    /// person ends up on.
    ///
    /// Buying the one-time purchase does not cancel a subscription — Apple has
    /// no mechanism for that, and the app cannot do it either. Someone who
    /// subscribes and later buys outright is billed for both until they cancel,
    /// and the tier alone can't reveal that: it resolves to `.full`, which isn't
    /// a subscription, so the row offering to manage one would vanish at exactly
    /// the moment it matters most.
    @Published private(set) var hasActiveSubscription = false

    private var updates: Task<Void, Never>?

    private init() {}

    // MARK: - Lifecycle

    /// Starts the transaction listener and loads the products. Idempotent, so
    /// it can be called from anywhere that might be the first thing to run.
    func start() {
        guard updates == nil else { return }
        // Before the products load, and before anything is offered for sale: a
        // transaction can arrive at any moment, including at launch, and one
        // that arrives with no listener attached is simply missed.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refreshEntitlements() }
        Task { await loadProducts() }
    }

    // MARK: - Products

    func loadProducts() async {
        state = .loading
        do {
            let products = try await Product.products(for: [StoreKitBridge.ProductID.monthly,
                                                            StoreKitBridge.ProductID.yearly,
                                                            StoreKitBridge.ProductID.full])
            monthly = products.first { $0.id == StoreKitBridge.ProductID.monthly }
            yearly = products.first { $0.id == StoreKitBridge.ProductID.yearly }
            full = products.first { $0.id == StoreKitBridge.ProductID.full }
            // Eligibility is per subscription *group*, so either product answers
            // for both — but only if one of them actually loaded.
            offersIntroductoryPeriod = await (monthly ?? yearly)?.subscription?.isEligibleForIntroOffer ?? false
            state = .loaded
        } catch {
            // Usually no network. Sometimes the products genuinely aren't there
            // yet — a build running against App Store Connect before the
            // products are approved gets an empty list rather than an error, so
            // the paywall checks for that separately.
            state = .failed(error.localizedDescription)
        }
    }

    /// The plans to show, cheapest commitment first, so the list reads as a
    /// ladder rather than in whatever order the App Store answered in.
    var availableProducts: [Product] { [monthly, yearly, full].compactMap { $0 } }

    /// What the yearly plan saves against paying monthly for a year, as a
    /// percentage, or nil if that can't be worked out. Both prices come from the
    /// same storefront in the same currency, so this is a fair comparison.
    var yearlySavingPercent: Int? {
        guard let yearly, let monthly,
              let period = yearly.subscription?.subscriptionPeriod,
              period.unit == .year, period.value == 1 else { return nil }
        let twelveMonths = monthly.price * 12
        guard twelveMonths > 0, yearly.price < twelveMonths else { return nil }
        let saved = (twelveMonths - yearly.price) / twelveMonths * 100
        let percent = Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
        return percent > 0 ? percent : nil
    }

    /// The yearly plan expressed per month, in the storefront's own currency and
    /// format — "$4.17", "€4,17", "¥600" — so the comparison with the monthly
    /// plan can be made without arithmetic.
    ///
    /// Approximate by a fraction of a cent (49.99 ÷ 12 is 4.1658…), which is why
    /// the paywall says "about". The exact sum charged is on the same row.
    var yearlyPerMonth: String? {
        guard let yearly,
              let period = yearly.subscription?.subscriptionPeriod,
              period.unit == .year, period.value == 1 else { return nil }
        return (yearly.price / 12).formatted(yearly.priceFormatStyle)
    }

    // MARK: - Buying

    /// Returns true only if the person now holds something they didn't before.
    /// Cancelling is a false, not an error.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard purchasing == nil else { return false }
        purchasing = product.id
        defer { purchasing = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                return entitledTier != nil
            case .userCancelled:
                return false
            case .pending:
                // Ask to Buy, or a payment method needing action. The purchase
                // may still complete later, which the updates listener catches.
                lastError = "That purchase needs approval before it can go through. "
                    + "You'll get access as soon as it's approved — nothing else to do here."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Hands back anything already paid for on this Apple ID.
    ///
    /// Required for the one-time purchase — someone on a new device has no
    /// other way to get it back — and harmless for the subscription, which
    /// restores itself.
    func restore() async {
        restoring = true
        defer { restoring = false }
        do {
            try await AppStore.sync()
        } catch {
            // A cancelled sign-in sheet throws here too, so this is only worth
            // reporting if nothing turned up either.
            await refreshEntitlements()
            if entitledTier == nil {
                lastError = "Nothing to restore on this Apple ID."
            }
            return
        }
        await refreshEntitlements()
        if entitledTier == nil {
            lastError = "Nothing to restore on this Apple ID."
        }
    }

    // MARK: - Entitlements

    /// Recomputes what's held from what StoreKit currently reports, then tells
    /// `Entitlements` to re-read it.
    ///
    /// Everything flows through here — a purchase, a renewal, a refund, a
    /// restore, a launch — so there is exactly one place that decides what a
    /// set of transactions adds up to.
    func refreshEntitlements() async {
        var tier: Tier?
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // Refunded or cancelled by Apple. Expired subscriptions drop out of
            // `currentEntitlements` on their own, but a revocation can arrive
            // while one is still inside its period.
            guard transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }

            switch transaction.productID {
            case StoreKitBridge.ProductID.full:
                tier = .full
            case StoreKitBridge.ProductID.yearly:
                // Ranked, not first-wins: someone who bought the one-time
                // purchase while a subscription was still running must not be
                // downgraded by whichever transaction comes back second.
                subscribed = true
                if tier != .full { tier = .yearly }
            case StoreKitBridge.ProductID.monthly:
                subscribed = true
                if tier != .full && tier != .yearly { tier = .monthly }
            default:
                break
            }
        }
        entitledTier = tier
        hasActiveSubscription = subscribed
        hasChecked = true
        Entitlements.shared.refresh()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            // Unsigned, or signed by something that isn't Apple. Nothing is
            // granted, and it is deliberately not finished — leaving it
            // outstanding is the safer half of a bad situation.
            return
        }
        await transaction.finish()
        await refreshEntitlements()
    }
}

// MARK: - Where the store is described to people

/// The two links App Review requires on any screen that sells an
/// auto-renewable subscription, kept together so neither can quietly rot.
enum LegalLinks {
    /// The published policy — the same document the About screen paraphrases.
    static let privacy = URL(string: "https://mattdevoti.github.io/Japanese-Study/")!
    /// Apple's standard licence, which applies unless a custom EULA is filed in
    /// App Store Connect. Swap this for that one if a custom EULA ever exists.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

extension Product {
    /// "month" / "year" / "3 days" — whatever this product's period actually
    /// is, rather than a word hard-coded next to a price that comes from the
    /// App Store.
    var periodDescription: String? {
        guard let period = subscription?.subscriptionPeriod else { return nil }
        let unit: String
        switch period.unit {
        case .day:   unit = "day"
        case .week:  unit = "week"
        case .month: unit = "month"
        case .year:  unit = "year"
        @unknown default: return nil
        }
        return period.value == 1 ? unit : "\(period.value) \(unit)s"
    }

    /// The introductory offer written out, for the disclosure the paywall has
    /// to carry when one is running.
    var introductoryDescription: String? {
        guard let offer = subscription?.introductoryOffer else { return nil }
        let length = offer.period.value == 1
            ? "\(offer.period.unit.singular)"
            : "\(offer.period.value) \(offer.period.unit.singular)s"
        switch offer.paymentMode {
        case .freeTrial:    return "\(length) free, then \(displayPrice)"
        case .payAsYouGo:   return "\(offer.displayPrice) per \(offer.period.unit.singular) for \(length), then \(displayPrice)"
        case .payUpFront:   return "\(offer.displayPrice) for the first \(length), then \(displayPrice)"
        default:            return nil
        }
    }
}

private extension Product.SubscriptionPeriod.Unit {
    var singular: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
}
