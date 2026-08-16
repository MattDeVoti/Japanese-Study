import SwiftUI

// MARK: - Universal study-weight settings
//
// One setting, shared by EVERY flashcard deck (kanji, vocab, grammar) and by
// every place the user can change it (each deck's options menu, a chapter's
// locked-flashcard menu, and the Home options sheet). Changing it anywhere
// changes it everywhere. Persisted so it survives app restarts.
//
// Default: Standard (even shuffle, checked cards hidden).
//
// The two modes differ in BOTH ordering and which cards are in play:
//   • .none      — even random order; checked-off (Confident) cards are hidden.
//   • .needsWork — biased toward high Needs-Work counts; EVERY card stays in the
//                  mix, including checked-off ones (they just carry base weight).
//
// Smart Study, when on, drives `mode` automatically — see SmartStudyEngine. The
// value still lives here, so every deck follows it exactly as if it had been set
// by hand. That is deliberate but worth knowing: while a vocab deck is running
// the programme, `mode` changes every few cards, and the kanji and grammar decks
// pick up whatever it was left on.

final class StudyWeightSettings: ObservableObject {
    static let shared = StudyWeightSettings()

    private static let modeKey = "StudyWeightMode"
    private static let strengthKey = "StudyWeightStrength"
    private static let smartKey = "StudyWeightSmartStudy"

    @Published var mode: WeightMode = .none {
        didSet { if didLoad { persist() } }
    }
    @Published var strength: Double = 0.2 {
        didSet { if didLoad { persist() } }
    }
    /// Hands `mode` to the Smart Study programme — see `SmartStudyEngine`.
    ///
    /// While it's on, `mode` is rewritten on every card the vocab decks deal, so
    /// the manual switch stays visible but disabled: the two would otherwise
    /// fight over the same value, with the programme always winning. Because
    /// `mode` is app-wide, the kanji and grammar decks inherit whichever side of
    /// the cycle the vocab deck last reached.
    ///
    /// Anything reading `mode` directly should keep this in mind — under Smart
    /// Study it is a fast-moving value, not a setting.
    @Published var smartStudy: Bool = false {
        didSet { if didLoad { persist() } }
    }

    /// Checked-off cards are dropped from the lineup only in Standard mode.
    /// In Priority Study every card stays in rotation.
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
        smartStudy = defaults.bool(forKey: Self.smartKey)
        didLoad = true
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: Self.modeKey)
        defaults.set(strength, forKey: Self.strengthKey)
        defaults.set(smartStudy, forKey: Self.smartKey)
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

// MARK: - Shared copy
//
// One source for the wording, so the four places the mode can be changed can't
// drift apart.

enum StudyPriorityCopy {
    static let smartTitle = "Smart Study"

    static let smartExplanation =
        "Picks your chapter and switches between the two modes for you. It works "
        + "through a chapter in Standard, then moves you on and starts mixing "
        + "older words back in — often at first, less as they stick. Marking a "
        + "resurfaced word Needs Work puts it back in the rotation."

    static let smartLockNote =
        "Switch Smart Study off to choose a mode yourself."

    static let smartOwnsPool =
        "Smart Study picked this chapter, but you can choose your own. That "
        + "resets its countdown, and once it has started mixing in older words "
        + "it holds off for 50 cards."
}

// MARK: - Reusable priority controls
//
// Drop this into any options sheet/menu. It binds directly to the shared
// singleton, so all instances stay in lockstep.

struct WeightPrioritySection: View {
    @ObservedObject private var settings = StudyWeightSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $settings.smartStudy) {
                Text(StudyPriorityCopy.smartTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appText)
            }

            Text(StudyPriorityCopy.smartExplanation)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Stays on screen while Smart Study runs so it's clear what the
            // programme is doing, but can't be touched — the two would fight
            // over the same setting.
            Picker("", selection: $settings.mode) {
                ForEach(WeightMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(settings.smartStudy)
            .opacity(settings.smartStudy ? 0.6 : 1)

            if settings.smartStudy {
                Text(StudyPriorityCopy.smartLockNote)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Both explanations, always — the point of the text is to help
            // choose, which means describing the mode you're not in.
            VStack(alignment: .leading, spacing: 6) {
                ForEach(WeightMode.allCases, id: \.self) { mode in
                    modeExplanation(mode)
                }
            }

            // Held on screen whenever Smart Study is running: the programme
            // moves in and out of Priority Study constantly, and a control that
            // appeared and vanished with it would be unusable.
            if settings.mode == .needsWork || settings.smartStudy {
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
        }
    }

    private func modeExplanation(_ mode: WeightMode) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(mode.displayName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(settings.mode == mode && !settings.smartStudy
                                 ? .appText : .secondary)
            Text(mode.explanation)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Menu variant
//
// The two chapter-locked decks put these controls in a `Menu`, which can't hold
// a slider or wrapped body text. Same settings, same wording, trimmed to what a
// menu can render.

struct WeightPriorityMenuItems: View {
    @ObservedObject private var settings = StudyWeightSettings.shared

    var body: some View {
        Toggle(isOn: $settings.smartStudy) {
            Label(StudyPriorityCopy.smartTitle, systemImage: "wand.and.stars")
        }
        Picker("Priority", selection: $settings.mode) {
            ForEach(WeightMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .disabled(settings.smartStudy)
    }
}
