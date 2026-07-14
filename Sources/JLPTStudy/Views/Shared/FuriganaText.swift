import SwiftUI
import UIKit
import CoreText

// MARK: - Public SwiftUI wrapper

/// Renders Japanese text with furigana (ruby annotations) above kanji using CoreText.
/// Accepts optional inline `kanji[reading]` markup — markup is stripped from display text
/// and the reading is applied as a ruby annotation above the kanji characters.
/// Falls back to automatic reading generation for plain (non-annotated) strings.
struct FuriganaText: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 17
    var color: Color = .primary
    var weight: UIFont.Weight = .regular
    var alignment: NSTextAlignment = .left

    func makeUIView(context: Context) -> FuriganaCanvas {
        FuriganaCanvas()
    }

    func updateUIView(_ canvas: FuriganaCanvas, context: Context) {
        canvas.configure(
            text: text,
            fontSize: fontSize,
            color: UIColor(color),
            weight: weight,
            alignment: alignment
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FuriganaCanvas, context: Context) -> CGSize? {
        let w = (proposal.width.flatMap { $0 > 0 ? $0 : nil }) ?? UIScreen.main.bounds.width
        let h = uiView.preferredHeight(for: w)
        return CGSize(width: w, height: max(h, 1))
    }
}

// MARK: - CoreText drawing view

final class FuriganaCanvas: UIView {
    private var rawText = ""        // original string (may contain [reading] markup)
    private var displayText = ""    // markup-stripped, what CoreText draws
    private var color: UIColor = .label
    private var fontSize: CGFloat = 17
    private var weight: UIFont.Weight = .regular
    private var alignment: NSTextAlignment = .left
    private var segments: [(range: NSRange, reading: String)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    func configure(
        text: String,
        fontSize: CGFloat,
        color: UIColor,
        weight: UIFont.Weight,
        alignment: NSTextAlignment
    ) {
        let contentChanged = text != rawText || fontSize != self.fontSize || weight != self.weight
        self.rawText = text
        self.color = color
        self.fontSize = fontSize
        self.weight = weight
        self.alignment = alignment
        if contentChanged {
            (displayText, segments) = FuriganaAnnotator.process(text)
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
        return ceil(fit.height)
    }

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
        CTFrameDraw(frame, ctx)
    }

    private func buildAttr(color: UIColor) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let rubyFont = UIFont.systemFont(ofSize: max(floor(fontSize * 0.55), 7), weight: weight)
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = alignment
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
            if c == "[", let closeIdx = raw[raw.index(after: i)...].firstIndex(of: "]") {
                let reading = String(raw[raw.index(after: i)..<closeIdx])
                // The ruby base is the trailing kanji run in pending.
                let base = trailingKanji(of: pending)
                let prefix = String(pending.dropLast(base.count))
                display += prefix
                let loc = (display as NSString).length
                display += base
                let len = (display as NSString).length - loc
                if !base.isEmpty && !reading.isEmpty {
                    segs.append((NSRange(location: loc, length: len), reading))
                }
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
        (0xF900...0xFAFF).contains(scalar.value)
    }
}
