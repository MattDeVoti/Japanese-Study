import SwiftUI

struct ParticleCardDetailView: View {
    let card: ParticleCard

    private var levelColor: Color { nLevelColor(card.nLevel) }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Particle + romaji + level badge
                ZStack(alignment: .top) {
                    VStack(spacing: 8) {
                        Text(card.particle)
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(.appText)
                            .multilineTextAlignment(.center)

                        Text(card.romaji)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.horizontal, 56) // leave room for level badge

                    // Level badge top-right
                    HStack {
                        Spacer()
                        Text("N\(card.nLevel)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(levelColor))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }

                Spacer().frame(height: 32)

                // Grammar meaning
                Text(card.meaning)
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.appText)
                    .padding(.horizontal, 32)

                Spacer()
            }
        }
        .standardNavBar(card.particle)
    }
}
