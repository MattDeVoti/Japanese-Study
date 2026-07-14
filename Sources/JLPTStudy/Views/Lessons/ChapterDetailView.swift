import SwiftUI

struct ChapterDetailView: View {
    let summary: ChapterSummary
    let accentColor: Color

    @State private var chapter: LessonChapter?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let chapter = chapter {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(chapter.points) { point in
                            if point.pointType == "kana" {
                                KanaCharacterCard(point: point, chapterId: summary.id, accentColor: accentColor)
                            } else {
                                GrammarPointCard(point: point, chapterId: summary.id, accentColor: accentColor)
                            }
                        }

                        // Chapter-level practice (used by kana lessons)
                        if let practice = chapter.chapterPractice, !practice.isEmpty {
                            NavigationLink {
                                GrammarPracticeView(
                                    pointName: chapter.title,
                                    questions: practice,
                                    accentColor: accentColor
                                )
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil.and.list.clipboard")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Practice This Lesson")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(accentColor)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }

                        if let vocab = chapter.vocab, !vocab.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Vocabulary", systemImage: "character.book.closed")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.top, 8)

                                ForEach(vocab) { word in
                                    VocabWordRow(word: word, accentColor: accentColor)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            } else {
                ProgressView()
            }
        }
        .standardNavBar(summary.title)
        .onAppear {
            if chapter == nil {
                chapter = LessonsService.shared.loadChapter(summary.id)
            }
        }
    }
}

// MARK: - Grammar point card

struct GrammarPointCard: View {
    let point: GrammarPoint
    let chapterId: String
    let accentColor: Color

    @State private var isExpanded = false
    @ObservedObject private var store = LessonsProgressStore.shared

    private var isFavorite: Bool { store.isFavorite(chapterId: chapterId, pointId: point.id) }
    private var isCompleted: Bool { store.isCompleted(chapterId: chapterId, pointId: point.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 0) {

                // Left side — tapping expands/collapses
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor)
                            .frame(width: 4)
                            .frame(minHeight: 38)

                        VStack(alignment: .leading, spacing: 4) {
                            FuriganaText(text: point.name, fontSize: 16, weight: .semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(point.shortDescription)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                // Favorite star
                Button {
                    store.toggleFavorite(chapterId: chapterId, pointId: point.id)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 15))
                        .foregroundColor(isFavorite ? .yellow : Color.secondary.opacity(0.45))
                }
                .buttonStyle(.plain)

                // Completed circle-check
                Button {
                    store.toggleCompleted(chapterId: chapterId, pointId: point.id)
                } label: {
                    ZStack {
                        Circle()
                            .stroke(isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)

                // Chevron — also toggles expand
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Expanded body
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 16) {

                    // Formation
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(title: "Formation", icon: "chevron.left.forwardslash.chevron.right")
                        Text(point.formation)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(accentColor.opacity(0.08))
                            .cornerRadius(7)
                    }

                    // Explanation
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(title: "Explanation", icon: "text.alignleft")
                        Text(point.explanation)
                            .font(.system(size: 14))
                            .foregroundColor(.appText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Rules
                    if !point.rules.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel(title: "Key Rules", icon: "list.bullet")
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(point.rules, id: \.self) { rule in
                                    HStack(alignment: .top, spacing: 7) {
                                        Text("•")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(accentColor)
                                        Text(rule)
                                            .font(.system(size: 13))
                                            .foregroundColor(.appText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    // Examples
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(title: "Examples", icon: "text.bubble")
                        VStack(spacing: 8) {
                            ForEach(point.examples.indices, id: \.self) { i in
                                ExampleCard(example: point.examples[i])
                            }
                        }
                    }

                    // Practice button — only rendered when questions exist
                    if let questions = point.practice, !questions.isEmpty {
                        NavigationLink {
                            GrammarPracticeView(
                                pointName: point.name,
                                questions: questions,
                                accentColor: accentColor
                            )
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Practice")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accentColor)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appBackground)
                .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - Shared subviews

struct SectionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

struct ExampleCard: View {
    let example: GrammarExample

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            FuriganaText(text: example.japanese, fontSize: 15)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(example.romaji)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .italic()
            Text(example.english)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}

struct VocabWordRow: View {
    let word: LessonVocabWord
    let accentColor: Color

    var body: some View {
        NavigationLink {
            VocabDictionaryView(word: word)
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            // Part-of-speech pill
            Text(word.partOfSpeech)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(accentColor.opacity(0.12))
                .cornerRadius(5)
                .fixedSize()

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(word.kanji)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appText)
                    if word.kanji != word.kana {
                        Text(word.kana)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    Text(word.romaji)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(word.definition)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.appBackground)
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - Vocab → dictionary bridge

/// Shows the dictionary entry for a tapped vocab word. If the bundled dictionary
/// doesn't contain the word, an entry is synthesized from the lesson's own data
/// so every vocab word still opens a useful detail page.
struct VocabDictionaryView: View {
    private let entry: DictionaryEntry

    init(word: LessonVocabWord) {
        // Every lesson vocab word now has a real entry in dictionary.db, so this
        // resolves to a normal dictionary entry. The inline fallback is only a
        // safety net for any word that hasn't been added to the dictionary yet.
        entry = DictionaryService.shared.entry(word: word.kanji, reading: word.kana)
            ?? DictionaryEntry(
                id: -1,
                word: word.kanji,
                reading: word.kanji == word.kana ? nil : word.kana,
                definitions: [word.definition],
                partsOfSpeech: [word.partOfSpeech],
                sortKeyEn: "",
                sortKeyJp: ""
            )
    }

    var body: some View {
        DictionaryDetailView(entry: entry)
    }
}
