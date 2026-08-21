import SwiftUI

struct GrammarPracticeView: View {
    let pointName: String
    let questions: [PracticeQuestion]
    let accentColor: Color
    var sessionLimit: Int = 5   // how many questions to draw per run

    @State private var currentIndex = 0
    @State private var selectedAnswer: Int? = nil
    @State private var score = 0
    @State private var isDone = false
    @State private var shuffledQuestions: [PracticeQuestion] = []
    @State private var shuffledChoices: [String] = []
    @State private var shuffledCorrectIndex: Int = 0

    @Environment(\.dismiss) private var dismiss

    private var currentQuestion: PracticeQuestion? {
        guard currentIndex < shuffledQuestions.count else { return nil }
        return shuffledQuestions[currentIndex]
    }

    private func setupQuestion() {
        guard currentIndex < shuffledQuestions.count else { return }
        let q = shuffledQuestions[currentIndex]
        let order = (0..<q.choices.count).shuffled()
        shuffledChoices = order.map { q.choices[$0] }
        shuffledCorrectIndex = order.firstIndex(of: q.correctIndex) ?? 0
    }

    var body: some View {
        ZStack {
            AppBackground()

            if isDone {
                PracticeScoreView(
                    score: score,
                    total: shuffledQuestions.count,
                    accentColor: accentColor,
                    onDone: { FeedbackSounds.shared.playNavigate(); dismiss() }
                )
            } else if let q = currentQuestion {
                VStack(spacing: 0) {
                    // Sits directly under the nav bar, so it needs its own top
                    // inset to avoid reading as part of the bar.
                    Text("Practice only — this doesn't affect your grade.")
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                        .padding(.bottom, 8)

                    PracticeProgressBar(
                        current: currentIndex,
                        total: shuffledQuestions.count,
                        color: accentColor
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {

                            // Question card — numbered badge, prompt, and the
                            // Japanese sentence it's asking about
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 10) {
                                    Text("\(currentIndex + 1)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(accentColor.badgeGradient))
                                        .shadow(color: accentColor.opacity(0.35), radius: 4, y: 2)

                                    Text("Question \(currentIndex + 1) of \(shuffledQuestions.count)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.appTextSecondary)
                                }

                                FuriganaText(text: q.prompt, fontSize: 19, weight: .semibold)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let japanese = q.japanese {
                                    FuriganaText(text: japanese, fontSize: 22, alignment: .center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(accentColor.opacity(0.12))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(accentColor.opacity(0.28), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appCard(cornerRadius: 20)

                            // Answer choices
                            VStack(spacing: 10) {
                                ForEach(shuffledChoices.indices, id: \.self) { i in
                                    PracticeChoiceButton(
                                        index: i,
                                        text: shuffledChoices[i],
                                        selectedAnswer: selectedAnswer,
                                        correctIndex: shuffledCorrectIndex,
                                        accentColor: accentColor
                                    ) {
                                        guard selectedAnswer == nil else { return }
                                        // The card turns green or red on the same
                                        // tap, so the cue is telling you what you
                                        // can already see — it just gets there first.
                                        if i == shuffledCorrectIndex {
                                            FeedbackSounds.shared.playCorrectVariation()
                                        } else {
                                            FeedbackSounds.shared.play(.incorrect)
                                        }
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedAnswer = i
                                            if i == shuffledCorrectIndex { score += 1 }
                                        }
                                    }
                                }
                            }

                            // Explanation + Next (shown after answering)
                            if selectedAnswer != nil {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Explanation", systemImage: "lightbulb")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.appTextSecondary)
                                        .textCase(.uppercase)

                                    FuriganaText(text: q.explanation, fontSize: 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.appSurface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.appHairline, lineWidth: 1)
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))

                                Button {
                                    // Moving through the quiz is navigation, and
                                    // gets the same click as moving between screens.
                                    FeedbackSounds.shared.playNavigate()
                                    if currentIndex + 1 < shuffledQuestions.count {
                                        currentIndex += 1
                                        selectedAnswer = nil
                                        setupQuestion()
                                    } else {
                                        isDone = true
                                    }
                                } label: {
                                    Text(currentIndex + 1 < shuffledQuestions.count ? "Next Question" : "See Results")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(accentColor.badgeGradient)
                                        )
                                        .shadow(color: accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .standardNavBar(pointName)
        .onAppear {
            shuffledQuestions = Array(questions.shuffled().prefix(sessionLimit))
            setupQuestion()
        }
    }
}

// MARK: - Progress bar

private struct PracticeProgressBar: View {
    let current: Int
    let total: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 5)
                Capsule()
                    .fill(color)
                    .frame(
                        width: total > 0 ? geo.size.width * CGFloat(current) / CGFloat(total) : 0,
                        height: 5
                    )
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Choice button

private struct PracticeChoiceButton: View {
    let index: Int
    let text: String
    let selectedAnswer: Int?
    let correctIndex: Int
    let accentColor: Color
    let onTap: () -> Void

    private let labels = ["A", "B", "C", "D"]

    private enum ChoiceState { case idle, correct, wrong }

    private var state: ChoiceState {
        guard let selected = selectedAnswer else { return .idle }
        if index == correctIndex { return .correct }
        if index == selected { return .wrong }
        return .idle
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(labels[index])
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(badgeTextColor)
                    .frame(width: 28, height: 28)
                    .background(badgeBg)
                    .clipShape(Circle())

                FuriganaText(
                    text: text,
                    fontSize: 14,
                    color: state == .idle ? .primary : .white
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                if let _ = selectedAnswer {
                    if state == .correct {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    } else if state == .wrong {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedAnswer != nil)
    }

    private var badgeTextColor: Color {
        state == .idle ? accentColor : .white
    }

    private var badgeBg: Color {
        switch state {
        case .idle:    return accentColor.opacity(0.12)
        case .correct: return .green
        case .wrong:   return .red
        }
    }

    private var rowBg: Color {
        switch state {
        case .idle:    return .appSurface
        case .correct: return .green
        case .wrong:   return .red
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:    return Color.appHairline
        case .correct: return .green
        case .wrong:   return .red
        }
    }
}

// MARK: - Score summary

private struct PracticeScoreView: View {
    let score: Int
    let total: Int
    let accentColor: Color
    let onDone: () -> Void

    private var pct: Double { Double(score) / Double(max(total, 1)) }

    private var medal: String {
        if pct >= 0.8 { return "star.fill" }
        if pct >= 0.6 { return "hand.thumbsup.fill" }
        return "arrow.clockwise"
    }

    private var message: String {
        if pct >= 0.8 { return "Great work!" }
        if pct >= 0.6 { return "Good effort!" }
        return "Keep practicing!"
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: medal)
                .font(.system(size: 60))
                .foregroundColor(pct >= 0.8 ? .yellow : accentColor)

            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.appText)
                Text("\(score) / \(total) correct")
                    .font(.system(size: 17))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}
