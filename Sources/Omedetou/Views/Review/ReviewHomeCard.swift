import SwiftUI

// The home screen's review bar. Deliberately self-hiding: with no schedule and
// nothing studied yet there is nothing useful to say, so it takes up no space and
// the tile layout stays exactly as designed.

struct ReviewHomeCard: View {
    @EnvironmentObject private var cardStore: CardStore
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var srs = SRSStore.shared

    // Observed so the bar appears the moment something is checked off or graded.
    @ObservedObject private var vocabFilter = VocabFlashcardsFilter.shared
    @ObservedObject private var lessonProgress = LessonsProgressStore.shared

    @State private var showSetup = false

    /// Derived on each render rather than cached in @State. It was cached and
    /// loaded from `.onAppear`, which deadlocked: with nothing loaded the card
    /// renders `EmptyView`, and SwiftUI never fires `onAppear` on an empty view —
    /// so the count stayed 0 and the card stayed invisible forever. These are
    /// three in-memory set reads, so recomputing is cheap.
    private var studiedCount: Int {
        SRSCatalogue.studiedItems(cardStore: cardStore).count
    }

    private enum State_ { case due(Int), caughtUp, setup(Int), hidden }

    /// Reviews are a tool for passing tests, not a goal of their own, so this bar
    /// only appears when there is something to actually do. An idle "nothing to
    /// practise" is a status with no action attached — it belongs on the Study
    /// tile, which shows it permanently, not in prime space under the test bar.
    private var state: State_ {
        let due = srs.dueCount()
        if srs.enrolledCount == 0 {
            return studiedCount > 0 ? .setup(studiedCount) : .hidden
        }
        // A finished round takes the bar away for an hour. Same reasoning as the
        // rest of this card: with nothing to do right now it shouldn't occupy
        // prime space, and an hour's wait is not an action.
        guard srs.reviewAvailable() else { return .hidden }
        return due > 0 ? .due(due) : .hidden
    }

    var body: some View {
        _ = themeManager.current
        let accent = Color.readableOnPage(.appAccent)

        return Group {
            switch state {
            case .hidden:
                EmptyView()
            case .setup(let n):
                Button { showSetup = true } label: {
                    bar(accent: accent, icon: "sparkles",
                        title: "Get started",
                        detail: "\(n) studied item\(n == 1 ? "" : "s")")
                }
                .buttonStyle(.plain)
            case .due:
                NavigationLink {
                    ReviewSessionView()
                } label: {
                    bar(accent: accent, icon: "bolt.fill",
                        title: "Quick practice",
                        detail: dueBreakdown)
                }
                .buttonStyle(.plain)
            case .caughtUp:
                EmptyView()
            }
        }
        .sheet(isPresented: $showSetup) {
            ReviewSetupView()
        }
    }

    private var dueBreakdown: String {
        SRSItemKind.allCases
            .map { ($0, srs.dueCount(kind: $0)) }
            .filter { $0.1 > 0 }
            .map { "\($0.1) \($0.0.label.lowercased())" }
            .joined(separator: " · ")
    }

    /// Slimmer and quieter than the test bar above it: single hairline instead of
    /// the double ring, smaller type, and an explicit REVIEWS tag so it can never
    /// be mistaken for the graded track.
    private func bar(accent: Color, icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(accent.opacity(0.3), lineWidth: 2)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent)
            }
            .frame(width: 26, height: 26)

            Text("REVIEWS")
                .font(.system(size: 9, weight: .black))
                .tracking(0.7)
                .foregroundColor(accent.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(accent.opacity(0.16)))

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(accent)
                .lineLimit(1)

            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(accent.opacity(0.65))
                    .lineLimit(1)
                    .layoutPriority(-1)
            }

            Spacer(minLength: 2)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accent.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.appBackgroundEnd.opacity(0.55)))
        .background(Capsule().fill(accent.opacity(0.10)))
        .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - Setup

/// Offers to convert everything already studied into a schedule, fanned out so
/// the first week isn't a wall of cards.
struct ReviewSetupView: View {
    @EnvironmentObject private var cardStore: CardStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var srs = SRSStore.shared

    @State private var breakdown: [SRSItemKind: Int] = [:]
    @State private var fanOut = 14

    private var total: Int { breakdown.values.reduce(0, +) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Daily reviews")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.appText)

                        Text("Spaced repetition schedules each item for the moment you're about to forget it, so a few minutes a day holds far more than long cramming sessions.\n\nYou've already worked through \(total) item\(total == 1 ? "" : "s"). These can seed your schedule now, spread over the next \(fanOut) days so you don't get everything at once.")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 8) {
                            ForEach(SRSItemKind.allCases, id: \.self) { kind in
                                let n = breakdown[kind] ?? 0
                                HStack {
                                    Circle().fill(kind.color).frame(width: 8, height: 8)
                                    Text(kind.label)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.appText)
                                    Spacer()
                                    Text("\(n)")
                                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                                        .foregroundColor(n > 0 ? kind.color : .appTextSecondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.appSurface))
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Spread over")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.appText)
                                Spacer()
                                Text("\(fanOut) days  ·  ~\(perDay)/day")
                                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                                    .foregroundColor(.appTextSecondary)
                            }
                            Slider(value: Binding(
                                get: { Double(fanOut) },
                                set: { fanOut = Int($0) }
                            ), in: 3...45, step: 1)
                            .tint(.appAccent)
                        }

                        AccentActionButton(title: total > 0 ? "Start reviewing" : "Close",
                                           icon: total > 0 ? "bolt.fill" : nil) {
                            if total > 0 {
                                srs.enroll(SRSCatalogue.studiedItems(cardStore: cardStore),
                                           fanOutDays: fanOut)
                            }
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)

                        Text("Anything you study from now on joins the schedule automatically.")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { breakdown = SRSCatalogue.studiedBreakdown(cardStore: cardStore) }
    }

    private var perDay: Int {
        max(total / max(fanOut, 1), total > 0 ? 1 : 0)
    }
}
