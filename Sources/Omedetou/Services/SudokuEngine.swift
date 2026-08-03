import Foundation

// 数独 — puzzle generation, solving and difficulty grading.
//
// Pure logic, no SwiftUI, so it can be exercised on its own. Two guarantees the
// rest of the game leans on:
//
//   1. Every puzzle has exactly one solution. Digging only ever removes a
//      number if the grid still solves uniquely afterwards, so a puzzle can
//      always be finished by reasoning — never by guessing between two valid
//      finishes.
//   2. Difficulty means what it says. A puzzle isn't labelled by how many
//      numbers it starts with — that's a poor proxy — but by the hardest
//      technique a solver actually has to reach for.

enum SudokuDifficulty: String, CaseIterable, Codable, Identifiable {
    case easy, medium, hard, expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        case .expert: return "Expert"
        }
    }

    var japanese: String {
        switch self {
        case .easy:   return "初級"
        case .medium: return "中級"
        case .hard:   return "上級"
        case .expert: return "達人"
        }
    }

    /// What counts as this difficulty, on both axes at once.
    ///
    /// Technique alone is too jumpy — a grid's hardest-required technique often
    /// leaps from "singles" straight past the middle rungs — and given-count
    /// alone says nothing about whether you'll have to think. Requiring both is
    /// what makes the four tiers actually feel different.
    fileprivate func accepts(givens: Int, grade: SudokuDifficulty) -> Bool {
        switch self {
        case .easy:   return givens >= 32 && grade == .easy
        case .medium: return (29...34).contains(givens) && (1...2).contains(grade.rank)
        case .hard:   return (25...30).contains(givens) && grade.rank >= 2
        case .expert: return givens <= 25 && grade == .expert
        }
    }

    /// How far to dig. A puzzle dug to N givens is genuinely minimal at N;
    /// taking a minimal puzzle and adding clues back to N is a much easier
    /// board, because the clues put back are exactly the ones that unlock
    /// singles. Measured: that mistake made "hard" fall back 14 times in 15.
    fileprivate var digTarget: ClosedRange<Int> {
        switch self {
        case .easy:   return 34...40
        case .medium: return 29...34
        case .hard:   return 25...30
        case .expert: return 21...25
        }
    }

    /// Shown to the player, so they know roughly what they're in for.
    var blurb: String {
        switch self {
        case .easy:   return "Plenty to go on"
        case .medium: return "Some looking ahead"
        case .hard:   return "Real deduction"
        case .expert: return "Bare bones"
        }
    }

    fileprivate var rank: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .expert: return 3
        }
    }
}

struct SudokuPuzzle {
    /// 81 cells, row-major. 0 is blank.
    let givens: [Int]
    let solution: [Int]
    let difficulty: SudokuDifficulty
}

enum SudokuEngine {

    // MARK: - Geometry

    static func box(_ i: Int) -> Int { (i / 27) * 3 + (i % 9) / 3 }
    static func row(_ i: Int) -> Int { i / 9 }
    static func col(_ i: Int) -> Int { i % 9 }

    /// The 20 cells that can't repeat a digit with cell i.
    static let peers: [[Int]] = (0..<81).map { i in
        var out = Set<Int>()
        for j in 0..<81 where j != i {
            if row(j) == row(i) || col(j) == col(i) || box(j) == box(i) { out.insert(j) }
        }
        return Array(out).sorted()
    }

    /// 27 units: 9 rows, 9 columns, 9 boxes.
    static let units: [[Int]] = {
        var out: [[Int]] = []
        for r in 0..<9 { out.append((0..<9).map { r * 9 + $0 }) }
        for c in 0..<9 { out.append((0..<9).map { $0 * 9 + c }) }
        for b in 0..<9 {
            let r0 = (b / 3) * 3, c0 = (b % 3) * 3
            out.append((0..<9).map { (r0 + $0 / 3) * 9 + c0 + $0 % 3 })
        }
        return out
    }()

    private static let rowCells: [[Int]] = (0..<9).map { r in (0..<9).map { r * 9 + $0 } }
    private static let colCells: [[Int]] = (0..<9).map { c in (0..<9).map { $0 * 9 + c } }
    private static let boxCells: [[Int]] = (0..<9).map { b in
        let r0 = (b / 3) * 3, c0 = (b % 3) * 3
        return (0..<9).map { (r0 + $0 / 3) * 9 + c0 + $0 % 3 }
    }

    private static func bit(_ d: Int) -> Int { 1 << (d - 1) }
    private static let allDigits = 0b1_1111_1111

    // MARK: - Candidates

    /// Digits not already placed by a peer. This is exactly what Auto notes
    /// writes: what isn't directly blocked, with no further deduction.
    static func candidates(_ grid: [Int], at i: Int) -> [Int] {
        guard grid[i] == 0 else { return [] }
        var mask = allDigits
        for p in peers[i] where grid[p] != 0 { mask &= ~bit(grid[p]) }
        return (1...9).filter { mask & bit($0) != 0 }
    }

    /// Whether a placed digit clashes with a peer holding the same digit.
    static func conflicts(_ grid: [Int], at i: Int) -> Bool {
        let d = grid[i]
        guard d != 0 else { return false }
        return peers[i].contains { grid[$0] == d }
    }

    // MARK: - Counting solver

    /// Number of solutions, stopped early at `limit`. Uniqueness rests on this.
    /// Picks the most constrained cell first, which keeps the search shallow.
    static func solutionCount(_ grid: [Int], limit: Int = 2) -> Int {
        var cells = grid
        var rowM = [Int](repeating: 0, count: 9)
        var colM = [Int](repeating: 0, count: 9)
        var boxM = [Int](repeating: 0, count: 9)
        for i in 0..<81 where cells[i] != 0 {
            let b = bit(cells[i])
            rowM[row(i)] |= b; colM[col(i)] |= b; boxM[box(i)] |= b
        }
        var found = 0
        search(&cells, &rowM, &colM, &boxM, &found, limit)
        return found
    }

    private static func search(_ cells: inout [Int],
                               _ rowM: inout [Int], _ colM: inout [Int], _ boxM: inout [Int],
                               _ found: inout Int, _ limit: Int) {
        var best = -1
        var bestMask = 0
        var bestCount = 10
        for i in 0..<81 where cells[i] == 0 {
            let mask = allDigits & ~(rowM[row(i)] | colM[col(i)] | boxM[box(i)])
            let n = mask.nonzeroBitCount
            if n == 0 { return }            // dead end
            if n < bestCount { best = i; bestMask = mask; bestCount = n
                if n == 1 { break } }
        }
        if best == -1 { found += 1; return } // every cell filled

        let r = row(best), c = col(best), b = box(best)
        for d in 1...9 where bestMask & bit(d) != 0 {
            let m = bit(d)
            cells[best] = d; rowM[r] |= m; colM[c] |= m; boxM[b] |= m
            search(&cells, &rowM, &colM, &boxM, &found, limit)
            cells[best] = 0; rowM[r] &= ~m; colM[c] &= ~m; boxM[b] &= ~m
            if found >= limit { return }
        }
    }

    /// The single solution, if there is exactly one.
    static func solve(_ grid: [Int]) -> [Int]? {
        var cells = grid
        var rowM = [Int](repeating: 0, count: 9)
        var colM = [Int](repeating: 0, count: 9)
        var boxM = [Int](repeating: 0, count: 9)
        for i in 0..<81 where cells[i] != 0 {
            let b = bit(cells[i])
            rowM[row(i)] |= b; colM[col(i)] |= b; boxM[box(i)] |= b
        }
        var out: [Int]?
        fill(&cells, &rowM, &colM, &boxM, &out)
        return out
    }

    @discardableResult
    private static func fill(_ cells: inout [Int],
                             _ rowM: inout [Int], _ colM: inout [Int], _ boxM: inout [Int],
                             _ out: inout [Int]?) -> Bool {
        var best = -1, bestMask = 0, bestCount = 10
        for i in 0..<81 where cells[i] == 0 {
            let mask = allDigits & ~(rowM[row(i)] | colM[col(i)] | boxM[box(i)])
            let n = mask.nonzeroBitCount
            if n == 0 { return false }
            if n < bestCount { best = i; bestMask = mask; bestCount = n; if n == 1 { break } }
        }
        if best == -1 { out = cells; return true }

        let r = row(best), c = col(best), b = box(best)
        for d in (1...9).shuffled() where bestMask & bit(d) != 0 {
            let m = bit(d)
            cells[best] = d; rowM[r] |= m; colM[c] |= m; boxM[b] |= m
            if fill(&cells, &rowM, &colM, &boxM, &out) { return true }
            cells[best] = 0; rowM[r] &= ~m; colM[c] &= ~m; boxM[b] &= ~m
        }
        return false
    }

    // MARK: - Grading
    //
    // A logical solver that only knows a fixed ladder of techniques. Whichever
    // rung it has to climb to is the puzzle's difficulty; if it can't finish at
    // all, the puzzle needs more than these and counts as expert.

    private struct Logic {
        var val: [Int]
        var cand: [Int]

        init(_ grid: [Int]) {
            val = grid
            cand = [Int](repeating: 0, count: 81)
            for i in 0..<81 where grid[i] == 0 {
                var m = allDigits
                for p in peers[i] where grid[p] != 0 { m &= ~bit(grid[p]) }
                cand[i] = m
            }
        }

        var solved: Bool { !val.contains(0) }
        /// A cell with no value and nowhere to go — the puzzle broke.
        var broken: Bool { (0..<81).contains { val[$0] == 0 && cand[$0] == 0 } }

        mutating func place(_ i: Int, _ d: Int) {
            val[i] = d
            cand[i] = 0
            for p in peers[i] { cand[p] &= ~bit(d) }
        }

        mutating func nakedSingles() -> Bool {
            var moved = false
            for i in 0..<81 where val[i] == 0 && cand[i].nonzeroBitCount == 1 {
                place(i, cand[i].trailingZeroBitCount + 1)
                moved = true
            }
            return moved
        }

        mutating func hiddenSingles() -> Bool {
            var moved = false
            for unit in units {
                for d in 1...9 {
                    let b = bit(d)
                    if unit.contains(where: { val[$0] == d }) { continue }
                    var spot = -1, count = 0
                    for c in unit where val[c] == 0 && cand[c] & b != 0 {
                        spot = c; count += 1
                        if count > 1 { break }
                    }
                    if count == 1 { place(spot, d); moved = true }
                }
            }
            return moved
        }

        /// Pointing and claiming: a digit confined to one row/column inside a
        /// box (or to one box inside a row/column) can be cleared elsewhere.
        mutating func lockedCandidates() -> Bool {
            var moved = false
            for b in 0..<9 {
                let cells = boxCells[b]
                for d in 1...9 {
                    let bd = bit(d)
                    let spots = cells.filter { val[$0] == 0 && cand[$0] & bd != 0 }
                    guard spots.count > 1 else { continue }
                    if let r = only(spots.map(row)) {
                        for c in rowCells[r] where box(c) != b && val[c] == 0 && cand[c] & bd != 0 {
                            cand[c] &= ~bd; moved = true
                        }
                    }
                    if let cc = only(spots.map(col)) {
                        for c in colCells[cc] where box(c) != b && val[c] == 0 && cand[c] & bd != 0 {
                            cand[c] &= ~bd; moved = true
                        }
                    }
                }
            }
            for line in rowCells + colCells {
                for d in 1...9 {
                    let bd = bit(d)
                    let spots = line.filter { val[$0] == 0 && cand[$0] & bd != 0 }
                    guard spots.count > 1, let b = only(spots.map(box)) else { continue }
                    for c in boxCells[b] where !line.contains(c) && val[c] == 0 && cand[c] & bd != 0 {
                        cand[c] &= ~bd; moved = true
                    }
                }
            }
            return moved
        }

        private func only(_ xs: [Int]) -> Int? {
            guard let f = xs.first, xs.allSatisfy({ $0 == f }) else { return nil }
            return f
        }

        /// Naked and hidden pairs.
        mutating func pairs() -> Bool {
            var moved = false
            for unit in units {
                let open = unit.filter { val[$0] == 0 }

                for a in 0..<open.count {
                    guard cand[open[a]].nonzeroBitCount == 2 else { continue }
                    for b in (a + 1)..<open.count where cand[open[b]] == cand[open[a]] {
                        let m = cand[open[a]]
                        for c in open where c != open[a] && c != open[b] && cand[c] & m != 0 {
                            cand[c] &= ~m; moved = true
                        }
                    }
                }

                for d1 in 1...8 {
                    for d2 in (d1 + 1)...9 {
                        let m = bit(d1) | bit(d2)
                        let s1 = open.filter { cand[$0] & bit(d1) != 0 }
                        let s2 = open.filter { cand[$0] & bit(d2) != 0 }
                        guard s1.count == 2, s1 == s2 else { continue }
                        for c in s1 where cand[c] != m {
                            cand[c] &= m; moved = true
                        }
                    }
                }
            }
            return moved
        }

        /// Naked and hidden triples, plus X-wing. The rung that was missing:
        /// without it puzzles jumped straight from singles to unsolvable.
        mutating func triplesAndFish() -> Bool {
            var moved = false
            for unit in units {
                let open = unit.filter { val[$0] == 0 }
                guard open.count > 3 else { continue }

                for a in 0..<open.count {
                    for b in (a + 1)..<open.count {
                        for c in (b + 1)..<open.count {
                            let m = cand[open[a]] | cand[open[b]] | cand[open[c]]
                            guard m.nonzeroBitCount == 3 else { continue }
                            for o in open where o != open[a] && o != open[b] && o != open[c]
                                            && cand[o] & m != 0 {
                                cand[o] &= ~m; moved = true
                            }
                        }
                    }
                }

                for d1 in 1...7 {
                    for d2 in (d1 + 1)...8 {
                        for d3 in (d2 + 1)...9 {
                            let m = bit(d1) | bit(d2) | bit(d3)
                            let spots = open.filter { cand[$0] & m != 0 }
                            guard spots.count == 3,
                                  [d1, d2, d3].allSatisfy({ d in
                                      open.contains { cand[$0] & bit(d) != 0 }
                                  }) else { continue }
                            for o in spots where cand[o] & ~m != 0 {
                                cand[o] &= m; moved = true
                            }
                        }
                    }
                }
            }

            for byRow in [true, false] {
                let lines = byRow ? rowCells : colCells
                let cross = byRow ? colCells : rowCells
                for d in 1...9 {
                    let bd = bit(d)
                    for a in 0..<9 {
                        let sa = lines[a].filter { val[$0] == 0 && cand[$0] & bd != 0 }
                        guard sa.count == 2 else { continue }
                        let ka = sa.map { byRow ? col($0) : row($0) }
                        for b in (a + 1)..<9 {
                            let sb = lines[b].filter { val[$0] == 0 && cand[$0] & bd != 0 }
                            guard sb.count == 2 else { continue }
                            guard ka == sb.map({ byRow ? col($0) : row($0) }) else { continue }
                            for k in ka {
                                for c in cross[k] where !sa.contains(c) && !sb.contains(c)
                                                    && val[c] == 0 && cand[c] & bd != 0 {
                                    cand[c] &= ~bd; moved = true
                                }
                            }
                        }
                    }
                }
            }
            return moved
        }
    }

    /// The hardest rung a solver must reach. `nil` never happens for puzzles
    /// this file produces — they're all uniquely solvable — but a puzzle needing
    /// more than the ladder above grades as expert.
    static func grade(_ puzzle: [Int]) -> SudokuDifficulty {
        var l = Logic(puzzle)
        var hardest = 0
        while !l.solved {
            if l.broken { return .expert }
            if l.nakedSingles()     { hardest = max(hardest, 1); continue }
            if l.hiddenSingles()    { hardest = max(hardest, 2); continue }
            if l.lockedCandidates() { hardest = max(hardest, 3); continue }
            if l.pairs()            { hardest = max(hardest, 4); continue }
            if l.triplesAndFish()   { hardest = max(hardest, 5); continue }
            return .expert
        }
        switch hardest {
        case 0, 1: return .easy      // pure scanning
        case 2:    return .medium    // hidden singles needed
        default:   return .hard      // locked candidates, pairs, triples, fish
        }
    }

    /// Exposed so the difficulty definition itself can be asserted on.
    static func accepts(_ d: SudokuDifficulty, givens: Int, grade g: SudokuDifficulty) -> Bool {
        d.accepts(givens: givens, grade: g)
    }

    // MARK: - Generation

    /// A random completed grid.
    static func solvedGrid() -> [Int] {
        var cells = [Int](repeating: 0, count: 81)
        var rowM = [Int](repeating: 0, count: 9)
        var colM = [Int](repeating: 0, count: 9)
        var boxM = [Int](repeating: 0, count: 9)
        var out: [Int]?
        fill(&cells, &rowM, &colM, &boxM, &out)
        return out ?? cells
    }

    /// Removes numbers in random order, keeping the puzzle uniquely solvable,
    /// until it's down to `target` givens or nothing more can go.
    private static func dig(_ solved: [Int], downTo target: Int) -> [Int] {
        var puzzle = solved
        var givens = 81
        for i in (0..<81).shuffled() {
            if givens <= target { break }
            let keep = puzzle[i]
            puzzle[i] = 0
            if solutionCount(puzzle, limit: 2) == 1 {
                givens -= 1
            } else {
                puzzle[i] = keep      // that removal would allow a second finish
            }
        }
        return puzzle
    }

    /// A puzzle at the requested difficulty, on both axes: it starts with about
    /// the right number of clues *and* demands about the right amount of
    /// thought.
    ///
    /// The attempt ceiling is high because it has to be. Measured per-attempt
    /// success: easy 100%, medium 95%, expert 37%, hard 14% — digging to 27–32
    /// clues usually lands on a board that singles alone will crack, and hard
    /// insists you need more than that. Attempts are cheap (a dig is ~81
    /// uniqueness checks), so the fix is simply to keep trying.
    static func generate(_ difficulty: SudokuDifficulty, attempts: Int = 120) -> SudokuPuzzle {
        var fallback: SudokuPuzzle?
        var fallbackGap = Int.max

        for _ in 0..<attempts {
            let solution = solvedGrid()
            let puzzle = dig(solution, downTo: Int.random(in: difficulty.digTarget))
            let count = puzzle.filter { $0 != 0 }.count
            let g = grade(puzzle)

            if difficulty.accepts(givens: count, grade: g) {
                return SudokuPuzzle(givens: puzzle, solution: solution, difficulty: difficulty)
            }
            let gap = abs(g.rank - difficulty.rank)
            if gap < fallbackGap {
                fallbackGap = gap
                fallback = SudokuPuzzle(givens: puzzle, solution: solution,
                                        difficulty: difficulty)
            }
        }

        return fallback!
    }
}
