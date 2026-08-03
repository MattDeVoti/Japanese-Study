import SwiftUI

// The cheat sheets: charts you glance at rather than lessons you work through.
// Search runs across every cell of every sheet, so typing "ようか" or "humble" or
// "Tuesday" lands you on the right chart without knowing which one it lives in.

struct CheatSheetListView: View {
    @State private var query = ""

    private var results: [CheatSheet] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return CheatSheetLibrary.all }
        return CheatSheetLibrary.all.filter { $0.haystack.contains(q) }
    }

    /// Cells matching the query, so a search can jump straight to the row.
    private var matchingCells: [(sheet: CheatSheet, item: CheatItem)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        return CheatSheetLibrary.all.flatMap { sheet in
            sheet.sections.flatMap(\.items)
                .filter { ($0.main + " " + $0.sub).lowercased().contains(q) }
                .map { (sheet, $0) }
        }
    }

    var body: some View {
        ZStack {
            PatternedBackground(.textbook)

            VStack(spacing: 0) {
                SearchBar(text: $query, placeholder: "Search all sheets…")
                    .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !matchingCells.isEmpty {
                            Text("MATCHES")
                                .font(.system(size: 11, weight: .black))
                                .tracking(1.1)
                                .foregroundColor(.appTextSecondary)
                                .padding(.horizontal, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(matchingCells.prefix(12).enumerated()),
                                        id: \.offset) { idx, hit in
                                    if idx != 0 { Divider() }
                                    NavigationLink {
                                        CheatSheetDetailView(sheet: hit.sheet)
                                    } label: {
                                        matchRow(hit.sheet, hit.item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(Color.appSurface.opacity(0.85)))
                        }

                        if results.isEmpty && matchingCells.isEmpty {
                            Text("Nothing matches “\(query)”.")
                                .font(.system(size: 14))
                                .foregroundColor(.appTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        }

                        ForEach(results) { sheet in
                            NavigationLink {
                                CheatSheetDetailView(sheet: sheet)
                            } label: {
                                sheetRow(sheet)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .standardNavBar("Cheat Sheet")
    }

    private func matchRow(_ sheet: CheatSheet, _ item: CheatItem) -> some View {
        HStack(spacing: 10) {
            Text(item.main)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appText)
            Text(item.sub)
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(sheet.title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.readableOnPage(sheet.tint))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func sheetRow(_ sheet: CheatSheet) -> some View {
        HStack(spacing: 12) {
            Image(systemName: sheet.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(sheet.tint.badgeGradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(sheet.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appText)
                Text(sheet.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.appTextSecondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface.opacity(0.85)))
    }
}

// MARK: - One sheet

struct CheatSheetDetailView: View {
    let sheet: CheatSheet

    // On the Numbers sheet, tapping 三 → 六 → 九 — the divisions of a sudoku
    // grid — opens the kanji-numeral sudoku. Harmless everywhere else: the
    // sequence is only watched on that one sheet.
    @State private var numberProgress = 0
    @State private var foundSudoku = false
    private let sudokuOrder = ["三", "六", "九"]
    @ObservedObject private var unlocks = GameUnlocks.shared

    private func sudokuHint(_ main: String) -> Int? {
        guard sheet.id == "numbers", !unlocks.isUnlocked(.sudoku) else { return nil }
        return sudokuOrder.firstIndex(of: main)
    }

    var body: some View {
        ZStack {
            PatternedBackground(.textbook)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(sheet.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            if let t = section.title {
                                Text(t)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color.readableOnPage(sheet.tint))
                            }
                            if let n = section.note {
                                Text(n)
                                    .font(.system(size: 12))
                                    .foregroundColor(.appTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            switch section.visual {
                            case .positionMap:    PositionDiagram(tint: sheet.tint)
                            case .distanceMap:    DistanceDiagram(tint: sheet.tint)
                            case .frequencyScale: FrequencyScale(tint: sheet.tint)
                            case .clock:          ClockFace(tint: sheet.tint)
                            case .compass:        CompassRose(tint: sheet.tint)
                            case .body:           BodyDiagram(tint: sheet.tint)
                            case .face:           FaceIcons(tint: sheet.tint)
                            case .none:           EmptyView()
                            }
                            if section.isTable {
                                table(section)
                            } else if !section.items.isEmpty {
                                grid(section)
                            }
                        }
                    }

                    if sheet.hasIrregulars {
                        Text("Anything marked in colour breaks the pattern — those are the ones worth memorising.")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
            }
        }
        .standardNavBar(sheet.title)
        .fullScreenCover(isPresented: $foundSudoku) {
            NavigationStack { SudokuGame() }
        }
    }

    /// A headed chart: one row per word, one column per form.
    /// One flat cell in the chart. LazyVGrid places each child of its content
    /// builder into one slot, and a ForEach nested inside a ForEach does not get
    /// flattened into separate slots — so the rows are flattened here instead.
    private struct TableCell: Identifiable {
        let id: String
        let row: Int
        let col: Int
        let text: String
    }

    private func flatten(_ section: CheatSection) -> [TableCell] {
        var out: [TableCell] = []
        for (r, row) in section.rows.enumerated() {
            for (c, text) in row.cells.enumerated() {
                out.append(TableCell(id: "\(r)-\(c)", row: r, col: c, text: text))
            }
        }
        return out
    }

    private func table(_ section: CheatSection) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .topLeading),
                         count: section.headers.count)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(section.headers.enumerated()), id: \.offset) { _, h in
                    Text(h)
                        .font(.system(size: 10, weight: .black))
                        .tracking(0.5)
                        .foregroundColor(Color.readableOnPage(sheet.tint))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 7)
                }
            }
            .padding(.vertical, 7)
            .background(sheet.tint.opacity(0.14))

            LazyVGrid(columns: cols, spacing: 0) {
                ForEach(flatten(section)) { cell in
                    Text(cell.text)
                        .font(.system(size: 13, weight: cell.col == 0 ? .semibold : .regular))
                        .foregroundColor(cell.text == "—" ? Color.appTextSecondary.opacity(0.45)
                                         : (cell.col == 0 ? Color.appText : Color.appTextSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 8)
                        // maxHeight lets a short cell stretch to its row's height,
                        // so the stripe below covers the whole row rather than just
                        // the text in it.
                        .frame(maxWidth: .infinity, minHeight: 36,
                               maxHeight: .infinity, alignment: .topLeading)
                        // Zebra striping — three columns of Japanese are hard to
                        // track across without it.
                        .background(cell.row % 2 == 1 ? Color.appText.opacity(0.045) : Color.clear)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.appSurface.opacity(0.9)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.appHairline, lineWidth: 1))
    }

    private func grid(_ section: CheatSection) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                           count: max(1, section.columns)),
            spacing: 8
        ) {
            ForEach(section.items) { item in
                cell(item, wide: section.columns == 1)
            }
        }
    }

    private func cell(_ item: CheatItem, wide: Bool) -> some View {
        // Plain Text rather than FuriganaText: these cells are tight, and the
        // reading is already spelled out underneath in kana.
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if let c = item.swatch {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(c)
                        .frame(width: 22, height: 22)
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.appText.opacity(0.25), lineWidth: 1))
                }
                if let sym = item.symbol {
                    Image(systemName: sym)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.readableOnPage(sheet.tint))
                        .frame(width: 20)
                }
                Text(item.main)
                    .font(.system(size: wide ? 15 : 17, weight: .semibold))
                    .foregroundColor(item.irregular ? Color.readableOnPage(sheet.tint) : .appText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(item.sub)
                .font(.system(size: wide ? 12 : 11))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(item.irregular ? sheet.tint.opacity(0.16) : Color.appSurface.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(item.irregular ? sheet.tint.opacity(0.55) : Color.appHairline,
                              lineWidth: item.irregular ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { noteNumber(item.main) }
        .secretHint(sudokuHint(item.main) != nil, order: sudokuHint(item.main) ?? 0)
    }

    private func noteNumber(_ main: String) {
        guard sheet.id == "numbers" else { return }
        if main == sudokuOrder[numberProgress] {
            numberProgress += 1
            if numberProgress == sudokuOrder.count {
                numberProgress = 0
                GameUnlocks.shared.unlock(.sudoku)
                foundSudoku = true
            }
        } else {
            numberProgress = (main == sudokuOrder[0]) ? 1 : 0
        }
    }
}
