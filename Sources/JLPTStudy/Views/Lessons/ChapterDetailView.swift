import SwiftUI

struct ChapterDetailView: View {
    let summary: ChapterSummary
    let accentColor: Color
    /// When set (from a Textbook search hit), that point opens expanded and is
    /// scrolled into view.
    var focusPointId: String? = nil

    @EnvironmentObject private var cardStore: CardStore
    @State private var chapter: LessonChapter?
    @State private var query = ""

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Case-insensitive match of the in-lesson query against any of the given fields.
    private func matches(_ fields: [String]) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return fields.contains { $0.lowercased().contains(q) }
    }

    private func pointMatches(_ p: GrammarPoint) -> Bool {
        matches([p.name, p.shortDescription, p.formation, p.explanation] + p.rules)
    }

    private func wordMatches(_ w: LessonVocabWord) -> Bool {
        matches([w.kanji, w.kana, w.romaji, w.definition, w.partOfSpeech])
    }

    private func kanjiMatches(_ k: String) -> Bool {
        let card = cardStore.kanjiCard(for: k)
        let readings = ((card?.onyomi ?? []) + (card?.kunyomi ?? [])).flatMap { [$0.kana, $0.romaji] }
        return matches([k, card?.definition ?? ""] + readings)
    }

    var body: some View {
        ZStack {
            AppBackground()

            if let chapter = chapter {
                let points = chapter.points.filter(pointMatches)
                let vocab = (chapter.vocab ?? []).filter(wordMatches)
                let kanjiChars = (chapter.kanji ?? []).filter(kanjiMatches)

                VStack(spacing: 0) {
                    SearchBar(text: $query, placeholder: "Search this lesson…")

                    if isSearching && points.isEmpty && vocab.isEmpty && kanjiChars.isEmpty {
                        noMatches
                    } else {
                        chapterBody(chapter, points: points, vocab: vocab, kanjiChars: kanjiChars)
                    }
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

    private var noMatches: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Nothing in this lesson matches “\(query)”.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func chapterBody(_ chapter: LessonChapter, points: [GrammarPoint],
                             vocab: [LessonVocabWord], kanjiChars: [String]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(points) { point in
                        Group {
                            if point.pointType == "kana" {
                                KanaCharacterCard(point: point, chapterId: summary.id, accentColor: accentColor)
                            } else {
                                GrammarPointCard(point: point, chapterId: summary.id, accentColor: accentColor,
                                                 initiallyExpanded: point.id == focusPointId)
                                    .addToCustomLesson(.grammar(chapterId: summary.id, pointId: point.id, title: point.name))
                            }
                        }
                        .id(point.id)
                    }

                    // Chapter-level practice (used by kana lessons) — hidden while searching
                    if !isSearching, let practice = chapter.chapterPractice, !practice.isEmpty {
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

                        if !vocab.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Vocabulary", systemImage: "character.book.closed")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.top, 8)

                                ForEach(vocab) { word in
                                    VocabWordRow(word: word, accentColor: accentColor)
                                        .addToCustomLesson(.vocab(id: word.id, title: word.kanji))
                                }

                                if !isSearching {
                                    NavigationLink {
                                        VocabFlashcardsView(lockedChapter: LockedVocabChapter(
                                            id: summary.id, number: summary.chapterNumber,
                                            title: chapter.title, accent: accentColor))
                                    } label: {
                                        StudyButtonLabel(title: "Study Vocab", accent: accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // Kanji for this chapter (same N-level), shown below the vocab.
                        if !kanjiChars.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Kanji", systemImage: "character.textbox")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.top, 8)

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 78), spacing: 8)],
                                    alignment: .leading, spacing: 8
                                ) {
                                    ForEach(kanjiChars, id: \.self) { kc in
                                        if let card = cardStore.kanjiCard(for: kc) {
                                            KanjiExcludeCell(card: card)
                                                .addToCustomLesson(.kanji(char: card.kanji))
                                        }
                                    }
                                }

                                if !isSearching {
                                    NavigationLink {
                                        KanjiStudyView(lockedChapter: LockedKanjiChapter(
                                            title: chapter.title, kanji: kanjiChars))
                                    } label: {
                                        StudyButtonLabel(title: "Study Kanji", accent: accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 4)
                                }
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onAppear {
                // Arriving from a Textbook search hit — bring that point into view.
                guard let focus = focusPointId else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation { proxy.scrollTo(focus, anchor: .top) }
                }
            }
        }
    }
}

// MARK: - Chapter kanji cell + exclude checkmark

/// A chapter's kanji tile: taps through to the kanji detail and carries the green
/// "exclude from flashcards" checkmark. Shared by chapters and custom lessons.
struct KanjiExcludeCell: View {
    let card: KanjiCard
    @EnvironmentObject private var cardStore: CardStore

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                KanjiCardDetailView(card: card)
            } label: {
                ChapterKanjiCell(card: card)
            }
            .buttonStyle(.plain)

            Button {
                cardStore.toggleKanjiExcluded(cardId: card.id)
            } label: {
                Image(systemName: cardStore.isKanjiExcluded(card.id) ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 15))
                    .foregroundColor(cardStore.isKanjiExcluded(card.id) ? .green : Color.secondary.opacity(0.45))
                    .padding(3)
                    .background(Circle().fill(Color.appSurface))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
}

struct ChapterKanjiCell: View {
    let card: KanjiCard

    private var gloss: String {
        card.definition
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? card.definition
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(card.kanji)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(nLevelColor(card.nLevel))
            Text(gloss)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.appHairline, lineWidth: 1)
        )
    }
}

// MARK: - Grammar point card

struct GrammarPointCard: View {
    let point: GrammarPoint
    let chapterId: String
    let accentColor: Color

    @State private var isExpanded: Bool
    @ObservedObject private var store = LessonsProgressStore.shared

    init(point: GrammarPoint, chapterId: String, accentColor: Color, initiallyExpanded: Bool = false) {
        self.point = point
        self.chapterId = chapterId
        self.accentColor = accentColor
        _isExpanded = State(initialValue: initiallyExpanded)
    }

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
                        FuriganaText(text: point.formation, fontSize: 14, color: accentColor, weight: .medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(accentColor.opacity(0.08))
                            .cornerRadius(7)
                    }

                    // Explanation
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(title: "Explanation", icon: "text.alignleft")
                        ExplanationBody(text: point.explanation, fontSize: 14, color: .appText, bulletColor: accentColor)
                    }

                    // Visual aid (only the handful of points that have one)
                    if let visual = GrammarVisual.forPoint(point.id) {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel(title: "Diagram", icon: "map")
                            visual.view(accent: accentColor)
                        }
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
                                        FuriganaText(text: rule, fontSize: 13, color: .appText)
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
        .appCard(cornerRadius: 16)
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
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.appSurfaceHigh)
        )
    }
}

/// Accent-filled button used below a chapter's vocab / kanji to open flashcards
/// scoped to just that chapter.
struct StudyButtonLabel: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(accent)
        .cornerRadius(12)
    }
}

struct VocabWordRow: View {
    let word: LessonVocabWord
    let accentColor: Color
    @ObservedObject private var vocabFilter = VocabFlashcardsFilter.shared

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                VocabDictionaryView(word: word)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)

            Button {
                vocabFilter.toggleExcluded(word.id)
            } label: {
                Image(systemName: vocabFilter.isExcluded(word.id) ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(vocabFilter.isExcluded(word.id) ? .green : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.appHairline, lineWidth: 1)
        )
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

            Spacer(minLength: 4)
        }
        .contentShape(Rectangle())
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
