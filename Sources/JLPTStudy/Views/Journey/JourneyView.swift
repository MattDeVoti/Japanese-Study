import SwiftUI

// MARK: - Journey model

/// One section of the journey — a single lesson chapter (kana or grammar).
struct JourneySection {
    let summary: ChapterSummary
    let levelLabel: String            // "Hiragana", "Katakana", "N5" …
    var isKana: Bool { summary.chapterType == "kana" }
    var id: String { summary.id }
    var header: String { "\(levelLabel) · \(summary.title)" }
}

/// A friendly guidance / onboarding screen.
struct CoachCard {
    let icon: String      // emoji
    let title: String
    let body: String
}

/// A single teaching screen for a grammar point.
enum TeachCard {
    case concept(name: String, desc: String)   // big point name + one-liner
    case text(tag: String, body: String)       // an explanation chunk
    case pattern(String)                        // the formation pattern
    case rules([String])                        // key rules
    case examples([GrammarExample])             // worked examples
}

/// One screen in the linear path.
enum JourneyStep {
    case coach(CoachCard)                        // guidance / onboarding
    case intro(JourneySection)
    case teach(TeachCard)                        // one guided teaching screen
    case quiz(pointId: String?, PracticeQuestion) // pointId != nil marks that point on success
    case vocab(LessonVocabWord)
    case kanji(KanjiCard)
    case kana(GrammarPoint)                       // a kana character card
    case done(JourneySection)

    // Shown once, at the very start of the whole journey.
    static let welcome: [JourneyStep] = [
        .coach(CoachCard(icon: "🧭", title: "Welcome to your Journey",
            body: "This is a guided path through everything in the app — starting from the very basics. You'll learn a little at a time: read each screen, tap Continue, and answer short quizzes along the way. Take it at your own pace; your progress is saved automatically.")),
        .coach(CoachCard(icon: "📖", title: "How it works",
            body: "You'll see grammar explained step by step, then vocabulary and kanji, then quick quizzes to check what stuck. When you answer a grammar point's quiz correctly, it gets checked off for you in the Textbook.")),
        .coach(CoachCard(icon: "💡", title: "A quick tip",
            body: "Small hiragana printed above a kanji — like 本[ほん] — shows you how to read it. That's called furigana, and it's there to help while you're still learning the characters.")),
    ]

    static func build(chapter: LessonChapter, section: JourneySection,
                      store: CardStore, quizzesPerPoint: Int) -> [JourneyStep] {
        var steps: [JourneyStep] = [.intro(section)]

        if section.isKana {
            if section.summary.chapterNumber == 1 {
                steps.append(.coach(kanaCoach(section.levelLabel)))
            }
            for p in chapter.points { steps.append(.kana(p)) }
            if !(chapter.chapterPractice ?? []).isEmpty {
                steps.append(.coach(CoachCard(icon: "✏️", title: "Quick check",
                    body: "Let's make sure those characters stuck. Tap the answer you think is right — don't worry about getting one wrong, it's how you learn.")))
            }
            for q in (chapter.chapterPractice ?? []) { steps.append(.quiz(pointId: nil, q)) }
        } else {
            for (i, p) in chapter.points.enumerated() {
                if i == 0 {
                    steps.append(.coach(CoachCard(icon: "💡", title: "Grammar",
                        body: "Now some grammar. We'll go through each point slowly — what it means, how it's built, and a few real examples — then you'll try a couple of questions.")))
                }
                steps.append(.teach(.concept(name: p.name, desc: p.shortDescription)))
                for chunk in explanationChunks(p.explanation) {
                    steps.append(.teach(.text(tag: "How it works", body: chunk)))
                }
                if !p.formation.trimmingCharacters(in: .whitespaces).isEmpty {
                    steps.append(.teach(.pattern(p.formation)))
                }
                if !p.rules.isEmpty { steps.append(.teach(.rules(p.rules))) }
                if !p.examples.isEmpty { steps.append(.teach(.examples(Array(p.examples.prefix(4))))) }
                if !((p.practice ?? []).isEmpty) {
                    steps.append(.coach(CoachCard(icon: "✅", title: "Your turn",
                        body: "See if you've got it. Pick the answer that fits — the explanation afterward will tell you why.")))
                    for q in (p.practice ?? []).prefix(quizzesPerPoint) {
                        steps.append(.quiz(pointId: p.id, q))
                    }
                }
            }
            if let vocab = chapter.vocab, !vocab.isEmpty {
                steps.append(.coach(CoachCard(icon: "📚", title: "Vocabulary",
                    body: "Here are the words for this chapter. For each one, tap “Show reading” to see how it's pronounced and what it means, then move on.")))
                for w in vocab { steps.append(.vocab(w)) }
            }
            let kanjiCards = (chapter.kanji ?? []).compactMap { store.kanjiCard(for: $0) }
            if !kanjiCards.isEmpty {
                steps.append(.coach(CoachCard(icon: "🎴", title: "Kanji",
                    body: "Finally, this chapter's kanji — characters that carry meaning. Most have two kinds of readings: 音 (on'yomi, from Chinese) and 訓 (kun'yomi, native Japanese). Tap “Show reading” to see both plus the meaning.")))
                for c in kanjiCards { steps.append(.kanji(c)) }
            }
        }
        steps.append(.done(section))
        return steps
    }

    private static func kanaCoach(_ levelLabel: String) -> CoachCard {
        if levelLabel == "Katakana" {
            return CoachCard(icon: "🌏", title: "About Katakana",
                body: "Katakana is Japan's second alphabet. It has the exact same sounds as hiragana, but it's used for words borrowed from other languages — like コーヒー (coffee). You'll learn these characters a few at a time.")
        }
        return CoachCard(icon: "🌱", title: "About Hiragana",
            body: "Hiragana is the basic Japanese alphabet — 46 characters, each standing for one sound. It's the foundation for everything else, so we'll start here. Learn a few characters, then practice them.")
    }

    /// Splits a grammar explanation into bite-sized screens (≈1–2 sentences each).
    static func explanationChunks(_ text: String) -> [String] {
        let paras = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var out: [String] = []
        let limit = 230
        for para in paras {
            if para.count <= limit { out.append(para); continue }
            // break into sentences, then regroup up to the limit
            var sentences: [String] = []
            var cur = ""
            let chars = Array(para)
            for (idx, ch) in chars.enumerated() {
                cur.append(ch)
                let nextIsSpaceOrEnd = idx + 1 >= chars.count || chars[idx + 1] == " "
                if ch == "。" || ((ch == "." || ch == "!" || ch == "?") && nextIsSpaceOrEnd) {
                    sentences.append(cur.trimmingCharacters(in: .whitespaces)); cur = ""
                }
            }
            let tail = cur.trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty { sentences.append(tail) }
            var chunk = ""
            for s in sentences {
                if chunk.isEmpty { chunk = s }
                else if chunk.count + s.count + 1 <= limit { chunk += " " + s }
                else { out.append(chunk); chunk = s }
            }
            if !chunk.isEmpty { out.append(chunk) }
        }
        return out
    }
}

/// Tiny persistence for "where the user is" in the path.
enum JourneyProgress {
    private static let key = "JourneyPosition"
    static func save(section: Int, step: Int) {
        UserDefaults.standard.set(["s": section, "t": step], forKey: key)
    }
    static func load() -> (section: Int, step: Int) {
        let d = UserDefaults.standard.dictionary(forKey: key) as? [String: Int]
        return (d?["s"] ?? 0, d?["t"] ?? 0)
    }
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Journey player

struct JourneyView: View {
    @EnvironmentObject private var cardStore: CardStore
    @ObservedObject private var lessons = LessonsProgressStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var sections: [JourneySection] = []
    @State private var sectionIndex = 0
    @State private var steps: [JourneyStep] = []
    @State private var stepIndex = 0

    // Transient per-step state
    @State private var selected: Int? = nil
    @State private var order: [Int] = []      // shuffled choice indices
    @State private var revealed = false

    @State private var pointCorrect: [String: Int] = [:]
    @State private var showSkip = false
    @State private var finished = false

    private let quizzesPerPoint = 2
    private let correctNeeded = 2

    private var section: JourneySection? {
        sections.indices.contains(sectionIndex) ? sections[sectionIndex] : nil
    }
    private var step: JourneyStep? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }
    private var accent: Color {
        guard let lv = section?.levelLabel else { return .red }
        return levelAccentColor(lv)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if finished {
                JourneyDoneScreen(accent: .red) { dismiss() }
            } else if let step = step, let section = section {
                VStack(spacing: 0) {
                    topBar(section: section)
                    ScrollView {
                        content(step)
                            .id(stepIndex)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity))
                            .padding(.horizontal, 24)
                            .padding(.top, 28)
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity)
                    }
                    bottomControl(step)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                }
            } else {
                ProgressView()
            }

            if showSkip { skipOverlay }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: start)
    }

    // MARK: Top bar

    private func topBar(section: JourneySection) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.appHairline)
                        Capsule().fill(accent)
                            .frame(width: geo.size.width * progressFraction)
                            .animation(.easeInOut(duration: 0.25), value: stepIndex)
                    }
                }
                .frame(height: 8)
            }
            Text(section.header)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var progressFraction: CGFloat {
        guard steps.count > 1 else { return 0 }
        return CGFloat(stepIndex) / CGFloat(steps.count - 1)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ step: JourneyStep) -> some View {
        switch step {
        case .coach(let c):        JourneyCoach(card: c, accent: accent)
        case .intro(let s):        JourneyIntro(section: s, accent: accent)
        case .done(let s):         JourneySectionDone(section: s, accent: accent)
        case .teach(let card):     JourneyTeach(card: card, accent: accent)
        case .kana(let p):         JourneyKana(point: p, accent: accent, revealed: revealed)
        case .vocab(let w):        JourneyVocab(word: w, accent: accent, revealed: revealed)
        case .kanji(let c):        JourneyKanji(card: c, revealed: revealed)
        case .quiz(let pointId, let q):
            JourneyQuiz(question: q, order: order, selected: selected, accent: accent) { i in
                answerQuiz(displayed: i, pointId: pointId, question: q)
            }
        }
    }

    // MARK: Bottom control

    @ViewBuilder
    private func bottomControl(_ step: JourneyStep) -> some View {
        switch step {
        case .quiz:
            if selected != nil {
                continueButton("Continue")
            } else {
                Text("Choose an answer")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
        case .vocab, .kanji, .kana:
            continueButton(revealed ? "Continue" : "Show reading",
                           action: revealed ? advance : { withAnimation { revealed = true } })
        default:
            continueButton("Continue")
        }
    }

    private func continueButton(_ title: String, action: (() -> Void)? = nil) -> some View {
        Button(action: action ?? advance) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(accent.badgeGradient)
                )
                .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Skip overlay

    private var skipOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Already done ✓")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.appText)
                Text("You've already completed this chapter in the textbook. Skip ahead to the next section that still needs work?")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    Button { skipToNextUnfinished() } label: {
                        Text("Skip ahead")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(accent.badgeGradient))
                    }.buttonStyle(.plain)
                    Button { showSkip = false } label: {
                        Text("Stay here")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }.buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .appCard(cornerRadius: 20)
            .padding(.horizontal, 30)
        }
    }

    // MARK: Flow

    private func start() {
        LessonsService.shared.loadIfNeeded()
        if sections.isEmpty {
            sections = (LessonsService.shared.manifest?.levels ?? []).flatMap { lv in
                lv.chapters.map { JourneySection(summary: $0, levelLabel: lv.jlptLevel) }
            }
        }
        let saved = JourneyProgress.load()
        sectionIndex = min(max(saved.section, 0), max(sections.count - 1, 0))
        loadSteps()
        stepIndex = min(max(saved.step, 0), max(steps.count - 1, 0))
        resetStep()
        if stepIndex == 0 { checkSkip() }
    }

    private func loadSteps() {
        guard sections.indices.contains(sectionIndex) else { finished = true; return }
        let sec = sections[sectionIndex]
        guard let chapter = LessonsService.shared.loadChapter(sec.summary.id) else {
            sectionIndex += 1
            if sectionIndex >= sections.count { finished = true } else { loadSteps() }
            return
        }
        steps = JourneyStep.build(chapter: chapter, section: sec,
                                  store: cardStore, quizzesPerPoint: quizzesPerPoint)
        if sectionIndex == 0 {
            steps.insert(contentsOf: JourneyStep.welcome, at: 0)
        }
    }

    private func resetStep() {
        selected = nil
        revealed = false
        if case .quiz(_, let q) = step {
            order = Array(0..<q.choices.count).shuffled()
        } else {
            order = []
        }
    }

    private func advance() {
        if stepIndex + 1 < steps.count {
            withAnimation(.easeInOut(duration: 0.25)) { stepIndex += 1 }
            resetStep()
            persist()
        } else {
            sectionIndex += 1
            if sectionIndex >= sections.count {
                finished = true; persist(); return
            }
            loadSteps()
            stepIndex = 0
            resetStep()
            persist()
            checkSkip()
        }
    }

    private func answerQuiz(displayed: Int, pointId: String?, question: PracticeQuestion) {
        guard selected == nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) { selected = displayed }
        let correct = order[displayed] == question.correctIndex
        if correct, let pid = pointId {
            pointCorrect[pid, default: 0] += 1
            if pointCorrect[pid, default: 0] >= correctNeeded, let cid = section?.summary.id {
                lessons.markCompleted(chapterId: cid, pointId: pid)
            }
        }
    }

    private func checkSkip() {
        guard let sec = section else { return }
        if !sec.isKana && sec.summary.pointCount > 0 &&
            lessons.completedCount(chapterId: sec.summary.id) >= sec.summary.pointCount {
            showSkip = true
        }
    }

    private func skipToNextUnfinished() {
        showSkip = false
        var j = sectionIndex + 1
        while j < sections.count {
            let s = sections[j]
            if s.isKana || lessons.completedCount(chapterId: s.summary.id) < s.summary.pointCount { break }
            j += 1
        }
        if j >= sections.count { finished = true; persist(); return }
        sectionIndex = j
        loadSteps()
        stepIndex = 0
        resetStep()
        persist()
    }

    private func persist() { JourneyProgress.save(section: sectionIndex, step: stepIndex) }
}
