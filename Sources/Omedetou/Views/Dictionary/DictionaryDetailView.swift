import SwiftUI

struct DictionaryDetailView: View {
    let entry: DictionaryEntry

    @State private var isFavorite: Bool
    @State private var expandedSections: Set<String> = []

    private let conjugation: [ConjugationSection]?

    init(entry: DictionaryEntry) {
        self.entry = entry
        _isFavorite = State(initialValue: DictionaryService.shared.isFavorite(id: entry.id))
        conjugation = ConjugationEngine.conjugate(
            word: entry.word,
            reading: entry.reading,
            partsOfSpeech: entry.partsOfSpeech
        )
    }

    /// Opening the しりとり entry is the last step of finding the game — the clue
    /// on ん names the word, and reading its definition is the reward. The entry's
    /// definition describes the game rather than translating the noun, so the
    /// unlock and the explanation land on the same screen.
    private func unlockIfSecretEntry() {
        guard entry.word == "しりとり" else { return }
        GameUnlocks.shared.unlock(.shiritori)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Header card ──────────────────────────────────────
                    ZStack(alignment: .topLeading) {
                        // Favorite star (top-left)
                        Button {
                            isFavorite = DictionaryService.shared.toggleFavorite(id: entry.id)
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(isFavorite ? .yellow : Color.secondary.opacity(0.5))
                        }
                        .padding(.top, 20)
                        .padding(.leading, 20)

                        // Audio (top-right, mirroring the star)
                        HStack {
                            Spacer()
                            SpeakButton(text: entry.reading ?? entry.word, size: 22)
                        }
                        .padding(.top, 14)
                        .padding(.trailing, 14)

                        // Word + reading centered
                        VStack(spacing: 6) {
                            Text(entry.word)
                                .font(.system(size: 56, weight: .bold))
                                .foregroundColor(.appText)
                                .multilineTextAlignment(.center)

                            if let reading = entry.reading {
                                Text(reading)
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .padding(.horizontal, 56)
                        .padding(.bottom, 16)
                    }

                    // POS tags
                    if !entry.partsOfSpeech.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(entry.partsOfSpeech, id: \.self) { pos in
                                    Text(pos)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .overlay(Capsule().stroke(Color.red.opacity(0.5), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 16)
                    }

                    Divider().padding(.horizontal, 20)

                    // ── Definitions ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Definitions")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        ForEach(Array(entry.definitions.enumerated()), id: \.offset) { idx, def in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(idx + 1).")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 22, alignment: .trailing)
                                Text(def)
                                    .font(.system(size: 15))
                                    .foregroundColor(.appText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    // ── Conjugation ───────────────────────────────────────
                    if let sections = conjugation {
                        Divider().padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Conjugation")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 8)

                            ForEach(sections, id: \.title) { section in
                                ConjugationSectionView(section: section,
                                                       isExpanded: expandedSections.contains(section.title)) {
                                    if expandedSections.contains(section.title) {
                                        expandedSections.remove(section.title)
                                    } else {
                                        expandedSections.insert(section.title)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .standardNavBar(entry.word)
        .onAppear {
            // Expand first two sections by default
            if let sections = conjugation {
                for s in sections.prefix(2) { expandedSections.insert(s.title) }
            }
            unlockIfSecretEntry()
        }
    }
}

// MARK: - Conjugation section

private struct ConjugationSectionView: View {
    let section: ConjugationSection
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Section header (tappable)
            Button(action: onToggle) {
                HStack {
                    Text(section.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appText)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.appText.opacity(0.04))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(section.rows.enumerated()), id: \.offset) { idx, row in
                        ConjugationRowView(row: row, shaded: idx % 2 == 1)
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Conjugation row

private struct ConjugationRowView: View {
    let row: ConjugationRow
    let shaded: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(row.label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.value)
                    .font(.system(size: 16))
                    .foregroundColor(.appText)
                if let alt = row.alt {
                    Text("(\(alt))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(shaded ? Color.appText.opacity(0.03) : Color.clear)
    }
}
