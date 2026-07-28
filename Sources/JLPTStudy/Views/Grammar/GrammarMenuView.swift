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

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {

                    // MARK: Kana pronunciation drills
                    TileSection(header: "Kana Pronunciation", columns: columns) {
                        StudyTile(title: "Hiragana", subtitle: "Sounds & readings",
                                  glyph: "ひ", icon: "waveform", color: .hiraganaColor) {
                            GrammarPracticeView(pointName: "Hiragana Practice", questions: hiraQuestions,
                                                accentColor: .hiraganaColor, sessionLimit: pronunciationSessionLength)
                        }
                        StudyTile(title: "Katakana", subtitle: "Sounds & readings",
                                  glyph: "カ", icon: "waveform", color: .katakanaColor) {
                            GrammarPracticeView(pointName: "Katakana Practice", questions: kataQuestions,
                                                accentColor: .katakanaColor, sessionLimit: pronunciationSessionLength)
                        }
                    }

                    // MARK: Flashcards
                    TileSection(header: "Flashcards", columns: columns) {
                        StudyTile(title: "Vocab", subtitle: "Flash cards",
                                  glyph: "語", icon: "rectangle.stack.fill", color: .vocabColor) {
                            VocabFlashcardsView()
                        }
                        StudyTile(title: "Kanji", subtitle: "Flash cards",
                                  glyph: "漢", icon: "rectangle.stack.fill", color: .kanjiColor) {
                            KanjiStudyView()
                        }
                    }

                    // MARK: Quizzes
                    TileSection(header: "Grammar Quizzes", columns: columns) {
                        ForEach([5, 4, 3, 2, 1], id: \.self) { level in
                            StudyTile(title: levelName(level), subtitle: "Tell similar points apart",
                                      glyph: "\(levelNumber(level))", icon: "checklist",
                                      color: nLevelColor(level)) {
                                GrammarPracticeView(pointName: "\(levelName(level)) Grammar",
                                                    questions: grammarQuizzes[level] ?? [],
                                                    accentColor: nLevelColor(level),
                                                    sessionLimit: grammarQuizSessionLength)
                            }
                        }
                    }

                    // MARK: Reading comprehension
                    TileSection(header: "Reading", columns: columns) {
                        StudyTile(title: "Reading", subtitle: "Passages & questions",
                                  glyph: "読", icon: "book.fill", color: Color(hex: "0EA5E9")) {
                            ReadingListView()
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
        }
    }
}

// MARK: - Square study tile

/// A saturated square tile: gradient fill, an oversized translucent glyph
/// bleeding off the corner, a type icon, and the label stack at the bottom.
private struct StudyTile<Destination: View>: View {
    let title: String
    let subtitle: String
    let glyph: String
    let icon: String
    let color: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Base
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(color.badgeGradient)

                // Oversized watermark glyph, just kissing the bottom-right corner
                Text(glyph)
                    .font(.system(size: 92, weight: .black))
                    .foregroundColor(.white.opacity(0.18))
                    .offset(x: 12, y: 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                // Soft highlight sweep across the top-left
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                         startPoint: .topLeading, endPoint: .center))

                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.22)))

                    Spacer(minLength: 6)

                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.38), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section wrapper

private struct TileSection<Content: View>: View {
    let header: String
    let columns: [GridItem]
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(header)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.appText)
                .padding(.horizontal, 2)

            LazyVGrid(columns: columns, spacing: 12) {
                content()
            }
        }
    }
}
