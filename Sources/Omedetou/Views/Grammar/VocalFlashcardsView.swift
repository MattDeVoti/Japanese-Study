import SwiftUI

// Flashcards done out loud: the app says the word, you say what it means.
//
// The one rule that shapes the whole screen — nothing is marked while you play.
// A spoken answer is judged by a speech recogniser, and a recogniser is wrong
// often enough that letting it quietly rewrite your study weights would corrupt
// the deck over a few sessions. So a run only ever produces a tally, and the
// summary at the end asks before it changes anything.

struct VocalFlashcardsView: View {
    /// The vocal deck's own filter: same sheet, independent selections. Marks and
    /// favorites still land in the shared store behind it.
    @ObservedObject private var filter = VocalDeckFilter.shared
    @ObservedObject private var settings = VocalStudySettings.shared
    @ObservedObject private var speech = SpeechService.shared
    @ObservedObject private var listener = VocalAnswerListener.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var allCards: [VocabFlashCard] = []
    @State private var current: VocabFlashCard?
    /// Words asked so far — the position counter, and what keeps each utterance's
    /// id unique so a repeat of the same word never reads as "stop speaking".
    @State private var asked = 0
    @StateObject private var sequencer = DeckSequencer()
    @State private var phase: Phase = .ready
    @State private var answers: [Answer] = []
    @State private var heard = ""
    @State private var listeningUntil: Date?
    @State private var thinkingUntil: Date?
    @State private var advance: DispatchWorkItem?
    /// What the summary will do to each word, keyed by word id.
    @State private var marks: [String: Mark] = [:]
    @State private var showFilter = false
    /// Fires if a card's audio never reports back. See `armWatchdog`.
    @State private var watchdog: DispatchWorkItem?
    /// The card the watchdog has already rescued once, so a second failure ends
    /// the run instead of looping silently.
    @State private var rescued: String?
    @State private var cardDirection: CardDirection = .japaneseToEnglish

    private enum Phase: Equatable {
        case ready
        case prompting
        case listening
        case judged(VocalVerdict)
        /// Audio Only: the silent gap for answering in your head…
        case thinking
        /// …and the meaning being read out.
        case reveal
        case summary
    }

    private struct Answer {
        let card: VocabFlashCard
        var verdict: VocalVerdict
        /// The direction this card was actually asked in — never `.random`.
        let direction: CardDirection
    }

    private enum Mark: CaseIterable {
        case confident, needsWork, leave

        var next: Mark {
            switch self {
            case .confident: return .needsWork
            case .needsWork: return .leave
            case .leave:     return .confident
            }
        }
        var label: String {
            switch self {
            case .confident: return "Confident"
            case .needsWork: return "Needs Work"
            case .leave:     return "Leave as is"
            }
        }
        var color: Color {
            switch self {
            case .confident: return .green
            case .needsWork: return .red
            case .leave:     return .gray
            }
        }
    }

    /// Exactly the deck the written flashcards would deal from — same filter, same
    /// exclusions — so "whatever shows up there shows up here, and nothing else"
    /// is enforced by sharing the code rather than by remembering to.
    private var pool: [VocabFlashCard] {
        filter.apply(to: allCards)
    }

    /// Which half leads for the card on screen. Resolved once when the card is
    /// dealt and held, so a Random run can't flip direction mid-question.
    private var reversed: Bool { cardDirection.isReversed }

    private var rightCount: Int { answers.filter { $0.verdict == .correct }.count }
    private var skippedCount: Int { answers.filter { $0.verdict == .skipped }.count }
    private var wrongCount: Int { answers.count - rightCount - skippedCount }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            if !speech.isAvailable || !speech.isEnabled {
                needsAudio
            } else {
                switch phase {
                case .ready:   readyScreen
                case .summary: summaryScreen
                default:       sessionScreen
                }
            }
        }
        .standardNavBar("Audio Flash Cards")
        // The same filter sheet as the written deck — same pool, same controls.
        // Every section of it shapes what this mode deals, so nothing is hidden.
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button { showFilter = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .foregroundColor(.appNavBarText)
                            if filter.hasActiveFilter {
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showFilter) {
            VocabFilterSheet(filter: filter, allCards: allCards,
                             copyFromFlashcards: { filter.copyFromFlashcards() })
        }
        // A sheet doesn't stop the view behind it, so without this the mic would
        // keep listening — and the session keep advancing — behind the filter.
        // Opening it parks the run on the current word; closing it deals the next
        // from the freshly filtered pool.
        .onChange(of: showFilter) { open in
            guard phase != .ready, phase != .summary else { return }
            if open {
                advance?.cancel()
                cancelWatchdog()
                listener.cancel()
                speech.stop()
                phase = .prompting
            } else {
                drawNext()
            }
        }
        .alert(item: $listener.problem) { problem in
            Alert(title: Text("Can't listen"),
                  message: Text(problem.message),
                  dismissButton: .default(Text("OK")) { endSession() })
        }
        .onAppear {
            if allCards.isEmpty { allCards = VocabDeck.allCards() }
        }
        .onDisappear {
            advance?.cancel()
            cancelWatchdog()
            listener.cancel()
            speech.stop()
            settings.handsFreeRunning = false
        }
        // Audio Only is built to play on with the screen off. A microphone run
        // can't follow it there — iOS won't record from a locked device — so
        // rather than strand it on a countdown that will never finish, leaving
        // the app ends the run and shows what you got.
        .onChange(of: scenePhase) { newPhase in
            guard newPhase != .active, !settings.audioOnly,
                  phase != .ready, phase != .summary else { return }
            finishEarly()
        }
    }

    // MARK: - Gate

    private var needsAudio: some View {
        VStack(spacing: 14) {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(speech.isAvailable ? "Japanese audio is turned off." : "No Japanese voice is installed.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.appText)
            Text(speech.isAvailable
                 ? "Audio flash cards read each word aloud. Turn Japanese Audio back on in Options ▸ Audio."
                 : "Audio flash cards read each word aloud. Add a Japanese voice in Settings ▸ Accessibility ▸ Spoken Content ▸ Voices ▸ Japanese.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Ready

    private var readyScreen: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: settings.audioOnly ? "headphones" : "waveform.and.mic")
                .font(.system(size: 52))
                .foregroundColor(Color.readableOnPage(.appAccent))

            VStack(spacing: 8) {
                Text(settings.audioOnly
                     ? "Listen and answer in your head"
                     : reversed ? "Say the Japanese" : "Say what it means")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(pool.isEmpty
                     ? "No words match your filters."
                     : settings.audioOnly
                       ? (reversed
                          ? "Each meaning, a pause, then the Japanese. No microphone."
                          : "Each word, a pause, then its meaning. No microphone.")
                       : reversed
                         ? "Hear the meaning, say the Japanese word."
                         : "Hear a word, say any one of its meanings.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }

            // Spelled out rather than an icon: a headphones glyph reads as
            // "headphones are connected", and nothing about it suggests there
            // are two ways to study or that tapping changes anything.
            VStack(spacing: 8) {
                modeChoice(audioOnly: true, title: "Audio Only",
                           detail: reversed
                                   ? "No microphone. Hear the meaning, then the Japanese."
                                   : "No microphone. Hear the word, then its meaning.")
                modeChoice(audioOnly: false, title: "Audio and Voice Response",
                           detail: reversed
                                   ? "Say the Japanese out loud and it's marked."
                                   : "Say the meaning out loud and it's marked.")
            }
            .padding(.horizontal, 24)

            if !pool.isEmpty {
                Text(settings.audioOnly
                     ? "\(pool.count) words  ·  \(Int(VocalStudySettings.audioOnlyThink))s to think"
                     : "\(pool.count) words  ·  \(Int(settings.answerSeconds))s each")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextSecondary)

                Button { startSession() } label: {
                    Text("Start")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Color.appAccent.badgeGradient)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 44)
                .padding(.top, 4)
            }

            Spacer()
            Spacer()
        }
    }

    private func modeChoice(audioOnly: Bool, title: String, detail: String) -> some View {
        let on = (settings.audioOnly == audioOnly)
        return Button {
            guard !on else { return }
            toggleAudioOnly()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(on ? Color.readableOnPage(.appAccent) : .appTextSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appText)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(on ? Color.appAccent.opacity(0.12) : Color.appSurface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(on ? Color.readableOnPage(.appAccent) : Color.appHairline,
                              lineWidth: on ? 1.8 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session

    private var sessionScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if settings.audioOnly {
                    // Nothing is scored in Audio Only, so there is no score to
                    // show — just what you're listening to and how far in.
                    Label("Audio Only", systemImage: "headphones")
                        .foregroundColor(.appTextSecondary)
                    Text("\(asked)")
                        .foregroundColor(.appTextSecondary)
                        .monospacedDigit()
                } else {
                    // A running score rather than a position: the deck has no end
                    // to count towards, and how you're doing is the useful number.
                    Label("\(rightCount)", systemImage: "checkmark")
                        .foregroundColor(.green)
                    Label("\(wrongCount)", systemImage: "xmark")
                        .foregroundColor(.red)
                    if skippedCount > 0 {
                        Label("\(skippedCount)", systemImage: "arrow.forward")
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.top, 14)

            Spacer()

            if let card = current {
                VStack(spacing: 10) {
                    Text(card.word.kanji)
                        .font(.system(size: 46, weight: .bold))
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.center)
                    if card.word.kanji != card.word.kana {
                        Text(card.word.kana)
                            .font(.system(size: 19))
                            .foregroundColor(.secondary)
                    }
                    SpeakButton(text: card.word.kana, size: 20, tint: card.accentColor)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            stateArea
                .frame(height: 210)

            Spacer()

            // Ending a run is a deliberate act, so the control for it sits where
            // a deliberate tap lands rather than tucked in a corner.
            //
            // It hides — rather than moves — while "I was right" is up. Those two
            // land a thumb's width apart, and hitting Finish when you meant to
            // overrule a misheard answer ends the whole session. Opacity rather
            // than removal keeps the layout still, so nothing shifts under a
            // thumb already on its way down.
            Button { finishEarly() } label: {
                Text("Finish")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.readableOnPage(.appAccent))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.appSurface))
                    .overlay(Capsule().strokeBorder(Color.appHairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .opacity(overruleVisible ? 0 : 1)
            .allowsHitTesting(!overruleVisible)
            .animation(.easeInOut(duration: 0.18), value: overruleVisible)
            .padding(.bottom, 26)
        }
    }

    /// True while the "I was right" button is on screen.
    private var overruleVisible: Bool {
        if case .judged(let verdict) = phase {
            return verdict != .correct && verdict != .skipped
        }
        return false
    }

    @ViewBuilder
    private var stateArea: some View {
        switch phase {
        case .listening:
            listeningArea
        case .judged(let verdict):
            verdictArea(verdict)
        case .thinking:
            thinkingArea
        case .reveal:
            revealArea
        default:
            VStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color.readableOnPage(.appAccent))
                    .symbolEffectPulse(true)
                Text("Listen…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }

    private var listeningArea: some View {
        VStack(spacing: 14) {
            // 30 frames a second, not display rate: the ring sweeps too slowly
            // for 120Hz to be visible, and a session holds this screen open for
            // minutes at a time.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let remaining = max(0, listeningUntil?.timeIntervalSince(timeline.date) ?? 0)
                let fraction = min(1, max(0, remaining / max(settings.answerSeconds, 0.001)))

                ZStack {
                    Circle()
                        .stroke(Color.appHairline, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Color.readableOnPage(.appAccent),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 3) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.readableOnPage(.appAccent))
                        Text("\(Int(remaining.rounded(.up)))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.appText)
                            .monospacedDigit()
                    }
                }
                .frame(width: 104, height: 104)
            }

            Text(heardOrPrompt)
                .font(.system(size: 15, weight: heard.isEmpty ? .regular : .semibold))
                .foregroundColor(heard.isEmpty ? .appTextSecondary : .appText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 28)
                .frame(height: 44)
        }
    }

    /// Audio Only's thinking gap. Same ring as the mic mode so the screen stays
    /// recognisable, without the microphone at its centre.
    private var thinkingArea: some View {
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let remaining = max(0, thinkingUntil?.timeIntervalSince(timeline.date) ?? 0)
                let fraction = min(1, max(0, remaining / VocalStudySettings.audioOnlyThink))

                ZStack {
                    Circle().stroke(Color.appHairline, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Color.readableOnPage(.appAccent),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(remaining.rounded(.up)))")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.appText)
                        .monospacedDigit()
                }
                .frame(width: 104, height: 104)
            }

            Text("Think of the meaning…")
                .font(.system(size: 15))
                .foregroundColor(.appTextSecondary)
                .frame(height: 44)
        }
    }

    private var revealArea: some View {
        VStack(spacing: 10) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 34))
                .foregroundColor(Color.readableOnPage(.appAccent))
                .symbolEffectPulse(true)

            if let card = current {
                Text(card.word.definition)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(height: 210)
    }

    private var heardOrPrompt: String {
        let live = listener.partial.isEmpty ? heard : listener.partial
        if live.isEmpty { return reversed ? "Say the Japanese…" : "Say the meaning…" }
        return "“\(live)”"
    }

    private func verdictArea(_ verdict: VocalVerdict) -> some View {
        let right = (verdict == .correct)
        let skipped = (verdict == .skipped)
        return VStack(spacing: 10) {
            Image(systemName: right ? "checkmark.circle.fill"
                                    : skipped ? "arrow.forward.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(right ? .green : skipped ? .gray : .red)

            if let card = current {
                Text(reversed ? "\(card.word.kanji)  （\(card.word.kana)）" : card.word.definition)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if skipped {
                Text("Skipped")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            } else if !heard.isEmpty {
                Text("You said “\(heard)”")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 24)
            } else if verdict == .silent {
                Text("Nothing heard")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }

            HStack(spacing: 10) {
                // Recognition mishears; overruling it has to be cheap and easy to
                // hit — this is the only place the learner can say so, and it's a
                // moving target on a timer. A skip was the learner's own call, so
                // there's nothing to overrule there.
                if !right && !skipped {
                    Button { overrule() } label: {
                        Text("I was right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(Color.green.opacity(0.14)))
                            .overlay(Capsule().strokeBorder(Color.green.opacity(0.5), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                Button { advanceNow() } label: {
                    Text("Next")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.appSurfaceHigh))
                        .overlay(Capsule().strokeBorder(Color.appHairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Summary

    private var summaryScreen: some View {
        let rows = tally()
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("Session complete")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.appText)
                        let right = answers.filter { $0.verdict == .correct }.count
                        Text("\(right) of \(answers.count) right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, 18)

                    if !rows.isEmpty {
                        Text("Tap a word to change what happens to it.")
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)

                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.key) { idx, row in
                                summaryRow(row, striped: idx % 2 == 0)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.appHairline, lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 12)
                }
            }

            VStack(spacing: 8) {
                Button { applyMarks(rows) } label: {
                    Text(applyLabel(rows))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.appAccent.badgeGradient))
                }
                .buttonStyle(.plain)

                Button { phase = .ready } label: {
                    Text("Don't mark anything")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(Color.appBackgroundEnd.ignoresSafeArea(edges: .bottom))
        }
    }

    private func summaryRow(_ row: TallyRow, striped: Bool) -> some View {
        let mark = marks[row.key] ?? .leave
        return Button {
            marks[row.key] = mark.next
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.card.word.kanji)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appText)
                    Text(row.card.word.definition)
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    if row.right > 0 {
                        Label("\(row.right)", systemImage: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                    if row.wrong > 0 {
                        Label("\(row.wrong)", systemImage: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }
                    if row.skips > 0 {
                        Label("\(row.skips)", systemImage: "arrow.forward")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .labelStyle(.titleAndIcon)

                Text(mark.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(mark == .leave ? .appTextSecondary : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(mark == .leave
                                               ? Color.appSurfaceHigh
                                               : mark.color.opacity(0.9)))
                    .overlay(Capsule().strokeBorder(Color.appHairline,
                                                    lineWidth: mark == .leave ? 1 : 0))
                    .frame(width: 84, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(striped ? Color.appSurface : Color.appSurfaceHigh)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private struct TallyRow {
        let card: VocabFlashCard
        let direction: CardDirection
        var right = 0
        var wrong = 0
        var skips = 0

        /// Unique per word *and* direction.
        var key: String { "\(card.word.id)|\(direction.rawValue)" }
    }

    /// One row per word, however many times it came up.
    private func tally() -> [TallyRow] {
        var order: [String] = []
        var rows: [String: TallyRow] = [:]
        for answer in answers {
            // Keyed by word *and* direction: a Random run can ask the same word
            // both ways, and those are two different things to have learned.
            let id = "\(answer.card.word.id)|\(answer.direction.rawValue)"
            if rows[id] == nil {
                rows[id] = TallyRow(card: answer.card, direction: answer.direction)
                order.append(id)
            }
            switch answer.verdict {
            case .correct: rows[id]?.right += 1
            case .skipped: rows[id]?.skips += 1
            default:       rows[id]?.wrong += 1
            }
        }
        return order.compactMap { rows[$0] }
    }

    private func applyLabel(_ rows: [TallyRow]) -> String {
        let count = rows.filter { (marks[$0.card.word.id] ?? .leave) != .leave }.count
        return count == 0 ? "Done" : "Mark \(count) word\(count == 1 ? "" : "s")"
    }

    /// The only place the session writes anything, and only on a tap.
    ///
    /// Both marks record the session as it actually went: every right answer and
    /// every wrong one is added to that word's running tallies, so a word you got
    /// right four times out of five ends up weighted differently from one you
    /// scraped through once. The mark decides only one thing — whether the word
    /// is checked off and retired from the lineup, which a word you're mostly
    /// getting wrong should not be.
    ///
    /// Skips are counted on the wrong side. A skip is "I didn't know it", and
    /// without this a word you skipped three times and never answered would
    /// record nothing at all.
    private func applyMarks(_ rows: [TallyRow]) {
        let marked = rows.filter { (marks[$0.card.word.id] ?? .leave) != .leave }
        guard !marked.isEmpty else { phase = .ready; return }

        filter.addWeights(marked.map {
            (wordId: $0.card.word.id, confident: $0.right, needsWork: $0.wrong + $0.skips)
        })

        // One grade per word, not one per answer: the schedule is about when to
        // see the word next, and it only needs to know how the session went.
        for row in marked {
            let confident = (marks[row.key] ?? .leave) == .confident
            SRSStore.shared.grade(.vocab(row.card.word.id), confident ? .good : .again)
        }

        // Checkmarks belong to a direction: knowing 食[た]べる → "to eat" says
        // nothing about producing 食[た]べる from "to eat". A Random run mixes
        // both within one session, so each is applied to its own half.
        for direction in CardDirection.asked {
            let inDirection = marked.filter { $0.direction == direction }
            filter.exclude(inDirection.filter { marks[$0.key] == .confident }
                                      .map { $0.card.word.id }, direction: direction)
            // Needs Work and a checkmark contradict each other.
            filter.unexclude(inDirection.filter { marks[$0.key] == .needsWork }
                                        .map { $0.card.word.id }, direction: direction)
        }
        phase = .ready
    }

    // MARK: - Flow

    private func startSession() {
        guard !pool.isEmpty else { return }
        sequencer.reset()
        answers = []
        marks = [:]
        heard = ""
        asked = 0
        // Audio Only never opens the mic, so it must never ask for it — that is
        // most of the point of the mode.
        guard !settings.audioOnly else { drawNext(); return }
        // Clear the permission prompts before the first word is read, not during
        // the answer window it opens. A refusal surfaces through `problem`.
        listener.requestAccess { granted in
            guard granted else { return }
            drawNext()
        }
    }

    /// Switching mode restarts the run: the two are different loops, and carrying
    /// half a tally from one into the other would make the summary a lie.
    private func toggleAudioOnly() {
        let running = (phase != .ready && phase != .summary)
        advance?.cancel()
        cancelWatchdog()
        listener.cancel()
        speech.stop()
        settings.handsFreeRunning = false
        settings.audioOnly.toggle()
        if running { startSession() } else { phase = .ready }
    }

    /// Takes the next word from the deck the same way the written flashcards do,
    /// which brings the priority weighting across with it. The run has no end —
    /// it keeps dealing until Finish is tapped.
    private func drawNext() {
        guard let card = filter.selectNext(from: pool, using: sequencer) else {
            finishEarly()
            return
        }
        current = card
        cardDirection = filter.resolvedDirection(for: card.word.id)
        asked += 1
        heard = ""
        if settings.audioOnly { runAudioOnly(card); return }
        ask(card)
    }

    /// The microphone path: read the word, then open the mic.
    private func ask(_ card: VocabFlashCard) {
        phase = .prompting
        // A unique id per question: speaking the same id twice is read as a stop,
        // and a stopped utterance would never hand control back. Words can repeat
        // in a long run, so the counter — not the word — has to make it unique.
        let tail = speech.tailBeforeRecording
        let prompt = reversed ? card.word.definition : card.word.kana
        let speakPrompt: (@escaping () -> Void) -> Void = { done in
            if reversed { speech.speakEnglish(prompt, id: "vocal-\(asked)", completion: done) }
            else { speech.speak(prompt, id: "vocal-\(asked)-\(card.word.id)", completion: done) }
        }
        speakPrompt {
            // Let the word actually finish reaching the speaker before the mic
            // claims the route — see `tailBeforeRecording`. Without this the
            // last syllable is clipped on Bluetooth, which in a car is most of
            // what you were listening for.
            schedule(after: tail) {
                cancelWatchdog()
                listen()
            }
        }
        // Only covers the prompt and the gap after it: once the mic is open the
        // listener runs its own window, which cannot hang.
        armWatchdog(14 + tail, card: card)
    }

    /// Word, pause, meaning, beat, next — with the microphone never opened.
    ///
    /// Nothing is judged here, so nothing is tallied and the summary has nothing
    /// to propose: this is a listening loop, not a quiz, and the run simply ends
    /// where you stop it.
    ///
    /// The whole card is handed to the synthesiser in one call, pauses included,
    /// so no step of the loop depends on a timer firing. That's what survives the
    /// lock screen — see `speakCard`.
    private func runAudioOnly(_ card: VocabFlashCard) {
        settings.handsFreeRunning = true
        phase = .prompting
        thinkingUntil = nil

        speech.speakCard(
            prompt: reversed ? card.word.definition : card.word.kana,
            promptIsJapanese: !reversed,
            gap: VocalStudySettings.audioOnlyThink,
            answer: reversed ? card.word.kana : card.word.definition,
            answerIsJapanese: reversed,
            trailing: VocalStudySettings.audioOnlyGap,
            onGapStart: {
                phase = .thinking
                thinkingUntil = Date().addingTimeInterval(VocalStudySettings.audioOnlyThink)
            },
            onAnswerStart: { phase = .reveal },
            completion: {
                cancelWatchdog()
                step()
            })
        // Japanese + gap + English + tail, plus generous slack for a slow voice.
        armWatchdog(VocalStudySettings.audioOnlyThink + VocalStudySettings.audioOnlyGap + 16,
                    card: card)
    }

    /// The session advances only when the synthesiser reports back, and there are
    /// ways for that report never to arrive: an audio route change mid-utterance
    /// (a car stereo connecting), a phone call, a mode switch racing a cancel.
    /// When it doesn't, nothing else would ever move — the card just sits there,
    /// silent, forever. This is the only thing standing between that and a dead
    /// session, so it recovers rather than merely logging.
    private func armWatchdog(_ seconds: TimeInterval, card: VocabFlashCard) {
        watchdog?.cancel()
        let work = DispatchWorkItem {
            guard phase != .ready, phase != .summary else { return }
            if rescued == card.word.id {
                // Twice on the same card means the audio isn't coming back.
                // Ending with results beats pretending to run.
                rescued = nil
                finishEarly()
                return
            }
            rescued = card.word.id
            // Force the next utterance to rebuild the audio session, then retry
            // this same card — the usual cause is a session pointed at a device
            // that is no longer there.
            speech.yieldSession()
            if settings.audioOnly { runAudioOnly(card) } else { ask(card) }
        }
        watchdog = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func cancelWatchdog() {
        watchdog?.cancel()
        watchdog = nil
        rescued = nil
    }

    private func listen() {
        guard phase == .prompting, current != nil else { return }
        phase = .listening
        listeningUntil = Date().addingTimeInterval(settings.answerSeconds)
        // Japanese answers need a Japanese recogniser; an en-US one hears たべる
              // as nonsense syllables and would mark every answer wrong.
        listener.listen(seconds: settings.answerSeconds,
                        locale: reversed ? "ja-JP" : "en-US") { text in
            guard phase == .listening else { return }
            heard = text
            judge(text)
        }
    }

    private func judge(_ text: String) {
        guard let card = current, listener.problem == nil else { return }
        let verdict = reversed
            ? VocalAnswerMatcher.judgeJapanese(heard: text, word: card.word.kanji,
                                               kana: card.word.kana)
            : VocalAnswerMatcher.judge(heard: text, definition: card.word.definition)

        // "Stop" ends the run and goes straight to the results. Nothing is
        // recorded for this word: it was never attempted, and counting it wrong
        // would put a mark against a word whose only crime was being on screen
        // when the learner decided to leave.
        if verdict == .stopped {
            finishEarly()
            return
        }

        answers.append(Answer(card: card, verdict: verdict, direction: cardDirection))
        phase = .judged(verdict)

        switch verdict {
        case .correct:
            FeedbackSounds.shared.play(.correct)
            schedule(after: 1.1) { step() }
        case .skipped:
            // The learner asked to move on, so no buzz — a skip isn't a mistake.
            // The answer is still spoken: saying "skip" means "tell me", and the
            // shorter tail keeps the pace they asked for.
            speakAnswer(card) {
                schedule(after: 0.7) { step() }
            }
        default:
            FeedbackSounds.shared.play(.incorrect)
            // Let the cue finish before the voice starts, or the two collide.
            schedule(after: 0.45) {
                speakAnswer(card) {
                    // A real pause after hearing the answer. Rolling straight into
                    // the next word gives you no moment to take it in, and that
                    // moment is where the learning happens.
                    schedule(after: 1.8) { step() }
                }
            }
        }
    }

    /// Reads the half that was hidden, in its own language.
    private func speakAnswer(_ card: VocabFlashCard, then done: @escaping () -> Void) {
        if reversed { speech.speak(card.word.kana, id: "vocal-ans-\(asked)", completion: done) }
        else { speech.speakEnglish(card.word.definition, id: "vocal-ans-\(asked)", completion: done) }
    }

    /// Flips the last answer to correct — the recogniser, not the learner, was
    /// wrong. Only ever changes this session's tally.
    private func overrule() {
        guard case .judged = phase, !answers.isEmpty else { return }
        advance?.cancel()
        speech.stop()
        answers[answers.count - 1].verdict = .correct
        phase = .judged(.correct)
        FeedbackSounds.shared.play(.correct)
        schedule(after: 0.7) { step() }
    }

    private func advanceNow() {
        advance?.cancel()
        speech.stop()
        step()
    }

    private func step() {
        drawNext()
    }

    private func finishEarly() {
        advance?.cancel()
        cancelWatchdog()
        listener.cancel()
        speech.stop()
        settings.handsFreeRunning = false
        showSummary()
    }

    private func showSummary() {
        // Right beats wrong, and a tie counts as unsure — getting it right once
        // and wrong once is not knowing it. A skip counts on the wrong side
        // here: "I didn't know it" is exactly what Needs Work is for.
        for row in tally() {
            marks[row.key] = row.right > row.wrong + row.skips ? .confident : .needsWork
        }
        phase = answers.isEmpty ? .ready : .summary
    }

    private func endSession() {
        advance?.cancel()
        cancelWatchdog()
        listener.cancel()
        speech.stop()
        settings.handsFreeRunning = false
        phase = .ready
    }

    private func schedule(after seconds: TimeInterval, _ block: @escaping () -> Void) {
        advance?.cancel()
        let work = DispatchWorkItem(block: block)
        advance = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
