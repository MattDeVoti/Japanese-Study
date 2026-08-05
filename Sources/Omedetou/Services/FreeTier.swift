import Foundation

// What a free account can reach.
//
// One list, in one file. A paywall scattered through the views is a paywall
// nobody can audit — and the question "is this free?" gets answered differently
// in two places the moment it's asked in two places. Every gate in the app asks
// this type; nothing checks a tier or a product id directly.
//
// None of this has any effect while `BetaAccess.periodIsOpen` is true: everyone
// resolves to `.full`, `Entitlements.isPro` is always true, and no lock draws.
// That is deliberate — the gating can ship, be reviewed and be tested long
// before anything is actually for sale.

enum FreeTier {

    // MARK: - Textbook

    /// Both syllabaries in full, plus the first two grammar chapters.
    ///
    /// Kana is where a beginner is most likely to give up, and it's the part
    /// that makes everything after it legible. Charging before someone can read
    /// あ would be charging before the app has been any use to them.
    static let chapterIDs: Set<String> = {
        var ids = Set<String>()
        for i in 1...14 {
            ids.insert(String(format: "kana_h%02d", i))
            ids.insert(String(format: "kana_k%02d", i))
        }
        ids.formUnion(["ch01", "ch02"])
        return ids
    }()

    /// Levels that open at all. N5 opens so the first two chapters are reachable;
    /// its later chapters are locked individually.
    static let levelIDs: Set<String> = ["Hiragana", "Katakana", "N5"]

    static func isFree(chapter id: String) -> Bool { chapterIDs.contains(id) }
    static func isFree(level id: String) -> Bool { levelIDs.contains(id) }

    // MARK: - Particles

    /// The six that carry an ordinary sentence. Enough to read chapter one.
    static let particles: Set<String> = ["は", "が", "を", "に", "の", "か"]
    static func isFree(particle: String) -> Bool { particles.contains(particle) }

    // MARK: - Appearance

    /// One light, one dark.
    ///
    /// Sunset alone would leave anyone who needs a dark interface — light
    /// sensitivity, migraine, some low-vision conditions — with no usable option
    /// at all. That isn't a premium flourish to sell; it's whether the app can be
    /// looked at. Sumi Ink is the quietest of the dark set, so it reads as a
    /// default rather than as a taste.
    static let themeIDs: Set<String> = ["sunset", "inkwash"]
    static func isFree(theme id: String) -> Bool { themeIDs.contains(id) }

    // MARK: - Always free, whatever the tier
    //
    // These are not generosity. Each one would break something if locked:
    //
    // • About & Sources — the EDRDG licence requires the attribution screen be
    //   reachable from a menu. Behind a paywall, every free install ships their
    //   dictionary data with no reachable credit. That's a licence breach.
    // • Send Feedback — the published privacy policy states that questions about
    //   it can be sent from this screen. Locking it makes that statement false,
    //   and free users are exactly who bug reports come from.
    // • Backup & Restore — a person's own study data. Locking export holds their
    //   work hostage against a subscription.
    // • Japanese text size, audio, dictation, iCloud sync, the report card, and
    //   the hidden games.
    //
    // Listed rather than implemented: nothing calls these, because the gate is
    // simply never applied at those sites. The list is here so the reasoning
    // survives the next person who wonders why.
}
