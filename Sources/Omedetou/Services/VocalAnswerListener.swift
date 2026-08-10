import AVFoundation
import Speech
import SwiftUI

// Listening to an answer, for a fixed window, and handing back what was said.
//
// Why this is not part of DictationService: that one exists to *fill a field*
// and its header is explicit that it must never judge, because it listens in
// Japanese and a learner's pronunciation being marked wrong by a recogniser
// trained on natives teaches the wrong lesson. That reasoning is sound and it
// still holds.
//
// This listener is a different situation and keeps to the same spirit:
//
//   • It listens in English. What is being recognised is the learner's own
//     language, which is the case recognition is most reliable at.
//   • It scores *meaning*, never pronunciation — the matcher only asks which
//     English words were said, and 聞く is right whether you say "hear" crisply
//     or mumble it.
//   • A miss still costs one tap: the session always shows the transcript it
//     judged, with a button to overrule it.
//
// It also differs mechanically: a fixed answer window rather than open-ended
// dictation, so the session can keep time.

final class VocalAnswerListener: NSObject, ObservableObject {
    static let shared = VocalAnswerListener()

    enum Problem: Identifiable {
        case denied
        case noRecogniser
        case unavailable
        case failed(String)

        var id: String { message }

        var message: String {
            switch self {
            case .denied:
                return "Omedetou needs the microphone and speech recognition to hear your answers. Turn both on for Omedetou in Settings ▸ Privacy & Security."
            case .noRecogniser:
                return "This device doesn't have English speech recognition available."
            case .unavailable:
                return "Speech recognition isn't available right now. It needs either the English dictation language downloaded on this device, or a connection."
            case .failed(let why):
                return "Couldn't start listening — \(why)"
            }
        }
    }

    /// What has been heard so far, so the session can show it as it arrives.
    @Published private(set) var partial = ""
    @Published private(set) var isListening = false
    @Published var problem: Problem?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var finish: ((String) -> Void)?
    private var windowTimer: Timer?
    private var silenceTimer: Timer?
    /// Guards the gap between the call and the mic actually opening. Installing a
    /// tap on a bus that already has one raises an Objective-C exception no Swift
    /// `catch` can reach, so a second start inside that gap is a hard crash.
    private var starting = false

    /// Once something has been said, this much quiet ends the answer early rather
    /// than making the learner wait out the rest of the window.
    private static let endsOnSilence: TimeInterval = 0.9

    // MARK: - Control

    /// Opens the mic for `seconds`, then calls `onFinish` exactly once with the
    /// transcript — empty if nothing was said.
    func listen(seconds: TimeInterval, onFinish: @escaping (String) -> Void) {
        guard !isListening, !starting else { return }
        starting = true
        authorize { [weak self] ok in
            guard let self else { return }
            self.starting = false
            guard ok else {
                self.problem = .denied
                onFinish("")
                return
            }
            self.begin(seconds: seconds, onFinish: onFinish)
        }
    }

    /// Asks for microphone and speech access up front.
    ///
    /// Worth doing before a session rather than at the first `listen`: the system
    /// prompts are modal, and on a first run they would otherwise appear on top of
    /// an answer window that is already counting down.
    func requestAccess(_ done: @escaping (Bool) -> Void) {
        authorize { [weak self] ok in
            if !ok { self?.problem = .denied }
            done(ok)
        }
    }

    /// Ends the window early and delivers whatever was heard.
    func finishNow() {
        guard isListening else { return }
        let heard = partial
        teardown()
        deliver(heard)
    }

    /// Abandons the window without delivering — for leaving the screen.
    func cancel() {
        guard isListening || starting else { return }
        finish = nil
        teardown()
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

    private func begin(seconds: TimeInterval, onFinish: @escaping (String) -> Void) {
        guard let recogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            problem = .noRecogniser
            onFinish("")
            return
        }
        guard recogniser.isAvailable else {
            problem = .unavailable
            onFinish("")
            return
        }

        // Text-to-speech configures the session once and then assumes it still
        // owns it, so it has to be told to let go before the category changes.
        SpeechService.shared.yieldSession()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            problem = .failed(error.localizedDescription)
            onFinish("")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device wherever the language pack allows: nothing said during a
        // study session needs to leave the phone.
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
            // The category is already `.record` here; `teardown` won't run
            // because we never started listening, so hand it back by hand.
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            onFinish("")
            return
        }

        partial = ""
        finish = onFinish
        isListening = true

        task = recogniser.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.isListening else { return }
                if let result {
                    self.partial = result.bestTranscription.formattedString
                    // Answering takes a second or two; waiting out the rest of a
                    // window you've already answered feels broken, so a pause
                    // after real speech ends it.
                    if !self.partial.isEmpty { self.armSilence() }
                    if result.isFinal { self.finishNow(); return }
                }
                if error != nil { self.finishNow() }
            }
        }

        windowTimer = after(seconds) { [weak self] in self?.finishNow() }
    }

    private func armSilence() {
        silenceTimer?.invalidate()
        silenceTimer = after(Self.endsOnSilence) { [weak self] in self?.finishNow() }
    }

    private func deliver(_ heard: String) {
        let block = finish
        finish = nil
        block?(heard)
    }

    private func teardown() {
        isListening = false
        windowTimer?.invalidate(); windowTimer = nil
        silenceTimer?.invalidate(); silenceTimer = nil

        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // Clearing the flag makes the next utterance reconfigure the session for
        // playback; without it the app goes quiet for the rest of the launch.
        SpeechService.shared.yieldSession()
    }

    /// Scheduled in `.common`: a timer left in the default mode is parked the
    /// moment a scroll begins, which would hold the mic open indefinitely.
    private func after(_ seconds: TimeInterval, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: seconds, repeats: false) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
