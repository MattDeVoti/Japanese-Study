import SwiftUI

// The graded track: one test per lesson, a letter grade, and a permanent record.
//
// This replaces the streak as the app's motivation. A streak rewards showing up,
// which converges on doing the least that keeps it alive. A grade rewards knowing
// the material, and a grade you aren't happy with is a reason to go back — the
// pressure points at competence rather than attendance.

// MARK: - Grades

struct Grade: Codable, Equatable, Comparable {
    /// 0…100.
    let percent: Double

    static let passMark: Double = 60          // may move on to the next lesson
    /// B — what an ordinary lesson must score to stop holding its level back.
    static let standardMark: Double = 83
    /// A — a test-out stands in for every part of a syllabary at once, so it's
    /// held to a higher bar than any single part.
    static let testOutMark: Double = 93

    var letter: String {
        switch percent {
        case 93...:     return "A"
        case 90..<93:   return "A-"
        case 87..<90:   return "B+"
        case 83..<87:   return "B"
        case 80..<83:   return "B-"
        case 77..<80:   return "C+"
        case 73..<77:   return "C"
        case 70..<73:   return "C-"
        case 67..<70:   return "D+"
        case 63..<67:   return "D"
        case 60..<63:   return "D-"
        default:        return "F"
        }
    }

    /// 4.0-scale value, for the report card average.
    var points: Double {
        switch letter {
        case "A":  return 4.0
        case "A-": return 3.7
        case "B+": return 3.3
        case "B":  return 3.0
        case "B-": return 2.7
        case "C+": return 2.3
        case "C":  return 2.0
        case "C-": return 1.7
        case "D+": return 1.3
        case "D":  return 1.0
        case "D-": return 0.7
        default:   return 0.0
        }
    }

    var isPass: Bool { percent >= Self.passMark }
    func meets(_ mark: Double) -> Bool { percent >= mark }

    /// Green once it clears the bar it's being held to, amber if it merely passed,
    /// red if it failed. The bar is passed in because a B clears a lesson but not
    /// a test-out.
    func color(clearing mark: Double = Grade.standardMark) -> Color {
        if percent >= mark { return Color(hex: "22C55E") }
        if isPass { return Color(hex: "F59E0B") }
        return Color(hex: "EF4444")
    }

    var color: Color { color(clearing: Grade.standardMark) }

    static func < (a: Grade, b: Grade) -> Bool { a.percent < b.percent }
}

// MARK: - Attempts

/// One sitting of one lesson's test. Never deleted — a failure stays on the record
/// even after it's been rescued, which is the point.
struct ExamAttempt: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    let lessonId: String            // chapter id, or "kana:Hiragana"
    let takenAt: Date
    let grade: Grade
    /// Correct / total per section, for diagnosis.
    var sections: [SectionScore]

    struct SectionScore: Codable, Equatable {
        let section: ExamSection
        let correct: Int
        let total: Int
        var percent: Double { total == 0 ? 0 : Double(correct) / Double(total) * 100 }
    }
}

enum ExamSection: String, Codable, CaseIterable {
    case grammar, vocab, kanji, kana

    var label: String {
        switch self {
        case .grammar: return "Grammar"
        case .vocab:   return "Vocab"
        case .kanji:   return "Kanji"
        case .kana:    return "Kana"
        }
    }
    var color: Color {
        switch self {
        case .grammar: return .grammarColor
        case .vocab:   return .vocabColor
        case .kanji:   return .kanjiColor
        case .kana:    return .hiraganaColor
        }
    }
}

// MARK: - The track

/// One entry in the graded sequence.
struct ExamLesson: Identifiable, Equatable {
    enum Kind: Equatable {
        /// One grammar chapter.
        case chapter
        /// Part of a syllabary — a handful of kana rows.
        case kanaChunk
        /// The whole syllabary in one paper. Optional: pass it and the level is
        /// cleared without sitting the parts.
        case kanaTestOut
    }

    let id: String
    let levelId: String          // "Hiragana", "Katakana", "N5"…
    let title: String
    /// What the paper covers, shown under the title.
    let coverage: String
    /// Chapters this test draws from.
    let chapterIds: [String]
    let kind: Kind

    var isTestOut: Bool { kind == .kanaTestOut }

    /// The mark this paper must reach to clear.
    var requiredMark: Double { isTestOut ? Grade.testOutMark : Grade.standardMark }
    var requiredLetter: String { isTestOut ? "A" : "B" }
    /// Kana papers are built from character cards rather than grammar points.
    var usesKanaBuilder: Bool { kind != .chapter }
}

// MARK: - Deadline wording

extension Date {
    /// "today" / "tomorrow" / "Friday" / "12 Aug" — how a deadline should read.
    var deadlineLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "today" }
        if cal.isDateInTomorrow(self) { return "tomorrow" }
        if cal.isDateInYesterday(self) { return "yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                      to: cal.startOfDay(for: self)).day ?? 0
        let f = DateFormatter()
        if (0...6).contains(days) {
            f.dateFormat = "EEEE"                    // within the week: name the day
        } else {
            f.dateFormat = "d MMM"
        }
        return f.string(from: self)
    }

    /// Framed as a deadline: "due by Friday" — but "due today" rather than the
    /// clumsier "due by today".
    var deadlineDuePhrase: String {
        let l = deadlineLabel
        return ["today", "tomorrow", "yesterday"].contains(l) ? "due \(l)" : "due by \(l)"
    }
}
