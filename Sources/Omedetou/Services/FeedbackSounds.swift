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
        /// The soft tone for anything that is neither right nor wrong: a card
        /// turning over, a screen being opened, an answer being chosen on a test
        /// that won't mark it until the end.
        case notification
        /// A test has been handed in. One per paper, so it can be a fuller sound
        /// than the per-answer cues.
        case complete
        /// Moving to another screen.
        case navigate
        /// A star going on.
        case favorite
        /// A star coming off.
        case unfavorite
        /// Something opened or closed in place — a card's extra detail, a
        /// grammar point, a section of a page. Both directions get the same
        /// sound: it marks the panel moving, not which way it went.
        case slide = "slide_open"
        /// A secret game has just been found. Rare and one-off, so unlike the
        /// answer cues it is loaded on demand rather than kept ready.
        case unlock

        /// Whether the Ring/Silent switch should be able to mute this cue.
        ///
        /// All of them, now. Nothing reads the switch — iOS exposes no API for
        /// it, and none is needed: `.ambient` makes the system do the muting,
        /// exactly as `GameSounds` does for Kanji Invaders.
        ///
        /// The answer cues used to stay on `.playback` so a learner drilling on
        /// a muted phone still heard right from wrong. That split doesn't
        /// survive contact with the app as it now stands: the same piano sting
        /// answers a flashcard, a quiz, a reading question and a kanji match, so
        /// it cannot follow the switch in one place and ignore it in another
        /// without becoming unpredictable. A phone set to silent is silent.
        var respectsBell: Bool { true }
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

    /// When the interface click last played. See `playNavigate`.
    private var lastNavigate: Date?

    /// Remaining variants in the current shuffle.
    private var pianoBag: [Int] = []
    private var lastPiano: Int?

    private init() {
        // Only the answer cues are preloaded: they follow a tap and any delay
        // reads as lag. `unlock` is a once-ever moment, and the seven piano
        // stings are three megabytes between them — both are loaded on first
        // use instead, which costs a few milliseconds once.
        // `complete` is once per paper and `unlock` once ever; both are loaded on
        // first use instead of being kept ready. `navigate` is preloaded despite
        // being small — it fires on the very first tap of a session, and that is
        // the one that would arrive late.
        for cue in [Cue.correct, .incorrect, .notification, .navigate, .slide,
                    .favorite, .unfavorite] { _ = load(cue.rawValue) }
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

    /// Whether the study cues should sound at all.
    ///
    /// Tied to the app's Japanese Audio switch: someone who turned that off has
    /// asked the app to be quiet, and a chime on every answer is exactly the
    /// kind of noise they turned off. The unlock jingle is exempt — it belongs
    /// to the games, which follow the Ring/Silent switch instead.
    private var studyCuesEnabled: Bool { SpeechService.shared.isEnabled }

    func play(_ cue: Cue) {
        // `navigate`, `slide` and the two star cues are exempt: that switch is
        // labelled Japanese Audio and is about the app reading Japanese aloud,
        // which an interface click is not. The Ring/Silent switch is what
        // silences those.
        guard cue == .unlock || cue == .navigate || cue == .slide
                || cue == .favorite || cue == .unfavorite || studyCuesEnabled else { return }
        play(named: cue.rawValue, respectsBell: cue.respectsBell)
    }

    /// The interface click, with a short guard against playing it twice for one
    /// tap.
    ///
    /// A tap on a card fires this from the button (immediate, which is where the
    /// click belongs) and again a fraction of a second later when the screen it
    /// pushed arrives. Both hooks are wanted — plenty of rows that navigate are
    /// not `pressable`, and arriving is the only signal those give — so the
    /// duplicate is suppressed here rather than by trying to make the two hooks
    /// know about each other.
    func playNavigate() {
        let now = Date()
        if let last = lastNavigate, now.timeIntervalSince(last) < 0.35 { return }
        lastNavigate = now
        play(.navigate)
    }

    /// The star going on or off. Pass the state the item is in *after* the tap.
    func playFavorite(_ isFavorite: Bool) {
        play(isFavorite ? .favorite : .unfavorite)
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
        guard studyCuesEnabled else { return }
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
        // Resolved before the session is touched: claiming a `.playback` session
        // with `.duckOthers` dips whatever the learner is listening to, and doing
        // that for a cue whose file isn't there would duck their music to play
        // nothing at all.
        guard let player = load(name) else { return }

        // Never reconfigure the session out from under a voice that is already
        // speaking. The reading screen can be reading a passage aloud while an
        // answer is tapped, and switching the category mid-sentence would cut
        // the voice — or, on a muted phone, silence the rest of it. The cue just
        // plays on whatever session is already up.
        let speaking = SpeechService.shared.speakingID != nil

        // Otherwise: the session may have been left in a recording category by
        // the listener, or on `.ambient` by the game, in which case playback is
        // silent or muted. Claiming it back here keeps the cue independent of
        // whatever ran before it.
        let session = AVAudioSession.sharedInstance()
        if speaking {
            // nothing to claim — leave it exactly as the voice set it up
        } else if respectsBell {
            // Mixes rather than ducks, so a celebration doesn't dip someone's
            // music — same choice the game makes.
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        } else {
            try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        }
        if !speaking { try? session.setActive(true, options: []) }

        player.currentTime = 0
        player.play()

        // Hand the session back. `SpeechService` caches that it once configured
        // `.playback` and won't re-set it, so leaving the session on `.ambient`
        // would silence the next thing the app said whenever the bell was off —
        // and two of the four unlocks fire in the dictionary and the cheat
        // sheets, where the very next tap is likely to be a speaker button.
        // Only clears the cached flag, so the cue itself plays out normally.
        if respectsBell, !speaking { SpeechService.shared.invalidateSession() }
    }
}
