import AVFoundation
import SwiftUI

// Japanese text-to-speech. Uses the system ja-JP voices, so there are no audio
// assets to ship and it works offline.
//
// The important detail: anything the app can annotate, it can pronounce
// correctly. Sentences are converted to their kana reading from the furigana
// markup before being spoken, so the synthesiser is told 二時 is にじ rather than
// left to guess (and guess にとき).

final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    /// Identifier of the utterance currently being spoken, for per-button state.
    @Published private(set) var speakingID: String?

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled) }
    }
    /// 0…1 slider position, mapped onto a usable slice of the platform range.
    @Published var rate: Double {
        didSet { UserDefaults.standard.set(rate, forKey: Keys.rate) }
    }

    private enum Keys {
        static let enabled = "SpeechEnabled"
        static let rate = "SpeechRate"
        static let voice = "SpeechVoiceIdentifier"
    }

    private let synth = AVSpeechSynthesizer()
    private var sessionReady = false
    /// Utterances still queued for the current request; the button stays lit until
    /// the last one finishes rather than the first.
    private var pending = 0
    /// Runs when the last utterance of the current request finishes. Cleared by
    /// `stop()` *without* being called — a cancelled utterance didn't finish.
    private var onFinish: (() -> Void)?
    /// The two halves of a `speakCard` pair, and the cues that go with them:
    /// the Japanese finishing means the silent gap has begun, and the English
    /// starting means the answer is being given.
    private var japaneseUtterance: AVSpeechUtterance?
    private var englishUtterance: AVSpeechUtterance?
    private var onGapStart: (() -> Void)?
    private var onEnglishStart: (() -> Void)?

    /// The utterances belonging to the request currently in flight.
    ///
    /// Cancelling an utterance delivers its delegate callback *later*, by which
    /// time a new request may already have started — and that late callback was
    /// decrementing the new request's counter, firing its completion one
    /// utterance early. Switching modes mid-card did exactly that. Anything not
    /// in this set is a ghost from a cancelled request and is ignored.
    private var live: Set<ObjectIdentifier> = []
    /// Fires when a request makes no sound at all. See `armStartGuard`.
    private var startGuard: DispatchWorkItem?
    /// Speech should begin well inside this; anything longer means it never will.
    private static let mustStartWithin: TimeInterval = 3.5

    /// Every Japanese voice installed on this device, best quality first.
    ///
    /// Enumerated once: `speechVoices()` walks the installed set, and `voice` is
    /// read for every utterance.
    private(set) lazy var japaneseVoices: [AVSpeechSynthesisVoice] = {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") }
            .sorted { a, b in
                a.quality.rawValue != b.quality.rawValue
                    ? a.quality.rawValue > b.quality.rawValue
                    : a.name < b.name
            }
    }()

    /// The chosen voice, or nil to follow whatever the best installed one is.
    ///
    /// Stored as an identifier rather than an object so the choice survives a
    /// relaunch — and so a voice the user later deletes simply falls back to the
    /// best remaining one instead of leaving the app mute.
    @Published var voiceIdentifier: String? {
        didSet {
            stop()
            UserDefaults.standard.set(voiceIdentifier, forKey: Keys.voice)
        }
    }

    /// The voice actually used. Computed, so picking a new one in Options takes
    /// effect on the very next utterance with nothing to invalidate.
    var voice: AVSpeechSynthesisVoice? {
        if let id = voiceIdentifier,
           let chosen = japaneseVoices.first(where: { $0.identifier == id }) { return chosen }
        return japaneseVoices.first
    }

    /// A voice's name with its quality, where the system offers more than the
    /// compact default — that difference is the whole reason to choose.
    func label(for v: AVSpeechSynthesisVoice) -> String {
        switch v.quality {
        case .premium:  return "\(v.name) · Premium"
        case .enhanced: return "\(v.name) · Enhanced"
        default:        return v.name
        }
    }

    /// An English voice, for reading a definition back. Separate from `voice`
    /// because the Japanese synthesiser reads English as if it were romaji.
    private lazy var englishVoice: AVSpeechSynthesisVoice? =
        AVSpeechSynthesisVoice(language: "en-US")

    var isAvailable: Bool { voice != nil }

    /// Human-readable voice name for the options screen.
    var voiceName: String { voice?.name ?? "None installed" }

    private override init() {
        let d = UserDefaults.standard
        isEnabled = d.object(forKey: Keys.enabled) as? Bool ?? true
        rate = d.object(forKey: Keys.rate) as? Double ?? 0.42
        voiceIdentifier = d.string(forKey: Keys.voice)
        super.init()
        synth.delegate = self

        // Route changes and interruptions both leave the session configured for a
        // world that no longer exists — a car stereo that just connected, a call
        // that just ended. `prepareSession` runs once and then assumes it still
        // owns the session, so without these the app simply goes quiet for the
        // rest of the launch after you switch speakers.
        let centre = NotificationCenter.default
        centre.addObserver(self, selector: #selector(audioRouteChanged),
                           name: AVAudioSession.routeChangeNotification, object: nil)
        centre.addObserver(self, selector: #selector(audioInterrupted),
                           name: AVAudioSession.interruptionNotification, object: nil)
    }

    @objc private func audioRouteChanged(_ note: Notification) {
        sessionReady = false
    }


    /// Either edge of an interruption invalidates the session.
    ///
    /// Both, deliberately: `.began` means the synthesiser has been silenced
    /// without telling its delegate, and `.ended` means the session we had is no
    /// longer the one the system is offering. Marking it unready on either edge
    /// costs one reconfiguration and removes a whole class of silent failure.
    @objc private func audioInterrupted(_ note: Notification) {
        sessionReady = false
    }

    // MARK: - Speaking

    /// Speaks `text`. Markup is converted to its kana reading first. Tapping the
    /// same item again stops it, which is what a speaker button should do.
    /// `completion` runs when the last utterance finishes, and also on every path
    /// that declines to speak — a caller waiting on audio to advance must never
    /// be stranded by a muted device or an empty string.
    func speak(_ text: String, id: String? = nil, attempt: Int = 1,
               completion: (() -> Void)? = nil) {
        guard isEnabled, voice != nil else { completion?(); return }
        let key = id ?? text
        if speakingID == key {
            stop()
            completion?()
            return
        }
        stop()
        let spoken = FuriganaAnnotator.spokenText(text)
        guard !spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?()
            return
        }

        prepareSession()
        onFinish = completion

        // One utterance per sentence rather than one for the whole passage. The
        // synthesiser flattens intonation across a long string and runs sentences
        // together; feeding it a sentence at a time restores the fall at 。 and
        // lets a real pause sit between them.
        let sentences = Self.sentences(in: spoken)
        pending = sentences.count
        speakingID = key
        live = []
        for (i, sentence) in sentences.enumerated() {
            let u = utterance(for: sentence, isLast: i == sentences.count - 1)
            live.insert(ObjectIdentifier(u))
            synth.speak(u)
        }
        armStartGuard(attempt: attempt) { [weak self] in
            // Clear the id first: `speak` reads a repeat of the same id as a
            // request to stop, which would turn the retry into a cancel.
            self?.speakingID = nil
            self?.speak(text, id: id, attempt: attempt + 1, completion: completion)
        }
    }

    private func utterance(for sentence: String, isLast: Bool) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: sentence)
        u.voice = voice
        // AVSpeechUtteranceMinimumSpeechRate…Default is a narrow, non-linear band;
        // learners want slower than conversational, so bias toward the low end.
        let lo = AVSpeechUtteranceMinimumSpeechRate
        let hi = AVSpeechUtteranceDefaultSpeechRate
        u.rate = lo + Float(rate) * (hi - lo)
        u.pitchMultiplier = 1.0
        // A breath between sentences. Without it the next one starts on top of the
        // last syllable of the previous, which is most of what makes it sound
        // mechanical over a whole paragraph.
        u.postUtteranceDelay = isLast ? 0 : 0.28
        // VoiceOver users' global rate/voice settings otherwise override the ones
        // chosen here, which makes the audio unusable as a learning aid.
        u.prefersAssistiveTechnologySettings = false
        return u
    }

    /// Splits on Japanese sentence enders, keeping the punctuation so the voice
    /// still hears the question mark and rises at 〜か？.
    static func sentences(in text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if "。！？!?\n".contains(ch) {
                let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { out.append(t) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { out.append(tail) }
        return out.isEmpty ? [text] : out
    }

    /// One hands-free card: the Japanese, a silent gap to answer in, then the
    /// English — queued as a single unit rather than run as three timed steps.
    ///
    /// The gap is the synthesiser's own `postUtteranceDelay`, and that detail is
    /// the whole reason this method exists. A pause built from `asyncAfter` is
    /// dead air, and iOS suspends a backgrounded app that stops producing audio —
    /// so a timed gap would end the session the moment the screen locked, five
    /// seconds into the first word. Holding the pause inside the synthesiser
    /// keeps audio "playing" throughout, which is what lets the session run on
    /// with the phone in a pocket.
    func speakCard(prompt: String, promptIsJapanese: Bool, gap: TimeInterval,
                   answer: String, answerIsJapanese: Bool, trailing: TimeInterval,
                   attempt: Int = 1,
                   onGapStart: (() -> Void)? = nil,
                   onAnswerStart: (() -> Void)? = nil,
                   completion: (() -> Void)? = nil) {
        guard isEnabled, voice != nil else { completion?(); return }
        let answerText = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        prepareSession()
        onFinish = completion
        self.onGapStart = onGapStart
        self.onEnglishStart = onAnswerStart

        let first = cardUtterance(prompt, japanese: promptIsJapanese, delay: gap)
        speakingID = "card"
        pending = answerText.isEmpty ? 1 : 2
        japaneseUtterance = first          // "the prompt half", whichever language
        live = [ObjectIdentifier(first)]
        synth.speak(first)

        let guardReplay: () -> Void = { [weak self] in
            self?.speakCard(prompt: prompt, promptIsJapanese: promptIsJapanese, gap: gap,
                            answer: answer, answerIsJapanese: answerIsJapanese,
                            trailing: trailing, attempt: attempt + 1,
                            onGapStart: onGapStart, onAnswerStart: onAnswerStart,
                            completion: completion)
        }

        guard !answerText.isEmpty else {
            armStartGuard(attempt: attempt, replay: guardReplay)
            return
        }
        let second = cardUtterance(answerText, japanese: answerIsJapanese, delay: trailing)
        englishUtterance = second          // "the answer half"
        live.insert(ObjectIdentifier(second))
        synth.speak(second)
        armStartGuard(attempt: attempt, replay: guardReplay)
    }

    /// One half of a card, in whichever language it belongs to.
    private func cardUtterance(_ text: String, japanese: Bool,
                               delay: TimeInterval) -> AVSpeechUtterance {
        let body = japanese ? FuriganaAnnotator.spokenText(text) : text
        let u = AVSpeechUtterance(string: body)
        if japanese {
            u.voice = voice
            let lo = AVSpeechUtteranceMinimumSpeechRate
            let hi = AVSpeechUtteranceDefaultSpeechRate
            u.rate = lo + Float(rate) * (hi - lo)
        } else {
            u.voice = englishVoice
            u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
        }
        u.postUtteranceDelay = delay
        u.prefersAssistiveTechnologySettings = false
        return u
    }

    /// Reads English aloud, for saying a definition back after a missed answer.
    func speakEnglish(_ text: String, id: String? = nil, attempt: Int = 1,
                      completion: (() -> Void)? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, let englishVoice, !trimmed.isEmpty else { completion?(); return }
        stop()
        prepareSession()
        onFinish = completion
        pending = 1
        speakingID = id ?? trimmed

        let u = AVSpeechUtterance(string: trimmed)
        live = [ObjectIdentifier(u)]
        u.voice = englishVoice
        // A shade under conversational: this is the answer, and it is heard once.
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
        u.prefersAssistiveTechnologySettings = false
        synth.speak(u)
        armStartGuard(attempt: attempt) { [weak self] in
            self?.speakingID = nil
            self?.speakEnglish(text, id: id, attempt: attempt + 1, completion: completion)
        }
    }

    func stop() {
        cancelStartGuard()
        pending = 0
        onFinish = nil
        japaneseUtterance = nil
        englishUtterance = nil
        onGapStart = nil
        onEnglishStart = nil
        live = []
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speakingID = nil
    }

    /// How long to wait after speech before handing the session to the mic.
    ///
    /// Two things overlap here, and both bite hardest in a car. The synthesiser
    /// reports finished when it has finished *generating*, not when the sound
    /// has reached the speaker — over Bluetooth the tail of the word is still in
    /// flight. And opening the microphone forces the route off A2DP onto the
    /// hands-free channel, which tears the existing stream down to renegotiate.
    /// Do that immediately and the last syllable is simply cut.
    ///
    /// Wired and built-in outputs have almost no latency and no renegotiation,
    /// so they get a token pause; Bluetooth gets a real one.
    var tailBeforeRecording: TimeInterval {
        let bluetooth: Set<AVAudioSession.Port> = [
            .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio,
        ]
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains { bluetooth.contains($0.portType) } ? 0.9 : 0.25
    }

    /// Hands the audio session to something that needs the microphone.
    ///
    /// `prepareSession` deliberately runs once and then assumes the session is
    /// still configured the way it left it. That assumption breaks the moment
    /// dictation switches the category to `.record`: without this, speech would
    /// go quiet for the rest of the launch, because it would never reconfigure.
    /// Clearing the flag makes the next `speak` set the session up again.
    func yieldSession() {
        stop()
        sessionReady = false
    }

    /// A language app is expected to make sound even with the ringer switched
    /// off, so this uses .playback rather than .ambient — but ducks rather than
    /// interrupting whatever else is playing.
    @discardableResult
    private func prepareSession() -> Bool {
        if sessionReady { return true }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
            sessionReady = true
            return true
        } catch {
            // Deliberately left un-latched. Activation fails routinely while a
            // car's Bluetooth link is still negotiating, and the old code marked
            // the session ready *before* trying — so one failed activation while
            // pulling out of a driveway left every later utterance speaking into
            // a dead session, silently, for the rest of the launch.
            sessionReady = false
            return false
        }
    }

    /// Tear the session down and build it again from nothing.
    /// Forces the next utterance to reconfigure the audio session.
    ///
    /// The session is shared with the rest of the app. Anything that changes its
    /// category — Kanji Invaders switches to `.ambient` so the bell switch mutes
    /// it — leaves `sessionReady` claiming a `.playback` setup that is no longer
    /// in place, and speech would then be silenced along with the game. Callers
    /// that borrow the session call this when they hand it back.
    func invalidateSession() {
        sessionReady = false
    }

    private func rebuildSession() {
        sessionReady = false
        synth.stopSpeaking(at: .immediate)
        live = []
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
        prepareSession()
    }

    // MARK: - Never-started guard

    /// Watches for the case where a request produces no sound at all.
    ///
    /// `didStart` is the only proof that audio is really coming out. When it
    /// doesn't arrive, nothing else ever will either — no `didFinish`, no
    /// completion — and a session driven by those callbacks simply stops. So
    /// each request is guarded: rebuild the session and try once more, and if
    /// that is also silent, release the caller rather than leave it waiting.
    private func armStartGuard(attempt: Int, replay: @escaping () -> Void) {
        startGuard?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard attempt < 2 else { self.finishStranded(); return }
            self.rebuildSession()
            replay()
        }
        startGuard = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.mustStartWithin, execute: work)
    }

    private func cancelStartGuard() {
        startGuard?.cancel()
        startGuard = nil
    }

    /// No audio is coming. Release whoever is waiting so their session can move
    /// on instead of sitting on a silent card.
    private func finishStranded() {
        cancelStartGuard()
        let block = onFinish
        onFinish = nil
        onGapStart = nil
        onEnglishStart = nil
        pending = 0
        speakingID = nil
        live = []
        block?()
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        guard live.contains(ObjectIdentifier(u)) else { return }
        // Sound is actually coming out, so the session is healthy.
        cancelStartGuard()
        guard u === englishUtterance else { return }
        let block = onEnglishStart
        onEnglishStart = nil
        block?()
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        guard live.remove(ObjectIdentifier(u)) != nil else { return }
        if u === japaneseUtterance {
            japaneseUtterance = nil
            let block = onGapStart
            onGapStart = nil
            block?()
        }
        finishOne()
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        guard live.remove(ObjectIdentifier(u)) != nil else { return }
        finishOne()
    }
}

private extension SpeechService {
    /// A passage is several utterances; only the last one ends the session.
    func finishOne() {
        pending = max(0, pending - 1)
        guard pending == 0 else { return }
        speakingID = nil
        let block = onFinish
        onFinish = nil
        block?()
    }
}

// MARK: - Speaker button

/// Tap to hear the Japanese. Hides itself entirely when the device has no
/// Japanese voice or the user has turned speech off, so it never sits there dead.
struct SpeakButton: View {
    let text: String
    var size: CGFloat = 22
    var tint: Color? = nil
    /// Which voice reads it. Japanese unless told otherwise — the one caller
    /// that passes false is the audio deck replaying an English prompt.
    var isJapanese: Bool = true

    @ObservedObject private var speech = SpeechService.shared

    private var key: String { text }
    private var isSpeaking: Bool { speech.speakingID == key }

    var body: some View {
        if speech.isAvailable && speech.isEnabled {
            Button {
                if isJapanese { speech.speak(text, id: key) }
                else { speech.speakEnglish(text, id: key) }
            } label: {
                Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .font(.system(size: size, weight: .medium))
                    .foregroundColor(tint ?? .appAccent)
                    .symbolEffectPulse(isSpeaking)
                    .contentShape(Rectangle())
                    .frame(minWidth: size + 16, minHeight: size + 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSpeaking ? "Stop audio" : "Play Japanese audio")
        }
    }
}

extension View {
    /// `.symbolEffect(.pulse)` is iOS 17+; fall back to a plain opacity pulse so
    /// the button still reads as active on iOS 16.
    ///
    /// Shared with the dictation mic buttons — a live mic and a speaking
    /// speaker want the same "this is running" pulse.
    @ViewBuilder func symbolEffectPulse(_ active: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.pulse, isActive: active)
        } else {
            self.opacity(active ? 0.55 : 1)
                .animation(active ? .easeInOut(duration: 0.6).repeatForever()
                                  : .default, value: active)
        }
    }
}
