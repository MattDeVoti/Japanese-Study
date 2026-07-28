import SwiftUI

// MARK: - Universal study-weight settings
//
// One setting, shared by EVERY flashcard deck (kanji, vocab, grammar) and by
// every place the user can change it (each deck's options menu, a chapter's
// locked-flashcard menu, and the Home options sheet). Changing it anywhere
// changes it everywhere. Persisted so it survives app restarts.
//
// Default: No Priority (even shuffle, checked cards hidden).
//
// The two modes differ in BOTH ordering and which cards are in play:
//   • .none      — even random order; checked-off (Confident) cards are hidden.
//   • .needsWork — biased toward high Needs-Work counts; EVERY card stays in the
//                  mix, including checked-off ones (they just carry base weight).

final class StudyWeightSettings: ObservableObject {
    static let shared = StudyWeightSettings()

    private static let modeKey = "StudyWeightMode"
    private static let strengthKey = "StudyWeightStrength"

    @Published var mode: WeightMode = .none {
        didSet { if didLoad { persist() } }
    }
    @Published var strength: Double = 0.2 {
        didSet { if didLoad { persist() } }
    }

    /// Checked-off cards are dropped from the lineup only in No-Priority mode.
    /// In Needs-Work mode every card stays in rotation.
    var filtersOutCheckedCards: Bool { mode == .none }

    private var didLoad = false

    private init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Self.modeKey),
           let saved = WeightMode(rawValue: raw) {
            mode = saved
        }
        if defaults.object(forKey: Self.strengthKey) != nil {
            strength = defaults.double(forKey: Self.strengthKey)
        }
        didLoad = true
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: Self.modeKey)
        defaults.set(strength, forKey: Self.strengthKey)
    }
}

extension StudyWeightSettings {
    /// The one weighted-random pick shared by every flashcard deck. With
    /// prioritization on, each item's weight is `1 + needsWork·5·strength`;
    /// otherwise it's a plain random choice.
    func pick<T>(_ items: [T], needsWork: (T) -> Int) -> T? {
        guard !items.isEmpty else { return nil }
        guard mode == .needsWork, strength > 0 else { return items.randomElement() }
        let weights = items.map { 1.0 + Double(needsWork($0)) * 5.0 * strength }
        var r = Double.random(in: 0..<weights.reduce(0, +))
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return items[i] }
        }
        return items.last
    }
}

// MARK: - Reusable priority controls
//
// Drop this into any options sheet/menu. It binds directly to the shared
// singleton, so all instances stay in lockstep.

struct WeightPrioritySection: View {
    @ObservedObject private var settings = StudyWeightSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $settings.mode) {
                Text("No Priority").tag(WeightMode.none)
                Text("Prioritize Needs Work").tag(WeightMode.needsWork)
            }
            .pickerStyle(.segmented)

            if settings.mode == .needsWork {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Priority Level")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appText)
                        Spacer()
                        Text("\(Int((settings.strength * 100).rounded()))%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.strength, in: 0.05...1.0)
                        .tint(.orange)
                }
            }

            Text(hint)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hint: String {
        switch settings.mode {
        case .none:
            return "Even shuffle, and cards you’ve checked off (Confident) are hidden."
        case .needsWork:
            return "Every card stays in the mix — including checked-off ones — but cards you’ve marked “Needs Work” show up more often. Higher priority means they repeat more."
        }
    }
}
