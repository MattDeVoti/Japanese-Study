import SwiftUI

/// Diagnostic readout for the Smart Study cycle, pinned to the corner of a card.
///
/// **Off in shipping builds — flip `isEnabled` to bring it back.** Kept rather
/// than deleted because the programme's state is otherwise entirely invisible
/// (deliberately: see `SmartStudyEngine`), so this is the only way to watch a
/// countdown run or confirm which phase a session is in.
///
/// It reads `SmartStudyEngine.debugLines`, which exists for this and nothing
/// else. The two `.smartStudyDebug(...)` call sites are in the written and
/// audio vocab decks.
struct SmartStudyDebugOverlay: View {
    /// The one switch. `true` draws the readout on every card of both vocab
    /// decks whenever Smart Study is on; `false` never builds the view at all,
    /// so there is no cost to leaving this in place.
    static let isEnabled = false

    /// Observed, not just held. The engine's counters are plain stored state on
    /// a reference that never changes identity, so without this SwiftUI has no
    /// reason to redraw and most of the readout sits frozen between renders
    /// forced by something else.
    @ObservedObject var engine: SmartStudyEngine
    let cards: [VocabFlashCard]
    let filter: any VocabFiltering
    @ObservedObject private var settings = StudyWeightSettings.shared

    @ViewBuilder
    var body: some View {
        if settings.smartStudy, !cards.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(engine.debugLines(cards: cards, filter: filter), id: \.self) {
                    Text($0)
                }
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.appText.opacity(0.75))
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.appSurface.opacity(0.6))
            )
            // Purely a readout — it must never take a tap meant for the card.
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Pins the Smart Study readout to the top-left of a deck screen, when
    /// `SmartStudyDebugOverlay.isEnabled` says so.
    ///
    /// The check sits here rather than inside the overlay's body so that with
    /// the flag off the view is never constructed — nothing observes the
    /// engine, and `debugLines` is never called.
    func smartStudyDebug(_ engine: SmartStudyEngine, cards: [VocabFlashCard],
                         filter: any VocabFiltering, topPadding: CGFloat) -> some View {
        overlay(alignment: .topLeading) {
            if SmartStudyDebugOverlay.isEnabled {
                SmartStudyDebugOverlay(engine: engine, cards: cards, filter: filter)
                    .padding(.leading, 8)
                    .padding(.top, topPadding)
            }
        }
    }
}
