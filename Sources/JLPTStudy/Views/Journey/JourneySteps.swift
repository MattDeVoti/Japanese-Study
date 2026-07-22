import SwiftUI

// Shared helpers ---------------------------------------------------------

private func sectionBadge(_ levelLabel: String) -> String {
    switch levelLabel {
    case "Hiragana": return "ひ"
    case "Katakana": return "カ"
    default:
        // Grammar levels: show the level number (N5 → "1", … N1 → "5").
        if levelLabel.hasPrefix("N"), let n = Int(levelLabel.dropFirst()) { return "\(levelNumber(n))" }
        return levelLabel
    }
}

private struct StepTag: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

// Intro ------------------------------------------------------------------

struct JourneyIntro: View {
    let section: JourneySection
    let accent: Color
    var body: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(accent.badgeGradient)
                .frame(width: 78, height: 78)
                .overlay(Text(sectionBadge(section.levelLabel))
                    .font(.system(size: 30, weight: .bold)).foregroundColor(.white))
                .shadow(color: accent.opacity(0.4), radius: 10, x: 0, y: 5)
            Text(section.summary.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)
            Text(section.isKana ? "Learn these characters one at a time."
                                : "A few grammar points, then its vocab and kanji.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct JourneySectionDone: View {
    let section: JourneySection
    let accent: Color
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60)).foregroundColor(accent)
            Text("Section complete")
                .font(.system(size: 24, weight: .bold)).foregroundColor(.appText)
            Text(section.header)
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// Coach / guidance -------------------------------------------------------

struct JourneyCoach: View {
    let card: CoachCard
    let accent: Color
    var body: some View {
        VStack(spacing: 18) {
            Text(card.icon).font(.system(size: 52))
            Text(card.title)
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)
            FuriganaText(text: card.body, fontSize: 16, alignment: .center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Grammar teach ----------------------------------------------------------

struct JourneyTeach: View {
    let card: TeachCard
    let accent: Color

    var body: some View {
        switch card {
        case .concept(let name, let desc):
            VStack(spacing: 16) {
                StepTag(text: "Grammar", color: accent)
                FuriganaText(text: name, fontSize: 26, weight: .bold, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(desc)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

        case .text(let tag, let body):
            VStack(alignment: .leading, spacing: 14) {
                StepTag(text: tag, color: accent)
                ExplanationBody(text: body, fontSize: 18, color: .appText, bulletColor: accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .pattern(let formation):
            VStack(alignment: .leading, spacing: 10) {
                StepTag(text: "Pattern", color: accent)
                Text("Here's the shape to remember:")
                    .font(.system(size: 15)).foregroundColor(.secondary)
                FuriganaText(text: formation, fontSize: 18, color: .appText, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .appCard(cornerRadius: 14, elevated: false)
            }

        case .rules(let rules):
            VStack(alignment: .leading, spacing: 12) {
                StepTag(text: "Key points", color: accent)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rules.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(accent).frame(width: 6, height: 6).padding(.top, 8)
                            FuriganaText(text: rules[i], fontSize: 15)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

        case .examples(let examples):
            VStack(alignment: .leading, spacing: 12) {
                StepTag(text: "Examples", color: accent)
                Text("See it in action:")
                    .font(.system(size: 15)).foregroundColor(.secondary)
                ForEach(examples.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 4) {
                        FuriganaText(text: examples[i].japanese, fontSize: 19)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(examples[i].english)
                            .font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accent.opacity(0.10)))
                }
            }
        }
    }
}

// Kana / vocab / kanji reveal cards --------------------------------------

struct JourneyKana: View {
    let point: GrammarPoint
    let accent: Color
    let revealed: Bool
    var body: some View {
        VStack(spacing: 20) {
            Text(point.flashcardHeader ?? point.name)
                .font(.system(size: 96, weight: .bold))
                .foregroundColor(.appText)
            if revealed {
                Text(point.flashcardAnswer ?? point.shortDescription)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(accent)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }
}

struct JourneyVocab: View {
    let word: LessonVocabWord
    let accent: Color
    let revealed: Bool
    var body: some View {
        VStack(spacing: 12) {
            StepTag(text: word.partOfSpeech, color: accent)
            Text(word.kanji)
                .font(.system(size: 46, weight: .bold))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)
            if revealed {
                if word.kanji != word.kana {
                    Text(word.kana).font(.system(size: 20)).foregroundColor(.secondary)
                }
                Text(word.definition)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(accent)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }
}

struct JourneyKanji: View {
    let card: KanjiCard
    let revealed: Bool

    private var on: String { card.onyomi.map(\.kana).joined(separator: "・") }
    private var kun: String { card.kunyomi.map(\.kana).joined(separator: "・") }

    var body: some View {
        VStack(spacing: 14) {
            StepTag(text: "N\(card.nLevel) Kanji", color: nLevelColor(card.nLevel))
            Text(card.kanji)
                .font(.system(size: 88, weight: .bold))
                .foregroundColor(nLevelColor(card.nLevel))
            if revealed {
                VStack(spacing: 4) {
                    if !on.isEmpty {
                        Text("音  \(on)").font(.system(size: 15)).foregroundColor(.appText)
                    }
                    if !kun.isEmpty {
                        Text("訓  \(kun)").font(.system(size: 15)).foregroundColor(.appText)
                    }
                }
                Text(card.definition)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }
}

// Quiz -------------------------------------------------------------------

struct JourneyQuiz: View {
    let question: PracticeQuestion
    let order: [Int]
    let selected: Int?
    let accent: Color
    let onAnswer: (Int) -> Void

    private var correctDisplayed: Int? { order.firstIndex(of: question.correctIndex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTag(text: "Quiz", color: accent)

            FuriganaText(text: question.prompt, fontSize: 18, weight: .semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let jp = question.japanese {
                FuriganaText(text: jp, fontSize: 22, alignment: .center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accent.opacity(0.10)))
            }

            VStack(spacing: 10) {
                ForEach(order.indices, id: \.self) { i in
                    JourneyChoice(
                        text: question.choices[order[i]],
                        state: choiceState(i),
                        accent: accent
                    ) { onAnswer(i) }
                }
            }

            if selected != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Explanation", systemImage: "lightbulb")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary).textCase(.uppercase)
                    FuriganaText(text: question.explanation, fontSize: 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface))
                .transition(.opacity)
            }
        }
    }

    private func choiceState(_ i: Int) -> JourneyChoice.State {
        guard selected != nil else { return .idle }
        if i == correctDisplayed { return .correct }
        if i == selected { return .wrong }
        return .dimmed
    }
}

struct JourneyChoice: View {
    enum State { case idle, correct, wrong, dimmed }
    let text: String
    let state: State
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                FuriganaText(text: text, fontSize: 15, color: fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if state == .correct { Image(systemName: "checkmark.circle.fill").foregroundColor(.white) }
                if state == .wrong   { Image(systemName: "xmark.circle.fill").foregroundColor(.white) }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(border, lineWidth: 1.5))
            .opacity(state == .dimmed ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
    }

    private var fg: Color { (state == .correct || state == .wrong) ? .white : .primary }
    private var bg: Color {
        switch state { case .correct: return .green; case .wrong: return .red; default: return .appSurface }
    }
    private var border: Color {
        switch state { case .correct: return .green; case .wrong: return .red; default: return .appHairline }
    }
}

// Journey complete -------------------------------------------------------

struct JourneyDoneScreen: View {
    let accent: Color
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🎉").font(.system(size: 64))
            Text("You reached the end of the journey!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)
            Text("You've been through every chapter — Hiragana to N1.")
                .font(.system(size: 15)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.red.badgeGradient))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24).padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }
}
