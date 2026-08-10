import AVFoundation

/// The two short tones the vocal session answers with.
///
/// Both are bundled as WAVs rather than synthesised, so they can be swapped for
/// different recordings by replacing the files in Resources/Audio — nothing here
/// needs to change.
final class FeedbackSounds {
    static let shared = FeedbackSounds()

    enum Cue: String {
        case correct
        case incorrect
    }

    /// Players are built once and kept: allocating one at the moment of playback
    /// adds an audible delay to what is meant to be instant feedback.
    private var players: [Cue: AVAudioPlayer] = [:]

    private init() {
        for cue in [Cue.correct, .incorrect] {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[cue] = player
        }
    }

    func play(_ cue: Cue) {
        // The session may have been left in a recording category by the listener,
        // in which case playback is silent. Claiming it back here keeps the cue
        // independent of whatever ran before it.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true, options: [])

        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }
}
