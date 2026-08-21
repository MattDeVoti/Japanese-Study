import Foundation

// Assembles a test for a lesson.
//
// Grammar questions come from the chapter's own authored practice bank (median 60
// per chapter), sampled fresh each sitting so a retake is a different paper —
// otherwise the second attempt tests memory of the questions, not the material.
// Vocab and kanji have no authored banks, so those are generated, with distractors
// drawn from the same chapter first so the choices are plausibly confusable.

struct ExamQuestion: Identifiable {
    let id: String
    let section: ExamSection
    let prompt: String
    /// Japanese shown large under the prompt, if any. May carry furigana markup.
    let subject: String?
    let choices: [String]
    let correctIndex: Int
    let explanation: String?
    /// What to put into the review schedule if this is missed.
    /// What the question was about. Only used to count *distinct* items missed
    /// on the results screen — two questions on the same word are one thing to
    /// go back over.
    let reviewItem: StudyItemRef?

    var correctAnswer: String { choices[correctIndex] }
}

enum ExamBuilder {

    /// Total questions on a grammar lesson's paper.
    static let standardLength = 24
    /// A kana part covers a few rows; the test-out covers the whole syllabary, so
    /// it runs longer to be a fair substitute for all three parts.
    static let kanaChunkLength = 20
    static let kanaTestOutLength = 40

    /// `cardStore` supplies kanji meanings and readings — it owns the kanji data.
    static func build(for lesson: ExamLesson, cardStore: CardStore) -> [ExamQuestion] {
        lesson.usesKanaBuilder
            ? buildKana(lesson, length: lesson.isTestOut ? kanaTestOutLength : kanaChunkLength)
            : buildStandard(lesson, cardStore: cardStore)
    }

    // MARK: - Grammar lessons

    private static func buildStandard(_ lesson: ExamLesson, cardStore: CardStore) -> [ExamQuestion] {
        guard let chapterId = lesson.chapterIds.first,
              let chapter = LessonsService.shared.loadChapter(chapterId) else { return [] }

        let vocab = chapter.vocab ?? []
        let kanjiWords = chapter.kanjiWords ?? []

        // 40 / 35 / 25, with any section the chapter lacks giving its share back.
        var weights: [ExamSection: Double] = [:]
        weights[.grammar] = chapter.points.isEmpty ? 0 : 0.40
        weights[.vocab]   = vocab.isEmpty ? 0 : 0.35
        weights[.kanji]   = kanjiWords.isEmpty ? 0 : 0.25
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return [] }

        var out: [ExamQuestion] = []
        out += grammarQuestions(chapter: chapter,
                                count: share(weights[.grammar]!, total, standardLength))
        out += vocabQuestions(words: vocab, chapterId: chapterId,
                              count: share(weights[.vocab]!, total, standardLength))
        out += kanjiQuestions(words: kanjiWords,
                              count: share(weights[.kanji]!, total, standardLength))

        // Rounding and un-buildable questions leave papers short, which quietly
        // changes what each question is worth. Top up from the grammar bank, which
        // is the only section with reliable surplus.
        if out.count < standardLength {
            let used = Set(out.map(\.id))
            let extra = grammarQuestions(chapter: chapter, count: standardLength * 3)
                .filter { !used.contains($0.id) }
            var seen = used
            for q in extra where out.count < standardLength {
                guard !seen.contains(q.id) else { continue }
                seen.insert(q.id)
                out.append(q)
            }
        }
        return out
    }

    private static func share(_ weight: Double, _ total: Double, _ length: Int) -> Int {
        Int((weight / total * Double(length)).rounded())
    }

    private static func grammarQuestions(chapter: LessonChapter, count: Int) -> [ExamQuestion] {
        var pool: [(GrammarPoint, PracticeQuestion)] = []
        for p in chapter.points {
            for q in (p.practice ?? []) { pool.append((p, q)) }
        }
        for q in (chapter.chapterPractice ?? []) {
            if let first = chapter.points.first { pool.append((first, q)) }
        }
        return pool.shuffled().prefix(count).map { point, q in
            let (choices, correct) = shuffled(q.choices, q.correctIndex)
            // The id carries the chapter: te-iru_q1 exists in both ch06 and ch07,
            // and answers are keyed by id — two questions sharing one on a single
            // paper would answer each other and mis-grade.
            return ExamQuestion(id: "g:\(chapter.id):\(q.id)",
                         section: .grammar,
                         prompt: q.prompt,
                         subject: q.japanese,
                         choices: choices,
                         correctIndex: correct,
                         explanation: q.explanation,
                         reviewItem: .grammar(chapterId: chapter.id, pointId: point.id))
        }
    }

    // MARK: - Vocab

    private static func vocabQuestions(words: [LessonVocabWord], chapterId: String,
                                       count: Int) -> [ExamQuestion] {
        guard words.count >= 4, count > 0 else { return [] }
        var out: [ExamQuestion] = []
        for word in words.shuffled().prefix(count) {
            let others = words.filter { $0.id != word.id }
            // Try each style in turn rather than dropping the word: a word whose
            // reading question can't be built (kana-only words have no reading to
            // ask for) would otherwise silently shorten the paper.
            let styles = [0, 1, 2].shuffled()
            for style in styles {
                var made: ExamQuestion?
                switch style {
                case 0:
                    if let choices = pick(distractors: others.map(\.definition),
                                          correct: word.definition) {
                        made = ExamQuestion(id: "v:\(word.id):m", section: .vocab,
                                            prompt: "What does this mean?", subject: word.kanji,
                                            choices: choices,
                                            correctIndex: choices.firstIndex(of: word.definition) ?? 0,
                                            explanation: "\(word.kanji) (\(word.kana)) — \(word.definition)",
                                            reviewItem: .vocab(word.id))
                    }
                case 1:
                    // "Which word means X?" — a chapter-mate defined the same way
                    // is just as right, so it can't stand as a wrong answer.
                    let sameMeaning = others.filter { $0.definition == word.definition }
                                            .map(\.kanji)
                    if let choices = pick(distractors: others.map(\.kanji)
                                              .filter { !sameMeaning.contains($0) },
                                          correct: word.kanji) {
                        made = ExamQuestion(id: "v:\(word.id):w", section: .vocab,
                                            prompt: "Which word means “\(word.definition)”?",
                                            subject: nil, choices: choices,
                                            correctIndex: choices.firstIndex(of: word.kanji) ?? 0,
                                            explanation: "\(word.kanji) (\(word.kana)) — \(word.definition)",
                                            reviewItem: .vocab(word.id))
                    }
                default:
                    if word.kanji != word.kana,
                       let choices = pick(distractors: others.map(\.kana), correct: word.kana) {
                        made = ExamQuestion(id: "v:\(word.id):r", section: .vocab,
                                            prompt: "How is this read?", subject: word.kanji,
                                            choices: choices,
                                            correctIndex: choices.firstIndex(of: word.kana) ?? 0,
                                            explanation: "\(word.kanji) is read \(word.kana).",
                                            reviewItem: .vocab(word.id))
                    }
                }
                if let made { out.append(made); break }
            }
        }
        return out
    }

    // MARK: - Kanji

    /// Kanji questions, asked from the words the chapter teaches its kanji in.
    ///
    /// The subject is always a whole word — 高い, 校長 — never a bare character,
    /// because that is how the lessons now teach kanji: as parts of words. Wrong
    /// answers are drawn from other chapters' kanji words, which keeps every
    /// option something the course actually teaches.
    private static func kanjiQuestions(words: [ChapterKanjiWord],
                                       count: Int) -> [ExamQuestion] {
        guard count > 0, !words.isEmpty else { return [] }

        // Distractors come from the whole course, so a small chapter still has
        // a pool — but never from a word sharing a character with the subject,
        // whose reading or meaning can be close enough to also look right.
        let everything = LessonsService.shared.allKanjiWords().map(\.word)

        var out: [ExamQuestion] = []
        for entry in words.shuffled().prefix(count) {
            let chars = Set(entry.chars)
            let others = everything.filter { other in
                other.id != entry.id && !other.chars.contains(where: chars.contains)
            }

            if Bool.random(), !entry.kana.isEmpty {
                // Any word read the same way has to come out of the pool, or
                // two options would be right at once.
                let pool = others.map(\.kana)
                    .filter { !$0.isEmpty && $0 != entry.kana }
                guard let choices = pick(distractors: pool, correct: entry.kana) else { continue }
                out.append(ExamQuestion(
                    id: "k:\(entry.id):r", section: .kanji,
                    prompt: "How is this read?", subject: entry.word,
                    choices: choices, correctIndex: choices.firstIndex(of: entry.kana) ?? 0,
                    explanation: "\(entry.word) (\(entry.kana)) — \(entry.meaning)",
                    reviewItem: .kanji(entry.id)))
            } else {
                let pool = others.map(\.meaning).filter { !$0.isEmpty && $0 != entry.meaning }
                guard let choices = pick(distractors: pool, correct: entry.meaning) else { continue }
                out.append(ExamQuestion(
                    id: "k:\(entry.id):m", section: .kanji,
                    prompt: "What does this mean?", subject: entry.word,
                    choices: choices, correctIndex: choices.firstIndex(of: entry.meaning) ?? 0,
                    explanation: "\(entry.word) (\(entry.kana)) — \(entry.meaning)",
                    reviewItem: .kanji(entry.id)))
            }
        }
        return out
    }

    // MARK: - Kana

    /// One paper covering the whole syllabary, drawn from every kana chapter's
    /// character cards and their own practice questions.
    private static func buildKana(_ lesson: ExamLesson, length: Int) -> [ExamQuestion] {
        var characters: [(chapterId: String, point: GrammarPoint)] = []
        var authored: [(chapterId: String, q: PracticeQuestion, pointId: String)] = []

        for id in lesson.chapterIds {
            guard let ch = LessonsService.shared.loadChapter(id) else { continue }
            for p in ch.points where p.isKanaCharacter {
                characters.append((id, p))
            }
            for q in (ch.chapterPractice ?? []) {
                authored.append((id, q, ch.points.first?.id ?? ""))
            }
        }
        guard characters.count >= 4 else { return [] }

        var out: [ExamQuestion] = []
        // Roughly two thirds generated character recognition, one third authored.
        let generatedCount = Int(Double(length) * 0.66)
        for (chapterId, point) in characters.shuffled().prefix(generatedCount) {
            let others = characters.filter { $0.point.id != point.id }.map { $0.point.formation }
            guard let choices = pick(distractors: others, correct: point.formation) else { continue }
            out.append(ExamQuestion(
                id: "kana:\(point.id)", section: .kana,
                prompt: "How is this read?", subject: point.name,
                choices: choices, correctIndex: choices.firstIndex(of: point.formation) ?? 0,
                explanation: "\(point.name) is read \(point.formation).",
                reviewItem: .grammar(chapterId: chapterId, pointId: point.id)))
        }
        for (chapterId, q, pointId) in authored.shuffled().prefix(max(length - out.count, 0)) {
            let (choices, correct) = shuffled(q.choices, q.correctIndex)
            out.append(ExamQuestion(
                id: "kana-a:\(chapterId):\(q.id)", section: .kana,
                prompt: q.prompt, subject: q.japanese,
                choices: choices, correctIndex: correct, explanation: q.explanation,
                reviewItem: pointId.isEmpty ? nil
                    : .grammar(chapterId: chapterId, pointId: pointId)))
        }
        return out
    }

    // MARK: - Helpers

    /// Authored banks keep the answer in a fixed slot, and across the whole bank
    /// 49% of them sit first — enough to pass a paper by always tapping the top
    /// option. Generated questions already shuffle; papers now shuffle authored
    /// ones too. (Chapter practice shuffles separately, in GrammarPracticeView.)
    private static func shuffled(_ choices: [String], _ correct: Int) -> ([String], Int) {
        guard choices.indices.contains(correct) else { return (choices, correct) }
        let order = Array(choices.indices).shuffled()
        return (order.map { choices[$0] }, order.firstIndex(of: correct) ?? 0)
    }

    /// Four distinct choices, shuffled, or nil when there aren't three usable
    /// distractors (which happens on very small chapters).
    private static func pick(distractors: [String], correct: String) -> [String]? {
        let unique = Array(Set(distractors.filter { $0 != correct && !$0.isEmpty }))
        guard unique.count >= 3 else { return nil }
        return (unique.shuffled().prefix(3) + [correct]).shuffled()
    }
}
