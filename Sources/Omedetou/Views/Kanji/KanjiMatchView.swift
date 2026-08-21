import SwiftUI

// 見分け — telling apart kanji that look alike.
//
// Flashcards ask "what is this?" one card at a time, which is exactly the
// condition under which 待 and 持 both look right. This puts a confusable set on
// screen together and makes you commit: the reading and meaning have to go into
// one specific hole while its near-twin sits beside it.
//
// Nothing here is saved. The round summary exists to be read once and then
// thrown away, so it lives in view state and dies with the screen.

struct KanjiMatchView: View {
    @EnvironmentObject private var cardStore: CardStore
    @Environment(\.dismiss) private var dismiss

    @State private var round: SimilarKanji.Round?
    @State private var dealFailed = false
    /// kanji → the item dropped into it, once correct.
    @State private var filled: [String: SimilarKanji.Item] = [:]
    /// Every drop, right or wrong, for the summary.
    @State private var log: [Attempt] = []

    @State private var drag: Drag?
    @State private var dragToken = 0
    /// Which deal the measured frames belong to.
    ///
    /// Preference values outlive the views that published them: dealing a new
    /// round can leave the *previous* round's hole frames in the dictionary,
    /// and since those sit on the same grid cells as the new ones, a perfectly
    /// aimed drop resolves to a kanji that isn't on the board — which can never
    /// match, so the tile is refused every time. Stamping each frame with the
    /// deal it came from makes a stale entry impossible to look up.
    @State private var deal = 0
    @State private var holeFrames: [FrameID: CGRect] = [:]
    @State private var tileFrames: [FrameID: CGRect] = [:]
    @State private var flash: (kanji: String, correct: Bool)?
    /// Guards the delayed flash cleanup, so a second drop landing inside the
    /// first one's 0.45s window doesn't cut its own flash short.
    @State private var flashSeq = 0
    @State private var showSummary = false
    @State private var inspecting: StudyItemRef?

    private struct Attempt: Identifiable {
        let id = UUID()
        let kanji: String
        let dropped: SimilarKanji.Item
        var correct: Bool { dropped.kanji == kanji }
    }

    /// A tile in flight.
    ///
    /// It carries the frame it lifted out of and moves by the gesture's
    /// translation, so it leaves from exactly where it was sitting at exactly
    /// the size it was. Positioning it at the fingertip instead — which is the
    /// obvious way to write this — teleports the tile under your finger the
    /// instant the drag passes its 4pt threshold, and resizes it on the way.
    private struct Drag {
        /// Distinguishes one pickup from the next. Identifying a drag by its
        /// *tile* isn't enough: the delayed cleanup after a bounce-back would
        /// then match a fresh grab of that same tile and cancel it mid-gesture.
        let token: Int
        let item: SimilarKanji.Item
        let home: CGRect
        var translation: CGSize = .zero
        /// Set while the bounce-back is playing out. A fresh grab of the same
        /// tile replaces the whole `Drag` rather than reusing it, so the
        /// bounce-back's delayed cleanup can't cancel the new gesture.
        var returning = false
        var rect: CGRect { home.offsetBy(dx: translation.width, dy: translation.height) }
    }

    private let space = "match"
    private var accent: Color { .themeTile(6) }

    private var solved: Bool {
        guard let round else { return false }
        return filled.count == round.items.count
    }

    /// The hole the travelling tile would land in, for a live highlight.
    private var hovered: String? {
        guard let drag else { return nil }
        return hole(under: drag.rect)
    }

    var body: some View {
        ZStack {
            AppBackground()

            if let round {
                board(round)
            } else if dealFailed {
                unavailable
            } else {
                ProgressView()
            }
        }
        .standardNavBar("見分[みわ]け")
        .onAppear(perform: startIfNeeded)
        .sheet(isPresented: $showSummary, onDismiss: nextRound) {
            summarySheet
        }
        .sheet(item: $inspecting) { ItemDetailSheet(id: $0) }
    }

    // MARK: - Board

    /// The board and the tile in flight share one coordinate space, so a
    /// measured hole frame and a `position` resolve against the same origin.
    /// With the tile travelling from its own frame rather than the fingertip,
    /// any mismatch between those two spaces would show up as a jump at lift.
    private func board(_ round: SimilarKanji.Round) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                header(round)
                holes(round)
                Divider().padding(.vertical, 4)
                tiles(round)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // Drawn last so it floats over both halves of the screen while it
            // travels between them.
            if let drag {
                tileFace(drag.item, lifted: true)
                    .frame(width: drag.home.width, height: drag.home.height)
                    .position(x: drag.rect.midX, y: drag.rect.midY)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: space)
        .onPreferenceChange(HoleFrameKey.self) { holeFrames = $0 }
        .onPreferenceChange(TileFrameKey.self) { tileFrames = $0 }
    }

    private func header(_ round: SimilarKanji.Round) -> some View {
        HStack {
            Text("\(filled.count) of \(round.items.count)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text("Drag each reading onto its kanji")
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
        }
        .padding(.vertical, 8)
    }

    private func holes(_ round: SimilarKanji.Round) -> some View {
        LazyVGrid(columns: grid(for: round.items.count), spacing: 12) {
            ForEach(round.holeOrder) { item in
                hole(item)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func hole(_ item: SimilarKanji.Item) -> some View {
        let done = filled[item.kanji]
        let isFlashing = flash?.kanji == item.kanji
        let flashOK = flash?.correct == true
        let isHovered = hovered == item.kanji

        return ZStack {
            if let done {
                // Solved: the three halves of the answer become one card.
                VStack(spacing: 2) {
                    Text(item.kanji)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.appText)
                    Text(done.reading)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.readableOnPage(accent))
                    Text(done.meaning)
                        .font(.system(size: 10))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity, minHeight: 104)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accent.opacity(0.5), lineWidth: 1.5))
            } else {
                // Empty: recessed, so it reads as a hole waiting to be filled
                // rather than a card of its own. It lights up while a tile is
                // over it, so you can see where the drop will land before you
                // let go.
                Text(item.kanji)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.appText)
                    .frame(maxWidth: .infinity, minHeight: 104)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isHovered ? accent.opacity(0.18) : Color.appText.opacity(0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: isHovered ? 2.5 : 1.5,
                                                         dash: [5, 4]))
                        .foregroundColor(isHovered ? accent.opacity(0.9)
                                                   : .appText.opacity(0.22)))
                    .animation(.easeOut(duration: 0.12), value: isHovered)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isFlashing ? (flashOK ? Color(hex: "3B9A55") : Color(hex: "C0392B"))
                                         : .clear,
                              lineWidth: 3)
        )
        .scaleEffect(isFlashing && flashOK ? 1.04 : 1)
        .animation(.easeOut(duration: 0.18), value: isFlashing)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HoleFrameKey.self,
                                       value: [FrameID(deal: deal, name: item.kanji):
                                                geo.frame(in: .named(space))])
            }
        )
    }

    private func tiles(_ round: SimilarKanji.Round) -> some View {
        LazyVGrid(columns: grid(for: round.items.count), spacing: 10) {
            ForEach(round.tileOrder) { item in
                Group {
                    if filled[item.kanji] != nil {
                        // Its hole is filled — leave the gap so the remaining
                        // tiles don't jump around mid-round.
                        Color.clear.frame(height: 62)
                    } else {
                        let lifted = drag?.item.id == item.id
                        tileFace(item, lifted: lifted)
                            // The dimmed original stays put as a socket, so the
                            // tile has somewhere to visibly land on its way back.
                            .opacity(lifted ? 0.25 : 1)
                            .gesture(dragGesture(item))
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: TileFrameKey.self,
                                               value: [FrameID(deal: deal, name: item.id):
                                                        geo.frame(in: .named(space))])
                    }
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func tileFace(_ item: SimilarKanji.Item, lifted: Bool) -> some View {
        VStack(spacing: 1) {
            Text(item.reading)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.appText)
            Text(item.meaning)
                .font(.system(size: 10))
                .foregroundColor(.appTextSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.appHairline, lineWidth: 1))
        .shadow(color: .black.opacity(lifted ? 0.28 : 0.10),
                radius: lifted ? 12 : 3, y: lifted ? 8 : 2)
    }

    private func dragGesture(_ item: SimilarKanji.Item) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(space))
            .onChanged { v in
                if drag?.item.id != item.id || drag?.returning == true {
                    guard let home = tileFrames[FrameID(deal: deal, name: item.id)] else { return }
                    dragToken += 1
                    drag = Drag(token: dragToken, item: item, home: home)
                }
                drag?.translation = v.translation
            }
            .onEnded { _ in
                guard let flight = drag, flight.item.id == item.id else {
                    drag = nil
                    return
                }
                guard let target = hole(under: flight.rect) else {
                    returnHome()
                    return
                }
                if drop(item, on: target) {
                    drag = nil            // it landed; the hole takes over
                } else {
                    returnHome()          // wrong hole — hand it back
                }
            }
    }

    /// The hole the tile is most on top of, or nil if it isn't meaningfully
    /// over one.
    ///
    /// Hit-testing the fingertip instead is what the gesture hands you, and it
    /// is wrong: a tile can visibly cover a hole while the finger sits a few
    /// points outside it, and the drop gets refused. Refusals the player can't
    /// see the reason for read as the game ignoring them.
    private func hole(under rect: CGRect) -> String? {
        let minimum = rect.width * rect.height * 0.25
        var best: (kanji: String, area: CGFloat, distance: CGFloat)?
        for (id, frame) in holeFrames where id.deal == deal && filled[id.name] == nil {
            let overlap = frame.intersection(rect)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            guard area >= minimum else { continue }
            // Equal overlaps are common — a tile straddling two cells covers
            // the same slice of each — and picking between them by dictionary
            // order means the same drop lands somewhere different each time.
            let distance = hypot(frame.midX - rect.midX, frame.midY - rect.midY)
            if best == nil || area > best!.area
                || (area == best!.area && distance < best!.distance) {
                best = (id.name, area, distance)
            }
        }
        return best?.kanji
    }

    /// Spring the tile back to its slot instead of blinking it out of
    /// existence, which is what a bare `drag = nil` does.
    private func returnHome() {
        let token = drag?.token
        drag?.returning = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
            drag?.translation = .zero
        }
        // iOS 16 has no completion callback for withAnimation, so clear once
        // the spring has visibly settled — and only if this same pickup is
        // still the one in flight. Matching on the tile instead would let this
        // cancel a fresh grab of the same tile made inside the 0.34s window,
        // which is exactly what an impatient player does after a wrong drop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            if drag?.token == token { drag = nil }
        }
    }

    // MARK: - Rules

    /// Records the drop and reports whether it was right.
    @discardableResult
    private func drop(_ item: SimilarKanji.Item, on kanji: String) -> Bool {
        log.append(Attempt(kanji: kanji, dropped: item))
        let correct = item.kanji == kanji
        if correct {
            filled[kanji] = item
            FeedbackSounds.shared.playCorrectVariation()
        } else {
            FeedbackSounds.shared.play(.incorrect)
        }

        flash = (kanji, correct)
        flashSeq += 1
        let seq = flashSeq
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard seq == flashSeq else { return }
            flash = nil
            if correct, solved {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    guard seq == flashSeq else { return }
                    showSummary = true
                }
            }
        }
        return correct
    }

    private func startIfNeeded() { if round == nil { nextRound() } }

    private func nextRound() {
        // Rounds vary in size so the shape of the board isn't a hint in itself.
        let size = [2, 2, 3, 3, 4, 5].randomElement() ?? 3
        filled = [:]
        log = []
        flash = nil
        drag = nil
        holeFrames = [:]
        tileFrames = [:]
        deal += 1
        round = SimilarKanji.round(size: size, cardStore: cardStore)
        dealFailed = round == nil
    }

    private func grid(for count: Int) -> [GridItem] {
        let columns = count <= 2 ? 2 : (count <= 4 ? 2 : 3)
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)
    }

    /// Every bundled set can field two tiles, so this shouldn't appear — but a
    /// spinner that never resolves is the worst possible way to find out that
    /// something upstream changed.
    private var unavailable: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 34))
                .foregroundColor(.appTextSecondary)
            Text("Couldn't build a round from the kanji available.")
                .font(.system(size: 15))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { nextRound() }
                .fontWeight(.semibold)
        }
        .padding(28)
    }

    // MARK: - Round summary
    //
    // Read once, then gone: it lives in `log`, which `nextRound` clears.

    private var summarySheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(round?.items ?? []) { item in
                        summaryRow(item)
                    }
                } header: {
                    Text(mistakes.isEmpty ? "All correct, first try"
                                          : "\(mistakes.count) wrong \(mistakes.count == 1 ? "drop" : "drops")")
                } footer: {
                    Text("Tap any kanji to see its card. This summary isn't kept.")
                }
            }
            .navigationTitle("Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") { showSummary = false }.fontWeight(.semibold)
                }
            }
        }
    }

    private var mistakes: [Attempt] { log.filter { !$0.correct } }

    private func summaryRow(_ item: SimilarKanji.Item) -> some View {
        let wrong = mistakes.filter { $0.kanji == item.kanji }
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                inspecting = .kanji(item.kanji)
            } label: {
                HStack(spacing: 12) {
                    Text(item.kanji)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.appText)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.reading)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appText)
                        Text(item.meaning)
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                    }
                    Spacer()
                    Image(systemName: wrong.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(wrong.isEmpty ? Color(hex: "3B9A55") : Color(hex: "C0392B"))
                }
            }
            .buttonStyle(.plain)

            // What was tried here instead, so the confusion is named rather than
            // just marked wrong.
            ForEach(wrong) { a in
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10))
                        .foregroundColor(.appTextSecondary)
                    Text("you dropped \(a.dropped.reading) — that's \(a.dropped.kanji)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "C0392B"))
                }
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Where the holes are, and where each tile rests: the first so a dropped tile
/// can be matched to a hole, the second so a lifted tile knows where it came
/// from. Both are collected in the board's coordinate space.
/// A measured frame belongs to one kanji *in one deal*. Rounds reuse the same
/// grid, so a frame that outlives its round still lands squarely on a cell of
/// the next one.
private struct FrameID: Hashable {
    let deal: Int
    let name: String
}

private struct HoleFrameKey: PreferenceKey {
    static var defaultValue: [FrameID: CGRect] = [:]
    static func reduce(value: inout [FrameID: CGRect], nextValue: () -> [FrameID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct TileFrameKey: PreferenceKey {
    static var defaultValue: [FrameID: CGRect] = [:]
    static func reduce(value: inout [FrameID: CGRect], nextValue: () -> [FrameID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
