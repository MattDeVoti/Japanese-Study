import SwiftUI
import UIKit
import CoreText
import NaturalLanguage

// MARK: - Public SwiftUI wrapper

/// Renders Japanese text with furigana (ruby annotations) above kanji using CoreText.
/// Accepts optional inline `kanji[reading]` markup — markup is stripped from display text
/// and the reading is applied as a ruby annotation above the kanji characters.
/// Falls back to automatic reading generation for plain (non-annotated) strings.
///
/// When `interactive` is true, a long-press reports the word under the finger and
/// its on-screen rect (in global coordinates) via `onWordSelect` — used by reading
/// passages for pop-up dictionary lookups.
/// Text that may or may not carry furigana markup.
///
/// Renders as ruby when the string contains `漢字[よみ]` and as ordinary text when
/// it doesn't — which is exactly the rule a quiz needs: a question *about* a
/// reading carries no markup (that's the thing being asked), so it stays plain,
/// while everything else gets its readings set above the kanji instead of in
/// brackets beside it.
struct JapaneseText: View {
    let text: String
    var fontSize: CGFloat = 17
    var color: Color = .appText
    var weight: UIFont.Weight = .regular
    var alignment: NSTextAlignment = .left

    /// The markup is `kanji[kana]`; a bare `[` in an English prompt shouldn't
    /// send it down the ruby path.
    private var hasFurigana: Bool {
        text.range(of: "[一-鿿㐀-䶿々〆〇ヶ]+\\[[぀-ゟ゠-ヿー]+\\]",
                   options: .regularExpression) != nil
    }

    var body: some View {
        if hasFurigana {
            FuriganaText(text: text, fontSize: fontSize, color: color,
                         weight: weight, alignment: alignment)
        } else {
            Text(text)
                .font(.system(size: fontSize, weight: Font.Weight(weight)))
                .foregroundColor(color)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .frame(maxWidth: .infinity,
                       alignment: alignment == .center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension Font.Weight {
    /// The two weight types don't bridge, and the handful of weights this app
    /// actually uses is small enough to map by hand.
    init(_ w: UIFont.Weight) {
        switch w {
        case .bold:      self = .bold
        case .semibold:  self = .semibold
        case .medium:    self = .medium
        case .light:     self = .light
        case .heavy:     self = .heavy
        case .black:     self = .black
        default:         self = .regular
        }
    }
}

struct FuriganaText: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 17
    var color: Color = .primary
    var weight: UIFont.Weight = .regular
    var alignment: NSTextAlignment = .left
    var interactive: Bool = false
    var onWordSelect: ((String, CGRect) -> Void)? = nil
    /// Draws a dashed writing guide under every rendered line. The rules come from
    /// CoreText's own line origins, so they track the text exactly — including when
    /// the Japanese text-size slider changes the line height.
    var lineRule: Color? = nil

    /// Extra leading between lines, as a multiple of the font size.
    ///
    /// Opt-in and zero by default, because this view renders everywhere — reading
    /// passages, vocab rows, cheat sheets — and they are tuned as they are. Lesson
    /// prose sets it: with no leading, a ruby annotation is drawn into the line
    /// above it, so furigana on a wrapped paragraph physically collides with the
    /// previous line. Space is what separates them.
    var extraLeading: CGFloat = 0

    /// Observed so changing the Japanese text size re-renders every instance —
    /// CoreText draws at a fixed point size and won't pick it up on its own.
    @ObservedObject private var textSettings = TextSizeSettings.shared

    private var scaledFontSize: CGFloat { fontSize * CGFloat(textSettings.scale) }

    func makeUIView(context: Context) -> FuriganaCanvas {
        FuriganaCanvas()
    }

    func updateUIView(_ canvas: FuriganaCanvas, context: Context) {
        canvas.onWordSelect = onWordSelect
        canvas.setInteractive(interactive)
        canvas.lineRuleColor = lineRule.map { UIColor($0) }
        canvas.configure(
            text: text,
            fontSize: scaledFontSize,
            color: UIColor(color),
            weight: weight,
            alignment: alignment,
            extraLeading: extraLeading
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FuriganaCanvas, context: Context) -> CGSize? {
        let w = (proposal.width.flatMap { $0 > 0 ? $0 : nil }) ?? UIScreen.main.bounds.width
        // Measure against the size we're about to draw at, not the unscaled one —
        // otherwise larger text is clipped by a height computed for the old size.
        uiView.lineRuleColor = lineRule.map { UIColor($0) }
        uiView.configure(text: text, fontSize: scaledFontSize, color: UIColor(color),
                         weight: weight, alignment: alignment, extraLeading: extraLeading)
        let h = uiView.preferredHeight(for: w)
        return CGSize(width: w, height: max(h, 1))
    }
}

// MARK: - CoreText drawing view

final class FuriganaCanvas: UIView {
    /// When set, a dashed rule is stroked under each line of text.
    var lineRuleColor: UIColor? { didSet { if oldValue != lineRuleColor { setNeedsDisplay() } } }
    private var rawText = ""        // original string (may contain [reading] markup)
    private var displayText = ""    // markup-stripped, what CoreText draws
    private var color: UIColor = .label
    private var fontSize: CGFloat = 17
    private var weight: UIFont.Weight = .regular
    private var alignment: NSTextAlignment = .left
    private var extraLeading: CGFloat = 0
    private var segments: [(range: NSRange, reading: String)] = []

    var onWordSelect: ((String, CGRect) -> Void)?
    private var longPress: UILongPressGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Interactivity (long-press word lookup)

    func setInteractive(_ on: Bool) {
        isUserInteractionEnabled = on
        if on && longPress == nil {
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            lp.minimumPressDuration = 0.28
            addGestureRecognizer(lp)
            longPress = lp
        }
        longPress?.isEnabled = on
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        if let (word, rect) = wordAndRect(at: gr.location(in: self)) {
            onWordSelect?(word, rect)
        }
    }

    /// Maps a touch point to the word beneath it and that word's rect in global
    /// (window) coordinates, using CoreText line geometry + NLTokenizer segmentation.
    private func wordAndRect(at point: CGPoint) -> (String, CGRect)? {
        guard !displayText.isEmpty, bounds.width > 0, bounds.height > 0 else { return nil }
        let attr = buildAttr(color: color)
        let setter = CTFramesetterCreateWithAttributedString(attr)
        let frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0),
                                             CGPath(rect: bounds, transform: nil), nil)
        let cfLines = CTFrameGetLines(frame)
        let lineCount = CFArrayGetCount(cfLines)
        guard lineCount > 0 else { return nil }
        var lines: [CTLine] = []
        for i in 0..<lineCount {
            lines.append(unsafeBitCast(CFArrayGetValueAtIndex(cfLines, i), to: CTLine.self))
        }
        var origins = [CGPoint](repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)

        // CoreText y grows upward from the bottom; the touch y grows downward from the top.
        let ctY = bounds.height - point.y
        var lineIdx = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (i, line) in lines.enumerated() {
            var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
            CTLineGetTypographicBounds(line, &asc, &desc, &lead)
            let oy = origins[i].y
            if ctY <= oy + asc && ctY >= oy - desc { lineIdx = i; bestDist = 0; break }
            let d = min(abs(ctY - (oy + asc)), abs(ctY - (oy - desc)))
            if d < bestDist { bestDist = d; lineIdx = i }
        }

        let line = lines[lineIdx]
        let ox = origins[lineIdx].x
        let oy = origins[lineIdx].y
        var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
        CTLineGetTypographicBounds(line, &asc, &desc, &lead)

        let idx = CTLineGetStringIndexForPosition(line, CGPoint(x: point.x - ox, y: 0))
        let ns = displayText as NSString
        guard idx != kCFNotFound, idx >= 0, idx < ns.length else { return nil }
        guard let baseRange = wordRange(in: displayText, utf16Index: idx) else { return nil }
        // Greedy longest dictionary match from the token's first character — rejoins
        // compounds the tokenizer split (図書 + 館 → 図書館, 自転 + 車 → 自転車).
        let range = longestDictionaryMatch(from: baseRange.location, in: ns, fallback: baseRange)
        let word = ns.substring(with: range)

        let startX = ox + CTLineGetOffsetForStringIndex(line, range.location, nil)
        let endX = ox + CTLineGetOffsetForStringIndex(line, range.location + range.length, nil)
        let uiTop = bounds.height - (oy + asc)
        let ruby = fontSize * 0.7   // clear the furigana sitting above the base text
        let rect = CGRect(x: min(startX, endX), y: uiTop - ruby,
                          width: abs(endX - startX), height: asc + desc + ruby)
        return (word, convert(rect, to: nil))
    }

    private func longestDictionaryMatch(from start: Int, in ns: NSString, fallback: NSRange) -> NSRange {
        // Forward from where the tokenizer began the word: rejoins compounds it
        // split (図書 + 館 → 図書館, 自転 + 車 → 自転車).
        if let r = greedyMatch(from: start, in: ns) { return r }

        // Nothing starts here, which usually means the press landed on the tail
        // of a word rather than its head. The tokenizer hands back inflectional
        // pieces as their own tokens — 食べた arrives as 食べ + た — so a press on
        // た searched forward from た and found nothing, which is most of what
        // "no dictionary entry found" was. Walk the start backward and take the
        // first word that actually covers the character under the finger.
        var s = start - 1
        while s >= max(0, start - 8) {
            // A word starting back here is only useful if it reaches the
            // character under the finger, so never ask the dictionary about the
            // shorter ones — they cannot win even if they match. That prunes
            // about a third of the candidates on this path, and this path is
            // where a press gets expensive.
            if let r = greedyMatch(from: s, in: ns, minLength: start - s + 1) { return r }
            s -= 1
        }
        return fallback
    }

    /// Longest entry the dictionary knows that begins exactly at `start`.
    private func greedyMatch(from start: Int, in ns: NSString, minLength: Int = 1) -> NSRange? {
        guard start >= 0, start < ns.length, minLength <= 12 else { return nil }
        var len = min(ns.length - start, 12)
        while len >= minLength {
            let cand = ns.substring(with: NSRange(location: start, length: len))
            if WordLookup.lookup(cand) != nil { return NSRange(location: start, length: len) }
            len -= 1
        }
        return nil
    }

    private func wordRange(in text: String, utf16Index: Int) -> NSRange? {
        let strIdx = String.Index(utf16Offset: utf16Index, in: text)
        guard strIdx < text.endIndex else { return nil }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let r = tokenizer.tokenRange(at: strIdx)
        guard !r.isEmpty else { return nil }
        let loc = r.lowerBound.utf16Offset(in: text)
        let len = r.upperBound.utf16Offset(in: text) - loc
        guard len > 0 else { return nil }
        return NSRange(location: loc, length: len)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    func configure(
        text: String,
        fontSize: CGFloat,
        color: UIColor,
        weight: UIFont.Weight,
        alignment: NSTextAlignment,
        extraLeading: CGFloat = 0
    ) {
        let contentChanged = text != rawText || fontSize != self.fontSize || weight != self.weight
        self.rawText = text
        self.color = color
        self.fontSize = fontSize
        self.weight = weight
        self.alignment = alignment
        self.extraLeading = extraLeading
        if contentChanged {
            (displayText, segments) = FuriganaAnnotator.process(text)
            // CoreText drawing is invisible to VoiceOver — without this the view is
            // an empty rectangle to anyone using a screen reader. The reading is
            // spoken rather than the kanji, since that's what the ruby is telling a
            // sighted reader too.
            isAccessibilityElement = !displayText.isEmpty
            accessibilityTraits = .staticText
            accessibilityLabel = FuriganaAnnotator.spokenText(text)
            accessibilityValue = displayText == accessibilityLabel ? nil : displayText
            accessibilityLanguage = "ja-JP"
        }
        setNeedsDisplay()
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        guard !displayText.isEmpty, width > 0 else { return 0 }
        let attr = buildAttr(color: color)
        let setter = CTFramesetterCreateWithAttributedString(attr)
        let fit = CTFramesetterSuggestFrameSizeWithConstraints(
            setter, CFRangeMake(0, 0), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), nil
        )
        guard fit.height.isFinite else { return 0 }
        return ceil(fit.height) + (lineRuleColor != nil ? Self.ruleInset : 0)
    }

    /// Room under the final line for its own rule.
    static let ruleInset: CGFloat = 5

    override func draw(_ rect: CGRect) {
        guard !displayText.isEmpty, rect.width > 0, rect.height > 0,
              let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.textMatrix = .identity
        ctx.translateBy(x: 0, y: rect.height)
        ctx.scaleBy(x: 1, y: -1)
        let resolved = color.resolvedColor(with: traitCollection)
        let attr = buildAttr(color: resolved)
        let setter = CTFramesetterCreateWithAttributedString(attr)
        let frame = CTFramesetterCreateFrame(
            setter, CFRangeMake(0, 0), CGPath(rect: rect, transform: nil), nil
        )
        if let ruleColor = lineRuleColor {
            drawLineRules(frame: frame, in: rect, ctx: ctx, color: ruleColor)
        }
        CTFrameDraw(frame, ctx)
    }

    /// One dashed rule per rendered line, sitting just under that line's descent.
    /// Drawn before the glyphs so a descender crosses the rule rather than being
    /// cut by it, which is how ruled paper actually looks.
    private func drawLineRules(frame: CTFrame, in rect: CGRect,
                               ctx: CGContext, color: UIColor) {
        guard let lines = CTFrameGetLines(frame) as? [CTLine], !lines.isEmpty else { return }
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)

        ctx.saveGState()
        ctx.setStrokeColor(color.resolvedColor(with: traitCollection).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [5, 4])
        for (i, line) in lines.enumerated() {
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            let y = (origins[i].y - descent - 2).rounded()
            guard y >= 0, y < rect.height else { continue }
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: rect.width, y: y))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func buildAttr(color: UIColor) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let rubyFont = UIFont.systemFont(ofSize: max(floor(fontSize * 0.55), 7), weight: weight)
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = alignment
        // Scaled off the font rather than a fixed number of points, so it holds
        // its proportions when the Japanese text-size slider moves.
        paraStyle.lineSpacing = fontSize * extraLeading
        let result = NSMutableAttributedString(string: displayText, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paraStyle
        ])
        for seg in segments {
            let annotation = CTRubyAnnotationCreateWithAttributes(
                .auto, .auto, .before, seg.reading as CFString,
                [kCTFontAttributeName: rubyFont] as CFDictionary
            )
            result.addAttribute(
                kCTRubyAnnotationAttributeName as NSAttributedString.Key,
                value: annotation,
                range: seg.range
            )
        }
        return result
    }
}

// MARK: - Annotation helper

enum FuriganaAnnotator {
    /// Parses markup and returns (display text, ruby segments).
    /// If the string contains `kanji[reading]` markup it uses the explicit readings.
    /// Plain strings (no markup) are returned as-is with no ruby annotations.
    static func process(_ text: String) -> (displayText: String, segments: [(range: NSRange, reading: String)]) {
        if text.contains("[") {
            return parseMarkup(text)
        }
        return (text, [])
    }

    // MARK: Markup parser — handles kanji[reading] inline format

    private static func parseMarkup(_ raw: String) -> (String, [(NSRange, String)]) {
        var display = ""
        var segs: [(NSRange, String)] = []
        var pending = ""   // characters accumulated since last annotation
        var i = raw.startIndex

        while i < raw.endIndex {
            let c = raw[i]
            // Treat `[...]` as a furigana reading ONLY when the content is all kana
            // and it directly follows a kanji run. Otherwise it's an English
            // placeholder like [person] / [X] — keep it literal (brackets included).
            if c == "[", let closeIdx = raw[raw.index(after: i)...].firstIndex(of: "]"),
               case let reading = String(raw[raw.index(after: i)..<closeIdx]),
               isAllKana(reading), !trailingKanji(of: pending).isEmpty {
                let base = trailingKanji(of: pending)
                let prefix = String(pending.dropLast(base.count))
                display += prefix
                let loc = (display as NSString).length
                display += base
                let len = (display as NSString).length - loc
                segs.append((NSRange(location: loc, length: len), reading))
                pending = ""
                i = raw.index(after: closeIdx)
            } else {
                pending.append(c)
                i = raw.index(after: i)
            }
        }
        display += pending
        return (display, segs)
    }

    private static func trailingKanji(of s: String) -> String {
        var result = ""
        for scalar in s.unicodeScalars.reversed() {
            guard isKanji(scalar) else { break }
            result = String(scalar) + result
        }
        return result
    }

    // MARK: Helpers

    private static func isKanji(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) ||
        (0x3400...0x4DBF).contains(scalar.value) ||
        (0xF900...0xFAFF).contains(scalar.value) ||
        scalar.value == 0x3005 ||   // 々 iteration mark (人々, 時々, 様々)
        scalar.value == 0x3007 ||   // 〇 ideographic zero — a kanji numeral, as in
                                    // 一九七〇年代. Excluding it truncated the base of
                                    // any span containing it, so the whole reading
                                    // piled onto the two characters after the 〇.
        scalar.value == 0x30F6 ||   // ヶ (as in 鬼ヶ島)
        scalar.value == 0x30F5      // ヵ
    }

    private static func isKana(_ scalar: Unicode.Scalar) -> Bool {
        (0x3040...0x309F).contains(scalar.value) ||   // hiragana
        (0x30A0...0x30FF).contains(scalar.value)      // katakana (incl. ー)
    }

    /// True when the string is non-empty and every character is kana — i.e. a
    /// real reading, not an English grammatical placeholder such as [person].
    private static func isAllKana(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy(isKana)
    }

    // MARK: - Derived forms

    /// The string as drawn: markup removed, kanji intact. Also what VoiceOver and
    /// plain `Text` should use, since raw markup would leak literal brackets.
    static func plainText(_ text: String) -> String {
        process(text).displayText
    }

    /// The string as *pronounced*: every annotated kanji run replaced by its
    /// reading. This is what makes speech synthesis say にじ for 二時 instead of
    /// guessing — the app's curated furigana becomes the pronunciation guide.
    /// Unannotated kanji are left for the synthesiser to resolve on its own.
    static func spokenText(_ text: String) -> String {
        let (display, segments) = process(text)
        guard !segments.isEmpty else { return display }

        let ns = display as NSString
        var result = ""
        var cursor = 0
        for seg in segments.sorted(by: { $0.range.location < $1.range.location }) {
            guard seg.range.location >= cursor else { continue }   // ignore overlaps
            if seg.range.location > cursor {
                result += ns.substring(with: NSRange(location: cursor,
                                                     length: seg.range.location - cursor))
            }
            result += seg.reading
            cursor = seg.range.location + seg.range.length
        }
        if cursor < ns.length { result += ns.substring(from: cursor) }
        return result
    }
}

// MARK: - Explanation body (paragraphs + bulleted lists)

/// Renders a grammar explanation string that may mix prose paragraphs with
/// bulleted lists. Convention: a line beginning with "- " is a bullet item;
/// a run of consecutive bullet lines becomes one list. Blank lines (\n\n)
/// separate paragraphs. Each paragraph and bullet renders with furigana.
struct ExplanationBody: View {
    let text: String
    var fontSize: CGFloat = 14
    var color: Color = .appText
    var bulletColor: Color = .secondary
    /// Passed to every paragraph and bullet — see `FuriganaText.extraLeading`.
    ///
    /// Zero by default: the particle cards and the culture articles render their
    /// prose through here too, and they are not what this pass was asked to
    /// change. The grammar card opts in.
    var extraLeading: CGFloat = 0

    private enum Block: Identifiable {
        case paragraph(String)
        case bullets([String])
        var id: String {
            switch self {
            case .paragraph(let s): return "p:" + s
            case .bullets(let items): return "b:" + items.joined(separator: "|")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                switch block {
                case .paragraph(let s):
                    FuriganaText(text: s, fontSize: fontSize, color: color,
                                 extraLeading: extraLeading)
                        .fixedSize(horizontal: false, vertical: true)
                case .bullets(let items):
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.system(size: fontSize, weight: .bold))
                                    .foregroundColor(bulletColor)
                                FuriganaText(text: item, fontSize: fontSize, color: color,
                                             extraLeading: extraLeading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.leading, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blocks: [Block] {
        var result: [Block] = []
        // Paragraphs are separated by a blank line. Within a paragraph, a run of
        // "- "/"• "/"* " lines becomes a bulleted list; other lines are kept as
        // tight lines (joined with \n, so single line-breaks are preserved and
        // never merged into a run-on).
        for paragraph in text.components(separatedBy: "\n\n") {
            var buf: [String] = []
            var bullets: [String] = []
            func flushBuf() {
                let s = buf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { result.append(.paragraph(s)) }
                buf = []
            }
            func flushBullets() {
                if !bullets.isEmpty { result.append(.bullets(bullets)); bullets = [] }
            }
            for raw in paragraph.components(separatedBy: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if let item = Self.bulletItem(line) {
                    flushBuf(); bullets.append(item)
                } else if line.isEmpty {
                    continue
                } else {
                    flushBullets(); buf.append(line)
                }
            }
            flushBuf(); flushBullets()
        }
        return result
    }

    /// If a line is a bullet ("- ", "• ", or "* " prefix), returns its content.
    static func bulletItem(_ line: String) -> String? {
        for marker in ["- ", "• ", "* "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
