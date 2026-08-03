import Foundation

/// A reading-comprehension passage plus its bank of potential questions.
/// `passage` is Japanese with inline `kanji[reading]` furigana markup, rendered
/// by FuriganaText. `questions` holds up to 25 potential questions; the detail
/// view shows 5 chosen at random per visit.
struct Reading: Codable, Identifiable {
    let id: String
    let title: String        // shown in the list; may contain furigana markup
    let levelId: String    // "N5" … "N1"
    let order: Int           // difficulty rank within the level (1 = easiest)
    let type: String         // "letter" | "email" | "story" | "article" | "dialogue" | "diary"
    let passage: String      // Japanese, furigana markup, paragraphs split by "\n\n"
    let questions: [PracticeQuestion]

    var nLevel: Int { Int(levelId.dropFirst()) ?? 5 }
}
