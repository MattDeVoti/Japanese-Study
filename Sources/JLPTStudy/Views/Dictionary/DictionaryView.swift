import SwiftUI

// MARK: - Row model (headers + entries interleaved for section grouping)

enum DictionaryRow: Identifiable {
    case header(String)
    case entry(DictionaryEntry)

    var id: String {
        switch self {
        case .header(let l): return "h_\(l)"
        case .entry(let e):  return "e_\(e.id)"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class DictionaryViewModel: ObservableObject {
    @Published var rows: [DictionaryRow] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var sortOrder: SortOrder = .english
    @Published var searchText = ""
    @Published var scrollTarget: String? = nil

    // Letter index (English sort only)
    @Published var letterOffsets: [String: Int] = [:]
    @Published var availableLetters: Set<String> = []

    // Kana index (Japanese sort only)
    @Published var kanaOffsets: [String: Int] = [:]
    @Published var availableKana: Set<String> = []

    enum SortOrder { case english, japanese }

    private var browseOffset = 0
    private let pageSize = 100
    private var lastSectionLetter: String = ""
    private var entries: [DictionaryEntry] = []
    private var searchTask: Task<Void, Never>?
    private var pageTask: Task<Void, Never>?
    private var pendingScroll: String? = nil

    // MARK: Lifecycle

    func onAppear() {
        if rows.isEmpty {
            Task {
                await loadLetterMap()
                await loadKanaMap()
                await loadPage()
            }
        }
    }

    // MARK: Loading

    func loadPage() async {
        guard !isLoading, hasMore, searchText.isEmpty else { return }
        isLoading = true
        let off = browseOffset
        let size = pageSize
        let sort: DictionaryService.SortOrder = (sortOrder == .english) ? .english : .japanese
        let batch = await Task.detached(priority: .userInitiated) {
            DictionaryService.shared.browse(offset: off, limit: size, sort: sort)
        }.value
        append(batch)
        browseOffset += batch.count
        hasMore = batch.count == pageSize
        isLoading = false

        if let pending = pendingScroll {
            scrollTarget = pending
            pendingScroll = nil
        }
    }

    func reset(clearLetterMap: Bool = false) {
        searchTask?.cancel()
        pageTask?.cancel()
        rows = []
        entries = []
        browseOffset = 0
        hasMore = true
        isLoading = false
        lastSectionLetter = ""
        if clearLetterMap {
            letterOffsets = [:]
            availableLetters = []
        }
        pageTask = Task {
            if clearLetterMap { await loadLetterMap() }
            await loadPage()
        }
    }

    // MARK: Search

    func onSearchChanged(_ query: String) {
        searchTask?.cancel()
        if query.isEmpty { reset(); return }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let q = query
            let results = await Task.detached(priority: .userInitiated) {
                DictionaryService.shared.searchCombined(q)
            }.value
            self.rows = results.map { .entry($0) }
            self.entries = results
        }
    }

    // MARK: Kana jump

    func jumpToKana(_ kana: String) {
        let headerId = "h_\(kana)"
        if rows.contains(where: { $0.id == headerId }) {
            scrollTarget = headerId
            return
        }
        guard let offset = kanaOffsets[kana] else { return }
        rows = []
        entries = []
        browseOffset = offset
        hasMore = true
        isLoading = false
        lastSectionLetter = ""
        pendingScroll = headerId
        Task { await loadPage() }
    }

    // MARK: Letter jump

    func jumpToLetter(_ letter: String) {
        let headerId = "h_\(letter.uppercased())"

        // If the header is already loaded, just scroll to it.
        if rows.contains(where: { $0.id == headerId }) {
            scrollTarget = headerId
            return
        }

        // Otherwise reload from the letter's SQLite offset.
        guard let offset = letterOffsets[letter.lowercased()] else { return }
        rows = []
        entries = []
        browseOffset = offset
        hasMore = true
        lastSectionLetter = ""
        pendingScroll = headerId
        Task { await loadPage() }
    }

    // MARK: Letter map

    private func loadLetterMap() async {
        let map = await Task.detached(priority: .background) {
            DictionaryService.shared.letterBoundaries()
        }.value
        letterOffsets = map
        availableLetters = Set(map.keys)
    }

    private func loadKanaMap() async {
        let rawMap = await Task.detached(priority: .background) {
            DictionaryService.shared.kanaBoundaries()
        }.value
        var sectionMap: [String: Int] = [:]
        for (ch, offset) in rawMap {
            guard let scalar = ch.unicodeScalars.first else { continue }
            let section = kanaSectionHeader(scalar.value)
            guard section != "#" else { continue }
            if let existing = sectionMap[section] {
                sectionMap[section] = min(existing, offset)
            } else {
                sectionMap[section] = offset
            }
        }
        kanaOffsets = sectionMap
        availableKana = Set(sectionMap.keys)
    }

    // MARK: Helpers

    private func append(_ batch: [DictionaryEntry]) {
        for entry in batch {
            let letter = sectionLetter(for: entry, sortOrder: sortOrder)
            if letter != lastSectionLetter {
                lastSectionLetter = letter
                rows.append(.header(letter))
            }
            rows.append(.entry(entry))
        }
        entries.append(contentsOf: batch)
    }

    func isLastEntry(_ entry: DictionaryEntry) -> Bool {
        entries.last?.id == entry.id
    }
}

// MARK: - Main view

struct DictionaryView: View {
    @StateObject private var vm = DictionaryViewModel()
    @State private var mode: DictionaryMode = .dictionary
    enum DictionaryMode { case dictionary, vocab }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    Text("Dictionary").tag(DictionaryMode.dictionary)
                    Text("My Vocab").tag(DictionaryMode.vocab)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)

                if mode == .dictionary {
                SearchBar(text: $vm.searchText, placeholder: "Search Japanese or English…")
                    .onChange(of: vm.searchText) { vm.onSearchChanged($0) }
                    .padding(.top, 4)

                if vm.searchText.isEmpty {
                    sortToggle
                }

                Divider()

                ZStack(alignment: .trailing) {
                    if vm.rows.isEmpty && !vm.isLoading {
                        Color.clear
                        Text("Loading…").foregroundColor(.secondary)
                    } else {
                        ScrollViewReader { proxy in
                            List {
                                ForEach(vm.rows) { row in
                                    rowView(for: row)
                                        .id(row.id)
                                        .listRowBackground(rowBackground(for: row))
                                }
                                if vm.isLoading {
                                    HStack { Spacer(); ProgressView(); Spacer() }
                                        .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(.plain)
                            .onChange(of: vm.scrollTarget) { target in
                                guard let t = target else { return }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation { proxy.scrollTo(t, anchor: .top) }
                                    vm.scrollTarget = nil
                                }
                            }
                        }
                    }

                    // Kana index bar (Japanese sort only, no active search)
                    if vm.sortOrder == .japanese && vm.searchText.isEmpty {
                        KanaIndexBar(available: vm.availableKana) { kana in
                            vm.jumpToKana(kana)
                        }
                        .padding(.trailing, 4)
                    }
                    // A-Z index bar (English sort only, no active search)
                    if vm.sortOrder == .english && vm.searchText.isEmpty {
                        LetterIndexBar(available: vm.availableLetters) { letter in
                            vm.jumpToLetter(letter)
                        }
                        .padding(.trailing, 4)
                    }
                }
                } else {
                    VocabProgressView()
                }
            }
        }
        .standardNavBar("Dictionary")
        .onAppear { vm.onAppear() }
    }

    // MARK: Row builder

    @ViewBuilder
    private func rowView(for row: DictionaryRow) -> some View {
        switch row {
        case .header(let letter):
            Text(letter)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

        case .entry(let entry):
            NavigationLink {
                DictionaryDetailView(entry: entry)
            } label: {
                DictionaryRowView(entry: entry, englishFirst: vm.sortOrder == .english)
            }
            .onAppear {
                if vm.isLastEntry(entry) && vm.searchText.isEmpty {
                    Task { await vm.loadPage() }
                }
            }
        }
    }

    private func rowBackground(for row: DictionaryRow) -> Color {
        if case .header = row { return Color.appText.opacity(0.05) }
        return .appBackground
    }

    // MARK: Sort toggle

    private var sortToggle: some View {
        HStack(spacing: 0) {
            SortPill(label: "A–Z English", selected: vm.sortOrder == .english) {
                guard vm.sortOrder != .english else { return }
                vm.sortOrder = .english; vm.reset(clearLetterMap: true)
            }
            SortPill(label: "あ–ん Japanese", selected: vm.sortOrder == .japanese) {
                guard vm.sortOrder != .japanese else { return }
                vm.sortOrder = .japanese; vm.reset()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Kana index bar

private struct KanaIndexBar: View {
    let available: Set<String>
    let onSelect: (String) -> Void

    private let kana: [String] = [
        "あ","い","う","え","お",
        "か","き","く","け","こ",
        "さ","し","す","せ","そ",
        "た","ち","つ","て","と",
        "な","に","ぬ","ね","の",
        "は","ひ","ふ","へ","ほ",
        "ま","み","む","め","も",
        "や","ゆ","よ",
        "ら","り","る","れ","ろ",
        "わ","を","ん",
        "ア","カ","サ","タ","ナ","ハ","マ","ヤ","ラ","ワ"
    ]

    @State private var activeKana: String? = nil
    private let itemH: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            ForEach(kana, id: \.self) { k in
                Text(k)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isActive(k) ? .white :
                                     available.contains(k) ? .red : Color.secondary.opacity(0.2))
                    .frame(width: 20, height: itemH)
                    .background(isActive(k) ? Color.red : Color.clear)
                    .clipShape(Circle())
            }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let idx = max(0, min(kana.count - 1,
                                                 Int(val.location.y / itemH)))
                            let k = kana[idx]
                            if k != activeKana {
                                activeKana = k
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onSelect(k)
                            }
                        }
                        .onEnded { _ in activeKana = nil }
                )
        )
    }

    private func isActive(_ k: String) -> Bool { activeKana == k }
}

// MARK: - Letter index bar

private struct LetterIndexBar: View {
    let available: Set<String>
    let onSelect: (String) -> Void

    // A-Z first, # at the bottom
    private let letters: [String] =
        Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) } + ["#"]

    @State private var activeLetter: String? = nil
    private let itemH: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isActive(letter) ? .white :
                                     isAvailable(letter) ? .red : Color.secondary.opacity(0.2))
                    .frame(width: 20, height: itemH)
                    .background(isActive(letter) ? Color.red : Color.clear)
                    .clipShape(Circle())
            }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let idx = max(0, min(letters.count - 1,
                                                 Int(val.location.y / itemH)))
                            let letter = letters[idx]
                            if letter != activeLetter {
                                activeLetter = letter
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onSelect(letter.lowercased())
                            }
                        }
                        .onEnded { _ in activeLetter = nil }
                )
        )
    }

    private func isAvailable(_ letter: String) -> Bool {
        available.contains(letter.lowercased()) ||
        (letter == "#" && available.contains("#"))
    }

    private func isActive(_ letter: String) -> Bool {
        activeLetter == letter
    }
}

// MARK: - Row cell

private struct DictionaryRowView: View {
    let entry: DictionaryEntry
    var englishFirst: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if englishFirst {
                if let def = entry.definitions.first {
                    Text(def)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.word)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    if let reading = entry.reading, !reading.isEmpty {
                        Text("●")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(reading)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(entry.word)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appText)
                    if let reading = entry.reading, !reading.isEmpty {
                        Text(reading)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                if let def = entry.definitions.first {
                    Text(def)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Sort pill

private struct SortPill: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : .appText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(selected ? Color.red : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appText.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section letter helpers

private func sectionLetter(for entry: DictionaryEntry,
                            sortOrder: DictionaryViewModel.SortOrder) -> String {
    if sortOrder == .japanese {
        guard let scalar = entry.sortKeyJp.unicodeScalars.first else { return "#" }
        return kanaSectionHeader(scalar.value)
    }
    // English mode — use the pre-computed sort key; "~…" keys belong to "#"
    let key = entry.sortKeyEn
    guard let first = key.first, first != "~", first.isLetter else { return "#" }
    return String(first).uppercased()
}

/// Maps a Unicode scalar value to its section header.
/// Hiragana: individual character (dakuten grouped under base).
/// Katakana: row-level grouping.
private func kanaSectionHeader(_ v: UInt32) -> String {
    switch v {
    // Hiragana — individual sections, dakuten/handakuten grouped with base
    case 0x3041, 0x3042:           return "あ"   // ぁ, あ
    case 0x3043, 0x3044:           return "い"   // ぃ, い
    case 0x3045, 0x3046, 0x3094:   return "う"   // ぅ, う, ゔ
    case 0x3047, 0x3048:           return "え"   // ぇ, え
    case 0x3049, 0x304A:           return "お"   // ぉ, お
    case 0x304B, 0x304C:           return "か"   // か, が
    case 0x304D, 0x304E:           return "き"   // き, ぎ
    case 0x304F, 0x3050:           return "く"   // く, ぐ
    case 0x3051, 0x3052:           return "け"   // け, げ
    case 0x3053, 0x3054:           return "こ"   // こ, ご
    case 0x3055, 0x3056:           return "さ"   // さ, ざ
    case 0x3057, 0x3058:           return "し"   // し, じ
    case 0x3059, 0x305A:           return "す"   // す, ず
    case 0x305B, 0x305C:           return "せ"   // せ, ぜ
    case 0x305D, 0x305E:           return "そ"   // そ, ぞ
    case 0x305F, 0x3060:           return "た"   // た, だ
    case 0x3061, 0x3062:           return "ち"   // ち, ぢ
    case 0x3063, 0x3064, 0x3065:   return "つ"   // っ, つ, づ
    case 0x3066, 0x3067:           return "て"   // て, で
    case 0x3068, 0x3069:           return "と"   // と, ど
    case 0x306A:                   return "な"
    case 0x306B:                   return "に"
    case 0x306C:                   return "ぬ"
    case 0x306D:                   return "ね"
    case 0x306E:                   return "の"
    case 0x306F, 0x3070, 0x3071:   return "は"   // は, ば, ぱ
    case 0x3072, 0x3073, 0x3074:   return "ひ"   // ひ, び, ぴ
    case 0x3075, 0x3076, 0x3077:   return "ふ"   // ふ, ぶ, ぷ
    case 0x3078, 0x3079, 0x307A:   return "へ"   // へ, べ, ぺ
    case 0x307B, 0x307C, 0x307D:   return "ほ"   // ほ, ぼ, ぽ
    case 0x307E:                   return "ま"
    case 0x307F:                   return "み"
    case 0x3080:                   return "む"
    case 0x3081:                   return "め"
    case 0x3082:                   return "も"
    case 0x3083, 0x3084:           return "や"   // ゃ, や
    case 0x3085, 0x3086:           return "ゆ"   // ゅ, ゆ
    case 0x3087, 0x3088:           return "よ"   // ょ, よ
    case 0x3089:                   return "ら"
    case 0x308A:                   return "り"
    case 0x308B:                   return "る"
    case 0x308C:                   return "れ"
    case 0x308D:                   return "ろ"
    case 0x308E, 0x308F:           return "わ"   // ゎ, わ
    case 0x3092:                   return "を"
    case 0x3093:                   return "ん"
    // Katakana — row-level grouping
    case 0x30A1...0x30AA:          return "ア"
    case 0x30AB...0x30B4:          return "カ"
    case 0x30B5...0x30BE:          return "サ"
    case 0x30BF...0x30C9:          return "タ"
    case 0x30CA...0x30CE:          return "ナ"
    case 0x30CF...0x30DD:          return "ハ"
    case 0x30DE...0x30E2:          return "マ"
    case 0x30E3...0x30E8:          return "ヤ"
    case 0x30E9...0x30ED:          return "ラ"
    case 0x30EE...0x30F6:          return "ワ"
    default:                       return "#"
    }
}
