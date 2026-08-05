import Foundation

// Records that someone was here during the beta, so the promise the welcome
// screen makes can actually be kept.
//
// The welcome screen tells early users they keep full access for free, for good.
// That is a promise, and a promise needs a record behind it — a sheet that only
// shows text leaves nothing to honour later. The record has to be written now,
// while the app is still free, because it cannot be reconstructed afterwards:
// once a paid tier ships there is no way to work out who was already here.
//
// Deliberately generous, and deliberately not defended. The flag is a plain
// UserDefaults boolean, so deleting the app clears it and anyone determined could
// set it by hand. Both are acceptable. Wrongly granting free access costs one
// subscription; wrongly denying it breaks a promise made to someone who helped
// test the thing. This errs towards the user every time.

enum BetaAccess {

    /// Flip to `false` when the beta ends and the paid tier ships.
    ///
    /// This is what stops *new* arrivals being enrolled. It revokes nothing:
    /// `isMember` is written once and never cleared, so everyone enrolled while
    /// this was `true` keeps access permanently. It also hides the welcome sheet,
    /// which would otherwise go on promising free access to people who aren't
    /// entitled to it.
    ///
    /// Forgetting to flip it would quietly hand the entire paying audience the
    /// app for nothing, so it is the first thing to check before shipping a
    /// paywall.
    static let periodIsOpen = true

    private static let memberKey = "BetaMember"
    private static let sinceKey  = "BetaMemberSince"
    private static let seenKey   = "WelcomeShown"

    /// Whether this person opened the app during the beta, and so has permanent
    /// free access to everything. Once true, always true.
    static var isMember: Bool { UserDefaults.standard.bool(forKey: memberKey) }

    /// When they first opened it. Informational — `isMember` is what grants
    /// access — but it's the evidence behind the claim, so it's worth keeping.
    static var memberSince: Date? {
        let stamp = UserDefaults.standard.double(forKey: sinceKey)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    /// The welcome sheet appears once, on the first launch, and never again.
    ///
    /// Gated on `periodIsOpen` as well as on having been seen: after the beta
    /// closes the sheet's central claim stops being true, and showing it to a new
    /// arrival would be a straightforward lie.
    static var shouldShowWelcome: Bool {
        periodIsOpen && !UserDefaults.standard.bool(forKey: seenKey)
    }

    /// Enrols this install if the beta is open and it isn't enrolled already.
    /// Cheap and idempotent — safe to call on every launch.
    ///
    /// Separate from the welcome sheet on purpose. Someone who swipes the sheet
    /// away without reading it was still here during the beta, and the promise
    /// applies to them just the same.
    static func enrolIfNeeded() {
        guard periodIsOpen, !isMember else { return }
        let defaults = UserDefaults.standard
        // Only ever written as `true`, never `false`. SettingsSync relies on that
        // invariant — see the note beside its key list.
        defaults.set(true, forKey: memberKey)
        defaults.set(Date().timeIntervalSince1970, forKey: sinceKey)
    }

    static func markWelcomeSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}
