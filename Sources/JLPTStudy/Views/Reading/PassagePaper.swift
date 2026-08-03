import SwiftUI

// Each passage is dressed as the kind of document it actually is — stationery for
// a letter, a ruled page for a diary, newsprint for an article, speech bubbles for
// a dialogue. It isn't decoration for its own sake: register in Japanese is tied
// to the medium, and seeing 拝啓 on notepaper or 〜だそうだ in a column is a cue
// about why the language is pitched the way it is.
//
// Rules sit *between* paragraphs rather than behind the text. FuriganaText lays out
// through CoreText and its line height moves with the reading-size slider, so ruled
// lines drawn behind it would drift out of alignment the moment that slider moves.

enum PassageStyle {
    case letter, diary, article, dialogue, story

    init(rawType: String) {
        switch rawType {
        case "letter", "email": self = .letter
        case "diary":           self = .diary
        case "article":         self = .article
        case "dialogue":        self = .dialogue
        default:                self = .story
        }
    }

    /// Shown as a small caption on the paper itself.
    var caption: String {
        switch self {
        case .letter:   return "手紙 · LETTER"
        case .diary:    return "日記 · DIARY"
        case .article:  return "記事 · ARTICLE"
        case .dialogue: return "会話 · DIALOGUE"
        case .story:    return "物語 · STORY"
        }
    }

    var icon: String {
        switch self {
        case .letter:   return "envelope.fill"
        case .diary:    return "book.closed.fill"
        case .article:  return "newspaper.fill"
        case .dialogue: return "bubble.left.and.bubble.right.fill"
        case .story:    return "text.book.closed.fill"
        }
    }

    /// Newsprint is squared off; everything else is a soft page.
    var cornerRadius: CGFloat { self == .article ? 3 : 14 }
}

// MARK: - The paper

struct PassagePaper<Content: View>: View {
    let style: PassageStyle
    let accent: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content()
        }
        .padding(style == .diary ? EdgeInsets(top: 14, leading: 26, bottom: 16, trailing: 16)
                                 : EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(paper)
        .overlay(alignment: .leading) { marginRule }
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: style.icon)
                .font(.system(size: 10, weight: .bold))
            Text(style.caption)
                .font(.system(size: 10, weight: .black))
                .tracking(1.1)
            Spacer(minLength: 0)
        }
        .foregroundColor(accent.opacity(0.75))
        .padding(.bottom, style == .article ? 6 : 0)
        // A masthead needs a rule under it; the others don't.
        .overlay(alignment: .bottom) {
            if style == .article {
                VStack(spacing: 2) {
                    Rectangle().fill(accent.opacity(0.55)).frame(height: 2)
                    Rectangle().fill(accent.opacity(0.3)).frame(height: 0.5)
                }
            }
        }
    }

    private var paper: some View {
        ZStack {
            Color.appSurface
            // A warm wash on the handwritten formats, a cool flat one on newsprint.
            switch style {
            case .letter, .story:
                LinearGradient(colors: [Color.orange.opacity(0.05), Color.clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            case .diary:
                LinearGradient(colors: [accent.opacity(0.045), Color.clear],
                               startPoint: .top, endPoint: .bottom)
            case .article, .dialogue:
                Color.clear
            }
        }
    }

    /// The red margin line of a notebook page.
    @ViewBuilder private var marginRule: some View {
        if style == .diary {
            Rectangle()
                .fill(Color(hex: "E0574F").opacity(0.35))
                .frame(width: 1)
                .padding(.leading, 16)
        }
    }

    @ViewBuilder private var border: some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        switch style {
        case .letter:
            // Stationery edge.
            shape.strokeBorder(accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        case .article:
            shape.strokeBorder(Color.appText.opacity(0.35), lineWidth: 1)
        default:
            shape.strokeBorder(Color.appHairline, lineWidth: 1)
        }
    }
}

// MARK: - Paragraph rules

/// The line drawn under a paragraph. Dashed for a letter (writing guides), solid
/// and faint for a diary, a thin column rule for an article, nothing for prose.
struct ParagraphRule: View {
    let style: PassageStyle
    let accent: Color

    var body: some View {
        switch style {
        case .letter:
            // A single stroked path, not a stroked Rectangle — the latter draws all
            // four edges, and at 1pt tall the dashes close up into a solid line.
            HorizontalLine()
                .stroke(accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .frame(height: 1)
        case .diary:
            Rectangle().fill(Color.appText.opacity(0.10)).frame(height: 1)
        case .article:
            Rectangle().fill(Color.appText.opacity(0.14)).frame(height: 0.5)
        case .dialogue, .story:
            EmptyView()
        }
    }
}

/// One horizontal line across the middle of its rect.
private struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
