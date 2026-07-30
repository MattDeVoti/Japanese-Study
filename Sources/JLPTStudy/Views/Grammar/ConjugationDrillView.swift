import SwiftUI

// Conjugation drills, generated from ConjugationEngine rather than authored.
//
// The distractors are the *same verb's other forms*, which is the whole point:
// learners rarely invent a wrong ending from nothing, they reach for the
// neighbouring form. Asking "which of these four is the plain past?" trains the
// discrimination that actually fails in conversation.

private struct ConjugationQuestion {
    let word: String
    let reading: String?
    let meaning: String
    let group: String          // "godan verb" etc., shown after answering
    let sectionTitle: String   // "Plain Negative"
    let formLabel: String      // "Past"
    let answer: String
    let choices: [String]
    /// Accepted alternatives (the engine's colloquial `alt`).
    let alsoCorrect: String?
}

struct ConjugationDrillView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    private let accent = Color.themeTile(2)
    private let questionsPerRound = 15

    @State private var pool: [DictionaryEntry] = []
    @State private var question: ConjugationQuestion?
    @State private var picked: String?
    @State private var asked = 0
    @State private var correct = 0
    @State private var finished = false

    var body: some View {
        ZStack {
            PatternedBackground(.study)

            if finished {
                summary
            } else if let q = question {
                drill(q)
            } else {
                ProgressView()
            }
        }
        .standardNavBar("Conjugation")
        .onAppear { begin() }
    }

    // MARK: - Drill

    private func drill(_ q: ConjugationQuestion) -> some View {
        VStack(spacing: 0) {
            // Progress
            VStack(spacing: 6) {
                HStack {
                    Text("\(asked + 1) / \(questionsPerRound)")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    Text("\(correct) correct")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundColor(accent)
                }
                ProgressView(value: Double(asked), total: Double(questionsPerRound))
                    .tint(accent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                VStack(spacing: 16) {
                    // The word
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(q.word)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.appText)
                            SpeakButton(text: q.reading ?? q.word, size: 20, tint: accent)
                        }
                        if let r = q.reading, r != q.word {
                            Text(r)
                                .font(.system(size: 16))
                                .foregroundColor(.appTextSecondary)
                        }
                        Text(q.meaning)
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 18)

                    // The target form
                    VStack(spacing: 2) {
                        Text(q.sectionTitle.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(accent)
                        Text(q.formLabel)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.appText)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(accent.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // Choices
                    VStack(spacing: 10) {
                        ForEach(q.choices, id: \.self) { choice in
                            choiceRow(q, choice)
                        }
                    }
                    .padding(.horizontal, 20)

                    if picked != nil {
                        VStack(spacing: 10) {
                            Text(isCorrect(q) ? "Correct" : "The answer is \(q.answer)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(isCorrect(q) ? Color(hex: "22C55E") : Color(hex: "EF4444"))
                            Text("\(q.word) is a \(q.group).")
                                .font(.system(size: 12))
                                .foregroundColor(.appTextSecondary)

                            AccentActionButton(title: asked + 1 >= questionsPerRound ? "See results" : "Next",
                                               icon: "arrow.right", color: accent) {
                                next()
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private func choiceRow(_ q: ConjugationQuestion, _ choice: String) -> some View {
        let answered = picked != nil
        let isAnswer = choice == q.answer || choice == q.alsoCorrect
        let isPicked = picked == choice

        let border: Color = {
            guard answered else { return Color.appHairline }
            if isAnswer { return Color(hex: "22C55E") }
            return isPicked ? Color(hex: "EF4444") : Color.appHairline
        }()
        let fill: Color = {
            guard answered else { return Color.appSurface }
            if isAnswer { return Color(hex: "22C55E").opacity(0.14) }
            return isPicked ? Color(hex: "EF4444").opacity(0.12) : Color.appSurface
        }()

        return Button {
            guard picked == nil else { return }
            picked = choice
            if isAnswer { correct += 1 }
        } label: {
            HStack {
                Text(choice)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(.appText)
                Spacer()
                if answered && isAnswer {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "22C55E"))
                } else if answered && isPicked {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "EF4444"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
    }

    private func isCorrect(_ q: ConjugationQuestion) -> Bool {
        picked == q.answer || (q.alsoCorrect != nil && picked == q.alsoCorrect)
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("\(correct) / \(questionsPerRound)")
                .font(.system(size: 46, weight: .bold).monospacedDigit())
                .foregroundColor(accent)
            Text(verdict)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.appText)
            AccentActionButton(title: "Another round", icon: "arrow.clockwise", color: accent) {
                begin(force: true)
            }
            Spacer()
        }
        .padding(24)
    }

    private var verdict: String {
        let pct = Double(correct) / Double(questionsPerRound)
        switch pct {
        case 1:        return "Perfect."
        case 0.8...:   return "Strong — the endings are sticking."
        case 0.6..<0.8: return "Getting there. Watch the negatives."
        default:       return "Worth a slow pass through the conjugation tables."
        }
    }

    // MARK: - Generation

    private func begin(force: Bool = false) {
        if pool.isEmpty { pool = DictionaryService.shared.conjugableEntries() }
        guard force || question == nil else { return }
        asked = 0
        correct = 0
        finished = false
        picked = nil
        question = makeQuestion()
    }

    private func next() {
        picked = nil
        asked += 1
        if asked >= questionsPerRound {
            finished = true
        } else {
            question = makeQuestion()
        }
    }

    /// Builds one question, retrying if a word happens not to yield four distinct
    /// forms (short verbs can collapse several endings onto the same string).
    private func makeQuestion() -> ConjugationQuestion? {
        for _ in 0..<40 {
            guard let entry = pool.randomElement(),
                  let sections = ConjugationEngine.conjugate(
                    word: entry.word, reading: entry.reading,
                    partsOfSpeech: entry.partsOfSpeech) else { continue }

            // Flatten every form this word has, then pick a target.
            var all: [(section: String, label: String, value: String, alt: String?)] = []
            for s in sections {
                for r in s.rows where !r.value.isEmpty {
                    all.append((s.title, r.label, r.value, r.alt))
                }
            }
            guard let target = all.randomElement() else { continue }

            // Distractors: other forms of the same word, never equal to the answer.
            let others = all
                .filter { $0.value != target.value && $0.value != target.alt }
                .map(\.value)
            let distractors = Array(Set(others)).shuffled().prefix(3)
            guard distractors.count == 3 else { continue }

            let group = entry.partsOfSpeech.first {
                ["godan verb", "ichidan verb", "suru verb", "kuru verb",
                 "i-adjective", "na-adjective"].contains($0)
            } ?? "verb"

            return ConjugationQuestion(
                word: entry.word,
                reading: entry.reading,
                meaning: entry.definitions.first ?? "",
                group: group,
                sectionTitle: target.section,
                formLabel: target.label,
                answer: target.value,
                choices: (distractors + [target.value]).shuffled(),
                alsoCorrect: target.alt
            )
        }
        return nil
    }
}
