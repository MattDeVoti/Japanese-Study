import SwiftUI

struct ParticleCardDetailView: View {
    let card: ParticleCard

    private var levelColor: Color { nLevelColor(card.nLevel) }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Particle + romaji + level badge
                    ZStack(alignment: .top) {
                        VStack(spacing: 8) {
                            Text(card.particle)
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(.appText)
                                .multilineTextAlignment(.center)

                            Text(card.romaji)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.horizontal, 56) // leave room for level badge

                        // Level badge top-right
                        HStack {
                            Spacer()
                            Text(levelName(card.nLevel))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(levelColor))
                        }
                        .padding(.top, 20)
                    }

                    Spacer().frame(height: 20)

                    // Short description (the useful summary line)
                    Text(card.meaning)
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)

                    // Comprehensive usage explanation
                    if !card.explanation.isEmpty {
                        Divider().padding(.vertical, 18)

                        ExplanationBody(text: card.explanation, fontSize: 16,
                                        color: .appText, bulletColor: levelColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
        }
        .standardNavBar(card.particle)
    }
}
