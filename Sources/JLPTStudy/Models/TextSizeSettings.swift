import SwiftUI

// Japanese text size.
//
// `FuriganaText` draws with CoreText at an explicit point size, so it is immune to
// Dynamic Type — and its ruby is set at 55% of the base, which makes furigana the
// smallest text in the app by some margin. Anyone who needs larger text needs it
// most on exactly those readings, so the app carries its own scale factor and
// applies it wherever Japanese is drawn.

final class TextSizeSettings: ObservableObject {
    static let shared = TextSizeSettings()

    private static let key = "JapaneseTextScale"

    @Published var scale: Double {
        didSet { if loaded { UserDefaults.standard.set(scale, forKey: Self.key) } }
    }
    private var loaded = false

    private init() {
        scale = UserDefaults.standard.object(forKey: Self.key) as? Double ?? 1.0
        loaded = true
    }

    /// Clamped so layouts that reserve a fixed height can still cope.
    static let range: ClosedRange<Double> = 0.85...1.6

    var label: String {
        switch scale {
        case ..<0.95:  return "Small"
        case ..<1.05:  return "Default"
        case ..<1.25:  return "Large"
        case ..<1.45:  return "Larger"
        default:       return "Largest"
        }
    }
}
