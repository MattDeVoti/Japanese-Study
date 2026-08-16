import AVFoundation

/// Sound effects for Kanji Invaders.
///
/// Deliberately separate from `FeedbackSounds`, and the difference is the audio
/// session category:
///
///   • Study cues use `.playback`, which plays *through* the Ring/Silent switch.
///     That's right for them — someone drilling vocab on a muted phone still
///     wants to hear whether they got it right.
///   • A game is the opposite. Silent should mean silent, so this uses
///     `.ambient`, the category iOS mutes when the bell switch is off.
///
/// That is also why nothing here reads the switch: iOS gives no API for it, and
/// none is needed — `.ambient` makes the system do the muting. It also mixes
/// rather than interrupts, so someone playing with music on keeps it.
///
///
/// ## Why `AVAudioEngine` and not `AVAudioPlayer`
///
/// This was written with `AVAudioPlayer` first, and it does not survive contact
/// with a 60fps game loop. Every `play()` on an `AVAudioPlayer` spins up an
/// `AudioQueue`, which means IPC with the audio daemon; at full 速 the ship
/// fires fifteen times a second, and a single session produced 291 audio queue
/// objects with fourteen live at once. Apple's own performance diagnostics flag
/// the session calls behind that as "XPC on main thread — hang risk", and a main
/// thread blocked waiting on the audio server parks in `mach_msg2_trap`.
///
/// `AVAudioEngine` has one output unit for the whole graph. Sounds are decoded
/// once into buffers up front, and firing one is `scheduleBuffer` — an enqueue
/// onto an already-running node, with no daemon round-trip and no queue churn.
///
///
/// ## Overlapping
///
/// Nothing here ever cuts a sound off mid-ring. Three things guarantee it:
///
///   • **Cues never share nodes.** A laser physically cannot interrupt an
///     explosion or a pickup jingle, whatever else is happening.
///   • **Each cue has a pool of nodes**, sized below for the fastest the game
///     can trigger it.
///   • **Buffers queue, they don't replace.** If a pool did wrap around onto a
///     node still ringing, the new sound starts when that one ends rather than
///     chopping it — late, not truncated.
final class GameSounds {
    static let shared = GameSounds()

    enum Cue: String, CaseIterable {
        case laser      = "Laser"
        case enemyLaser = "Enemy Laser"
        case explosion  = "Explosion"
        case powerUp    = "Power Up"
        case extraLife  = "Extra Life"
    }

    /// How many copies of a cue can ring at once.
    ///
    /// Measured, not guessed: the game ticks at 60fps, and each sound's
    /// *audible* length was read off its waveform rather than taken from the
    /// file, several of which carry a lot of trailing silence (Extra Life is a
    /// 1.5s file with 0.77s of sound in it).
    ///
    ///   • laser — 速 at full level fires every 4 frames, so 15/sec, against
    ///     0.94s of audible laser. 15 × 0.94 ≈ 14.
    ///   • enemyLaser — at the hardest escalation a foe fires every 15 frames,
    ///     4/sec, and the shot rings 0.74s. A five-shot spray is one trigger.
    ///   • explosion — no fixed rate; a pierced shot can clear several kanji in
    ///     a single frame, so this is sized for a burst rather than a rate.
    ///   • powerUp / extraLife — pickups arrive one at a time, but a second can
    ///     land while the first (1.55s) is still going.
    private static func poolSize(for cue: Cue) -> Int {
        switch cue {
        case .laser:      return 14
        case .enemyLaser: return 4
        case .explosion:  return 8
        case .powerUp:    return 3
        case .extraLife:  return 2
        }
    }

    /// Relative levels. The files are quiet to begin with — peaks run from 0.19
    /// (enemy laser) to 0.70 (power up) — so these mostly bring the softer ones
    /// up. The ship's laser is held back because it fires constantly and stacks
    /// up to fourteen deep.
    private static func volume(for cue: Cue) -> Float {
        switch cue {
        case .laser:      return 0.70
        case .enemyLaser: return 0.95
        case .explosion:  return 1.0
        case .powerUp:    return 0.85
        case .extraLife:  return 1.0
        }
    }

    private let engine = AVAudioEngine()
    /// One decoded copy of each sound, shared by every node that plays it.
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nodes: [Cue: [AVAudioPlayerNode]] = [:]
    /// Round-robin cursor per cue.
    private var next: [Cue: Int] = [:]
    private var running = false

    private init() {}

    // MARK: - Lifecycle

    /// Builds the graph and starts it. Called when the game appears, so the
    /// first shot isn't waiting on a file to decode.
    func prepare() {
        guard !running else { return }
        claimSession()

        if buffers.isEmpty { loadBuffers() }
        guard !buffers.isEmpty else { return }

        if nodes.isEmpty { buildGraph() }

        do {
            try engine.start()
        } catch {
            // Nothing to recover: the game is silent this session rather than
            // broken. Left un-`running` so a later `prepare` can retry.
            return
        }
        // Started once and left running. A player node with nothing scheduled
        // costs nothing, and starting one per sound would put back the
        // per-trigger overhead this design exists to avoid.
        for node in nodes.values.flatMap({ $0 }) { node.play() }
        running = true
    }

    /// Called when the game closes.
    ///
    /// Tears the graph down — several megabytes of decoded audio is fine to hold
    /// while playing and pointless afterwards for an easter egg most sessions
    /// never open.
    ///
    /// Also nudges speech. The session is shared and this leaves it on
    /// `.ambient`; `SpeechService` caches that it once configured `.playback`
    /// and won't re-set it, so without this the next thing the app said would be
    /// silenced by the bell switch — a game sound effect quietly breaking the
    /// dictionary.
    func finish() {
        guard running else { return }
        for node in nodes.values.flatMap({ $0 }) { node.stop() }
        engine.stop()
        running = false
        buffers.removeAll()
        SpeechService.shared.invalidateSession()
    }

    // MARK: - Playing

    /// Fires a cue. Cheap enough to call from the game loop: it schedules a
    /// buffer on a node that is already running, with no session or daemon work.
    func play(_ cue: Cue) {
        guard running,
              let buffer = buffers[cue],
              let pool = nodes[cue], !pool.isEmpty else { return }

        // Prefer an idle node so nothing has to wait; fall back to round-robin,
        // where the buffer queues behind what's playing rather than cutting it.
        let cursor = next[cue] ?? 0
        var chosen = pool[cursor]
        for offset in 0..<pool.count {
            let candidate = pool[(cursor + offset) % pool.count]
            if !candidate.isPlaying || candidate.lastRenderTime == nil {
                chosen = candidate
                break
            }
        }
        next[cue] = (cursor + 1) % pool.count
        chosen.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    // MARK: - Setup

    private func loadBuffers() {
        for cue in Cue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length))
            else { continue }
            do {
                try file.read(into: buffer)
                buffers[cue] = buffer
            } catch {
                continue
            }
        }
    }

    /// Attaches the nodes once and leaves them attached. Rebuilding the graph
    /// per game would mean re-attaching thirty-one nodes each time for no gain.
    private func buildGraph() {
        for cue in Cue.allCases {
            guard let buffer = buffers[cue] else { continue }
            var pool: [AVAudioPlayerNode] = []
            for _ in 0..<Self.poolSize(for: cue) {
                let node = AVAudioPlayerNode()
                node.volume = Self.volume(for: cue)
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
                pool.append(node)
            }
            nodes[cue] = pool
            next[cue] = 0
        }
    }

    /// Study features leave the session in `.playback`, or in a recording
    /// category if the microphone has been used — the first ignores the bell
    /// switch, the second would mute the game outright. Claimed once per game;
    /// deliberately *not* per sound, because these calls are XPC to the audio
    /// daemon and Apple flags them as a main-thread hang risk.
    private func claimSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }
}
