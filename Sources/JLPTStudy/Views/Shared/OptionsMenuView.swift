import SwiftUI

struct OptionsMenuView: View {
    @ObservedObject var filter: StudyFilter
    let onClearWeights: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // Provided only for the kanji picker sub-screen
    var store: CardStore? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // N Level selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("N Level")
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
                                    Text("N\(level)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(selected ? .white : nLevelColor(level))
                                        .frame(minWidth: 44, minHeight: 36)
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
        var cards = store.kanjiCards
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
                .background(Color.primary.opacity(0.05))
                .cornerRadius(10)
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

    private var allSelected: Bool {
        !filter.selectedKanjiIds.isEmpty && filtered.allSatisfy { filter.selectedKanjiIds.contains($0.id) }
    }

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
                .background(Color.primary.opacity(0.07))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Bulk toggle
                HStack {
                    Text("\(filtered.count) kanji")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(allSelected ? "Deselect All" : "Select All") {
                        if allSelected {
                            for card in filtered { filter.selectedKanjiIds.remove(card.id) }
                        } else {
                            for card in filtered { filter.selectedKanjiIds.insert(card.id) }
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { card in
                            let selected = filter.selectedKanjiIds.isEmpty
                                || filter.selectedKanjiIds.contains(card.id)
                            Button {
                                toggleKanji(card)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(card.kanji)
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(nLevelColor(card.nLevel))
                                        .frame(width: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.definition)
                                            .font(.system(size: 14))
                                            .foregroundColor(.appText)
                                            .lineLimit(1)
                                        Text("N\(card.nLevel)")
                                            .font(.system(size: 11))
                                            .foregroundColor(nLevelColor(card.nLevel))
                                    }
                                    Spacer()
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(nLevelColor(card.nLevel))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .opacity(selected ? 1 : 0.35)
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 68)
                        }
                    }
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
        if filter.selectedKanjiIds.isEmpty {
            // All currently included; start excluding this one
            filter.selectedKanjiIds = Set(pool.map(\.id)).subtracting([card.id])
        } else if filter.selectedKanjiIds.contains(card.id) {
            filter.selectedKanjiIds.remove(card.id)
            if filter.selectedKanjiIds.isEmpty {
                // Nothing left selected → revert to all
                filter.selectedKanjiIds = Set(pool.map(\.id))
            }
        } else {
            filter.selectedKanjiIds.insert(card.id)
        }
    }
}
