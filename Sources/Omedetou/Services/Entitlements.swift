import SwiftUI

// MARK: - What someone is entitled to
//
// Three tiers, established now rather than later. The point of writing this
// before anything is for sale is grandfathering: beta users have to resolve to
// full access on the day the paywall lands, and that only works if the tier they
// hold is already a real thing the app can read. Retrofitting it afterwards means
// guessing who was here first, which is exactly the guess that can't be made.
//
// The beta is closed and the paid tiers are live, so this now decides real
// access. The order in `refresh()` is the whole safety argument: beta membership
// is checked before any purchase and can never be overridden by one, so nobody
// who was here early can be dropped behind a paywall by an expired subscription
// or a StoreKit hiccup.

enum Tier: String {
    /// The default for new arrivals now that the beta has closed.
    case free
    /// Auto-renewing, billed monthly.
    case monthly
    /// Auto-renewing, billed yearly. Same subscription group as `monthly`, so
    /// someone moving between the two is switching plans rather than holding
    /// both — App Store Connect handles the proration.
    case yearly
    /// The one-time purchase — "lifetime", though that word is best kept off the
    /// storefront (Apple reads it as a promise the app will outlive itself).
    case full

    /// Every paid tier unlocks exactly the same features; they differ in how they
    /// are paid for, not in what they give. Keeping that in one property means a
    /// future decision to split them is a change here and nowhere else.
    var unlocksEverything: Bool {
        switch self {
        case .free:                       return false
        case .monthly, .yearly, .full:    return true
        }
    }

    /// Whether this renews. Only a renewing plan has anything to manage or
    /// cancel, which is what the Options row keys off.
    var isSubscription: Bool {
        switch self {
        case .monthly, .yearly:  return true
        case .free, .full:       return false
        }
    }

    var displayName: String {
        switch self {
        case .free:     return "Free"
        case .monthly:  return "Monthly"
        case .yearly:   return "Yearly"
        case .full:     return "Full access"
        }
    }
}

/// How the current tier was arrived at. Not used for access decisions — `Tier`
/// alone settles those — but it's what lets the UI say "thanks for being early"
/// to one person and "manage your subscription" to another.
enum EntitlementSource: String {
    case none
    /// Enrolled during the beta. Permanent, free, never charged.
    case beta
    /// Bought through the App Store.
    case purchase
}

// MARK: - Store

@MainActor
final class Entitlements: ObservableObject {
    static let shared = Entitlements()

    @Published private(set) var tier: Tier = .free
    @Published private(set) var source: EntitlementSource = .none

#if DEBUG
    /// Developer switch: behave as though this account has paid for nothing, so
    /// the locks and the paywall can actually be exercised.
    ///
    /// Without it there is no way to see them. Everyone who opens the app during
    /// the beta is enrolled by `BetaAccess`, deleting the app just re-enrols on
    /// the next launch, and editing `periodIsOpen` doesn't help either — an
    /// existing `BetaMember` flag survives it.
    ///
    /// `#if DEBUG` by construction: the property, the check in `refresh()` and
    /// the toggle in Options all vanish from a Release build, so this cannot
    /// reach the App Store even if someone leaves it switched on.
    @Published var debugForceFree: Bool = UserDefaults.standard.bool(forKey: "DebugForceFree") {
        didSet {
            UserDefaults.standard.set(debugForceFree, forKey: "DebugForceFree")
            refresh()
        }
    }
#endif

    /// The one gate the rest of the app should ask. Features check this, never a
    /// tier or a product id — otherwise every new way of paying means hunting
    /// down every `if` in the codebase.
    var isPro: Bool { tier.unlocksEverything }

    private init() { refresh() }

    /// Works out what this person currently holds. Cheap, synchronous and safe to
    /// call as often as you like — at launch, when a purchase finishes, or when
    /// iCloud hands over a `BetaMember` flag from another device.
    func refresh() {
#if DEBUG
        // Checked before everything else, including the beta, so the switch works
        // for the developer — who is necessarily a beta member.
        if debugForceFree {
            set(.free, from: .none)
            return
        }
#endif
        // While the beta is open, nothing is for sale — so nothing may be locked,
        // whatever else is or isn't recorded. This is deliberately independent of
        // the BetaMember flag: if that write ever failed, the flag-based path
        // below would drop the person to `.free` and strand them behind a paywall
        // with nothing to buy. Now that the beta has closed this is false, and
        // the flag below is what carries early users.
        if BetaAccess.periodIsOpen {
            set(.full, from: .beta)
            return
        }

        // Beta first, and unconditionally. An early user who later subscribes
        // anyway should still never be billed on the strength of this app's
        // checks, and an expired subscription must not drop them to free.
        if BetaAccess.isMember {
            set(.full, from: .beta)
            return
        }

        if let purchased = StoreKitBridge.purchasedTier() {
            set(purchased, from: .purchase)
            return
        }

        set(.free, from: .none)
    }

    private func set(_ newTier: Tier, from newSource: EntitlementSource) {
        guard newTier != tier || newSource != source else { return }
        tier = newTier
        source = newSource
    }
}

// MARK: - The seam StoreKit plugs in at

/// The names the App Store knows, and the one question `Entitlements` asks it.
///
/// This stays a thin seam on purpose: `StoreService` does the talking, and
/// everything above this line deals in `Tier`. Nothing in the app outside these
/// two files has ever heard of a product id.
enum StoreKitBridge {

    /// Must match App Store Connect character for character. Product ids are
    /// permanent — they cannot be renamed or reused once created.
    enum ProductID {
        /// Auto-renewable subscription, inside a subscription group.
        static let monthly = "com.mattdevoti1.omedetou.pro.monthly"
        /// The same group as `monthly`, at a higher subscription level, so
        /// moving up from monthly is an upgrade that takes effect immediately
        /// and moving back down waits for the renewal date. Two groups instead
        /// of one would let somebody pay for both at once.
        static let yearly = "com.mattdevoti1.omedetou.pro.yearly"
        /// Non-consumable. A subscription can't be a one-off purchase, so this is
        /// a different product type in a different part of App Store Connect.
        static let full = "com.mattdevoti1.omedetou.pro.full"
    }

    /// The tier this Apple ID currently holds, as of the last time StoreKit was
    /// asked. Synchronous by design — it is read from view bodies — so it reads
    /// a cache that `StoreService` refreshes on launch, on every transaction and
    /// on every restore.
    @MainActor
    static func purchasedTier() -> Tier? { StoreService.shared.entitledTier }
}


