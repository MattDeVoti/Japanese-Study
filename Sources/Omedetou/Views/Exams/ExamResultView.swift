import SwiftUI

/// The mark sheet: grade, per-section breakdown, what it unlocked (or didn't),
/// and every question you missed with the answer.
struct ExamResultView: View {
    let lesson: ExamLesson
    let attempt: ExamAttempt
    let questions: [ExamQuestion]
    let answers: [String: Int]
    let missedCount: Int

    @ObservedObject private var exams = ExamStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showPaper = false

    private var grade: Grade { attempt.grade }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                gradeBlock
                verdict
                sections

                if missedCount > 0 {
                    // Says what actually happens. Missed items used to be queued
                    // into a review deck; that deck is gone, and the line stayed
                    // behind promising something the app no longer does.
                    Label("\(missedCount) item\(missedCount == 1 ? "" : "s") missed — each one is in Review the paper below",
                          systemImage: "list.bullet.rectangle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.appSurface))
                }

                actions

                DisclosureGroup(isExpanded: $showPaper) {
                    VStack(spacing: 12) {
                        ForEach(questions) { q in
                            reviewRow(q)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Text("Review the paper")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSurface))
                .onChange(of: showPaper) { _ in FeedbackSounds.shared.play(.slide) }
            }
            .padding(20)
        }
    }

    // MARK: - Blocks

    private var gradeBlock: some View {
        VStack(spacing: 4) {
            Text(grade.letter)
                .font(.system(size: 86, weight: .bold, design: .rounded))
                .foregroundColor(grade.color(clearing: lesson.requiredMark))
            Text("\(Int(grade.percent.rounded()))%")
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundColor(.appTextSecondary)
            Text(lesson.title)
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var verdict: some View {
        let text: String
        let icon: String
        if grade.meets(lesson.requiredMark) {
            text = lesson.isTestOut
                ? "Cleared. \(lesson.levelId) is done — you can move straight on."
                : "Cleared. This lesson no longer holds \(lesson.levelId) back."
            icon = "checkmark.seal.fill"
        } else if grade.isPass {
            let owed = exams.lessonsBelowAdvance(in: lesson.levelId).count
            text = "Passed, but below \(lesson.requiredLetter). \(owed) lesson\(owed == 1 ? "" : "s") in \(lesson.levelId) still need a B before the next level opens."
            icon = "exclamationmark.triangle.fill"
        } else {
            text = "Below the pass mark. Take it again whenever you're ready, or move on and come back to it."
            icon = "xmark.seal.fill"
        }
        return Label(text, systemImage: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(grade.color(clearing: lesson.requiredMark))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(grade.color(clearing: lesson.requiredMark).opacity(0.12)))
    }

    private var sections: some View {
        VStack(spacing: 10) {
            ForEach(attempt.sections, id: \.section) { s in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(s.section.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appText)
                        Spacer()
                        Text("\(s.correct)/\(s.total)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundColor(s.section.color)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.appHairline).frame(height: 7)
                            Capsule().fill(s.section.color)
                                .frame(width: geo.size.width * (s.percent / 100), height: 7)
                        }
                    }
                    .frame(height: 7)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.appSurface))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            AccentActionButton(title: "Back to the report card", icon: "list.clipboard") {
                dismiss()
            }
            .frame(maxWidth: .infinity)

            if !grade.isPass {
                Button {
                    exams.skip(lesson.id)
                    dismiss()
                } label: {
                    Text("Skip this lesson and move on")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .underline()
                }
                .buttonStyle(.plain)
                Text("The grade stays on your report card, and this lesson still needs a B before \(lesson.levelId) is finished.")
                    .font(.system(size: 11))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func reviewRow(_ q: ExamQuestion) -> some View {
        let chosen = answers[q.id]
        let right = chosen == q.correctIndex
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(right ? Color(hex: "22C55E") : Color(hex: "EF4444"))
                VStack(alignment: .leading, spacing: 4) {
                    JapaneseText(text: q.prompt, fontSize: 13,
                                 color: .appText, weight: .semibold)
                    if let s = q.subject, !s.isEmpty {
                        JapaneseText(text: s, fontSize: 15, color: .appText)
                    }
                    if !right {
                        if let chosen, q.choices.indices.contains(chosen) {
                            // Split from its label so the answer itself can carry
                            // furigana: interpolating it into a Text would print
                            // the markup as brackets.
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("You said:")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "EF4444"))
                                JapaneseText(text: q.choices[chosen], fontSize: 12,
                                             color: Color(hex: "EF4444"))
                            }
                        } else {
                            Text("Unanswered")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "EF4444"))
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Answer:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "22C55E"))
                            JapaneseText(text: q.correctAnswer, fontSize: 12,
                                         color: Color(hex: "22C55E"), weight: .semibold)
                        }
                    }
                    if let e = q.explanation, !right {
                        JapaneseText(text: e, fontSize: 11, color: .appTextSecondary)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(right ? Color.appSurfaceHigh : Color(hex: "EF4444").opacity(0.08)))
    }
}
