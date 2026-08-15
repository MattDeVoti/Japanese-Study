import SwiftUI

// 数独 — sudoku written in kanji numerals.
//
// Same rules as always, but 一 through 九 instead of 1 through 9, which turns a
// number puzzle into reading practice you do for an hour without noticing. The
// board is generated on the device (see SudokuEngine) and always has exactly one
// solution, so it can be finished by reasoning rather than guessing.

// MARK: - The 数独 palette

/// Washi paper and sumi ink, fixed. Like the other games, the board doesn't
/// change colour because the app's Appearance did — and both the game and its
/// tile read from here so the two can't drift.
enum SudokuTheme {
    static let paper     = Color(hex: "F3E9D6")
    static let paperEdge = Color(hex: "E0CFAC")
    static let ink       = Color(hex: "2B2118")   // the numbers you were given
    static let pencil    = Color(hex: "1D4E89")   // the numbers you wrote
    static let wrong     = Color(hex: "C0392B")
    static let note      = Color(hex: "8C7C64")
    static let line      = Color(hex: "C3B190")
    static let heavy     = Color(hex: "6E5C42")
    static let peer      = Color(hex: "E8DBBE")   // row / column / box of the selection
    static let selected  = Color(hex: "D8C299")
    static let dim       = Color(hex: "7A6A54")
    static let twin      = Color(hex: "DCE3D9")   // other cells holding the same number

    static var background: LinearGradient {
        LinearGradient(colors: [Color(hex: "F6EEDD"), Color(hex: "E7D9BC")],
                       startPoint: .top, endPoint: .bottom)
    }
    static let navBar = LinearGradient(colors: [Color(hex: "6E5C42"), Color(hex: "4A3C2A")],
                                       startPoint: .top, endPoint: .bottom)
}

/// 〇 is deliberately absent — index 0 is the empty cell.
let sudokuKanji = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

// MARK: - Game state

final class SudokuGameModel: ObservableObject {
    @Published private(set) var givens: [Int] = []
    @Published private(set) var solution: [Int] = []
    @Published private(set) var entries: [Int] = []
    /// One 9-bit mask per cell.
    @Published private(set) var notes: [Int] = []
    @Published var selected: Int?
    @Published var noteMode = false
    @Published var elapsed: TimeInterval = 0
    @Published private(set) var difficulty: SudokuDifficulty = .easy
    @Published private(set) var finished = false
    @Published private(set) var gaveUp = false
    @Published private(set) var hasGame = false

    private let key = "SudokuSaveV2"

    private struct Save: Codable {
        var givens: [Int]; var solution: [Int]; var entries: [Int]; var notes: [Int]
        var elapsed: TimeInterval; var difficulty: SudokuDifficulty
        var finished: Bool; var gaveUp: Bool
    }

    // MARK: Persistence — a game survives backing out and comes back where it was

    func restore() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Save.self, from: data),
              s.givens.count == 81, s.solution.count == 81,
              s.entries.count == 81, s.notes.count == 81,
              isSane(s) else { return }
        givens = s.givens; solution = s.solution; entries = s.entries; notes = s.notes
        elapsed = s.elapsed; difficulty = s.difficulty
        finished = s.finished; gaveUp = s.gaveUp
        hasGame = true
    }

    /// A save is only worth restoring if it describes a real game: a legal
    /// finished grid, givens that agree with it, and no entry sitting on top of
    /// a given. Anything else is discarded rather than shown to the player.
    private func isSane(_ s: Save) -> Bool {
        guard !s.solution.contains(0) else { return false }
        for u in SudokuEngine.units where Set(u.map { s.solution[$0] }) != Set(1...9) {
            return false
        }
        for i in 0..<81 where s.givens[i] != 0 {
            if s.givens[i] != s.solution[i] { return false }
            if s.entries[i] != 0 { return false }
        }
        return true
    }

    func persist() {
        guard hasGame else { return }
        let s = Save(givens: givens, solution: solution, entries: entries, notes: notes,
                     elapsed: elapsed, difficulty: difficulty,
                     finished: finished, gaveUp: gaveUp)
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
    }

    // MARK: Lifecycle

    func newGame(_ d: SudokuDifficulty) {
        let puzzle = SudokuEngine.generate(d)
        givens = puzzle.givens
        solution = puzzle.solution
        entries = [Int](repeating: 0, count: 81)
        notes = [Int](repeating: 0, count: 81)
        difficulty = d
        elapsed = 0
        selected = nil
        noteMode = false
        finished = false
        gaveUp = false
        hasGame = true
        persist()
    }

    /// Same puzzle, wiped clean.
    func reset() {
        entries = [Int](repeating: 0, count: 81)
        notes = [Int](repeating: 0, count: 81)
        elapsed = 0
        selected = nil
        finished = false
        gaveUp = false
        persist()
    }

    /// Show the answer and stop the clock. The board stays on screen to look at.
    func giveUp() {
        entries = (0..<81).map { givens[$0] == 0 ? solution[$0] : 0 }
        notes = [Int](repeating: 0, count: 81)
        gaveUp = true
        finished = true
        selected = nil
        persist()
    }

    // MARK: Reading the board

    func value(_ i: Int) -> Int { givens[i] != 0 ? givens[i] : entries[i] }
    func isGiven(_ i: Int) -> Bool { givens[i] != 0 }
    func isWrong(_ i: Int) -> Bool { entries[i] != 0 && entries[i] != solution[i] }

    var board: [Int] { (0..<81).map { value($0) } }

    /// How many of a digit are still to be placed — lets the pad grey out a
    /// number once all nine are down.
    func remaining(_ d: Int) -> Int {
        9 - (0..<81).reduce(0) { $0 + (value($1) == d ? 1 : 0) }
    }

    // MARK: Playing

    func place(_ d: Int) {
        guard let i = selected, !finished, givens[i] == 0 else { return }
        if noteMode {
            guard entries[i] == 0 else { return }
            notes[i] ^= 1 << (d - 1)
        } else {
            entries[i] = entries[i] == d ? 0 : d
            if entries[i] != 0 {
                notes[i] = 0
                // A number that's actually right rules itself out everywhere it
                // can see, so the maybes it kills go with it. Only on a correct
                // placement — a wrong guess shouldn't quietly eat your notes.
                if entries[i] == solution[i] { retractNote(d, around: i) }
            }
            checkFinished()
        }
        persist()
    }

    /// Clears digit `d` from the notes of every cell sharing a row, column or
    /// box with `i`.
    private func retractNote(_ d: Int, around i: Int) {
        let bit = 1 << (d - 1)
        for p in SudokuEngine.peers[i] where notes[p] & bit != 0 {
            notes[p] &= ~bit
        }
    }

    func erase() {
        guard let i = selected, !finished, givens[i] == 0 else { return }
        entries[i] = 0
        notes[i] = 0
        persist()
    }

    /// Every digit no peer already holds — nothing cleverer. Deliberately does
    /// no further deduction, so the notes stay yours to reason about.
    func fillAutoNotes() {
        guard !finished else { return }
        let b = board
        for i in 0..<81 where givens[i] == 0 && entries[i] == 0 {
            var mask = 0
            for d in SudokuEngine.candidates(b, at: i) { mask |= 1 << (d - 1) }
            notes[i] = mask
        }
        persist()
    }

    func clearNotes() {
        notes = [Int](repeating: 0, count: 81)
        persist()
    }

    private func checkFinished() {
        if (0..<81).allSatisfy({ value($0) == solution[$0] }) {
            finished = true
            selected = nil
        }
    }
}

// MARK: - The game

struct SudokuGame: View {
    @StateObject private var model = SudokuGameModel()
    @State private var showRules = false
    @State private var choosing = false
    @State private var confirmGiveUp = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SudokuTheme.background.ignoresSafeArea()

            if model.hasGame {
                board
            }
            if choosing || !model.hasGame {
                picker
            }
        }
        .standardNavBar("数独", background: SudokuTheme.navBar)
        .onAppear {
            model.restore()
            if !model.hasGame { choosing = true }
        }
        // Backing out stops the clock; the game is already saved, so coming back
        // picks it up at the same second.
        .onDisappear { model.persist() }
        .onReceive(tick) { _ in
            guard model.hasGame, !model.finished, !choosing, !showRules else { return }
            model.elapsed += 1
            if Int(model.elapsed) % 10 == 0 { model.persist() }
        }
        .sheet(isPresented: $showRules) { GameRulesSheet(game: .sudoku) }
        .environment(\.colorScheme, .light)
    }

    // MARK: Board

    private var board: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                grid(side: geo.size.width)
                Spacer(minLength: 0)
                if model.finished { verdict } else { controls; pad }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var header: some View {
        HStack {
            Text("\(model.difficulty.japanese) · \(model.difficulty.title)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SudokuTheme.dim)
            Spacer()
            Text(clock)
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundColor(SudokuTheme.ink)
            Spacer()
            Button { showRules = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SudokuTheme.dim)
            }
            .buttonStyle(.plain)
            Menu {
                Button { model.reset() } label: { Label("Reset this puzzle", systemImage: "arrow.counterclockwise") }
                Button { model.clearNotes() } label: { Label("Clear all notes", systemImage: "eraser") }
                Button(role: .destructive) { confirmGiveUp = true } label: {
                    Label("Give up", systemImage: "flag")
                }
                Button { choosing = true } label: { Label("New puzzle", systemImage: "plus.square") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SudokuTheme.dim)
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 8)
        .confirmationDialog("Give up on this puzzle?", isPresented: $confirmGiveUp,
                            titleVisibility: .visible) {
            Button("Show the answer", role: .destructive) { model.giveUp() }
            Button("Keep trying", role: .cancel) {}
        }
    }

    private var clock: String {
        let t = Int(model.elapsed)
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func grid(side: CGFloat) -> some View {
        let cell = side / 9
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(SudokuTheme.paper)

            ForEach(0..<81, id: \.self) { i in
                cellView(i, size: cell)
                    .frame(width: cell, height: cell)
                    .position(x: cell * (CGFloat(i % 9) + 0.5),
                              y: cell * (CGFloat(i / 9) + 0.5))
            }

            lines(side: side, cell: cell)
        }
        .frame(width: side, height: side)
        .overlay(Rectangle().strokeBorder(SudokuTheme.heavy, lineWidth: 2.5))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
    }

    private func lines(side: CGFloat, cell: CGFloat) -> some View {
        ZStack {
            Path { p in
                for k in 1..<9 where k % 3 != 0 {
                    let o = cell * CGFloat(k)
                    p.move(to: CGPoint(x: o, y: 0));    p.addLine(to: CGPoint(x: o, y: side))
                    p.move(to: CGPoint(x: 0, y: o));    p.addLine(to: CGPoint(x: side, y: o))
                }
            }
            .stroke(SudokuTheme.line, lineWidth: 1)

            Path { p in
                for k in [3, 6] {
                    let o = cell * CGFloat(k)
                    p.move(to: CGPoint(x: o, y: 0));    p.addLine(to: CGPoint(x: o, y: side))
                    p.move(to: CGPoint(x: 0, y: o));    p.addLine(to: CGPoint(x: side, y: o))
                }
            }
            .stroke(SudokuTheme.heavy, lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }

    private func cellView(_ i: Int, size: CGFloat) -> some View {
        let v = model.value(i)
        return ZStack {
            fillColor(i)
            if v != 0 {
                Text(sudokuKanji[v])
                    .font(.system(size: size * 0.58,
                                  weight: model.isGiven(i) ? .bold : .medium))
                    .foregroundColor(model.isWrong(i) ? SudokuTheme.wrong
                                     : (model.isGiven(i) ? SudokuTheme.ink : SudokuTheme.pencil))
            } else if model.notes[i] != 0 {
                noteGrid(model.notes[i], size: size)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(SudokuTheme.heavy, lineWidth: model.selected == i ? 2 : 0)
                .padding(1)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.selected = (model.selected == i) ? nil : i }
    }

    /// Selecting a cell tints its whole row, column and box, which is what makes
    /// a clash jump out without the app having to point at it.
    private func fillColor(_ i: Int) -> Color {
        guard let s = model.selected else { return .clear }
        if s == i { return SudokuTheme.selected }
        let picked = model.value(s)
        if picked != 0, model.value(i) == picked { return SudokuTheme.twin }
        return SudokuEngine.peers[s].contains(i) ? SudokuTheme.peer : .clear
    }

    private func noteGrid(_ mask: Int, size: CGFloat) -> some View {
        // The digit sitting in the selected cell, if it holds one. Selecting a 五
        // thickens every pencilled 五 on the board, which is how you actually
        // scan for where a digit can still go.
        let focus = model.selected.map { model.value($0) } ?? 0
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let d = r * 3 + c + 1
                        let lit = (d == focus)
                        Text(mask & (1 << (d - 1)) != 0 ? sudokuKanji[d] : " ")
                            .font(.system(size: size * 0.24,
                                          weight: lit ? .black : .medium))
                            // `ink` rather than a true black: it's the same
                            // near-black the given numbers are printed in, so a
                            // lit note reads as firmly on the page instead of
                            // fighting the aged-paper background.
                            .foregroundColor(lit ? SudokuTheme.ink : SudokuTheme.note)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(1)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 8) {
            toggle("Notes", icon: "square.and.pencil", on: model.noteMode) {
                model.noteMode.toggle()
            }
            toggle("Auto notes", icon: "wand.and.stars", on: false) {
                model.fillAutoNotes()
            }
            toggle("Erase", icon: "delete.left", on: false) { model.erase() }
        }
        .padding(.top, 10)
    }

    private func toggle(_ title: String, icon: String, on: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(on ? SudokuTheme.paper : SudokuTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(on ? SudokuTheme.heavy : SudokuTheme.paper))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(SudokuTheme.paperEdge, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var pad: some View {
        HStack(spacing: 5) {
            ForEach(1...9, id: \.self) { d in
                let done = model.remaining(d) == 0
                Button { model.place(d) } label: {
                    VStack(spacing: 1) {
                        Text(sudokuKanji[d])
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundColor(done ? SudokuTheme.note.opacity(0.4)
                                                  : (model.noteMode ? SudokuTheme.note
                                                                    : SudokuTheme.pencil))
                        Text(done ? "✓" : "\(model.remaining(d))")
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundColor(SudokuTheme.note.opacity(done ? 0.4 : 0.75))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 9).fill(SudokuTheme.paper))
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(SudokuTheme.paperEdge, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(done)
            }
        }
        .padding(.top, 6)
    }

    private var verdict: some View {
        VStack(spacing: 8) {
            Text(model.gaveUp ? "答え" : "できました！")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(SudokuTheme.ink)
            Text(model.gaveUp
                 ? "The finished board — have a look at where it went."
                 : "\(model.difficulty.title) in \(clock)")
                .font(.system(size: 13))
                .foregroundColor(SudokuTheme.dim)
            BoardButton(title: "New puzzle", icon: "plus.square", tint: SudokuTheme.ink) {
                choosing = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }

    // MARK: Difficulty picker

    private var picker: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 3) {
                    Text("数独")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(SudokuTheme.ink)
                    Text("Sudoku in kanji numerals")
                        .font(.system(size: 13))
                        .foregroundColor(SudokuTheme.dim)
                }

                ForEach(SudokuDifficulty.allCases) { d in
                    Button {
                        model.newGame(d)
                        choosing = false
                    } label: {
                        HStack {
                            Text(d.japanese)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(SudokuTheme.ink)
                                .frame(width: 44, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(d.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(SudokuTheme.ink)
                                Text(d.blurb)
                                    .font(.system(size: 11))
                                    .foregroundColor(SudokuTheme.dim)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(SudokuTheme.note)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 11).fill(SudokuTheme.paper))
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(SudokuTheme.paperEdge, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                if model.hasGame {
                    Button { choosing = false } label: {
                        Text("Back to my puzzle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SudokuTheme.dim)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(SudokuTheme.paperEdge))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(SudokuTheme.heavy.opacity(0.5), lineWidth: 1))
            .padding(24)
        }
    }
}
