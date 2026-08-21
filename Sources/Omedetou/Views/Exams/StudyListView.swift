import SwiftUI

// What's on the next test, available for the whole run-up. Everything the paper
// can draw from, in one place, with links into the textbook.

struct StudyListView: View {
    let lesson: ExamLesson

    @EnvironmentObject private var cardStore: CardStore
    @ObservedObject private var progress = LessonsProgressStore.shared
    @ObservedObject private var vocabFilter = VocabFlashcardsFilter.shared
    @ObservedObject private var exams = ExamStore.shared
    @State private var sitting: ExamLesson?

    private var chapters: [LessonChapter] {
        lesson.chapterIds.compactMap { LessonsService.shared.loadChapter($0) }
    }

    var body: some View {
        ZStack {
            PatternedBackground(.study)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    banner

                    testOutCard

                    chapterLinks

                    VStack(alignment: .leading, spacing: 3) {
                        Text("What to review")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appText)
                        Text("Everything below is fair game on the test.")
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, 2)

                    ForEach(chapters, id: \.id) { chapter in
                        chapterBlock(chapter)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .standardNavBar("On the test")
        .fullScreenCover(item: $sitting) { l in
            NavigationStack { ExamView(lesson: l) }
        }
    }

    private var banner: some View {
        let a = exams.availability(of: lesson)
        return VStack(alignment: .leading, spacing: 10) {
            Text(lesson.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.appText)

            Text(weighting)
                .font(.system(size: 13))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            switch a {
            case .open:
                AccentActionButton(title: "Take the test", icon: "square.and.pencil") {
                    sitting = lesson
                }
                .frame(maxWidth: .infinity)
            case .due(let date):
                Label("You have until \(date.deadlineLabel) to complete this test",
                      systemImage: "calendar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appTextSecondary)
                AccentActionButton(title: "Take the test", icon: "square.and.pencil") {
                    sitting = lesson
                }
                .frame(maxWidth: .infinity)
            case .overdue(let date):
                Label("The deadline (\(date.deadlineLabel)) has passed — this is scoring 0 until you take it",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "EF4444"))
                    .fixedSize(horizontal: false, vertical: true)
                AccentActionButton(title: "Take the test now", icon: "square.and.pencil") {
                    sitting = lesson
                }
                .frame(maxWidth: .infinity)
            case .levelLocked(let level):
                Label("Finish \(level) first", systemImage: "lock.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
    }

    // MARK: - Straight to the chapter

    /// The lesson itself, one tap away.
    ///
    /// Everything below this point is a *list* of what the paper can ask —
    /// useful for checking off, useless for actually learning something you've
    /// forgotten. This is the way back to the teaching: the explanations,
    /// examples and diagrams the summary can only name. A kana part covers
    /// several chapters, so each gets its own row.
    @ViewBuilder
    private var chapterLinks: some View {
        if !chapters.isEmpty {
            VStack(spacing: 8) {
                ForEach(chapters, id: \.id) { chapter in
                    NavigationLink {
                        if let summary = LessonsService.shared.chapterSummary(for: chapter.id) {
                            ChapterDetailView(summary: summary, accentColor: accent(for: chapter.id))
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(accent(for: chapter.id))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(accent(for: chapter.id).opacity(0.15)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(chapters.count > 1 ? chapter.title : "Study this chapter")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.appText)
                                Text(chapters.count > 1
                                     ? "Chapter \(chapter.chapterNumber)"
                                     : "\(chapter.title) — grammar, vocab and kanji in full")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appTextSecondary)
                                    .lineLimit(1)
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
            }
        }
    }

    private func accent(for chapterId: String) -> Color {
        levelAccentColor(LessonsService.shared.levelId(for: chapterId) ?? lesson.levelId)
    }

    // MARK: - Test out

    /// Only the syllabaries offer a way past the whole section, so this appears
    /// only on a kana part — never on a grammar chapter, and never on the
    /// test-out's own page. Styled like its counterpart on the report card, with
    /// a dashed edge to mark it as the optional route rather than the next step.
    @ViewBuilder
    private var testOutCard: some View {
        if lesson.kind == .kanaChunk,
           let out = exams.testOut(for: lesson.levelId),
           !exams.clears(out) {

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 14, weight: .bold))
                    Text("Already know all of \(lesson.levelId)?")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.appAccent)

                Text(testOutBlurb)
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button { sitting = out } label: {
                    Text("Test out of \(lesson.levelId)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.readableOnPage(.appAccent))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Color.appAccent.opacity(0.16)))
                        .overlay(Capsule().strokeBorder(Color.appAccent.opacity(0.75), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.appAccent.opacity(0.09)))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.appAccent.opacity(0.42),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
    }

    private var testOutBlurb: String {
        let base = "Skip the three parts and sit one \(ExamBuilder.kanaTestOutLength)-question paper "
            + "covering every \(lesson.levelId) character."
        guard let next = nextLevelName else {
            return base + " Score an A and \(lesson.levelId) is done."
        }
        return base + " Score an A and \(lesson.levelId) is done — straight on to \(next)."
    }

    /// What clearing this level opens up, for the blurb.
    private var nextLevelName: String? {
        guard let i = exams.levelOrder.firstIndex(of: lesson.levelId),
              i + 1 < exams.levelOrder.count else { return nil }
        let next = exams.levelOrder[i + 1]
        return next.hasPrefix("N") ? levelName(jlpt: next) : next
    }

    private func relative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: Date())
    }

    private var weighting: String {
        if lesson.usesKanaBuilder {
            let n = lesson.isTestOut ? ExamBuilder.kanaTestOutLength : ExamBuilder.kanaChunkLength
            return "\(lesson.coverage). \(n) questions, drawn fresh each attempt."
        }
        guard let ch = chapters.first else { return "" }
        var parts: [String] = []
        if !ch.points.isEmpty { parts.append("\(ch.points.count) grammar points") }
        if let v = ch.vocab, !v.isEmpty { parts.append("\(v.count) words") }
        if let k = ch.kanji, !k.isEmpty { parts.append("\(k.count) kanji") }
        return parts.joined(separator: " · ")
            + ". \(ExamBuilder.standardLength) questions, drawn fresh each attempt."
    }

    // MARK: - Chapter content

    @ViewBuilder
    private func chapterBlock(_ chapter: LessonChapter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if chapters.count > 1 {
                Text(chapter.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.appText)
            }

            if !chapter.points.isEmpty {
                let isKana = chapter.points.first?.isKanaCharacter == true
                section(isKana ? "Characters" : "Grammar",
                        isKana ? .hiraganaColor : .grammarColor) {
                    ForEach(chapter.points, id: \.id) { p in
                        NavigationLink {
                            ChapterDetailView(summary: summary(for: chapter),
                                              accentColor: .grammarColor)
                        } label: {
                            itemRow(title: p.name, subtitle: p.shortDescription,
                                    done: progress.isCompleted(chapterId: chapter.id, pointId: p.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let vocab = chapter.vocab, !vocab.isEmpty {
                section("Vocab (\(vocab.count))", .vocabColor) {
                    ForEach(vocab.prefix(60), id: \.id) { w in
                        itemRow(title: "\(w.kanji)   \(w.kana)", subtitle: w.definition,
                                done: vocabFilter.isExcluded(w.id))
                    }
                }
            }

            let kanjiWords = chapter.kanjiWords ?? []
            if !kanjiWords.isEmpty {
                section("Kanji Words (\(kanjiWords.count))", .kanjiColor) {
                    ForEach(kanjiWords.prefix(60)) { w in
                        itemRow(title: "\(w.word)   \(w.kana)", subtitle: w.meaning,
                                done: cardStore.isKanjiExcluded(w.id))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
    }

    private func summary(for chapter: LessonChapter) -> ChapterSummary {
        LessonsService.shared.chapterSummary(for: chapter.id)
            ?? ChapterSummary(id: chapter.id, chapterNumber: chapter.chapterNumber,
                              title: chapter.title, pointCount: chapter.points.count,
                              chapterType: nil)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, _ color: Color,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundColor(color)
            content()
        }
        .padding(.top, 4)
    }

    private func itemRow(title: String, subtitle: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(done ? Color(hex: "22C55E") : .appTextSecondary.opacity(0.4))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appText)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
