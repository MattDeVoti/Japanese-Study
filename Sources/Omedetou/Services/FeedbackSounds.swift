import AVFoundation

/// The short tones the app answers with.
///
/// All are bundled as WAVs rather than synthesised, so they can be swapped for
/// different recordings by replacing the files in Resources/Audio — nothing here
/// needs to change.
final class FeedbackSounds {
    static let shared = FeedbackSounds()

    enum Cue: String {
        case correct
        case incorrect
        /// A secret game has just been found. Rare and one-off, so unlike the
        /// answer cues it is loaded on demand rather than kept ready.
        case unlock
    }

    /// The piano stings the audio flashcards use instead of the plain `correct`
    /// tone. Named `piano_correct_1…7` in Resources/Audio/correct_piano.
    ///
    /// Adding an eighth is just dropping the file in and changing this number.
    private static let pianoVariants = 7
    private static func pianoName(_ n: Int) -> String { "piano_correct_\(n)" }

    /// Players are kept once built: allocating one at the moment of playback
    /// adds an audible delay to what is meant to be instant feedback. Keyed by
    /// resource name so the piano variants can share the cache.
    private var players: [String: AVAudioPlayer] = [:]

    /// Remaining variants in the current shuffle.
    private var pianoBag: [Int] = []
    private var lastPiano: Int?

    private init() {
        // Only the answer cues are preloaded: they follow a tap and any delay
        // reads as lag. `unlock` is a once-ever moment, and the seven piano
        // stings are three megabytes between them — both are loaded on first
        // use instead, which costs a few milliseconds once.
        for cue in [Cue.correct, .incorrect] { _ = load(cue.rawValue) }
    }

    @discardableResult
    private func load(_ name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[name] = player
        return player
    }

    func play(_ cue: Cue) {
        play(named: cue.rawValue)
    }

    /// A different piano sting each time something is answered correctly in the
    /// audio flashcards.
    ///
    /// Dealt from a shuffled bag rather than picked at random per answer: true
    /// random plays the same clip twice in a row about one time in seven, which
    /// is exactly the thing having seven of them is meant to avoid. Every clip
    /// is heard once before any repeats, and the seam between bags is checked so
    /// a reshuffle can't hand back the clip that just played.
    func playCorrectVariation() {
        let variant = nextPianoVariant()
        // Falls back to the original single tone if a variant is missing, so a
        // renamed or absent file means a plainer cue rather than silence.
        if load(Self.pianoName(variant)) == nil {
            play(.correct)
        } else {
            play(named: Self.pianoName(variant))
        }
    }

    // BEGIN-BAG (extracted verbatim by the shuffle test)
    /// Deals the next variant, refilling and reshuffling when the bag runs out.
    func nextPianoVariant() -> Int {
        if pianoBag.isEmpty {
            pianoBag = Array(1...Self.pianoVariants).shuffled()
            // The seam is the only place a repeat can sneak in: the last clip of
            // one bag and the first of the next are independent draws.
            if pianoBag.count > 1, pianoBag.first == lastPiano { pianoBag.swapAt(0, 1) }
        }
        let variant = pianoBag.removeFirst()
        lastPiano = variant
        return variant
    }
    // END-BAG

    private func play(named name: String) {
        // The session may have been left in a recording category by the listener,
        // in which case playback is silent. Claiming it back here keeps the cue
        // independent of whatever ran before it.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true, options: [])

        guard let player = load(name) else { return }
        player.currentTime = 0
        player.play()
    }
}
