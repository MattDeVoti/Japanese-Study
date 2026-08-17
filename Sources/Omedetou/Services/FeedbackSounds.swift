import AVFoundation

/// The short tones the app answers with.
///
/// All are bundled as WAVs rather than synthesised, so they can be swapped for
/// different recordings by replacing the files in Resources/Audio — nothing here
/// needs to change.
///
/// Two audio-session categories live here, per cue — see `Cue.respectsBell`.
/// Study cues play *through* the Ring/Silent switch, because someone drilling
/// vocab on a muted phone still wants to hear whether they got it right. The
/// unlock jingle is a celebration rather than feedback, so it follows the games'
/// rule instead: silent means silent.
final class FeedbackSounds {
    static let shared = FeedbackSounds()

    enum Cue: String {
        case correct
        case incorrect
        /// A secret game has just been found. Rare and one-off, so unlike the
        /// answer cues it is loaded on demand rather than kept ready.
        case unlock

        /// Whether the Ring/Silent switch should be able to mute this cue.
        ///
        /// Nothing reads the switch — iOS exposes no API for it, and none is
        /// needed: `.ambient` makes the system do the muting, exactly as
        /// `GameSounds` does for Kanji Invaders. Answer cues stay on `.playback`
        /// and are deliberately heard on a muted phone.
        var respectsBell: Bool { self == .unlock }
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
        play(named: cue.rawValue, respectsBell: cue.respectsBell)
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

    private func play(named name: String, respectsBell: Bool = false) {
        // The session may have been left in a recording category by the listener,
        // or on `.ambient` by the game, in which case playback is silent or
        // muted. Claiming it back here keeps the cue independent of whatever ran
        // before it.
        let session = AVAudioSession.sharedInstance()
        if respectsBell {
            // Mixes rather than ducks, so a celebration doesn't dip someone's
            // music — same choice the game makes.
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        } else {
            try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        }
        try? session.setActive(true, options: [])

        guard let player = load(name) else { return }
        player.currentTime = 0
        player.play()

        // Hand the session back. `SpeechService` caches that it once configured
        // `.playback` and won't re-set it, so leaving the session on `.ambient`
        // would silence the next thing the app said whenever the bell was off —
        // and two of the four unlocks fire in the dictionary and the cheat
        // sheets, where the very next tap is likely to be a speaker button.
        // Only clears the cached flag, so the cue itself plays out normally.
        if respectsBell { SpeechService.shared.invalidateSession() }
    }
}
