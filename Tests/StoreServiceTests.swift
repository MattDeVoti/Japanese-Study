import XCTest
import StoreKit
import StoreKitTest
@testable import Omedetou

// What a purchase is supposed to add up to.
//
// StoreKit code is the one part of an app that cannot be checked by looking at
// it: the interesting cases are a renewal arriving while the app is closed, a
// refund landing mid-period, and a one-time purchase reappearing on a new
// device — none of which a person tapping around can produce on demand.
// `SKTestSession` produces all of them locally, against the same
// `Omedetou.storekit` file the app runs on in the simulator.
//
// These assert on `StoreService.entitledTier` — what the store itself concludes
// — rather than on `Entitlements.isPro`. `Entitlements` grants full access to
// beta members before it looks at any purchase, so on a device that has ever
// run the beta build every one of these would pass for the wrong reason.

@MainActor
final class StoreServiceTests: XCTestCase {

    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Omedetou")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true

        // StoreKit Test needs the app to be installed *for development*, which
        // is something Xcode does when it runs a scheme and `xcodebuild test`
        // on its own does not. Without it `storekitd` refuses the configuration
        // and hands back an empty catalogue — an empty storefront is the first
        // visible sign. Skipping beats failing: the code is fine, the harness
        // isn't there. Run these from Xcode (⌘U) to actually exercise them.
        try XCTSkipIf(session.storefront.isEmpty,
                      "StoreKit Test is not available in this environment — run from Xcode.")

        await StoreService.shared.refreshEntitlements()
    }

    override func tearDown() async throws {
        session.clearTransactions()
        session = nil
    }

    func testProductsLoadWithTheIdsTheAppAsksFor() async throws {
        let store = StoreService.shared
        await store.loadProducts()

        XCTAssertEqual(store.state, .loaded)
        XCTAssertNotNil(store.monthly, "the monthly id doesn't match the configuration")
        XCTAssertNotNil(store.yearly, "the yearly id doesn't match the configuration")
        XCTAssertNotNil(store.full, "the one-time id doesn't match the configuration")
        XCTAssertEqual(store.monthly?.periodDescription, "month")
        XCTAssertEqual(store.yearly?.periodDescription, "year")
        XCTAssertNotNil(store.full?.displayPrice)
        // Cheapest commitment first, so the paywall reads as a ladder.
        XCTAssertEqual(store.availableProducts.map(\.id),
                       [StoreKitBridge.ProductID.monthly,
                        StoreKitBridge.ProductID.yearly,
                        StoreKitBridge.ProductID.full])
    }

    func testBuyingTheYearlyPlanGrantsYearly() async throws {
        let store = StoreService.shared
        await store.loadProducts()

        let bought = await store.purchase(try XCTUnwrap(store.yearly))

        XCTAssertTrue(bought)
        XCTAssertEqual(store.entitledTier, .yearly)
        XCTAssertTrue(Tier.yearly.unlocksEverything)
        XCTAssertTrue(Tier.yearly.isSubscription)
    }

    /// The saving is shown to people as a number, so it has to be the real one:
    /// 49.99 against twelve months at 5.99 is 30.45%, which rounds to 30.
    func testTheYearlySavingIsWorkedOutFromTheRealPrices() async throws {
        let store = StoreService.shared
        await store.loadProducts()

        XCTAssertEqual(store.yearlySavingPercent, 30)
    }

    /// Nothing to compare against means no badge, rather than a made-up one.
    func testNoSavingIsClaimedWithoutBothPrices() async throws {
        let store = StoreService.shared
        XCTAssertNil(store.yearlySavingPercent)
        XCTAssertNil(store.yearlyPerMonth)
    }

    /// 49.99 over twelve months is 4.1658…, which the storefront's own formatter
    /// rounds to 4.17 — hence "about" on the paywall.
    func testTheYearlyPlanIsShownPerMonth() async throws {
        let store = StoreService.shared
        await store.loadProducts()

        let perMonth = try XCTUnwrap(store.yearlyPerMonth)
        XCTAssertTrue(perMonth.contains("4.17"), "unexpected per-month figure: \(perMonth)")
    }

    func testNothingIsEntitledBeforeAnythingIsBought() async throws {
        await StoreService.shared.refreshEntitlements()
        XCTAssertNil(StoreService.shared.entitledTier)
    }

    func testBuyingTheSubscriptionGrantsMonthly() async throws {
        let store = StoreService.shared
        await store.loadProducts()
        let monthly = try XCTUnwrap(store.monthly)

        let bought = await store.purchase(monthly)

        XCTAssertTrue(bought)
        XCTAssertEqual(store.entitledTier, .monthly)
        XCTAssertTrue(Tier.monthly.unlocksEverything)
    }

    func testBuyingTheOneTimePurchaseGrantsFull() async throws {
        let store = StoreService.shared
        await store.loadProducts()
        let full = try XCTUnwrap(store.full)

        let bought = await store.purchase(full)

        XCTAssertTrue(bought)
        XCTAssertEqual(store.entitledTier, .full)
    }

    /// Someone holding both must not be downgraded by whichever transaction
    /// `currentEntitlements` happens to yield second.
    func testTheOneTimePurchaseOutranksEverySubscription() async throws {
        let store = StoreService.shared
        await store.loadProducts()

        await store.purchase(try XCTUnwrap(store.yearly))
        await store.purchase(try XCTUnwrap(store.full))

        XCTAssertEqual(store.entitledTier, .full)
    }

    /// Buying outright does not cancel a running subscription, and the app has
    /// no way to do it either — so it has to keep offering the way to cancel,
    /// even though the tier has stopped being a subscription.
    func testBuyingOutrightWhileSubscribedStillOffersTheWayToCancel() async throws {
        let store = StoreService.shared
        await store.loadProducts()

        await store.purchase(try XCTUnwrap(store.monthly))
        XCTAssertTrue(store.hasActiveSubscription)

        await store.purchase(try XCTUnwrap(store.full))

        XCTAssertEqual(store.entitledTier, .full)
        XCTAssertTrue(store.hasActiveSubscription,
                      "they are still being billed monthly with nowhere to cancel")
    }

    func testTheYearlyPlanOutranksTheMonthlyOne() async throws {
        let store = StoreService.shared
        await store.loadProducts()

        await store.purchase(try XCTUnwrap(store.monthly))
        await store.purchase(try XCTUnwrap(store.yearly))

        XCTAssertEqual(store.entitledTier, .yearly)
    }

    /// An expired subscription has to stop unlocking things. This is the case
    /// that silently gives the app away if `currentEntitlements` is trusted
    /// without checking dates.
    func testAnExpiredSubscriptionStopsUnlocking() async throws {
        let store = StoreService.shared
        await store.loadProducts()
        await store.purchase(try XCTUnwrap(store.monthly))
        XCTAssertEqual(store.entitledTier, .monthly)

        try session.expireSubscription(productIdentifier: StoreKitBridge.ProductID.monthly)
        await store.refreshEntitlements()

        XCTAssertNil(store.entitledTier, "an expired subscription still unlocked the app")
    }

    /// A refund arrives as a revocation on a transaction that is otherwise
    /// still inside its period.
    func testARefundRemovesAccess() async throws {
        let store = StoreService.shared
        await store.loadProducts()
        await store.purchase(try XCTUnwrap(store.full))
        XCTAssertEqual(store.entitledTier, .full)

        let transaction = try XCTUnwrap(session.allTransactions().first {
            $0.productIdentifier == StoreKitBridge.ProductID.full
        })
        try await session.refundTransaction(identifier: UInt(transaction.identifier))
        await store.refreshEntitlements()

        XCTAssertNil(store.entitledTier, "a refunded purchase still unlocked the app")
    }

    /// The listener is what catches a purchase made elsewhere — on another
    /// device, or approved after an Ask to Buy. Simulated here by buying
    /// outside the app and asking the store to re-read.
    func testAPurchaseMadeOutsideTheAppIsPickedUp() async throws {
        let store = StoreService.shared
        _ = try session.buyProduct(productIdentifier: StoreKitBridge.ProductID.monthly)

        await store.refreshEntitlements()

        XCTAssertEqual(store.entitledTier, .monthly)
    }

    /// Every transaction has to be finished, or Apple treats it as undelivered
    /// and keeps refunding it.
    func testPurchasesAreFinished() async throws {
        let store = StoreService.shared
        await store.loadProducts()
        await store.purchase(try XCTUnwrap(store.monthly))

        var unfinished = 0
        for await _ in Transaction.unfinished { unfinished += 1 }
        XCTAssertEqual(unfinished, 0, "an unfinished transaction will be replayed forever")
    }
}
