import SwiftUI

struct OptionsMenuView: View {
    @ObservedObject var filter: StudyFilter
    let onClearWeights: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // Provided only for the kanji picker sub-screen
    var store: CardStore? = nil

    /// Provided only for kanji: clears every kanji flashcard checkmark.
    var onClearExclusions: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Level selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Level")
                            .font(.headline)
                            .foregroundColor(.appText)
                        HStack(spacing: 8) {
                            ForEach(filter.availableLevels, id: \.self) { level in
                                let selected = filter.selectedLevels.contains(level)
                                Button {
                                    if selected {
                                        filter.selectedLevels.remove(level)
                                    } else {
                                        filter.selectedLevels.insert(level)
                                    }
                                    // Clear individual kanji selection when levels change
                                    if let kf = filter as? KanjiFilter { kf.selectedKanjiIds = [] }
                                } label: {
                                    Text(levelName(level))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(selected ? .white : nLevelColor(level))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selected ? nLevelColor(level) : nLevelColor(level).opacity(0.12))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(nLevelColor(level).opacity(0.5), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(filter.selectedLevels.isEmpty ? "All levels shown" : "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Kanji selection (only for KanjiFilter)
                    if let kanjiFilter = filter as? KanjiFilter, let store = store {
                        KanjiSelectionRow(filter: kanjiFilter, store: store)
                        Divider()
                    }

                    // Weighted shuffle
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weighted Shuffle")
                            .font(.headline)
                            .foregroundColor(.appText)
                        Picker("", selection: $filter.weightMode) {
                            ForEach(WeightMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Weight strength slider (visible when not NONE)
                    if filter.weightMode != .none {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Weight Strength")
                                    .font(.headline)
                                    .foregroundColor(.appText)
                                Spacer()
                                Text(String(format: "%.0f%%", filter.weightStrength * 100))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $filter.weightStrength, in: 0...1)
                                .tint(filter.weightMode == .harder ? .red : .green)
                        }
                    }

                    Divider()

                    // Show favorites only
                    Toggle(isOn: $filter.showFavoritesOnly) {
                        Text("Show Favorites Only")
                            .font(.headline)
                            .foregroundColor(.appText)
                    }
                    .tint(.yellow)

                    Divider()

                    // Clear weights
                    Button {
                        onClearWeights()
                    } label: {
                        Text("Reset Study Weights")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.85)))
                    }
                    .buttonStyle(.plain)

                    // Clear checkmarks (kanji only)
                    if let onClearExclusions = onClearExclusions {
                        Button {
                            onClearExclusions()
                        } label: {
                            Text("Clear All Kanji Checkmarks")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
}

// MARK: - Kanji selection summary row + picker link

private struct KanjiSelectionRow: View {
    @ObservedObject var filter: KanjiFilter
    @ObservedObject var store: CardStore

    private var availablePool: [KanjiCard] {
        // Same order as the Kanji list on the home page (number kanji pinned first)
        var cards = store.allKanjiCards()
        if !filter.selectedLevels.isEmpty {
            cards = cards.filter { filter.selectedLevels.contains($0.nLevel) }
        }
        return cards
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Selected Kanji")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                if !filter.selectedKanjiIds.isEmpty {
                    Button("Clear") { filter.selectedKanjiIds = [] }
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            NavigationLink {
                KanjiPickerView(filter: filter, pool: availablePool)
            } label: {
                HStack {
                    if filter.selectedKanjiIds.isEmpty {
                        Text("All kanji included")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(filter.selectedKanjiIds.count) kanji selected")
                            .font(.system(size: 15))
                            .foregroundColor(.appText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.appHairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Kanji Picker (full-screen within sheet NavigationStack)

private struct KanjiPickerView: View {
    @ObservedObject var filter: KanjiFilter
    let pool: [KanjiCard]
    @State private var searchText = ""

    private var filtered: [KanjiCard] {
        guard !searchText.isEmpty else { return pool }
        return pool.filter {
            $0.kanji.contains(searchText) ||
            $0.definition.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var noneSelected: Bool { filter.selectedKanjiIds.isEmpty }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search kanji or meaning…", text: $searchText)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurfaceHigh)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.appHairline, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Select All / Deselect All + live count
                HStack(spacing: 10) {
                    Button {
                        for card in filtered { filter.selectedKanjiIds.insert(card.id) }
                    } label: {
                        Text("Select All")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(.plain)

                    Button {
                        filter.selectedKanjiIds.removeAll()
                    } label: {
                        Text("Deselect All")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(noneSelected ? .secondary : .red)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(
                                Capsule().stroke(noneSelected ? Color.secondary.opacity(0.3)
                                                              : Color.red.opacity(0.6), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(noneSelected)

                    Spacer()

                    Text(noneSelected ? "All \(pool.count)" : "\(filter.selectedKanjiIds.count) selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Make the "pick nothing = study everything" default explicit
                if noneSelected {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("Nothing picked, so all \(pool.count) kanji will be studied. Tap kanji below to study only specific ones.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurfaceHigh)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 104), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(filtered) { card in
                            KanjiCell(
                                card: card,
                                selected: filter.selectedKanjiIds.contains(card.id)
                            ) {
                                toggleKanji(card)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle("Select Kanji")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appNavBar, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func toggleKanji(_ card: KanjiCard) {
        if filter.selectedKanjiIds.contains(card.id) {
            filter.selectedKanjiIds.remove(card.id)
        } else {
            filter.selectedKanjiIds.insert(card.id)
        }
    }
}

// MARK: - Kanji grid cell

private struct KanjiCell: View {
    let card: KanjiCard
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let color = nLevelColor(card.nLevel)
        Button(action: action) {
            VStack(spacing: 4) {
                HStack {
                    Text(levelName(card.nLevel))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(selected ? .white.opacity(0.9) : color)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundColor(selected ? .white : Color.secondary.opacity(0.4))
                }

                Text(card.kanji)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(selected ? .white : color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(card.definition)
                    .font(.system(size: 10.5))
                    .foregroundColor(selected ? .white.opacity(0.9) : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(8)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? color : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.clear : color.opacity(0.4), lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
