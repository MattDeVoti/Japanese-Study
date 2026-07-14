import SwiftUI

struct KanaCharacterCard: View {
    let point: GrammarPoint
    let chapterId: String
    let accentColor: Color

    @State private var isExpanded = false
    @ObservedObject private var store = LessonsProgressStore.shared

    private var isFavorite: Bool { store.isFavorite(chapterId: chapterId, pointId: point.id) }
    private var isCompleted: Bool { store.isCompleted(chapterId: chapterId, pointId: point.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 14) {

                    // Large character
                    Text(point.name)
                        .font(.system(size: 46, weight: .medium))
                        .foregroundColor(accentColor)
                        .frame(width: 58, alignment: .center)
                        .minimumScaleFactor(0.6)

                    // Romaji + pronunciation hint
                    VStack(alignment: .leading, spacing: 3) {
                        Text(point.formation)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.appText)
                        Text(point.shortDescription)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    // Favorite + complete + chevron
                    HStack(spacing: 10) {
                        Button {
                            store.toggleFavorite(chapterId: chapterId, pointId: point.id)
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 15))
                                .foregroundColor(isFavorite ? .yellow : Color.secondary.opacity(0.45))
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.toggleCompleted(chapterId: chapterId, pointId: point.id)
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

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 16) {

                    // Explanation
                    Text(point.explanation)
                        .font(.system(size: 14))
                        .foregroundColor(.appText)
                        .fixedSize(horizontal: false, vertical: true)

                    // Tips / notes
                    if !point.rules.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel(title: "Tips", icon: "lightbulb")
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(point.rules, id: \.self) { rule in
                                    HStack(alignment: .top, spacing: 7) {
                                        Text("•")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(accentColor)
                                        Text(rule)
                                            .font(.system(size: 13))
                                            .foregroundColor(.appText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    // Example words
                    if !point.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Example Words", icon: "text.bubble")
                            VStack(spacing: 0) {
                                ForEach(point.examples.indices, id: \.self) { i in
                                    KanaExampleRow(example: point.examples[i], accentColor: accentColor)
                                    if i < point.examples.count - 1 {
                                        Divider().padding(.leading, 12)
                                    }
                                }
                            }
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.07), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appBackground)
                .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? accentColor.opacity(0.35) : Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - Example word row

private struct KanaExampleRow: View {
    let example: GrammarExample
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(example.japanese)
                .font(.system(size: 18))
                .foregroundColor(.appText)
                .frame(minWidth: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(example.romaji)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .italic()
                Text(example.english)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appText)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
