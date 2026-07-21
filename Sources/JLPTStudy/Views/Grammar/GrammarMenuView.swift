import SwiftUI

struct GrammarMenuView: View {
    // How many questions each pronunciation drill draws per run (from an 80-question bank).
    private let pronunciationSessionLength = 20
    // How many questions each grammar quiz draws per run (from an ~84-question bank).
    private let grammarQuizSessionLength = 20

    @State private var hiraQuestions: [PracticeQuestion] = []
    @State private var kataQuestions: [PracticeQuestion] = []
    // Grammar discrimination quizzes, keyed by JLPT level (5 = N5 … 1 = N1).
    @State private var grammarQuizzes: [Int: [PracticeQuestion]] = [:]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Kana pronunciation drills
                    SectionGroup(header: "Kana Pronunciation") {
                        KanaPracticeRow(
                            title: "Hiragana Practice",
                            subtitle: "Sounds, letters & word readings",
                            badge: "ひ",
                            color: .hiraganaColor,
                            questions: hiraQuestions,
                            sessionLimit: pronunciationSessionLength
                        )
                        Divider().padding(.leading, 16)
                        KanaPracticeRow(
                            title: "Katakana Practice",
                            subtitle: "Sounds, letters & word readings",
                            badge: "カ",
                            color: .katakanaColor,
                            questions: kataQuestions,
                            sessionLimit: pronunciationSessionLength
                        )
                    }

                    // MARK: Flashcards
                    SectionGroup(header: "Flashcards") {
                        StudyMenuRow(label: "Vocab Flash Cards", badge: "語", badgeColor: .vocabColor) {
                            VocabFlashcardsView()
                        }
                        Divider().padding(.leading, 16)
                        StudyMenuRow(label: "Kanji Flash Cards", badge: "漢", badgeColor: .kanjiColor) {
                            KanjiStudyView()
                        }
                    }

                    // MARK: Quizzes
                    SectionGroup(header: "Grammar Quizzes") {
                        ForEach([5, 4, 3, 2, 1], id: \.self) { level in
                            if level != 5 {
                                Divider().padding(.leading, 16)
                            }
                            GrammarQuizRow(
                                level: level,
                                questions: grammarQuizzes[level] ?? [],
                                sessionLimit: grammarQuizSessionLength
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
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
        }
    }
}

// MARK: - Kana pronunciation drill row

private struct KanaPracticeRow: View {
    let title: String
    let subtitle: String
    let badge: String
    let color: Color
    let questions: [PracticeQuestion]
    let sessionLimit: Int

    var body: some View {
        NavigationLink {
            GrammarPracticeView(
                pointName: title,
                questions: questions,
                accentColor: color,
                sessionLimit: sessionLimit
            )
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(color.badgeGradient)
                    .frame(width: 34, height: 34)
                    .shadow(color: color.opacity(0.35), radius: 4, y: 2)
                    .overlay(
                        Text(badge)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(.appText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Grammar quiz row

private struct GrammarQuizRow: View {
    let level: Int          // 5 = N5 … 1 = N1
    let questions: [PracticeQuestion]
    let sessionLimit: Int

    private var color: Color { nLevelColor(level) }

    var body: some View {
        NavigationLink {
            GrammarPracticeView(
                pointName: "\(levelName(level)) Grammar",
                questions: questions,
                accentColor: color,
                sessionLimit: sessionLimit
            )
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(color.badgeGradient)
                    .frame(width: 34, height: 34)
                    .shadow(color: color.opacity(0.35), radius: 4, y: 2)
                    .overlay(
                        Text("\(levelNumber(level))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(levelName(level)) Grammar")
                        .font(.system(size: 17))
                        .foregroundColor(.appText)
                    Text("Tell similar grammar points apart")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subviews

private struct SectionGroup<Content: View>: View {
    let header: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .appCard(cornerRadius: 16)
        }
    }
}

private struct StudyMenuRow<Destination: View>: View {
    let label: String
    var badge: String? = nil
    var badgeColor: Color = .secondary
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                if let badge {
                    Circle()
                        .fill(badgeColor.badgeGradient)
                        .frame(width: 34, height: 34)
                        .shadow(color: badgeColor.opacity(0.35), radius: 4, y: 2)
                        .overlay(
                            Text(badge)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                Text(label)
                    .font(.system(size: 17))
                    .foregroundColor(.appText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
