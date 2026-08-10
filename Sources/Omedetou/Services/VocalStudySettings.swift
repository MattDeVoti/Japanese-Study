import Foundation

/// Settings for the vocal flashcards, kept out of the view so the options screen
/// and the session read the same values.
final class VocalStudySettings: ObservableObject {
    static let shared = VocalStudySettings()

    /// How long the microphone stays open for an answer.
    ///
    /// The range is deliberately generous at the top: recalling a word you
    /// half-know is slower than recalling one you know, and a clock that runs out
    /// mid-answer teaches hesitation rather than vocabulary. Answering early ends
    /// the window anyway, so a longer setting only costs you when you're stuck.
    @Published var answerSeconds: Double {
        didSet { UserDefaults.standard.set(answerSeconds, forKey: Keys.seconds) }
    }

    /// Audio Only: no microphone — the word is read, a pause leaves room to
    /// answer in your head, then the meaning is read. For studying where a mic
    /// can't be used (or heard).
    @Published var audioOnly: Bool {
        didSet { UserDefaults.standard.set(audioOnly, forKey: Keys.audioOnly) }
    }

    /// True while a hands-free run is playing.
    ///
    /// Read by the app's scene-phase handler, which silences speech the instant
    /// the screen locks — and not silencing it is the entire point of this mode.
    /// Deliberately not `@Published`: nothing renders from it, and publishing
    /// would redraw the session on every word.
    var handsFreeRunning = false

    static let secondsRange: ClosedRange<Double> = 3...20
    /// The in-your-head pause and the beat after the answer, per the spec.
    static let audioOnlyThink: TimeInterval = 5
    static let audioOnlyGap: TimeInterval = 1

    private enum Keys {
        static let seconds = "VocalAnswerSeconds"
        static let audioOnly = "VocalAudioOnly"
    }

    private init() {
        answerSeconds = UserDefaults.standard.object(forKey: Keys.seconds) as? Double ?? 7
        audioOnly = UserDefaults.standard.bool(forKey: Keys.audioOnly)
    }
}
