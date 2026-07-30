import Foundation

// FSRS (Free Spaced Repetition Scheduler), the algorithm that replaced SM-2 in
// most modern SRS tools. It models two hidden variables per item:
//
//   stability  — how many days until recall probability decays to 90%
//   difficulty — how resistant this particular item is to gaining stability
//
// and schedules each card for the moment its predicted recall drops to the
// requested retention. That beats SM-2's fixed multipliers because an item's
// history, not just its last answer, sets the next interval.
//
// Weights are the published FSRS-4.5 defaults, trained on a very large review
// corpus. They can later be re-fit per user from their own review log.

enum ReviewGrade: Int, Codable, CaseIterable {
    case again = 1      // forgot
    case hard  = 2      // recalled, but a struggle
    case good  = 3      // recalled
    case easy  = 4      // trivially recalled

    var label: String {
        switch self {
        case .again: return "Again"
        case .hard:  return "Hard"
        case .good:  return "Good"
        case .easy:  return "Easy"
        }
    }
}

/// The per-item memory model. Absent for an item that has never been reviewed.
struct SRSMemory: Codable, Equatable {
    var stability: Double
    var difficulty: Double
    var due: Date
    var lastReview: Date
    var reps: Int
    var lapses: Int
    /// Set after a lapse until the item is answered correctly again. FSRS models
    /// long-term memory but says nothing about same-session recovery, so the
    /// scheduler adds a short relearning step: forgetting something should bring
    /// it back in minutes, not leave it a month out on the strength of its history.
    var isRelearning: Bool = false

    private enum CodingKeys: String, CodingKey {
        case stability, difficulty, due, lastReview, reps, lapses, isRelearning
    }
}

enum FSRS {
    // FSRS-4.5 default parameters.
    static let w: [Double] = [
        0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.0310,
        1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.5870, 0.2272, 2.8755,
    ]

    private static let decay = -0.5
    private static let factor = 19.0 / 81.0

    /// Target recall probability at the moment of review.
    static var requestedRetention = 0.90
    static let maximumInterval = 365.0 * 10

    // MARK: - Core curve

    /// Probability of recall after `days` elapsed at a given stability.
    static func retrievability(days: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        return pow(1 + factor * days / stability, decay)
    }

    /// Days until retrievability falls to `retention`.
    static func interval(stability: Double, retention: Double = requestedRetention) -> Double {
        let raw = (stability / factor) * (pow(retention, 1 / decay) - 1)
        return min(max(raw, 0.0), maximumInterval)
    }

    // MARK: - First review

    private static func initialStability(_ g: ReviewGrade) -> Double {
        max(w[g.rawValue - 1], 0.1)
    }

    /// FSRS-4.5 uses a *linear* initial difficulty. (FSRS-5's exponential form
    /// `w4 - e^(w5(G-1)) + 1` only makes sense with FSRS-5's weights — pairing it
    /// with these ones drives difficulty to the floor on a first "Good", which
    /// then maximises the (11 - D) growth term and explodes the intervals.)
    private static func initialDifficulty(_ g: ReviewGrade) -> Double {
        clampDifficulty(w[4] - Double(g.rawValue - 3) * w[5])
    }

    private static func clampDifficulty(_ d: Double) -> Double { min(max(d, 1), 10) }

    // MARK: - Updates

    private static func nextDifficulty(_ d: Double, _ g: ReviewGrade) -> Double {
        let delta = -w[6] * Double(g.rawValue - 3)
        let next = d + delta
        // Mean reversion toward the "Easy" baseline keeps difficulty from
        // ratcheting to 10 after a bad run.
        let reverted = w[7] * initialDifficulty(.easy) + (1 - w[7]) * next
        return clampDifficulty(reverted)
    }

    private static func stabilityOnRecall(stability s: Double, difficulty d: Double,
                                          retrievability r: Double, _ g: ReviewGrade) -> Double {
        let hardPenalty = g == .hard ? w[15] : 1
        let easyBonus   = g == .easy ? w[16] : 1
        let growth = exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1)
            * hardPenalty * easyBonus
        return s * (1 + growth)
    }

    private static func stabilityOnLapse(stability s: Double, difficulty d: Double,
                                         retrievability r: Double) -> Double {
        let next = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
        // A lapse must never raise stability.
        return min(next, s)
    }

    // MARK: - Public scheduling

    /// Applies a grade, returning the new memory state. `now` is injectable so the
    /// scheduler can be tested without waiting days.
    static func review(_ memory: SRSMemory?, grade: ReviewGrade,
                       now: Date = Date()) -> SRSMemory {
        var next: SRSMemory
        if let m = memory {
            let elapsed = max(now.timeIntervalSince(m.lastReview) / 86_400, 0)
            let r = retrievability(days: elapsed, stability: m.stability)
            let d = nextDifficulty(m.difficulty, grade)
            let s = grade == .again
                ? stabilityOnLapse(stability: m.stability, difficulty: d, retrievability: r)
                : stabilityOnRecall(stability: m.stability, difficulty: d, retrievability: r, grade)
            next = SRSMemory(stability: max(s, 0.1), difficulty: d, due: now,
                             lastReview: now, reps: m.reps + 1,
                             lapses: m.lapses + (grade == .again ? 1 : 0))
        } else {
            next = SRSMemory(stability: initialStability(grade),
                             difficulty: initialDifficulty(grade),
                             due: now, lastReview: now, reps: 1,
                             lapses: grade == .again ? 1 : 0)
        }

        if grade == .again {
            // Come back inside the same session; the model keeps the stability it
            // just computed, which is what sets the interval once it's recalled.
            next.isRelearning = true
            next.due = now.addingTimeInterval(relearningStep)
        } else {
            next.isRelearning = false
            next.due = now.addingTimeInterval(dueOffset(stability: next.stability))
        }
        return next
    }

    /// How soon a lapsed item comes back.
    static let relearningStep: TimeInterval = 10 * 60

    /// Seconds until the next review. Intervals below a day are kept in minutes so
    /// a freshly-lapsed card comes back in the same session rather than tomorrow.
    private static func dueOffset(stability: Double) -> TimeInterval {
        let days = interval(stability: stability)
        if days < 1 {
            let minutes = max(days * 24 * 60, 1)
            return minutes * 60
        }
        return days.rounded() * 86_400
    }

    /// What each button would schedule, for showing "Good → 4d" on the buttons.
    static func preview(_ memory: SRSMemory?, now: Date = Date()) -> [ReviewGrade: TimeInterval] {
        var out: [ReviewGrade: TimeInterval] = [:]
        for g in ReviewGrade.allCases {
            let m = review(memory, grade: g, now: now)
            out[g] = m.due.timeIntervalSince(now)
        }
        return out
    }
}

// MARK: - Interval formatting

extension TimeInterval {
    /// Compact human interval for review buttons: 10m, 4h, 3d, 2mo, 1.5y.
    var srsShortLabel: String {
        let minutes = self / 60
        if minutes < 60 { return "\(max(Int(minutes.rounded()), 1))m" }
        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours.rounded()))h" }
        let days = hours / 24
        if days < 30 { return "\(Int(days.rounded()))d" }
        let months = days / 30.4
        if months < 12 { return "\(Int(months.rounded()))mo" }
        let years = days / 365
        return years < 10 ? String(format: "%.1fy", years) : "\(Int(years.rounded()))y"
    }
}
