import SwiftUI

struct GrammarMenuView: View {
    // How many questions each pronunciation drill draws per run (from an 80-question bank).
    private let pronunciationSessionLength = 20
    // How many questions each grammar quiz draws per run (from an ~84-question bank).
    private let grammarQuizSessionLength = 20

    @State private var hiraQuestions: [PracticeQuestion] = []
    @State private var kataQuestions: [PracticeQuestion] = []
    // Grammar discrimination quizzes, keyed by level (5 = N5 … 1 = N1).
    @State private var grammarQuizzes: [Int: [PracticeQuestion]] = [:]
    @State private var slangQuestions: [PracticeQuestion] = []

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    @ObservedObject private var exams = ExamStore.shared

    var body: some View {
        ZStack {
            PatternedBackground(.study)

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {

                    // MARK: Progress
                    // One entry, shaped like a document rather than a drill tile.
                    // Reviews live inside it — the home bar surfaces them when any
                    // are due, and they're test prep rather than a drill of their own.
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Progress")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appText)
                            .padding(.horizontal, 2)
                        NavigationLink {
                            ReportCardView()
                        } label: {
                            ReportCardButton()
                        }
                        .buttonStyle(.plain)

                        // The report card is the only thing on this screen tied to
                        // the graded track. Everything below it is practice.
                        Text("Only the tests on your report card count towards your "
                             + "grade. Everything else in Study is practice — drill "
                             + "it as much as you like, nothing here changes your GPA.")
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 2)
                            .padding(.top, 2)
                    }

                    // MARK: Kana pronunciation drills
                    SectionStack(header: "Kana Pronunciation") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            NavigationLink {
                                GrammarPracticeView(pointName: "Hiragana Practice", questions: hiraQuestions,
                                                    accentColor: .hiraganaColor, sessionLimit: pronunciationSessionLength)
                            } label: {
                                KanaSoundTile(character: "あ", title: "Hiragana", color: .hiraganaColor)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                GrammarPracticeView(pointName: "Katakana Practice", questions: kataQuestions,
                                                    accentColor: .katakanaColor, sessionLimit: pronunciationSessionLength)
                            } label: {
                                KanaSoundTile(character: "ア", title: "Katakana", color: .katakanaColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // MARK: Flashcards
                    SectionStack(header: "Flashcards") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            NavigationLink { VocabFlashcardsView() } label: {
                                VocabDeckTile(color: .themeTile(5))
                            }
                            .buttonStyle(.plain)
                            .locked(true, feature: "Vocabulary flashcards")

                            NavigationLink { KanjiStudyView() } label: {
                                KanjiFlipTile(color: .themeTile(7))
                            }
                            .buttonStyle(.plain)
                            .locked(true, feature: "Kanji flashcards")
                        }
                    }

                    // MARK: Conjugation & reading
                    // Full width rather than squares: both animate, and the motion
                    // needs room to read.
                    SectionStack(header: "Practice") {
                        VStack(spacing: 12) {
                            NavigationLink { ConjugationDrillView() } label: {
                                ConjugationTile(color: .themeTile(2))
                            }
                            .buttonStyle(.plain)
                            .locked(true, feature: "Conjugation drills")

                            NavigationLink { ReadingListView() } label: {
                                ReadingTile(color: .themeTile(10))
                            }
                            .buttonStyle(.plain)
                            .locked(true, feature: "Reading passages")

                            NavigationLink { KanjiMatchView() } label: {
                                KanjiMatchTile(color: .themeTile(6))
                            }
                            .buttonStyle(.plain)
                            .locked(true, feature: "The kanji matcher")
                        }
                    }
                    // MARK: Grammar quizzes
                    // One per line at the same size as Conjugation and Reading.
                    SectionStack(header: "Grammar Quizzes") {
                        VStack(spacing: 12) {
                            ForEach([5, 4, 3, 2, 1], id: \.self) { level in
                                NavigationLink {
                                    GrammarPracticeView(pointName: "\(levelName(level)) Grammar",
                                                        questions: grammarQuizzes[level] ?? [],
                                                        accentColor: nLevelColor(level),
                                                        sessionLimit: grammarQuizSessionLength)
                                } label: {
                                    LevelQuizTile(level: level)
                                }
                                .buttonStyle(.plain)
                                .locked(true, feature: "\(levelName(level)) grammar quiz")
                            }

                            // Slang has no authored quiz bank, so its questions are
                            // pooled from the slang chapters' own practice sets.
                            NavigationLink {
                                GrammarPracticeView(pointName: "Slang",
                                                    questions: slangQuestions,
                                                    accentColor: SlangContent.accent,
                                                    sessionLimit: grammarQuizSessionLength)
                            } label: {
                                LevelQuizTile(title: "Slang",
                                              subtitle: "Test your knowledge of Slang",
                                              bigMark: "俗",
                                              color: SlangContent.accent,
                                              phase: 5.1)
                            }
                            .locked(true, feature: "The slang quiz")
                            .buttonStyle(.plain)
                        }
                    }

                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
        }
        .standardNavBar("Study")
        .onAppear {
            if hiraQuestions.isEmpty {
                hiraQuestions = LessonsService.shared.loadQuestionBank("hiragana_pronunciation")
            }
            if kataQuestions.isEmpty {
                kataQuestions = LessonsService.shared.loadQuestionBank("katakana_pronunciation")
            }
            if grammarQuizzes.isEmpty {
                for level in 1...5 {
                    grammarQuizzes[level] = LessonsService.shared.loadQuestionBank("grammar_quiz_n\(level)")
                }
            }
            if slangQuestions.isEmpty {
                LessonsService.shared.loadIfNeeded()
                let chapters = LessonsService.shared.manifest?.levels
                    .first { $0.levelId == SlangContent.levelId }?.chapters ?? []
                slangQuestions = chapters
                    .compactMap { LessonsService.shared.loadChapter($0.id) }
                    .flatMap { ch in
                        ch.points.flatMap { $0.practice ?? [] } + (ch.chapterPractice ?? [])
                    }
            }
        }
    }
}

// MARK: - Section wrapper

private struct SectionStack<Content: View>: View {
    let header: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(header)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.appText)
                .padding(.horizontal, 2)
            content()
        }
    }
}
