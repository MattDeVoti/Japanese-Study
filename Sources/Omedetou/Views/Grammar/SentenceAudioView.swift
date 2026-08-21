import SwiftUI

// Example sentences, read aloud, hands free.
//
// The audio flash cards drill words you already chose; this drills the sentences
// the chapters teach them in. A sentence is read in Japanese, then — after a
// pause long enough to actually work it out — in English. Nothing is marked and
// nothing is judged: it is a listening loop, so there is no summary to show and
// no way to get it wrong.
//
// The whole sentence (Japanese, pause, English) is handed to the synthesiser in
// one call, exactly as Audio Only does, because that is what keeps playing when
// the screen locks. Anything driven by a timer stops the moment it does.

/// One example sentence, tagged with where it came from.
struct SentenceItem: Identifiable, Hashable {
    let id: String
    let chapterId: String
    let chapterNumber: Int
    let levelId: String
    let pointName: String
    /// Japanese in the app's furigana markup — `SpeechService` strips it for TTS
    /// and `FuriganaText` renders it.
    let japanese: String
    let english: String
}

/// Which chapters the sentence loop draws from, remembered between runs.
final class SentenceAudioSettings: ObservableObject {
    static let shared = SentenceAudioSettings()

    /// Empty means every chapter — the same convention the vocab filter uses, so
    /// a first run plays rather than showing an empty screen.
    @Published var selectedChapterIds: Set<String> {
        didSet { UserDefaults.standard.set(Array(selectedChapterIds), forKey: Keys.chapters) }
    }

    /// Whether the loop leaves you room to work the sentence out before it
    /// answers. On by default: translating in the gap is the exercise, and the
    /// mode is much less useful without it. Turned off, the English follows
    /// almost straight away — for listening to the pair as a pair, or for a
    /// second pass through material you already know.
    @Published var letMeThink: Bool {
        didSet { UserDefaults.standard.set(letMeThink, forKey: Keys.letMeThink) }
    }

    /// The silence between the Japanese and the English.
    ///
    /// Long enough to hear the sentence, parse it and try a translation, short
    /// enough that the loop keeps moving.
    static let thinkingGap: TimeInterval = 7
    /// Just enough to keep the two languages from running together.
    static let quickGap: TimeInterval = 1
    /// A beat after the English so the next sentence doesn't tread on it.
    static let trailing: TimeInterval = 1.4

    /// The gap the next sentence will use.
    var gap: TimeInterval { letMeThink ? Self.thinkingGap : Self.quickGap }

    private enum Keys {
        static let chapters = "SentenceAudioChapters"
        static let letMeThink = "SentenceAudioLetMeThink"
    }

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: Keys.chapters) ?? []
        selectedChapterIds = Set(saved)
        // Absent means never set, which is a first run — and the default is on.
        letMeThink = UserDefaults.standard.object(forKey: Keys.letMeThink) as? Bool ?? true
    }
}

struct SentenceAudioView: View {
    @ObservedObject private var settings = SentenceAudioSettings.shared
    @ObservedObject private var speech = SpeechService.shared
    @ObservedObject private var vocalSettings = VocalStudySettings.shared

    @State private var allSentences: [SentenceItem] = []
    /// The shuffled running order for this session.
    @State private var queue: [SentenceItem] = []
    @State private var current: SentenceItem?
    @State private var played = 0
    @State private var phase: Phase = .ready
    @State private var gapEnds: Date?
    /// The gap the sentence on screen was queued with. Flipping the toggle
    /// mid-sentence must not stretch or squash the countdown already running.
    @State private var currentGap: TimeInterval = SentenceAudioSettings.thinkingGap
    @State private var showChapters = false
    @State private var watchdog: DispatchWorkItem?
    @State private var rescued: String?

    private enum Phase: Equatable {
        case ready
        /// The Japanese is being read.
        case japanese
        /// The silence in between.
        case thinking
        /// The English is being read.
        case english
    }

    /// Every sentence in the selected chapters. Empty selection means all of them.
    private var pool: [SentenceItem] {
        settings.selectedChapterIds.isEmpty
            ? allSentences
            : allSentences.filter { settings.selectedChapterIds.contains($0.chapterId) }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            if !speech.isAvailable || !speech.isEnabled {
                needsAudio
            } else if phase == .ready {
                readyScreen
            } else {
                sessionScreen
            }
        }
        .standardNavBar("Sentence Audio")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showChapters = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundColor(.appNavBarText)
                        if !settings.selectedChapterIds.isEmpty {
                            Circle().fill(Color.yellow)
                                .frame(width: 7, height: 7)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showChapters) {
            SentenceChapterSheet(settings: settings, sentences: allSentences)
        }
        // The sheet deliberately does NOT interrupt the loop. This mode is built
        // to keep reading while you do something else, and stopping the
        // synthesiser only to restart it a moment later is unreliable: the
        // restart lands while the cancel is still in flight, and the run goes
        // silent. A changed selection takes effect from the next sentence.
        .onChange(of: showChapters) { open in
            guard !open, phase != .ready else { return }
            queue = pool.shuffled()
        }
        .onAppear {
            if allSentences.isEmpty { allSentences = Self.loadSentences() }
        }
        // No scene-phase handling on purpose: unlike a microphone run, this one
        // is *meant* to keep playing with the screen off, so backgrounding must
        // not end it. Leaving the screen does.
        .onDisappear { endSession() }
    }

    private var needsAudio: some View {
        VStack(spacing: 14) {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(speech.isAvailable ? "Japanese audio is turned off." : "No Japanese voice is installed.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.appText)
            Text(speech.isAvailable
                 ? "Sentence Audio reads each example aloud. Turn Japanese Audio back on in Options ▸ Audio."
                 : "Sentence Audio reads each example aloud. Add a Japanese voice in Settings ▸ Accessibility ▸ Spoken Content ▸ Voices ▸ Japanese.")
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

            Image(systemName: "text.bubble")
                .font(.system(size: 52))
                .foregroundColor(Color.readableOnPage(.appAccent))

            VStack(spacing: 8) {
                Text("Listen to example sentences")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(pool.isEmpty
                     ? "No sentences in the chapters you picked."
                     : settings.letMeThink
                       ? "A sentence in Japanese, \(Int(SentenceAudioSettings.thinkingGap)) seconds to work it out, then the English. No microphone."
                       : "A sentence in Japanese, then the English straight after. No microphone.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }

            Button { showChapters = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.closed")
                    Text(chapterSummaryLabel)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.appHairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            if !pool.isEmpty {
                Text(settings.letMeThink
                     ? "\(pool.count) sentences  ·  \(Int(SentenceAudioSettings.thinkingGap))s to think"
                     : "\(pool.count) sentences  ·  no pause")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextSecondary)

                Button { startSession() } label: {
                    Text("Start")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color.appAccent.badgeGradient))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 44)
                .padding(.top, 4)
            }

            Spacer()
            Spacer()
        }
    }

    private var chapterSummaryLabel: String {
        let ids = settings.selectedChapterIds
        if ids.isEmpty { return "All chapters" }
        if ids.count == 1,
           let only = allSentences.first(where: { $0.chapterId == ids.first }) {
            return "\(levelName(jlpt: only.levelId)) · Chapter \(only.chapterNumber)"
        }
        return "\(ids.count) chapters"
    }

    // MARK: - Session

    private var sessionScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(played) played")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
                Spacer()
                if let c = current {
                    Text("\(levelName(jlpt: c.levelId)) · Ch \(c.chapterNumber)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appTextSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            if let c = current {
                VStack(spacing: 18) {
                    Text(c.pointName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.readableOnPage(.appAccent))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    FuriganaText(text: c.japanese, fontSize: 24, color: .appText,
                                 weight: .semibold, alignment: .center)
                        .padding(.horizontal, 24)

                    // The English is held back until it is spoken: seeing it
                    // during the pause removes the only thing the pause is for.
                    Group {
                        if phase == .english {
                            Text(c.english)
                                .font(.system(size: 17))
                                .foregroundColor(.appText)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        } else if phase == .thinking, settings.letMeThink {
                            // With the pause turned off there is nothing to time:
                            // a ring that appears and vanishes inside a second is
                            // just a flicker between the two languages.
                            ThinkingCountdown(until: gapEnds, total: currentGap)
                        } else {
                            Text(" ").font(.system(size: 17))
                        }
                    }
                    .frame(minHeight: 74)
                    .padding(.horizontal, 24)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button { endSession() } label: {
                    Text("Stop")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.appSurfaceHigh))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.appHairline, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button { skip() } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                        Image(systemName: "forward.fill")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appAccent.badgeGradient))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Flow

    private func startSession() {
        guard !pool.isEmpty else { return }
        played = 0
        queue = pool.shuffled()
        playNext()
    }

    private func playNext() {
        guard !pool.isEmpty else { endSession(); return }
        // A finished queue reshuffles rather than stopping: this is a loop you
        // leave when you're done, not a deck you get to the end of.
        if queue.isEmpty { queue = pool.shuffled() }
        let item = queue.removeFirst()
        current = item
        speak(item)
    }

    private func speak(_ item: SentenceItem) {
        vocalSettings.handsFreeRunning = true
        phase = .japanese
        gapEnds = nil

        // Read once here: the whole sentence is queued in one call, so this is
        // the gap it will actually run with even if the toggle moves meanwhile.
        let gap = settings.gap
        currentGap = gap

        speech.speakCard(
            prompt: item.japanese,
            promptIsJapanese: true,
            gap: gap,
            answer: item.english,
            answerIsJapanese: false,
            trailing: SentenceAudioSettings.trailing,
            onGapStart: {
                withAnimation(.easeOut(duration: 0.2)) { phase = .thinking }
                gapEnds = Date().addingTimeInterval(gap)
            },
            onAnswerStart: {
                withAnimation(.easeOut(duration: 0.2)) { phase = .english }
                gapEnds = nil
            },
            completion: {
                cancelWatchdog()
                played += 1
                playNext()
            })

        // Japanese + gap + English + tail, plus slack for a slow voice and a long
        // sentence. Same reasoning as the audio flash cards' watchdog: if the
        // synthesiser never reports back, nothing else would ever move.
        armWatchdog(gap + SentenceAudioSettings.trailing + 30, item: item)
    }

    /// Skips to the next sentence without waiting for the English.
    private func skip() {
        cancelWatchdog()
        speech.stop()
        played += 1
        playNext()
    }

    private func endSession() {
        stopAudio()
        phase = .ready
        current = nil
        gapEnds = nil
    }

    private func stopAudio() {
        cancelWatchdog()
        speech.stop()
        vocalSettings.handsFreeRunning = false
    }

    private func armWatchdog(_ seconds: TimeInterval, item: SentenceItem) {
        watchdog?.cancel()
        let work = DispatchWorkItem {
            guard phase != .ready else { return }
            if rescued == item.id {
                // Twice on the same sentence means the audio isn't coming back.
                rescued = nil
                endSession()
                return
            }
            rescued = item.id
            speech.yieldSession()
            speak(item)
        }
        watchdog = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func cancelWatchdog() {
        watchdog?.cancel()
        watchdog = nil
        rescued = nil
    }

    // MARK: - Content

    /// Every example sentence the grammar chapters teach, in chapter order.
    ///
    /// Kana chapters are skipped: their "examples" are single words drilled for
    /// their sound, and a loop that reads あお and waits ten seconds for you to
    /// translate it is not what this mode is for.
    static func loadSentences() -> [SentenceItem] {
        LessonsService.shared.loadIfNeeded()
        var out: [SentenceItem] = []
        for level in LessonsService.shared.manifest?.levels ?? [] {
            for summary in level.chapters where !summary.isKanaChapter {
                guard let chapter = LessonsService.shared.loadChapter(summary.id) else { continue }
                for point in chapter.points where !point.isKanaCharacter {
                    for (i, ex) in point.examples.enumerated() {
                        let jp = ex.japanese.trimmingCharacters(in: .whitespacesAndNewlines)
                        let en = ex.english.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !jp.isEmpty, !en.isEmpty else { continue }
                        out.append(SentenceItem(id: "\(summary.id):\(point.id):\(i)",
                                                chapterId: summary.id,
                                                chapterNumber: summary.chapterNumber,
                                                levelId: level.levelId,
                                                pointName: point.name,
                                                japanese: jp,
                                                english: en))
                    }
                }
            }
        }
        return out
    }
}

// MARK: - Countdown

/// The pause, drawn as a shrinking ring so the wait reads as deliberate rather
/// than as the app having stopped.
private struct ThinkingCountdown: View {
    let until: Date?
    /// The gap this ring is counting down, so a run started under one setting
    /// isn't drawn against the other one's length.
    let total: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let remaining = max(0, until?.timeIntervalSince(context.date) ?? 0)
            let fraction = total > 0 ? remaining / total : 0
            ZStack {
                Circle()
                    .stroke(Color.appHairline, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(fraction))
                    .stroke(Color.readableOnPage(.appAccent),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(ceil(remaining)))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .monospacedDigit()
            }
            .frame(width: 64, height: 64)
        }
    }
}

// MARK: - Chapter picker

private struct SentenceChapterSheet: View {
    @ObservedObject var settings: SentenceAudioSettings
    let sentences: [SentenceItem]
    @Environment(\.dismiss) private var dismiss

    /// Only chapters that actually have sentences, so the grid can't offer an
    /// empty selection.
    private var chapterIdsWithSentences: Set<String> {
        Set(sentences.map(\.chapterId))
    }

    private var levels: [LessonLevel] {
        (LessonsService.shared.manifest?.levels ?? []).filter { level in
            level.chapters.contains { chapterIdsWithSentences.contains($0.id) }
        }
    }

    private var selectedCount: Int {
        settings.selectedChapterIds.isEmpty
            ? sentences.count
            : sentences.filter { settings.selectedChapterIds.contains($0.chapterId) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VoiceSpeedSlider(showsHeading: true)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $settings.letMeThink) {
                                Text("Let me think…")
                                    .font(.headline)
                                    .foregroundColor(.appText)
                            }
                            .tint(.appAccent)
                            Text(settings.letMeThink
                                 ? "\(Int(SentenceAudioSettings.thinkingGap)) seconds between the Japanese and the English, to work the sentence out for yourself."
                                 : "The English follows about a second after the Japanese, with no pause to translate in.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider()

                        Text("Sentences are drawn from every grammar point in the chapters you pick. With nothing picked, the loop uses them all.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        ForEach(levels, id: \.levelId) { level in
                            levelBlock(level)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("All") { settings.selectedChapterIds = [] }
                        .disabled(settings.selectedChapterIds.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { FeedbackSounds.shared.playNavigate(); dismiss() }
                }
                ToolbarItem(placement: .status) {
                    Text("\(selectedCount) sentences")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func levelBlock(_ level: LessonLevel) -> some View {
        let color = levelAccentColor(level.levelId)
        let chapters = level.chapters.filter { chapterIdsWithSentences.contains($0.id) }
        let allSelected = chapters.allSatisfy { settings.selectedChapterIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(levelName(jlpt: level.levelId))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Button(allSelected ? "Deselect All" : "Select All") {
                    for c in chapters {
                        if allSelected { settings.selectedChapterIds.remove(c.id) }
                        else { settings.selectedChapterIds.insert(c.id) }
                    }
                }
                .font(.caption)
                .foregroundColor(color)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                ForEach(chapters) { summary in
                    ChapterSquare(number: summary.chapterNumber,
                                  color: color,
                                  selected: settings.selectedChapterIds.contains(summary.id)) {
                        if settings.selectedChapterIds.contains(summary.id) {
                            settings.selectedChapterIds.remove(summary.id)
                        } else {
                            settings.selectedChapterIds.insert(summary.id)
                        }
                    }
                }
            }
        }
    }
}
