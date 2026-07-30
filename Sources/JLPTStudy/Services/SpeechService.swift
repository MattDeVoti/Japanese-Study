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
        guard isEnabled, let voice else { return }
        let key = id ?? text
        if speakingID == key {
            stop()
            return
        }
        stop()
        let spoken = FuriganaAnnotator.spokenText(text)
        guard !spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        prepareSession()
        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = voice
        // AVSpeechUtteranceMinimumSpeechRate…Default is a narrow, non-linear band;
        // learners want slower than conversational, so bias toward the low end.
        let lo = AVSpeechUtteranceMinimumSpeechRate
        let hi = AVSpeechUtteranceDefaultSpeechRate
        utterance.rate = lo + Float(rate) * (hi - lo)
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0

        speakingID = key
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speakingID = nil
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
        speakingID = nil
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        speakingID = nil
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

private extension View {
    /// `.symbolEffect(.pulse)` is iOS 17+; fall back to a plain opacity pulse so
    /// the button still reads as active on iOS 16.
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
