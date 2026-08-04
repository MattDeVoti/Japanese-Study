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
    }

    private let synth = AVSpeechSynthesizer()
    private var sessionReady = false
    /// Utterances still queued for the current request; the button stays lit until
    /// the last one finishes rather than the first.
    private var pending = 0

    /// The best available Japanese voice, or nil if the device has none.
    private(set) lazy var voice: AVSpeechSynthesisVoice? = Self.bestJapaneseVoice()

    var isAvailable: Bool { voice != nil }

    /// Human-readable voice name for the options screen.
    var voiceName: String { voice?.name ?? "None installed" }

    private override init() {
        let d = UserDefaults.standard
        isEnabled = d.object(forKey: Keys.enabled) as? Bool ?? true
        rate = d.object(forKey: Keys.rate) as? Double ?? 0.42
        super.init()
        synth.delegate = self
    }

    /// Prefers the highest-quality Japanese voice the user has installed —
    /// Siri/premium voices sound markedly better than the compact default.
    private static func bestJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let japanese = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("ja")
        }
        return japanese.max { a, b in
            a.quality.rawValue < b.quality.rawValue
        }
    }

    // MARK: - Speaking

    /// Speaks `text`. Markup is converted to its kana reading first. Tapping the
    /// same item again stops it, which is what a speaker button should do.
    func speak(_ text: String, id: String? = nil) {
        guard isEnabled, voice != nil else { return }
        let key = id ?? text
        if speakingID == key {
            stop()
            return
        }
        stop()
        let spoken = FuriganaAnnotator.spokenText(text)
        guard !spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        prepareSession()

        // One utterance per sentence rather than one for the whole passage. The
        // synthesiser flattens intonation across a long string and runs sentences
        // together; feeding it a sentence at a time restores the fall at 。 and
        // lets a real pause sit between them.
        let sentences = Self.sentences(in: spoken)
        pending = sentences.count
        speakingID = key
        for (i, sentence) in sentences.enumerated() {
            synth.speak(utterance(for: sentence, isLast: i == sentences.count - 1))
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

    func stop() {
        pending = 0
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speakingID = nil
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
    private func prepareSession() {
        guard !sessionReady else { return }
        sessionReady = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        finishOne()
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        finishOne()
    }
}

private extension SpeechService {
    /// A passage is several utterances; only the last one ends the session.
    func finishOne() {
        pending = max(0, pending - 1)
        if pending == 0 { speakingID = nil }
    }
}

// MARK: - Speaker button

/// Tap to hear the Japanese. Hides itself entirely when the device has no
/// Japanese voice or the user has turned speech off, so it never sits there dead.
struct SpeakButton: View {
    let text: String
    var size: CGFloat = 22
    var tint: Color? = nil

    @ObservedObject private var speech = SpeechService.shared

    private var key: String { text }
    private var isSpeaking: Bool { speech.speakingID == key }

    var body: some View {
        if speech.isAvailable && speech.isEnabled {
            Button {
                speech.speak(text, id: key)
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
