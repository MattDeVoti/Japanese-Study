import SwiftUI

// ことばパズル — guess a five-kana word in six tries.
//
// Same feedback rules as the puzzle everyone knows, but the alphabet is the
// gojūon, which changes what the game trains. Guessing in English is about
// spelling; guessing in kana is about *readings* — you're reaching for words you
// know by sound and checking them against a grid. Answers are five full morae,
// never small kana, so every cell is something you can reason about.

struct KotobaGame: View {
    @Environment(\.dismiss) private var dismiss

    private let rows = 6
    private let length = 5

    @State private var answer: KanaWordBank.Word?
    @State private var guesses: [String] = []
    @State private var current = ""
    @State private var finished = false
    @State private var won = false
    @State private var shakeRow = false
    @State private var toast: String?
    /// Keyboard voicing modifier: 0 plain · 1 ゛ · 2 ゜
    @State private var voicing = 0
    @State private var showRules = false
    /// Shown unprompted the first time — the ゛゜ key isn't guessable.
    @AppStorage("KotobaSeenRules") private var seenRules = false
    @State private var showEntry = false

    var body: some View {
        ZStack {
            KotobaTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                grid.padding(.top, 6)
                Spacer(minLength: 4)

                if finished { verdict } else { keyboard }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            if let t = toast {
                Text(t)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(Color.black.opacity(0.78)))
                    .transition(.opacity)
                    .offset(y: -180)
            }
        }
        .standardNavBar("ことばパズル", background: KotobaTheme.navBar)
        .onAppear(perform: startIfNeeded)
        .sheet(isPresented: $showRules) { GameRulesSheet(game: .kotoba) }
        .sheet(isPresented: $showEntry) {
            if let id = answer?.entryId, let e = DictionaryService.shared.entry(id: id) {
                NavigationStack { DictionaryDetailView(entry: e) }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Five kana · six tries")
                .font(.system(size: 12))
                .foregroundColor(KotobaTheme.dim)
            Spacer()
            Button { showRules = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(KotobaTheme.text)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            Button {
                newRound()
            } label: {
                Label("New", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KotobaTheme.text)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Grid

    /// Cells are sized explicitly rather than with `aspectRatio` — inside a
    /// vertically-squeezed stack that collapses them into slivers.
    private var grid: some View {
        GeometryReader { geo in
            let side = min((geo.size.width - 6 * CGFloat(length - 1)) / CGFloat(length), 44)
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 6) {
                        ForEach(0..<length, id: \.self) { c in
                            cell(row: r, col: c, side: side)
                        }
                    }
                    .offset(x: (r == guesses.count && shakeRow) ? 6 : 0)
                    .animation(.default.repeatCount(3, autoreverses: true).speed(6),
                               value: shakeRow)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 44 * 6 + 6 * 5)
    }

    private func cell(row: Int, col: Int, side: CGFloat) -> some View {
        let submitted = row < guesses.count
        let ch: Character? = {
            if submitted { return Array(guesses[row])[col] }
            if row == guesses.count, col < current.count { return Array(current)[col] }
            return nil
        }()
        let state = submitted ? mark(for: guesses[row])[col] : Mark.empty
        return Text(ch.map(String.init) ?? "")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(state == .empty ? KotobaTheme.text : .white)
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: 8).fill(fill(state)))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(state == .empty ? KotobaTheme.outline : .clear,
                              lineWidth: 1.5))
    }

    private enum Mark { case empty, absent, present, correct }

    private func fill(_ m: Mark) -> Color {
        switch m {
        case .empty:   return Color.white.opacity(0.05)
        case .absent:  return KotobaTheme.absent
        case .present: return KotobaTheme.present
        case .correct: return KotobaTheme.correct
        }
    }

    /// Two passes, so a repeated kana isn't marked "present" more times than it
    /// actually occurs — the classic bug in Wordle clones.
    private func mark(for guess: String) -> [Mark] {
        guard let answer else { return Array(repeating: .empty, count: length) }
        let g = Array(guess), a = Array(answer.kana)
        var out = [Mark](repeating: .absent, count: length)
        var pool: [Character: Int] = [:]
        for i in 0..<length where g[i] != a[i] { pool[a[i], default: 0] += 1 }
        for i in 0..<length where g[i] == a[i] { out[i] = .correct }
        for i in 0..<length where out[i] != .correct {
            if let n = pool[g[i]], n > 0 { out[i] = .present; pool[g[i]] = n - 1 }
        }
        return out
    }

    /// Best state seen for a kana so far, for tinting the keyboard.
    private func keyState(_ k: Character) -> Mark {
        var best = Mark.empty
        for g in guesses {
            let marks = mark(for: g)
            for (i, c) in Array(g).enumerated() where c == k {
                switch marks[i] {
                case .correct: return .correct
                case .present: best = .present
                case .absent:  if best == .empty { best = .absent }
                case .empty:   break
                }
            }
        }
        return best
    }

    // MARK: - Keyboard

    private var keyboard: some View {
        VStack(spacing: 5) {
            ForEach(Array(KanaWordBank.kotobaKeyboard.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 5) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, base in
                        let g = KanaWordBank.keyGlyph(base, mark: voicing)
                        let live = KanaWordBank.hasMark(base, mark: voicing)
                        Button { if live { tap(g) } } label: {
                            Text(String(g))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(!live ? KotobaTheme.dim.opacity(0.45)
                                                 : (keyState(g) == .empty ? KotobaTheme.text : .white))
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(keyState(g) == .empty
                                          ? KotobaTheme.surface : fill(keyState(g))))
                        }
                        .buttonStyle(.plain)
                        .disabled(!live)
                    }
                }
            }
            HStack(spacing: 6) {
                Button { voicing = (voicing + 1) % 3 } label: {
                    Text(voicing == 0 ? "゛゜" : (voicing == 1 ? "゛" : "゜"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(voicing == 0 ? KotobaTheme.text : .white)
                        .frame(width: 54, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(voicing == 0 ? KotobaTheme.surface : KotobaTheme.active))
                }
                .buttonStyle(.plain)

                Button { tap("ん") } label: {
                    Text("ん")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(keyState("ん") == .empty ? KotobaTheme.text : .white)
                        .frame(width: 54, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(keyState("ん") == .empty
                                  ? KotobaTheme.surface : fill(keyState("ん"))))
                }
                .buttonStyle(.plain)

                Button { if !current.isEmpty { current.removeLast() } } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(KotobaTheme.surface))
                }
                .buttonStyle(.plain).foregroundColor(KotobaTheme.text)

                Button(action: submit) {
                    Text("Enter")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KotobaTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.17)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Verdict

    private var verdict: some View {
        VStack(spacing: 10) {
            Text(won ? "正解！" : "残念…")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(won ? KotobaTheme.correct : KotobaTheme.text)

            if let a = answer {
                VStack(spacing: 6) {
                    // Kana only, as everywhere else on this board — the written
                    // form lives behind the dictionary button.
                    Text(a.kana)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(KotobaTheme.text)

                    VStack(spacing: 2) {
                        ForEach(Array(a.meanings.prefix(3).enumerated()), id: \.offset) { i, m in
                            Text(a.meanings.count > 1 ? "\(i + 1). \(m)" : m)
                                .font(.system(size: 13))
                                .foregroundColor(KotobaTheme.dim)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(KotobaTheme.surface))
                }
            }

            Text(won ? "Solved in \(guesses.count) \(guesses.count == 1 ? "try" : "tries")"
                     : "Six tries used")
                .font(.system(size: 12))
                .foregroundColor(KotobaTheme.dim)

            HStack(spacing: 10) {
                if answer?.entryId ?? -1 >= 0 {
                    BoardButton(title: "Dictionary", icon: "book") { showEntry = true }
                }
                BoardButton(title: "Play again", icon: "arrow.clockwise") { newRound() }
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - Flow

    private func startIfNeeded() {
        if answer == nil { newRound() }
        if !seenRules { seenRules = true; showRules = true }
    }

    private func newRound() {
        answer = KanaWordBank.kotobaAnswers.randomElement()
        guesses = []; current = ""; finished = false; won = false
        voicing = 0
    }

    private func tap(_ k: Character) {
        guard !finished, current.count < length else { return }
        current.append(k)
    }

    private func submit() {
        guard !finished, let answer else { return }
        guard current.count == length else { flash("Five kana"); return }
        guard KanaWordBank.kotobaGuesses.contains(current) else {
            flash("Not in the word list"); shake(); return
        }
        guesses.append(current)
        if current == answer.kana { won = true; finished = true }
        else if guesses.count >= rows { finished = true }
        current = ""
    }

    private func shake() {
        shakeRow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeRow = false }
    }

    private func flash(_ m: String) {
        withAnimation { toast = m }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { toast = nil }
        }
    }
}
