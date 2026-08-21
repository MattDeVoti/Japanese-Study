import SwiftUI

// Sitting a test. No feedback until the end — it's an exam, not a drill. The
// full paper is read back afterwards, with every miss explained.

struct ExamView: View {
    let lesson: ExamLesson

    @EnvironmentObject private var cardStore: CardStore
    @ObservedObject private var exams = ExamStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var questions: [ExamQuestion] = []
    @State private var answers: [String: Int] = [:]      // question id -> chosen index
    @State private var index = 0
    @State private var submitted = false
    @State private var result: ExamAttempt?
    @State private var missedCount = 0
    @State private var showQuestionList = false

    private var accent: Color { .themeTile(11) }

    var body: some View {
        ZStack {
            AppBackground()

            if questions.isEmpty {
                ProgressView()
            } else if submitted, let result {
                ExamResultView(lesson: lesson, attempt: result, questions: questions,
                               answers: answers, missedCount: missedCount)
            } else {
                paper
            }
        }
        .standardNavBar(lesson.title)
        .onAppear {
            if questions.isEmpty {
                questions = ExamBuilder.build(for: lesson, cardStore: cardStore)
            }
        }
    }

    // MARK: - Paper

    private var current: ExamQuestion { questions[min(index, questions.count - 1)] }

    private var allAnswered: Bool {
        !questions.isEmpty && questions.allSatisfy { answers[$0.id] != nil }
    }

    /// Where Next goes: the first blank question after this one, wrapping past
    /// the end to catch anything skipped on the way down.
    ///
    /// Nil only when the last blank question is the one already on screen —
    /// there is nowhere to send you, so Next greys out and answering it turns
    /// the button into Submit.
    private var nextUnanswered: Int? {
        guard !questions.isEmpty else { return nil }
        let order = (index + 1..<questions.count).map { $0 } + (0..<index).map { $0 }
        return order.first { answers[questions[$0].id] == nil }
    }

    private var paper: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Readings set above the kanji, as everywhere else in the
                    // app — but only when the question carries them. A question
                    // *about* a reading has no markup, and must stay bare.
                    JapaneseText(text: current.prompt, fontSize: 17,
                                 color: .appText, weight: .semibold)

                    if let subject = current.subject, !subject.isEmpty {
                        JapaneseText(text: subject, fontSize: subjectSize,
                                     color: .appText, weight: .bold, alignment: .center)
                            .padding(.vertical, 6)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(current.choices.enumerated()), id: \.offset) { i, choice in
                            choiceRow(i, choice)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }

            footer
        }
    }

    /// Single kanji and kana get set large; sentences do not.
    private var subjectSize: CGFloat {
        guard let s = current.subject else { return 20 }
        if s.count <= 2 { return 76 }
        return s.count > 18 ? 18 : 24
    }

    private func choiceRow(_ i: Int, _ choice: String) -> some View {
        let picked = answers[current.id] == i
        return Button {
            // A test doesn't mark anything until it is handed in, so the cue
            // here is the neutral one: it confirms the tap without hinting at
            // whether the answer was right.
            FeedbackSounds.shared.play(.notification)
            answers[current.id] = i
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(picked ? accent : Color.appHairline, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if picked { Circle().fill(accent).frame(width: 12, height: 12) }
                }
                JapaneseText(text: choice, fontSize: 16, color: .appText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(picked ? accent.opacity(0.12) : Color.appSurface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(picked ? accent : Color.appHairline, lineWidth: picked ? 1.8 : 1))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text(current.section.label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(current.section.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(current.section.color.opacity(0.15))
                    .cornerRadius(6)
                Spacer()
                Text("\(index + 1) / \(questions.count)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(.appTextSecondary)
                Text("· \(answers.count) answered")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
            ProgressView(value: Double(answers.count), total: Double(questions.count))
                .tint(accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                if index > 0 { index -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(index > 0 ? accent : .appTextSecondary.opacity(0.4))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.appSurface))
            }
            .buttonStyle(.plain)
            .disabled(index == 0)

            if allAnswered {
                AccentActionButton(title: "Submit", icon: "checkmark", color: accent) {
                    submit()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Next never runs out: past the last question it doubles back to
                // whatever is still blank, so the only way to reach Submit is to
                // have answered everything.
                AccentActionButton(title: "Next", icon: "chevron.right", color: accent) {
                    if let next = nextUnanswered { index = next }
                }
                .frame(maxWidth: .infinity)
                .disabled(nextUnanswered == nil)
                .opacity(nextUnanswered == nil ? 0.45 : 1)
            }

            // Jump to any question. Sized to match the back button so the
            // primary action sits centred between two equal circles.
            Button { showQuestionList = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.appSurface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("All questions")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .sheet(isPresented: $showQuestionList) {
            ExamQuestionList(questions: questions, answers: answers,
                             current: index, accent: accent) { picked in
                index = picked
                showQuestionList = false
            }
        }
    }

    // MARK: - Marking

    private func submit() {
        FeedbackSounds.shared.play(.complete)
        var perSection: [ExamSection: (correct: Int, total: Int)] = [:]
        var missed: [ExamQuestion] = []

        for q in questions {
            var entry = perSection[q.section] ?? (0, 0)
            entry.total += 1
            if answers[q.id] == q.correctIndex { entry.correct += 1 } else { missed.append(q) }
            perSection[q.section] = entry
        }

        let correct = perSection.values.reduce(0) { $0 + $1.correct }
        let total = max(perSection.values.reduce(0) { $0 + $1.total }, 1)
        let grade = Grade(percent: Double(correct) / Double(total) * 100)

        let attempt = ExamAttempt(
            lessonId: lesson.id, takenAt: Date(), grade: grade,
            sections: ExamSection.allCases.compactMap { section in
                guard let e = perSection[section] else { return nil }
                return ExamAttempt.SectionScore(section: section, correct: e.correct, total: e.total)
            })

        exams.record(attempt)

        // Distinct items missed, for the result screen's summary line.
        missedCount = Set(missed.compactMap(\.reviewItem?.id)).count
        result = attempt
        withAnimation { submitted = true }
    }
}

// MARK: - Question list

/// Every question in the test, with the answer you gave under each one you've
/// answered. Tapping a row jumps straight to it.
///
/// Only the chosen answer is shown, never the other options: this is a way to
/// find your place and check what you put, and listing all four choices would
/// turn it into a second, scrollable copy of the test.
private struct ExamQuestionList: View {
    let questions: [ExamQuestion]
    let answers: [String: Int]
    let current: Int
    let accent: Color
    let onPick: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(questions.enumerated()), id: \.element.id) { i, q in
                            row(i, q)
                                .id(i)
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(AppBackground())
                .onAppear { proxy.scrollTo(current, anchor: .center) }
            }
            .navigationTitle("\(answers.count) of \(questions.count) answered")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { FeedbackSounds.shared.playNavigate(); dismiss() }.fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color.appNavBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    /// Furigana markup reads as noise at this size — 二時[にじ] rather than 二時.
    private func plain(_ text: String?) -> String {
        guard let text else { return "" }
        return text.replacingOccurrences(of: "\\[[^\\]]*\\]", with: "",
                                         options: .regularExpression)
    }

    private func row(_ i: Int, _ q: ExamQuestion) -> some View {
        let chosen = answers[q.id].flatMap { q.choices.indices.contains($0) ? plain(q.choices[$0]) : nil }
        return Button { onPick(i) } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(i + 1)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(chosen == nil ? .appTextSecondary : .white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(chosen == nil ? Color.appSurfaceHigh : accent))

                VStack(alignment: .leading, spacing: 3) {
                    // The subject is the Japanese being asked about; the prompt
                    // alone ("What does this mean?") wouldn't tell them apart.
                    // Furigana markup is stripped — these rows are one line each.
                    Text(plain(q.subject).isEmpty ? q.prompt : plain(q.subject))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let chosen {
                        Text(chosen)
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Not answered")
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary.opacity(0.7))
                            .italic()
                    }
                }
                Spacer(minLength: 4)
                if i == current {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accent)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(i == current ? accent.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
