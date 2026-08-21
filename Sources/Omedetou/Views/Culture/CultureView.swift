import SwiftUI

// MARK: - Model

struct CultureTopic: Codable, Identifiable {
    let id: String
    let icon: String        // SF Symbol name
    let title: String
    let subtitle: String
    /// Body text — supports "- " bullet lines and inline kanji[reading] furigana,
    /// rendered through ExplanationBody. Loaded from culture.json.
    let body: String
}

// MARK: - Content
//
// Japanese culture, customs, history, and manners — a chapter in the Textbook.
// The content lives in Resources/culture.json.

enum CultureContent {
    /// Chapter id used for favorites / completion progress in LessonsProgressStore.
    static let chapterId = "ch_culture"
    static var accent: Color { .themeTile(11) }

    static let topics: [CultureTopic] = load()

    private static func load() -> [CultureTopic] {
        Bundle.main.decodeJSON([CultureTopic].self, resource: "culture") ?? []
    }
}

// MARK: - Chapter view (list of culture points)

struct CultureChapterView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Customs, history, and manners — the traditions and everyday habits that shape Japanese life, and where they come from.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                ForEach(CultureContent.topics) { topic in
                    CulturePointCard(topic: topic)
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .standardNavBar("Culture")
    }
}

// MARK: - Culture point card (expandable, with favorite + completed toggles)

struct CulturePointCard: View {
    let topic: CultureTopic
    var accentColor: Color = CultureContent.accent

    @State private var isExpanded = false
    @ObservedObject private var store = LessonsProgressStore.shared

    private var chapterId: String { CultureContent.chapterId }
    private var isFavorite: Bool { store.isFavorite(chapterId: chapterId, pointId: topic.id) }
    private var isCompleted: Bool { store.isCompleted(chapterId: chapterId, pointId: topic.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 0) {
                Button {
                    FeedbackSounds.shared.play(.slide)
                    withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: topic.icon)
                            .font(.system(size: 18))
                            .foregroundColor(accentColor)
                            .frame(width: 26)
                            .frame(minHeight: 38)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.appText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(topic.subtitle)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                // Favorite star
                Button {
                    store.toggleFavorite(chapterId: chapterId, pointId: topic.id)
                    FeedbackSounds.shared.playFavorite(isFavorite)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 15))
                        .foregroundColor(isFavorite ? .yellow : Color.secondary.opacity(0.45))
                }
                .buttonStyle(.plain)

                // Completed circle-check
                Button {
                    FeedbackSounds.shared.play(.notification)
                    store.toggleCompleted(chapterId: chapterId, pointId: topic.id)
                } label: {
                    ZStack {
                        Circle()
                            .stroke(isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)

                // Chevron
                Button {
                    FeedbackSounds.shared.play(.slide)
                    withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Expanded body
            if isExpanded {
                Divider().padding(.horizontal, 14)
                ExplanationBody(text: topic.body, fontSize: 15, color: .appText, bulletColor: accentColor)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            }
        }
        .appCard()
    }
}

