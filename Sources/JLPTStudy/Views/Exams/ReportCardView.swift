import SwiftUI

// The permanent record. Every lesson, every grade, every level's standing —
// including the failures, which stay visible even after they've been rescued.

/// The Study menu's entry to the report card.
///
/// Deliberately not an `AestheticTile`: every other tile in Study is a gradient
/// square that opens a drill, so a thirteenth one would read as another quiz.
/// This is a document — ruled paper, a masthead, your GPA and your latest marks —
/// so it's obvious at a glance that it's a record rather than an exercise.
struct ReportCardButton: View {
    @ObservedObject private var exams = ExamStore.shared

    /// The most recent marks, newest first.
    private var recent: [ExamAttempt] {
        Array(exams.attempts.sorted { $0.takenAt > $1.takenAt }.prefix(5))
    }

    private var currentLevelLine: String {
        guard let lesson = exams.currentLesson else { return "Every test cleared" }
        let owed = exams.lessonsBelowAdvance(in: lesson.levelId).count
        let name = lesson.levelId.hasPrefix("N") ? levelName(jlpt: lesson.levelId) : lesson.levelId
        return owed == 0 ? name : "\(name) · \(owed) below B"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Masthead
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("REPORT CARD")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.6)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.6)
            }
            .foregroundColor(.appText.opacity(0.75))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appText.opacity(0.06))

            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 1) {
                    // With no marks yet a heavy accent em-dash reads as a struck-out
                    // number, so the empty state is quieter than a real GPA.
                    if let gpa = exams.gpa {
                        Text(String(format: "%.2f", gpa))
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(.appAccent)
                    } else {
                        Text("––")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.appTextSecondary.opacity(0.5))
                            .frame(height: 41)
                    }
                    Text("GPA")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                        .foregroundColor(.appTextSecondary)
                }
                .frame(minWidth: 74)

                Rectangle()
                    .fill(Color.appHairline)
                    .frame(width: 1, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(exams.attempts.isEmpty ? 0 : Set(exams.attempts.map(\.lessonId)).count) of \(exams.gradedTrack.count) tests taken")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appText)
                    Text(currentLevelLine)
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)

                    if recent.isEmpty {
                        Text("No marks yet")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                    } else {
                        HStack(spacing: 4) {
                            ForEach(recent) { a in
                                // A B clears a lesson but not a test-out, so each
                                // chip is coloured against its own paper's bar.
                                let mark = exams.lesson(id: a.lessonId)?.requiredMark
                                    ?? Grade.standardMark
                                Text(a.grade.letter)
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(a.grade.color(clearing: mark))
                                    .frame(minWidth: 22)
                                    .padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: 4)
                                        .fill(a.grade.color(clearing: mark).opacity(0.16)))
                            }
                        }
                        .padding(.top, 1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            ZStack {
                Color.appSurface
                RuledPaper()          // faint lines, so it reads as a document
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.appHairline, lineWidth: 1)
        )
    }
}

/// Evenly spaced hairlines — the one texture in the app that isn't a woven motif,
/// because it's standing in for paper rather than fabric.
private struct RuledPaper: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            var y: CGFloat = 16
            while y < size.height {
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                y += 16
            }
            ctx.stroke(p, with: .color(.white.opacity(0.045)), lineWidth: 0.75)
        }
        .allowsHitTesting(false)
    }
}

struct ReportCardView: View {
    @EnvironmentObject private var cardStore: CardStore
    @ObservedObject private var exams = ExamStore.shared
    @ObservedObject private var srs = SRSStore.shared
    @State private var expanded: Set<String> = []
    @State private var sitting: ExamLesson?

    var body: some View {
        ZStack {
            PatternedBackground(.study)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    overallCard
                    reviewsRow

                    ForEach(exams.levelOrder, id: \.self) { level in
                        levelSection(level)
                    }

                    Text("A lesson needs a B or better to stop holding its level back, and a test-out needs an A. Miss a deadline and that test scores 0 until you sit it. You can read any chapter in the Textbook at any time — only the tests follow the order.")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .standardNavBar("Report Card")
        .onAppear { exams.ensureCurrentDeadline() }
        .fullScreenCover(item: $sitting) { lesson in
            NavigationStack { ExamView(lesson: lesson) }
        }
    }

    // MARK: - Overall

    private var overallCard: some View {
        let graded = exams.gradedTrack.filter { exams.effectiveGrade(for: $0.id) != nil }.count
        return HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(exams.gpa.map { String(format: "%.2f", $0) } ?? "—")
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(.appAccent)
                Text("GPA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
            Divider().frame(height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(graded) of \(exams.gradedTrack.count) tests taken")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)
                let cleared = exams.levelOrder.filter { exams.isLevelCleared($0) }.count
                Text("\(cleared) level\(cleared == 1 ? "" : "s") complete")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
    }

    /// Reviews are prep for these tests, so they hang off the record rather than
    /// sitting in the Study grid as if they were another drill.
    private var reviewsRow: some View {
        NavigationLink {
            ReviewSessionView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appAccent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.appAccent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reviews")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appText)
                    Text(reviewDetail)
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
        }
        .buttonStyle(.plain)
    }

    private var reviewDetail: String {
        srs.enrolledCount > 0
            ? "A few cards on what you've been getting wrong"
            : "Builds as you study and take tests"
    }

    // MARK: - Levels

    private func levelSection(_ level: String) -> some View {
        let lessons = exams.lessons(in: level)
        let unlocked = exams.isLevelUnlocked(level)
        let cleared = exams.isLevelCleared(level)
        let owed = exams.lessonsBelowAdvance(in: level).count
        let isOpen = expanded.contains(level)

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if isOpen { expanded.remove(level) } else { expanded.insert(level) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: cleared ? "checkmark.seal.fill"
                                     : unlocked ? "book.fill" : "lock.fill")
                        .font(.system(size: 15))
                        .foregroundColor(cleared ? Color(hex: "22C55E")
                                         : unlocked ? .appAccent : .appTextSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(levelTitle(level))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.appText)
                        Text(status(level, unlocked: unlocked, cleared: cleared, owed: owed))
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                    }
                    Spacer()
                    if let g = exams.gpa(level: level) {
                        Text(String(format: "%.2f", g))
                            .font(.system(size: 15, weight: .bold).monospacedDigit())
                            .foregroundColor(.appTextSecondary)
                    }
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.appTextSecondary)
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 8) {
                    ForEach(lessons) { lesson in
                        lessonRow(lesson, levelUnlocked: unlocked)
                    }
                    if let out = exams.testOut(for: level) {
                        testOutRow(out, levelUnlocked: unlocked)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
    }

    private func levelTitle(_ level: String) -> String {
        level.hasPrefix("N") ? levelName(jlpt: level) : level
    }

    private func status(_ level: String, unlocked: Bool, cleared: Bool, owed: Int) -> String {
        if cleared { return "Complete" }
        if !unlocked {
            let prior = exams.levelOrder.prefix(while: { $0 != level }).last
            return "Opens when \(prior.map(levelTitle) ?? "the previous level") is finished"
        }
        let taken = exams.lessons(in: level).filter { exams.effectiveGrade(for: $0.id) != nil }.count
        return "\(taken)/\(exams.lessons(in: level).count) taken · \(owed) still need B"
    }

    private func lessonRow(_ lesson: ExamLesson, levelUnlocked: Bool) -> some View {
        let best = exams.effectiveGrade(for: lesson.id)
        let attempts = exams.attempts(for: lesson.id)
        let failed = exams.hasFailedAttempt(for: lesson.id)
        let availability = exams.availability(of: lesson)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if attempts.isEmpty {
                        Text(availabilityLabel(availability))
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                    } else {
                        Text("\(attempts.count) attempt\(attempts.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                        // A rescued failure stays on the record.
                        if failed, best?.isPass == true {
                            Text("· earlier fail")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "EF4444").opacity(0.9))
                        }
                        if exams.skipped.contains(lesson.id) {
                            Text("· skipped")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            if let best {
                Text(best.letter)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(best.color(clearing: lesson.requiredMark))
                    .frame(minWidth: 34)
            }

            if levelUnlocked {
                Button { sitting = lesson } label: {
                    Text(best == nil ? "Take" : "Retake")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.readableOnPage(.appAccent))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Color.appAccent.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(Color.appAccent.opacity(0.7), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.appSurfaceHigh))
    }

    private func availabilityLabel(_ a: ExamStore.Availability) -> String {
        switch a {
        case .open:                return "Ready to take"
        case .due(let date):       return "Due \(date.deadlineLabel)"
        case .overdue(let date):   return "Missed \(date.deadlineLabel) — scoring 0"
        case .levelLocked:         return "Locked"
        }
    }

    /// The optional shortcut past a whole syllabary, set apart from the parts so
    /// it's clear it isn't just another one of them.
    @ViewBuilder
    private func testOutRow(_ lesson: ExamLesson, levelUnlocked: Bool) -> some View {
        let best = exams.effectiveGrade(for: lesson.id)
        let cleared = exams.clears(lesson)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: cleared ? "checkmark.seal.fill" : "figure.walk.motion")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(cleared ? Color(hex: "22C55E") : .appAccent)
                Text(lesson.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appText)
                Spacer()
                if let best {
                    Text(best.letter)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(best.color(clearing: lesson.requiredMark))
                }
            }
            Text(lesson.coverage)
                .font(.system(size: 11))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if levelUnlocked && !cleared {
                Button { sitting = lesson } label: {
                    Text("Take the full test")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.readableOnPage(.appAccent))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.appAccent.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(Color.appAccent.opacity(0.7), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(Color.appAccent.opacity(cleared ? 0.06 : 0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.appAccent.opacity(0.35),
                          style: StrokeStyle(lineWidth: 1, dash: cleared ? [] : [5, 4])))
    }
}
