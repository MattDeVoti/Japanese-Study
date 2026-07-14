import SwiftUI

struct GrammarMenuView: View {
    // How many questions each pronunciation drill draws per run (from an 80-question bank).
    private let pronunciationSessionLength = 20

    @State private var hiraQuestions: [PracticeQuestion] = []
    @State private var kataQuestions: [PracticeQuestion] = []

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
                    SectionGroup(header: "Quizzes") {
                        EmptyView()
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
                    .fill(color)
                    .frame(width: 34, height: 34)
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
            .background(Color.appBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(12)
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
                        .fill(badgeColor)
                        .frame(width: 34, height: 34)
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
