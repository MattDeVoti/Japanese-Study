import SwiftUI

/// Identifies a chapter when the vocab flashcards are opened from a lesson's
/// "Study Vocab" button — the pool auto-filters to just that chapter's words.
struct LockedVocabChapter {
    let id: String
    let number: Int
    let title: String
    let accent: Color
}

struct VocabFlashcardsView: View {
    /// When set, this is a chapter's "Study Vocab" session (pool locked to the
    /// chapter). When nil, it's the global Study-section vocab flashcards.
    var lockedChapter: LockedVocabChapter? = nil

    @ObservedObject private var filter = VocabFlashcardsFilter.shared
    @State private var allCards: [VocabFlashCard] = []
    @State private var current: VocabFlashCard?
    @State private var isRevealed = false
    @State private var isLoading = true
    @State private var showFilter = false
    /// Weight mode for a locked chapter session — independent of the Study section.
    @State private var lockedWeightMode: WeightMode = .none
    @Namespace private var wordNS

    /// The chapter's word ids (locked mode only) — used to scope "clear checkmarks".
    private var chapterWordIds: [String] { lockedChapter == nil ? [] : allCards.map(\.word.id) }

    private var pool: [VocabFlashCard] {
        lockedChapter == nil
            ? filter.apply(to: allCards)
            : allCards.filter { !filter.isExcluded($0.word.id) }
    }

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    ProgressView()
                }
                .vocabNavBar(title: "Vocab Flash Cards", filter: filter, showFilter: $showFilter, locked: lockedChapter, chapterWordIds: chapterWordIds, weightMode: $lockedWeightMode, onAfterClear: { pickNext() })
            } else if let card = current {
                cardView(card)
            } else {
                emptyState
            }
        }
        .onAppear(perform: load)
        .onChange(of: filter.selectedChapterIds) { _ in if lockedChapter == nil { pickNext() } }
        .onChange(of: filter.selectedWordIds) { _ in if lockedChapter == nil { pickNext() } }
        .onChange(of: filter.showFavoritesOnly) { _ in if lockedChapter == nil { pickNext() } }
        .onChange(of: lockedWeightMode) { _ in pickNext() }
        .sheet(isPresented: $showFilter) {
            VocabFilterSheet(filter: filter, allCards: allCards)
        }
    }

    // MARK: - Card

    private func cardView(_ card: VocabFlashCard) -> some View {
        let isFav = filter.isFavorite(card.word.id)
        let isExcluded = filter.isExcluded(card.word.id)

        // Word block, shared by both faces so it slides between them.
        let wordBlock = VStack(spacing: 10) {
            Text(card.word.partOfSpeech)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(card.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(card.accentColor.opacity(0.12))
                .cornerRadius(6)

            Text(card.word.kanji)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)

            if card.word.kanji != card.word.kana {
                Text(card.word.kana)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .matchedGeometryEffect(id: "word", in: wordNS)

        return ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed top bar: favorite + checkmark (stay put while the word slides)
                HStack {
                    Button {
                        filter.toggleFavorite(card.word.id)
                    } label: {
                        Image(systemName: isFav ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundColor(isFav ? .yellow : Color.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        filter.toggleExcluded(card.word.id)
                        pickNext()
                    } label: {
                        Image(systemName: isExcluded ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 26))
                            .foregroundColor(isExcluded ? .green : Color.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if isRevealed {
                    ScrollView {
                        VStack(spacing: 20) {
                            wordBlock
                                .padding(.top, 8)

                            // Answer box
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.word.romaji)
                                    .font(.system(size: 14))
                                    .foregroundColor(card.accentColor)
                                    .italic()
                                Text(card.word.definition)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.appText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(card.accentColor.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal, 24)
                            .transition(.opacity.animation(.easeIn(duration: 0.3).delay(0.2)))

                            // Chapter
                            Text("ch\(String(format: "%02d", card.chapterNumber))  \(card.chapterTitle)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(card.accentColor)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .transition(.opacity.animation(.easeIn(duration: 0.3).delay(0.2)))

                            Spacer().frame(height: 90)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer()

                        wordBlock

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                                isRevealed = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red.badgeGradient)
                                    .frame(width: 88, height: 88)
                                    .shadow(color: Color.red.opacity(0.40), radius: 10, x: 0, y: 4)
                                Text("Check")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)

                        Spacer()
                        Spacer().frame(height: 88)
                    }
                }
            }

            // Bottom bar
            HStack(spacing: 12) {
                Button { filter.markNeedsWork(card.word.id); pickNext() } label: {
                    Text("Don't Know")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.badgeGradient)
                                .shadow(color: Color.red.opacity(0.30), radius: 6, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)

                Button { filter.markConfident(card.word.id); pickNext() } label: {
                    Text("Got It")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.green.badgeGradient)
                                .shadow(color: Color.green.opacity(0.30), radius: 6, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
        }
        .vocabNavBar(title: card.word.kanji, filter: filter, showFilter: $showFilter, locked: lockedChapter, chapterWordIds: chapterWordIds, weightMode: $lockedWeightMode, onAfterClear: { pickNext() })
    }

    // MARK: - Empty

    private var emptyState: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "rectangle.stack.badge.minus")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No words match\nthe current filters.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                if filter.hasActiveFilter {
                    Button("Clear Filters") { filter.reset() }
                        .padding(.top, 4)
                }
                Spacer()
            }
        }
        .vocabNavBar(title: "Vocab Flash Cards", filter: filter, showFilter: $showFilter, locked: lockedChapter, chapterWordIds: chapterWordIds, weightMode: $lockedWeightMode, onAfterClear: { pickNext() })
    }

    // MARK: - Data

    private func load() {
        guard isLoading else { return }
        LessonsService.shared.loadIfNeeded()

        // Chapter "Study Vocab": pool is locked to this chapter's words.
        if let locked = lockedChapter {
            let words = LessonsService.shared.loadChapter(locked.id)?.vocab ?? []
            allCards = words.map { word in
                VocabFlashCard(word: word, chapterId: locked.id, chapterNumber: locked.number,
                               chapterTitle: locked.title, accentColor: locked.accent)
            }.shuffled()
            isLoading = false
            pickNext()
            return
        }

        guard let manifest = LessonsService.shared.manifest else { isLoading = false; return }

        var result: [VocabFlashCard] = []
        for level in manifest.levels {
            let lvlInt = Int(level.jlptLevel.dropFirst()) ?? 5
            let color = nLevelColor(lvlInt)
            for summary in level.chapters {
                guard let chapter = LessonsService.shared.loadChapter(summary.id),
                      let words = chapter.vocab else { continue }
                for word in words {
                    result.append(VocabFlashCard(
                        word: word,
                        chapterId: summary.id,
                        chapterNumber: summary.chapterNumber,
                        chapterTitle: chapter.title,
                        accentColor: color
                    ))
                }
            }
        }

        allCards = result.shuffled()
        isLoading = false
        syncCompletedChapters()
        pickNext()
    }

    /// Auto-selects the chapter filter for any lesson whose grammar points are all
    /// checked complete. One-way: lessons drive the filter, never the reverse.
    private func syncCompletedChapters() {
        guard let manifest = LessonsService.shared.manifest else { return }
        let store = LessonsProgressStore.shared
        let chaptersWithVocab = Set(allCards.map(\.chapterId))
        var completed: Set<String> = []
        for level in manifest.levels {
            for ch in level.chapters where chaptersWithVocab.contains(ch.id) {
                let pointIds = LessonsService.shared.pointIds(for: ch.id)
                if !pointIds.isEmpty && store.completedCount(chapterId: ch.id, among: pointIds) == pointIds.count {
                    completed.insert(ch.id)
                }
            }
        }
        filter.syncCompletedChapters(completed)
    }

    private func pickNext() {
        let p = pool
        guard !p.isEmpty else { current = nil; return }
        isRevealed = false
        current = lockedChapter == nil
            ? filter.selectWeighted(from: p)
            : filter.selectWeighted(from: p, mode: lockedWeightMode, strength: filter.weightStrength)
    }
}

// MARK: - Filter Sheet

private struct VocabFilterSheet: View {
    @ObservedObject var filter: VocabFlashcardsFilter
    let allCards: [VocabFlashCard]
    @Environment(\.dismiss) private var dismiss

    private var manifest: LessonManifest? { LessonsService.shared.manifest }

    // Only chapters that actually have vocab cards (kana chapters have none).
    private var chapterIdsWithCards: Set<String> { Set(allCards.map(\.chapterId)) }

    private var levelsWithVocab: [LessonLevel] {
        (manifest?.levels ?? []).filter { level in
            level.chapters.contains { chapterIdsWithCards.contains($0.id) }
        }
    }

    private var wordsInSelection: [VocabFlashCard] {
        guard !filter.selectedChapterIds.isEmpty else { return allCards }
        return allCards.filter { filter.selectedChapterIds.contains($0.chapterId) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Favorites
                    Toggle(isOn: $filter.showFavoritesOnly) {
                        Label("Favorites Only", systemImage: "star.fill")
                            .foregroundColor(.appText)
                    }
                    .tint(.yellow)

                    Divider()

                    weightedSection

                    Divider()

                    checkmarksSection

                    Divider()

                    chaptersSection

                    if !filter.selectedChapterIds.isEmpty {
                        Divider()
                        wordsSection
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") { filter.reset() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color.appNavBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Weighted shuffle

    private var weightedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weighted Shuffle")
                .font(.headline)
                .foregroundColor(.appText)

            Picker("", selection: $filter.weightMode) {
                ForEach(WeightMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if filter.weightMode != .none {
                HStack {
                    Text("Weight Strength")
                        .font(.subheadline)
                        .foregroundColor(.appText)
                    Spacer()
                    Text(String(format: "%.0f%%", filter.weightStrength * 100))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Slider(value: $filter.weightStrength, in: 0...1)
                    .tint(filter.weightMode == .harder ? .red : .green)
            }

            Text(weightHint)
                .font(.caption)
                .foregroundColor(.secondary)

            Button { filter.clearWeights() } label: {
                Text("Reset Study Weights")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }

    private var weightHint: String {
        switch filter.weightMode {
        case .none:   return "Words appear at random. Mark “Got It” / “Don’t Know” while studying to build up weights."
        case .harder: return "Words you mark “Don’t Know” appear more often."
        case .easier: return "Words you mark “Got It” appear more often."
        }
    }

    // MARK: - Checkmarks

    private var checkmarksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Checkmarks")
                .font(.headline)
                .foregroundColor(.appText)
            Text("Checked-off words are hidden from the flashcard lineup — here and in their chapter.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button { filter.clearExclusions() } label: {
                Text("Clear All Vocab Checkmarks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Chapters (grid of CH# squares)

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chapters")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                Text(filter.selectedChapterIds.isEmpty ? "All shown"
                                                       : "\(filter.selectedChapterIds.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(levelsWithVocab, id: \.jlptLevel) { level in
                levelBlock(level)
            }
        }
    }

    private func levelBlock(_ level: LessonLevel) -> some View {
        let color = nLevelColor(Int(level.jlptLevel.dropFirst()) ?? 5)
        let chapters = level.chapters.filter { chapterIdsWithCards.contains($0.id) }
        let allSelected = chapters.allSatisfy { filter.selectedChapterIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(levelName(jlpt: level.jlptLevel))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Button(allSelected ? "Deselect All" : "Select All") {
                    for c in chapters {
                        if allSelected { filter.selectedChapterIds.remove(c.id) }
                        else { filter.selectedChapterIds.insert(c.id) }
                    }
                    filter.selectedWordIds = []
                }
                .font(.caption)
                .foregroundColor(color)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                ForEach(chapters) { summary in
                    ChapterSquare(
                        number: summary.chapterNumber,
                        color: color,
                        selected: filter.selectedChapterIds.contains(summary.id)
                    ) {
                        if filter.selectedChapterIds.contains(summary.id) {
                            filter.selectedChapterIds.remove(summary.id)
                        } else {
                            filter.selectedChapterIds.insert(summary.id)
                        }
                        filter.selectedWordIds = []
                    }
                }
            }
        }
    }

    // MARK: - Words

    private var wordsSection: some View {
        let words = wordsInSelection
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Words")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                if !filter.selectedWordIds.isEmpty {
                    Button("Show All") { filter.selectedWordIds = [] }
                        .font(.caption)
                }
            }

            if words.count > 60 {
                Text("Select 5 or fewer chapters to filter individual words (\(words.count) words in current selection).")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(words) { card in
                    let selected = filter.selectedWordIds.isEmpty
                        || filter.selectedWordIds.contains(card.word.id)
                    Button {
                        toggleWord(card.word.id, in: words)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(card.word.kanji)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.appText)
                                    if card.word.kanji != card.word.kana {
                                        Text(card.word.kana)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text(card.word.definition)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(card.accentColor)
                            }
                        }
                        .opacity(selected ? 1 : 0.4)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private func toggleWord(_ wordId: String, in pool: [VocabFlashCard]) {
        if filter.selectedWordIds.isEmpty {
            // All currently shown; start excluding this one
            filter.selectedWordIds = Set(pool.map(\.word.id)).subtracting([wordId])
        } else if filter.selectedWordIds.contains(wordId) {
            filter.selectedWordIds.remove(wordId)
            if filter.selectedWordIds.isEmpty {
                // All deselected — reset to "all"
                filter.selectedWordIds = Set(pool.map(\.word.id))
            }
        } else {
            filter.selectedWordIds.insert(wordId)
        }
    }
}

// MARK: - Chapter square

private struct ChapterSquare: View {
    let number: Int
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10)
                .fill(selected ? color : Color.clear)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(selected ? 0 : 0.55), lineWidth: 1.5)
                )
                .overlay(
                    Text("CH\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selected ? .white : color)
                        .minimumScaleFactor(0.7)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nav bar modifier

private struct VocabNavBar: ViewModifier {
    let title: String
    @ObservedObject var filter: VocabFlashcardsFilter
    @Binding var showFilter: Bool
    /// nil for the global Study section; set for a chapter's Study Vocab session.
    let locked: LockedVocabChapter?
    let chapterWordIds: [String]
    @Binding var weightMode: WeightMode
    let onAfterClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.appNavBarText)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appNavBarText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if locked != nil {
                        Menu {
                            Picker("Priority", selection: $weightMode) {
                                Text("Random Order").tag(WeightMode.none)
                                Text("Prioritize “Don’t Know”").tag(WeightMode.harder)
                                Text("Prioritize “Got It”").tag(WeightMode.easier)
                            }
                            Divider()
                            Button(role: .destructive) {
                                filter.clearExclusions(for: chapterWordIds)
                                onAfterClear()
                            } label: {
                                Label("Clear Checkmarks (This Chapter)", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.appNavBarText)
                        }
                    } else {
                        Button {
                            showFilter = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .foregroundColor(.appNavBarText)
                                if filter.hasActiveFilter {
                                    Circle()
                                        .fill(Color.yellow)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                }
            }
            .toolbarBackground(Color.appNavBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private extension View {
    func vocabNavBar(title: String, filter: VocabFlashcardsFilter, showFilter: Binding<Bool>,
                     locked: LockedVocabChapter?, chapterWordIds: [String],
                     weightMode: Binding<WeightMode>, onAfterClear: @escaping () -> Void) -> some View {
        modifier(VocabNavBar(title: title, filter: filter, showFilter: showFilter,
                             locked: locked, chapterWordIds: chapterWordIds,
                             weightMode: weightMode, onAfterClear: onAfterClear))
    }
}
