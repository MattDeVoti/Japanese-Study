import AVFoundation
import Speech
import SwiftUI

// Speaking instead of typing.
//
// Two places earn this: looking a word up in the dictionary, where typing
// Japanese means switching keyboards first, and しりとり, where you're typing
// kana against a fifteen-second clock.
//
// It only ever *fills a field*. Nothing here judges what was said, and it must
// stay that way: recognition is trained on native speakers, so a learner's
// pronunciation will sometimes miss, and a miss that costs you a game or a mark
// would be teaching the wrong lesson. A wrong transcription should cost one tap
// to correct, never more.

final class DictationService: NSObject, ObservableObject {
    static let shared = DictationService()

    enum Problem: Identifiable {
        case denied
        case noRecogniser
        case offline
        case failed(String)

        var id: String { message }

        var message: String {
            switch self {
            case .denied:
                return "Omedetou doesn't have permission to listen. Turn on Microphone and Speech Recognition for Omedetou in Settings ▸ Privacy."
            case .noRecogniser:
                return "This device doesn't have Japanese speech recognition available."
            case .offline:
                return "Speech recognition isn't available right now. It needs either the Japanese dictation language downloaded on this device, or a connection."
            case .failed(let why):
                return "Couldn't start listening — \(why)"
            }
        }
    }

    @Published private(set) var isListening = false
    @Published var problem: Problem?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var deliver: ((String) -> Void)?
    private var heard = ""
    /// True between the tap and the mic actually opening.
    ///
    /// Authorisation always answers asynchronously, even when permission was
    /// granted long ago, so `isListening` stays false across that gap. Without
    /// this, a second tap inside it starts a second `begin`, and installing a
    /// tap on a bus that already has one raises an Objective-C exception no
    /// Swift `catch` can reach — an outright crash.
    private var starting = false

    /// A pause this long ends the phrase, and nothing runs longer than the cap —
    /// a mic left open because recognition never finalised is both a battery
    /// drain and, with a live indicator, alarming.
    private static let endsOnSilence: TimeInterval = 1.4
    private static let cap: TimeInterval = 12
    private var silenceTimer: Timer?
    private var capTimer: Timer?

    // MARK: - Control

    /// Tapping the mic a second time stops it, which is what a mic button should
    /// do. `onText` runs for every partial too, so the field fills as you speak.
    func toggle(locale: String, onText: @escaping (String) -> Void) {
        if isListening { stop(); return }
        guard !starting else { return }
        starting = true
        authorize { [weak self] ok in
            guard let self else { return }
            defer { self.starting = false }
            guard ok else { self.problem = .denied; return }
            self.begin(locale: locale, onText: onText)
        }
    }

    func stop() {
        guard isListening else { return }
        isListening = false
        silenceTimer?.invalidate(); silenceTimer = nil
        capTimer?.invalidate(); capTimer = nil

        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        deliver = nil
        // Handing the session back lets whatever was ducked come up again, and
        // lets SpeechService reclaim it for playback on its next utterance.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Permission

    private func authorize(_ done: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { done(false) }
                return
            }
            let granted: (Bool) -> Void = { ok in DispatchQueue.main.async { done(ok) } }
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission(completionHandler: granted)
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission(granted)
            }
        }
    }

    // MARK: - Listening

    private func begin(locale: String, onText: @escaping (String) -> Void) {
        guard let recogniser = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            problem = .noRecogniser
            return
        }
        guard recogniser.isAvailable else {
            problem = .offline
            return
        }

        // Text-to-speech configures the audio session once and then assumes it
        // still owns it, so it has to be told to let go before the category
        // changes under it.
        SpeechService.shared.yieldSession()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            problem = .failed(error.localizedDescription)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device whenever the language pack is installed: faster, works with
        // no signal, and nothing leaves the phone.
        request.requiresOnDeviceRecognition = recogniser.supportsOnDeviceRecognition
        self.request = request

        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024,
                         format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            problem = .failed(error.localizedDescription)
            input.removeTap(onBus: 0)
            self.request = nil
            // The session is already active and set to .record at this point;
            // `stop()` won't undo it because we never started listening, so it
            // has to be handed back here or the mic category outlives the
            // failure.
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            return
        }

        heard = ""
        deliver = onText
        isListening = true

        task = recogniser.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.isListening else { return }
                if let result {
                    self.heard = result.bestTranscription.formattedString
                    self.deliver?(self.heard)
                    self.armSilence()
                    if result.isFinal { self.stop() }
                }
                // A cancel on the way out surfaces here as an error too; there's
                // nothing to report once we've already stopped listening.
                if error != nil { self.stop() }
            }
        }

        armSilence()
        capTimer = after(Self.cap) { [weak self] in self?.stop() }
    }

    private func armSilence() {
        silenceTimer?.invalidate()
        silenceTimer = after(Self.endsOnSilence) { [weak self] in self?.stop() }
    }

    /// Scheduled in `.common`, not the default mode.
    ///
    /// `Timer.scheduledTimer` lands in `.default`, which the run loop leaves the
    /// moment a scroll starts — so scrolling the search results or the しりとり
    /// chain would park both the silence timeout and the hard cap, and the mic
    /// would stay open until the user thought to close it.
    private func after(_ seconds: TimeInterval, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: seconds, repeats: false) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
