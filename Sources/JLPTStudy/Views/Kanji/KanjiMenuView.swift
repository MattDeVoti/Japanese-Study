import SwiftUI

struct KanjiMenuView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var filter: KanjiFilter

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 4) {
                NavigationLink {
                    KanjiListView()
                } label: {
                    Text("List")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    KanjiStudyView()
                } label: {
                    Text("Study")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .standardNavBar("Kanji")
        .withOptions(filter: filter, store: store, section: .kanji, label: "Kanji")
    }
}
