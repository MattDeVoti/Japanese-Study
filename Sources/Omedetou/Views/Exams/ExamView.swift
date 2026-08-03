import SwiftUI

// Sitting a test. No feedback until the end — it's an exam, not a drill. The
// full paper is reviewed afterwards, with every miss explained and pushed into
// the review schedule.

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
    @State private var showConfirmSubmit = false

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

    private var paper: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(current.prompt)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subject = current.subject, !subject.isEmpty {
                        Group {
                            if subject.contains("[") {
                                FuriganaText(text: subject, fontSize: subjectSize,
                                             color: .appText, weight: .bold, alignment: .center)
                                    .frame(height: subjectSize * 2.2)
                            } else {
                                Text(subject)
                                    .font(.system(size: subjectSize, weight: .bold))
                                    .foregroundColor(.appText)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                            }
                        }
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
            answers[current.id] = i
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(picked ? accent : Color.appHairline, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if picked { Circle().fill(accent).frame(width: 12, height: 12) }
                }
                if choice.contains("[") {
                    FuriganaText(text: choice, fontSize: 16, color: .appText)
                        .frame(height: 40)
                } else {
                    Text(choice)
                        .font(.system(size: 16))
                        .foregroundColor(.appText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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

            if index == questions.count - 1 {
                AccentActionButton(title: "Submit", icon: "checkmark", color: accent) {
                    if answers.count < questions.count { showConfirmSubmit = true }
                    else { submit() }
                }
                .frame(maxWidth: .infinity)
            } else {
                AccentActionButton(title: "Next", icon: "chevron.right", color: accent) {
                    index += 1
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .confirmationDialog("Submit with \(questions.count - answers.count) unanswered?",
                            isPresented: $showConfirmSubmit, titleVisibility: .visible) {
            Button("Submit anyway", role: .destructive) { submit() }
            Button("Keep working", role: .cancel) {}
        } message: {
            Text("Unanswered questions are marked wrong.")
        }
    }

    // MARK: - Marking

    private func submit() {
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

        // Everything missed goes into the review schedule, so preparing for the
        // retake is exactly what reviewing does.
        var enrolled = Set<String>()
        for q in missed {
            guard let item = q.reviewItem, !enrolled.contains(item.storageKey) else { continue }
            SRSStore.shared.grade(item, .again)
            enrolled.insert(item.storageKey)
        }
        missedCount = enrolled.count
        result = attempt
        withAnimation { submitted = true }
    }
}
