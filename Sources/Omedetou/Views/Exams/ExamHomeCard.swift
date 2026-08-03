import SwiftUI

// The home screen's headline: what test is next, and how you're doing.
// This is what the streak flame used to be, pointed at competence instead of
// attendance — missing a day costs nothing, and the only way forward is a grade.

struct ExamHomeCard: View {
    @EnvironmentObject private var cardStore: CardStore
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var exams = ExamStore.shared

    var body: some View {
        _ = themeManager.current
        let accent = Color.readableOnPage(.appAccent)

        return Group {
            if let lesson = exams.currentLesson {
                NavigationLink {
                    StudyListView(lesson: lesson)
                } label: {
                    bar(accent: accent, lesson: lesson)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    ReportCardView()
                } label: {
                    simpleBar(accent: accent, icon: "checkmark.seal.fill",
                              title: "Every test cleared",
                              detail: exams.gpa.map { "GPA \(String(format: "%.2f", $0))" } ?? "")
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { exams.ensureCurrentDeadline() }
    }

    private func bar(accent: Color, lesson: ExamLesson) -> some View {
        let availability = exams.availability(of: lesson)
        let best = exams.effectiveGrade(for: lesson.id)

        let title: String
        let detail: String
        let icon: String

        switch availability {
        case .due(let date):
            title = "Next test \(date.deadlineDuePhrase)"
            detail = lesson.title
            icon = "calendar"
        case .overdue:
            title = "Overdue — scoring 0"
            detail = lesson.title
            icon = "exclamationmark.triangle.fill"
        case .open:
            title = best == nil ? "Test ready" : "Retake ready"
            detail = lesson.title
            icon = "square.and.pencil"
        case .levelLocked(let level):
            title = "Finish \(level)"
            detail = "Tests are locked until then"
            icon = "lock.fill"
        }

        return HStack(spacing: 12) {
            ZStack {
                Circle().stroke(accent.opacity(0.22), lineWidth: 3)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(accent)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(accent.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let gpa = exams.gpa {
                VStack(spacing: 0) {
                    Text(String(format: "%.2f", gpa))
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundColor(accent)
                    Text("GPA")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(accent.opacity(0.6))
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accent.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color.appBackgroundEnd.opacity(0.66)))
        .background(Capsule().fill(accent.opacity(0.14)))
        .overlay(Capsule().strokeBorder(accent.opacity(0.85), lineWidth: 1.5))
        .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1).padding(4))
    }

    private func simpleBar(accent: Color, icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(accent)
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 11, weight: .medium))
                        .foregroundColor(accent.opacity(0.75))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accent.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color.appBackgroundEnd.opacity(0.66)))
        .background(Capsule().fill(accent.opacity(0.14)))
        .overlay(Capsule().strokeBorder(accent.opacity(0.85), lineWidth: 1.5))
        .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1).padding(4))
    }
}
