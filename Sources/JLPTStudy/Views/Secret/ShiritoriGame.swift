import SwiftUI

// しりとり — the word chain.
//
// I say さくら, you answer with something starting ら. End a word with ん and
// you're out. It's the game every Japanese child plays, and it trains the one
// thing flashcards can't: pulling a word out of memory by its sound, against a
// clock.
//
// The app plays fair. It won't use る to starve you — the dictionary only has a
// handful of words starting with る against hundreds ending in it, so the
// classic る攻め would end every round in seconds and teach nothing.

struct ShiritoriGame: View {
    @Environment(\.dismiss) private var dismiss

    private let turnSeconds = 15
    private var accent: Color { ShiritoriTheme.gold }

    @State private var chain: [ChainLink] = []
    @State private var used = Set<String>()
    @State private var typed = ""
    @State private var remaining = 15
    @State private var over = false
    @State private var reason = ""
    @State private var best = UserDefaults.standard.integer(forKey: "ShiritoriBest")
    @State private var started = false
    @State private var showRules = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    struct ChainLink: Identifiable {
        let id = UUID()
        let word: KanaWordBank.Word
        let mine: Bool
    }

    var body: some View {
        ZStack {
            ShiritoriTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                chainList
                if over { verdict } else { input }
            }
            if !started { intro }
        }
        .standardNavBar("しりとり", background: ShiritoriTheme.navBar)
        .onAppear(perform: startIfNeeded)
        .onReceive(tick) { _ in
            // Never while the player is still reading.
            guard started, !showRules, !over, !chain.isEmpty else { return }
            remaining -= 1
            if remaining <= 0 { end("Out of time") }
        }
        .sheet(isPresented: $showRules) { GameRulesSheet(game: .shiritori) }
        .environment(\.colorScheme, .dark)
    }

    /// The clock starts on the player's say-so, not on appear — losing your
    /// first turn to reading the rules would be a rotten way in.
    private var intro: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("しりとり")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(ShiritoriTheme.text)
                    Text("Chain words, never end in ん")
                        .font(.system(size: 13))
                        .foregroundColor(ShiritoriTheme.dim)
                }
                GameRulesList(game: .shiritori,
                              textColor: ShiritoriTheme.text, defaultIconTint: ShiritoriTheme.dim)
                BoardButton(title: "Start", icon: "play.fill", tint: ShiritoriTheme.gold) {
                    started = true
                    remaining = turnSeconds
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 18).fill(ShiritoriTheme.chip))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(ShiritoriTheme.hairline, lineWidth: 1))
            .padding(22)
        }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Chain \(chain.count)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundColor(ShiritoriTheme.text)
                Spacer()
                Text("Best \(best)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(ShiritoriTheme.dim)
                Button { showRules = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ShiritoriTheme.gold)
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
            }
            if !over {
                ProgressView(value: Double(remaining), total: Double(turnSeconds))
                    .tint(remaining <= 5 ? ShiritoriTheme.danger : ShiritoriTheme.gold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var chainList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(chain.enumerated()), id: \.element.id) { i, link in
                        HStack {
                            if link.mine { Spacer(minLength: 40) }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    kanaLine(link.word.kana,
                                             litHead: i > 0,
                                             litTail: i < chain.count - 1)
                                    if link.word.display != link.word.kana {
                                        Text(link.word.display)
                                            .font(.system(size: 13))
                                            .foregroundColor(ShiritoriTheme.dim)
                                    }
                                }
                                Text(link.word.meaning)
                                    .font(.system(size: 11))
                                    .foregroundColor(ShiritoriTheme.dim)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(link.mine ? ShiritoriTheme.gold.opacity(0.14) : ShiritoriTheme.chip))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(link.mine ? ShiritoriTheme.gold.opacity(0.45) : ShiritoriTheme.hairline,
                                              lineWidth: 1))
                            if !link.mine { Spacer(minLength: 40) }
                        }
                        .id(link.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: chain.count) { _ in
                withAnimation { proxy.scrollTo(chain.last?.id, anchor: .bottom) }
            }
        }
    }

    private var input: some View {
        VStack(spacing: 8) {
            if let need = nextKana {
                Text("Your word starts with 「\(String(need))」")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ShiritoriTheme.gold)
            }
            HStack(spacing: 8) {
                TextField("かな", text: $typed)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .foregroundColor(ShiritoriTheme.text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ShiritoriTheme.chip))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(ShiritoriTheme.hairline, lineWidth: 1))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(play)
                Button(action: play) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(ShiritoriTheme.gold)
                }
                .buttonStyle(.plain)
            }
            Text("Hiragana only. A word ending in ん loses.")
                .font(.system(size: 11))
                .foregroundColor(ShiritoriTheme.dim)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var verdict: some View {
        VStack(spacing: 10) {
            Text(reason)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ShiritoriTheme.text)
                .multilineTextAlignment(.center)
            Text("Chain of \(chain.count)")
                .font(.system(size: 13))
                .foregroundColor(ShiritoriTheme.dim)
            BoardButton(title: "Play again", icon: "arrow.clockwise", tint: ShiritoriTheme.gold) { restart() }
        }
        .padding(.bottom, 18)
    }

    /// The kana a word takes and the kana it hands on, marked in gold — the
    /// same reading the tile gives the chain.
    private func kanaLine(_ kana: String, litHead: Bool, litTail: Bool) -> some View {
        let chars = Array(kana)
        return HStack(spacing: 0) {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .foregroundColor((i == 0 && litHead) || (i == chars.count - 1 && litTail)
                                     ? ShiritoriTheme.gold : ShiritoriTheme.text)
            }
        }
        .font(.system(size: 17, weight: .semibold))
    }

    // MARK: - Rules

    private var nextKana: Character? {
        guard let last = chain.last else { return nil }
        return KanaWordBank.tail(of: last.word.kana)
    }

    private func startIfNeeded() { if chain.isEmpty { restart() } }

    private func restart() {
        used = []; chain = []; typed = ""; over = false; reason = ""
        // The app opens, so the player always has something to answer.
        if let opener = KanaWordBank.shiritoriPool.filter({ safeToPlay($0) }).randomElement() {
            chain = [ChainLink(word: opener, mine: false)]
            used.insert(opener.kana)
        }
        remaining = turnSeconds
    }

    /// Don't hand the player a tail with almost nothing after it.
    private func safeToPlay(_ w: KanaWordBank.Word) -> Bool {
        guard let t = KanaWordBank.tail(of: w.kana) else { return false }
        return continuations(from: t) >= 6
    }

    private func continuations(from k: Character) -> Int {
        KanaWordBank.shiritoriPool.reduce(0) {
            $0 + ((KanaWordBank.head(of: $1.kana) == k && !used.contains($1.kana)) ? 1 : 0)
        }
    }

    private func play() {
        guard !over else { return }
        let guess = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        typed = ""
        guard !guess.isEmpty else { return }

        if KanaWordBank.endsGame(guess) { end("「\(guess)」ends in ん — that's the loss.") ; return }
        if let need = nextKana, KanaWordBank.head(of: guess) != need {
            end("「\(guess)」doesn't start with 「\(String(need))」."); return
        }
        if used.contains(guess) { end("「\(guess)」has already been used."); return }
        guard let word = KanaWordBank.shiritoriPool.first(where: { $0.kana == guess }) else {
            end("「\(guess)」isn't in the dictionary."); return
        }

        chain.append(ChainLink(word: word, mine: true))
        used.insert(word.kana)
        remaining = turnSeconds
        answer()
    }

    /// The app's reply. Prefers a word that leaves the player a workable tail.
    private func answer() {
        guard let need = KanaWordBank.tail(of: chain.last!.word.kana) else { return }
        let options = KanaWordBank.shiritoriPool.filter {
            KanaWordBank.head(of: $0.kana) == need && !used.contains($0.kana)
        }
        guard !options.isEmpty else {
            end("The app is stuck on 「\(String(need))」 — you win!"); return
        }
        let kind = options.filter { safeToPlay($0) }
        let pick = (kind.isEmpty ? options : kind).randomElement()!
        chain.append(ChainLink(word: pick, mine: false))
        used.insert(pick.kana)
        remaining = turnSeconds
    }

    private func end(_ why: String) {
        over = true
        reason = why
        let score = chain.count
        if score > best {
            best = score
            UserDefaults.standard.set(score, forKey: "ShiritoriBest")
        }
    }
}
