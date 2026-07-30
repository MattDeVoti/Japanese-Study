import SwiftUI

// A practice round. One card at a time across vocab, kanji and grammar, graded on
// the four-button FSRS scale.
//
// It draws anything genuinely ripe first, then fills the rest with whatever the
// model rates hardest — so practice is always available and is never presented as
// a backlog to be cleared.

struct ReviewSessionView: View {
    @EnvironmentObject private var cardStore: CardStore
    @ObservedObject private var srs = SRSStore.shared
    @Environment(\.dismiss) private var dismiss

    /// Queue of ids still to see this session. Lapsed cards get pushed back on.
    @State private var queue: [SRSItemID] = []
    @State private var current: ReviewCard?
    @State private var isRevealed = false
    @State private var completed = 0
    @State private var startCount = 0
    @State private var gradeCounts: [ReviewGrade: Int] = [:]
    @State private var finished = false

    /// Cards per round, so a long session never feels unbounded.
    private let sessionCap = 60

    var body: some View {
        ZStack {
            AppBackground()

            if finished || (current == nil && queue.isEmpty) {
                summary
            } else if let card = current {
                cardBody(card)
            } else {
                ProgressView()
            }
        }
        .standardNavBar("Practice")
        .onAppear(perform: startIfNeeded)
    }

    // MARK: - Card

    private func cardBody(_ card: ReviewCard) -> some View {
        VStack(spacing: 0) {
            header(card)

            // Centre the prompt in whatever space is left, but still allow scrolling
            // when a long grammar answer needs it.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 18) {
                        Spacer(minLength: 0)
                        promptAndAnswer(card)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                }
            }

            if isRevealed {
                gradeButtons(card)
            } else {
                AccentActionButton(title: "Show Answer") {
                    withAnimation(.easeIn(duration: 0.18)) { isRevealed = true }
                }
                .padding(.bottom, 28)
            }
        }
    }

    private func promptAndAnswer(_ card: ReviewCard) -> some View {
        VStack(spacing: 18) {
            // Prompt
            VStack(spacing: 10) {
                if card.front.contains("[") {
                    FuriganaText(text: card.front, fontSize: promptSize(card),
                                 color: .appText, weight: .bold, alignment: .center)
                        .frame(maxWidth: .infinity)
                        .frame(height: promptSize(card) * 2.1)
                } else {
                    Text(card.front)
                        .font(.system(size: promptSize(card), weight: .bold))
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.center)
                }

                if isRevealed, let reading = card.reading, reading != card.front {
                    Text(reading)
                        .font(.system(size: 20))
                        .foregroundColor(.appTextSecondary)
                }
            }
            .padding(.horizontal, 24)

            if isRevealed {
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.back)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.appText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let extra = card.extra {
                        Text(extra)
                            .font(.system(size: 13))
                            .foregroundColor(card.accent)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(card.accent.opacity(0.10))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .transition(.opacity)
            }
        }
    }

    /// A lone glyph can be set huge; phrases cannot.
    private func promptSize(_ card: ReviewCard) -> CGFloat {
        if card.isSingleGlyph { return 96 }
        switch card.kind {
        case .kanji:   return 96
        case .vocab:   return card.front.count > 6 ? 34 : 48
        case .grammar: return card.front.count > 14 ? 22 : 28
        }
    }

    private func header(_ card: ReviewCard) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(card.badge.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(card.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(card.accent.opacity(0.14))
                    .cornerRadius(6)

                if let m = srs.memory(for: card.id), m.isRelearning {
                    Text("RELEARNING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.14))
                        .cornerRadius(6)
                }

                Spacer()

                SpeakButton(text: card.reading ?? card.front, size: 20, tint: card.accent)

                Text("\(completed)/\(startCount)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(.appTextSecondary)
            }

            ProgressView(value: Double(completed),
                         total: Double(max(startCount, 1)))
                .tint(card.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func gradeButtons(_ card: ReviewCard) -> some View {
        let previews = FSRS.preview(srs.memory(for: card.id))
        return HStack(spacing: 8) {
            ForEach(ReviewGrade.allCases, id: \.rawValue) { grade in
                Button {
                    answer(card, grade)
                } label: {
                    VStack(spacing: 3) {
                        Text(grade.label)
                            .font(.system(size: 14, weight: .semibold))
                        Text(previews[grade]?.srsShortLabel ?? "")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .opacity(0.75)
                    }
                    .foregroundColor(Color.readableOnPage(tint(grade)))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint(grade).opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(tint(grade).opacity(0.55), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 26)
    }

    /// Grading is semantic — fail/struggle/pass/easy must be unmistakable, so these
    /// stay fixed rather than following the active theme (a themed "Good" came out
    /// red enough to be confused with "Again").
    private func tint(_ g: ReviewGrade) -> Color {
        switch g {
        case .again: return Color(hex: "EF4444")
        case .hard:  return Color(hex: "F59E0B")
        case .good:  return Color(hex: "22C55E")
        case .easy:  return Color(hex: "38BDF8")
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: completed > 0 ? "checkmark.seal.fill" : "tray")
                .font(.system(size: 64))
                .foregroundColor(.appAccent)

            Text(completed > 0 ? "Round complete" : "Nothing to practise yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.appText)

            if completed > 0 {
                Text("\(completed) card\(completed == 1 ? "" : "s")")
                    .font(.system(size: 15))
                    .foregroundColor(.appTextSecondary)

                HStack(spacing: 10) {
                    ForEach(ReviewGrade.allCases, id: \.rawValue) { g in
                        VStack(spacing: 2) {
                            Text("\(gradeCounts[g] ?? 0)")
                                .font(.system(size: 20, weight: .bold).monospacedDigit())
                                .foregroundColor(tint(g))
                            Text(g.label)
                                .font(.system(size: 11))
                                .foregroundColor(.appTextSecondary)
                        }
                        .frame(minWidth: 56)
                    }
                }
                .padding(.top, 4)

            } else {
                Text(nextDueMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if srs.enrolledCount > 0 {
                AccentActionButton(title: "Practise some more",
                                   icon: "arrow.clockwise") {
                    restart()
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(24)
    }

    private var nextDueMessage: String {
        "Anything you get wrong on a test, or study on a flashcard, lands here to practise."
    }

    // MARK: - Flow

    private func startIfNeeded() {
        srs.rolloverDayIfNeeded()
        guard queue.isEmpty, current == nil else { return }
        restart()
    }

    private func restart() {
        let due = srs.practiceIDs(limit: sessionCap)
        queue = due
        startCount = due.count
        completed = 0
        gradeCounts = [:]
        finished = false
        advance()
    }

    private func advance() {
        isRevealed = false
        // Skip anything that no longer resolves rather than dead-ending the queue.
        while let next = queue.first {
            queue.removeFirst()
            if let card = SRSCatalogue.card(for: next, cardStore: cardStore) {
                current = card
                return
            } else {
                srs.unenroll(next)
                startCount = max(startCount - 1, 0)
            }
        }
        current = nil
        finished = true
    }

    private func answer(_ card: ReviewCard, _ grade: ReviewGrade) {
        srs.grade(card.id, grade)
        gradeCounts[grade, default: 0] += 1
        completed += 1

        // A lapsed card comes back before the session ends, a few cards later.
        if grade == .again {
            let insertAt = min(3, queue.count)
            queue.insert(card.id, at: insertAt)
            startCount += 1
        }

        // Keep the existing needs-work weighting in sync so the older decks agree
        // with what happened here.
        syncLegacyWeights(card.id, grade)

        withAnimation(.easeOut(duration: 0.15)) { advance() }
    }

    /// The pre-SRS decks track confident/needs-work counts. Mirror the grade into
    /// them so the two systems don't disagree about what the user struggles with.
    private func syncLegacyWeights(_ id: SRSItemID, _ grade: ReviewGrade) {
        let struggled = (grade == .again || grade == .hard)
        switch id.kind {
        case .vocab:
            if struggled { VocabFlashcardsFilter.shared.markNeedsWork(id.key) }
            else { VocabFlashcardsFilter.shared.markConfident(id.key) }
        case .kanji:
            if struggled { cardStore.incrementNeedsWork(cardId: id.key) }
            else { cardStore.incrementConfident(cardId: id.key) }
        case .grammar:
            break       // grammar points have no weight store of their own
        }
    }
}
