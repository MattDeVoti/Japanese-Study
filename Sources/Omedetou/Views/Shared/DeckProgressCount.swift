import SwiftUI

/// "12/40" — how much of the current set you've checked off.
///
/// Only shown in Standard mode. That's the mode where a checked card leaves the
/// deck, so the count is a real position in a finite set: it only ever goes up,
/// and reaching the total empties the deck. In Priority Study every card stays
/// in rotation however often you check it, so the same number would sit there
/// describing nothing you're working towards.
///
/// Smart Study is the exception: it moves in and out of Priority Study
/// constantly, but there is still a set being worked through, so the vocab deck
/// keeps the count up and sources it from the programme instead. See
/// `SmartStudyEngine.progress`.
struct DeckProgressCount: View {
    let done: Int
    let total: Int

    var body: some View {
        Text("\(done)/\(total)")
            // Monospaced digits so the counter doesn't twitch sideways each
            // time a card is checked off.
            .font(.system(size: 14, weight: .semibold).monospacedDigit())
            .foregroundColor(.appTextSecondary)
            .accessibilityLabel("\(done) of \(total) checked off")
    }
}

extension View {
    /// Centres the count on the *screen*, not between whatever sits either side
    /// of it. The star, the level badge and the WORD chip all come and go
    /// between cards, so laying it out as a middle element would leave it
    /// drifting from card to card.
    @ViewBuilder
    func deckProgress(_ progress: (done: Int, total: Int)?) -> some View {
        if let progress {
            overlay(DeckProgressCount(done: progress.done, total: progress.total))
        } else {
            self
        }
    }
}
