import SwiftUI

// MARK: - Reading list (grouped by level, easiest first)

struct ReadingListView: View {
    @State private var readings: [Reading] = []

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if readings.isEmpty {
                        Text("No readings available yet.")
                            .foregroundColor(.appTextSecondary)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(ReadingsService.shared.levelsPresent, id: \.self) { level in
                            levelSection(level)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
        }
        .standardNavBar("Reading Comprehension")
        .onAppear {
            ReadingsService.shared.loadIfNeeded()
            readings = ReadingsService.shared.readings
        }
    }

    private func levelSection(_ level: String) -> some View {
        let items = ReadingsService.shared.readings(forLevel: level)
        let n = Int(level.dropFirst()) ?? 5
        let color = nLevelColor(n)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                SectionHeading(levelName(jlpt: level))
                Text(level)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(color))
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, reading in
                    if idx != 0 { Divider().padding(.leading, 16) }
                    ReadingRow(reading: reading, color: color)
                }
            }
            .appCard(cornerRadius: 16)
        }
    }
}

private struct ReadingRow: View {
    let reading: Reading
    let color: Color

    var body: some View {
        NavigationLink {
            ReadingDetailView(reading: reading)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(color.badgeGradient))
                    .shadow(color: color.opacity(0.35), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 3) {
                    FuriganaText(text: reading.title, fontSize: 16, color: .appText, weight: .semibold)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(typeLabel)
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch reading.type {
        case "letter", "email": return "envelope.fill"
        case "article": return "newspaper.fill"
        case "dialogue": return "bubble.left.and.bubble.right.fill"
        case "diary": return "book.closed.fill"
        default: return "text.book.closed.fill"
        }
    }
    private var typeLabel: String {
        switch reading.type {
        case "letter": return "Letter"
        case "email": return "Email"
        case "article": return "Article"
        case "dialogue": return "Dialogue"
        case "diary": return "Diary"
        default: return "Story"
        }
    }
}

// MARK: - Reading detail (passage + questions + word-lookup popup)

struct ReadingDetailView: View {
    let reading: Reading

    @State private var shownQuestions: [PracticeQuestion] = []
    @State private var selectedWord: String?
    @State private var selectedDef: WordDefinition?
    @State private var wordRectGlobal: CGRect = .zero
    @State private var popupSize: CGSize = .zero

    private var accent: Color { nLevelColor(reading.nLevel) }

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Passage, dressed as the kind of document it is.
                        PassagePaper(style: style, accent: accent) {
                            // Listen to the whole passage — the annotations mean the
                            // readings are correct, which makes this usable as a
                            // listening exercise rather than a novelty.
                            HStack(spacing: 4) {
                                SpeakButton(text: paragraphs.joined(separator: "\n"),
                                            size: 16, tint: accent)
                                Text("Listen")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(accent)
                                Spacer()
                            }

                            if style == .dialogue {
                                dialogueBody
                            } else {
                                proseBody
                            }
                        }

                        Text("Tip: press and hold a word to see its meaning.")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 4)

                        // Questions
                        Text("QUESTIONS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accent)
                            .padding(.top, 6)

                        ForEach(Array(shownQuestions.enumerated()), id: \.element.id) { i, q in
                            QuestionCard(number: i + 1, question: q, accent: accent)
                        }
                    }
                    .padding(20)
                }

                // Dim + tap-to-dismiss layer
                if selectedWord != nil {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { dismissPopup() }

                    DefinitionPopup(word: selectedWord ?? "", def: selectedDef, accent: accent)
                        .fixedSize()
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear { popupSize = proxy.size }
                                    .onChange(of: proxy.size) { popupSize = $0 }
                            }
                        )
                        .offset(popupOffset(in: geo.size, origin: origin))
                        .opacity(popupSize == .zero ? 0 : 1)
                }
            }
        }
        .standardNavBar("Reading")
        .onAppear {
            if shownQuestions.isEmpty {
                shownQuestions = Array(reading.questions.shuffled().prefix(5))
            }
        }
    }

    private var style: PassageStyle { PassageStyle(rawType: reading.type) }

    /// Letters, diaries, articles and stories: paragraphs stacked down the page,
    /// each followed by the rule that suits the format.
    private var proseBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, para in
                FuriganaText(text: para, fontSize: 18, color: .appText,
                             interactive: true,
                             onWordSelect: { word, rect in handleWord(word, rect) },
                             // A letter is written on ruled stationery, so every
                             // line gets a guide, not just every paragraph.
                             lineRule: style == .letter ? accent.opacity(0.45) : nil)
                    .fixedSize(horizontal: false, vertical: true)
                // Diaries and articles keep a rule between sections; a letter
                // already has one under every line, and a story reads as prose.
                if idx < paragraphs.count - 1 && style != .letter {
                    ParagraphRule(style: style, accent: accent)
                }
            }
        }
    }

    /// A dialogue is a conversation, so each paragraph becomes a turn. Sides are
    /// keyed to the speaker named before the 「：」, not to the paragraph's position —
    /// two consecutive lines from one person would otherwise flip sides and read
    /// as a reply from someone else.
    private var dialogueBody: some View {
        let sides = speakerSides
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, para in
                let mine = sides[idx]
                HStack(spacing: 0) {
                    if mine { Spacer(minLength: 28) }
                    FuriganaText(text: para, fontSize: 17, color: .appText,
                                 interactive: true) { word, rect in
                        handleWord(word, rect)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(mine ? accent.opacity(0.14) : Color.appText.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(mine ? accent.opacity(0.30) : Color.appHairline,
                                          lineWidth: 1)
                    )
                    if !mine { Spacer(minLength: 28) }
                }
            }
        }
    }

    /// Which side of the transcript each paragraph belongs on. The first speaker
    /// found sits left, the next distinct one right; anything without a name
    /// falls back to alternating so an unlabelled transcript still reads as a
    /// back-and-forth.
    private var speakerSides: [Bool] {
        var order: [String] = []
        var out: [Bool] = []
        for (i, para) in paragraphs.enumerated() {
            let name = Self.speaker(in: para)
            if let name, !order.contains(name) { order.append(name) }
            if let name, let idx = order.firstIndex(of: name) {
                out.append(idx % 2 == 1)
            } else {
                out.append(i % 2 == 1)
            }
        }
        return out
    }

    /// The name before a full-width colon, with any furigana brackets stripped.
    private static func speaker(in paragraph: String) -> String? {
        guard let sep = paragraph.firstIndex(where: { $0 == "：" || $0 == ":" }) else { return nil }
        let raw = String(paragraph[paragraph.startIndex..<sep])
        let name = raw.replacingOccurrences(of: "\\[[^\\]]*\\]", with: "",
                                            options: .regularExpression)
                      .trimmingCharacters(in: .whitespaces)
        // A colon deep into a sentence isn't a speaker label.
        return (name.isEmpty || name.count > 8) ? nil : name
    }

    private var paragraphs: [String] {
        reading.passage.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func handleWord(_ word: String, _ rectGlobal: CGRect) {
        selectedWord = word
        selectedDef = WordLookup.lookup(word)
        wordRectGlobal = rectGlobal
    }

    private func dismissPopup() {
        selectedWord = nil
        selectedDef = nil
        popupSize = .zero
    }

    /// Places the popup above the held word (or below if there's no room above),
    /// horizontally centered on the word and clamped to the screen.
    private func popupOffset(in container: CGSize, origin: CGPoint) -> CGSize {
        let local = CGRect(x: wordRectGlobal.minX - origin.x, y: wordRectGlobal.minY - origin.y,
                           width: wordRectGlobal.width, height: wordRectGlobal.height)
        let w = popupSize.width, h = popupSize.height
        var x = local.midX - w / 2
        x = max(8, min(x, container.width - w - 8))
        var y = local.minY - h - 8
        if y < 8 { y = local.maxY + 8 }   // not enough room above → go below
        return CGSize(width: x, height: y)
    }
}

// MARK: - Definition popup

private struct DefinitionPopup: View {
    let word: String
    let def: WordDefinition?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(def?.word ?? word)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appText)
                if let r = def?.reading, r != (def?.word ?? word) {
                    Text(r)
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                }
            }
            if let def, !def.definitions.isEmpty {
                Text(def.definitions.prefix(4).joined(separator: "; "))
                    .font(.system(size: 14))
                    .foregroundColor(.appText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No dictionary entry found.")
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
                    .italic()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 280, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appSurfaceHigh)
                .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Question card

private struct QuestionCard: View {
    let number: Int
    let question: PracticeQuestion
    let accent: Color

    @State private var selected: Int?
    /// Display order for the choices.
    ///
    /// These questions are stored with the answer in the same slot nearly every
    /// time — 92% of the 1,250 of them sit at index 1 — so rendering them in
    /// file order let anyone score by always tapping the second option without
    /// reading a word. Grammar practice and the exam builder both already
    /// shuffle; this is the one path that didn't.
    ///
    /// Only the order changes. `choiceRow` still judges correctness by each
    /// choice's original index, so there's nothing to keep in sync.
    @State private var order: [Int] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(accent)
                FuriganaText(text: question.prompt, fontSize: 15, color: .appText, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(order, id: \.self) { idx in
                choiceRow(idx, question.choices[idx])
            }

            if selected != nil {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: selected == question.correctIndex ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundColor(selected == question.correctIndex ? .green : accent)
                        .font(.system(size: 13))
                    FuriganaText(text: question.explanation, fontSize: 13, color: .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
        // Shuffled once when the card appears, not in `body` — reshuffling on
        // every redraw would make the options jump around under the finger.
        .onAppear {
            if order.count != question.choices.count {
                order = Array(question.choices.indices).shuffled()
            }
        }
    }

    private func choiceRow(_ idx: Int, _ choice: String) -> some View {
        let isCorrect = idx == question.correctIndex
        let answered = selected != nil
        let isPicked = selected == idx
        let bg: Color = {
            guard answered else { return Color.appSurfaceHigh }
            if isCorrect { return Color.green.opacity(0.22) }
            if isPicked { return Color.red.opacity(0.20) }
            return Color.appSurfaceHigh
        }()
        let border: Color = {
            guard answered else { return Color.appHairline }
            if isCorrect { return .green }
            if isPicked { return .red }
            return Color.appHairline
        }()
        return Button {
            if selected == nil { selected = idx }
        } label: {
            HStack(spacing: 10) {
                Text(letters[idx])
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(answered && isCorrect ? .green : (answered && isPicked ? .red : accent))
                FuriganaText(text: choice, fontSize: 14, color: .appText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if answered && isCorrect {
                    Image(systemName: "checkmark").foregroundColor(.green).font(.system(size: 13, weight: .bold))
                } else if answered && isPicked {
                    Image(systemName: "xmark").foregroundColor(.red).font(.system(size: 13, weight: .bold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(selected != nil)
    }

    private let letters = ["A", "B", "C", "D", "E", "F"]
}
