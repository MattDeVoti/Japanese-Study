import SwiftUI

/// Shows every vocab word alongside its "Got It" (green) and "Don't Know"
/// (red) flashcard button-press counts, sortable by most red / most green.
struct VocabProgressView: View {
    @StateObject private var filter = VocabFlashcardsFilter()
    @State private var cards: [VocabFlashCard] = []
    @State private var loaded = false
    @State private var sort: Sort = .mostRed

    enum Sort: String, CaseIterable, Identifiable {
        case mostRed = "Most red"
        case mostGreen = "Most green"
        case az = "A–Z"
        var id: String { rawValue }
    }

    private func red(_ c: VocabFlashCard) -> Int { filter.needsWorkCounts[c.word.id] ?? 0 }
    private func green(_ c: VocabFlashCard) -> Int { filter.confidentCounts[c.word.id] ?? 0 }

    private var sorted: [VocabFlashCard] {
        switch sort {
        case .mostRed:
            return cards.sorted {
                if red($0) != red($1) { return red($0) > red($1) }
                if green($0) != green($1) { return green($0) > green($1) }
                return $0.word.kana < $1.word.kana
            }
        case .mostGreen:
            return cards.sorted {
                if green($0) != green($1) { return green($0) > green($1) }
                if red($0) != red($1) { return red($0) > red($1) }
                return $0.word.kana < $1.word.kana
            }
        case .az:
            return cards.sorted { $0.word.kana < $1.word.kana }
        }
    }

    private var studiedCount: Int { cards.filter { red($0) + green($0) > 0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sort) {
                ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                Text("\(studiedCount) of \(cards.count) practiced")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                LegendDot(color: .green, label: "Got It")
                LegendDot(color: .red, label: "Don't Know")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            Divider()

            if loaded && cards.isEmpty {
                Spacer()
                Text("No vocabulary found.").foregroundColor(.secondary)
                Spacer()
            } else {
                List(sorted) { card in
                    VocabProgressRow(card: card, green: green(card), red: red(card))
                        .listRowBackground(Color.appBackground)
                        .listRowSeparatorTint(Color.appHairline)
                }
                .listStyle(.plain)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        LessonsService.shared.loadIfNeeded()
        guard let manifest = LessonsService.shared.manifest else { loaded = true; return }
        var result: [VocabFlashCard] = []
        for level in manifest.levels {
            let color = levelAccentColor(level.jlptLevel)
            for summary in level.chapters {
                guard let chapter = LessonsService.shared.loadChapter(summary.id),
                      let words = chapter.vocab else { continue }
                for w in words {
                    result.append(VocabFlashCard(
                        word: w, chapterId: summary.id,
                        chapterNumber: summary.chapterNumber,
                        chapterTitle: chapter.title, accentColor: color))
                }
            }
        }
        cards = result
        loaded = true
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
    }
}

private struct VocabProgressRow: View {
    let card: VocabFlashCard
    let green: Int
    let red: Int

    private var subtitle: String {
        let kana = card.word.kana == card.word.kanji ? "" : "\(card.word.kana)  "
        return kana + card.word.definition
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.word.kanji)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            CountPill(count: green, color: .green)
            CountPill(count: red, color: .red)
        }
        .padding(.vertical, 2)
    }
}

private struct CountPill: View {
    let count: Int
    let color: Color
    var body: some View {
        Text("\(count)")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(count > 0 ? .white : .secondary)
            .frame(minWidth: 24)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Capsule().fill(count > 0 ? color : color.opacity(0.14)))
    }
}
