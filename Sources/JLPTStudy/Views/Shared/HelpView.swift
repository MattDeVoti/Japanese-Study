import SwiftUI

// How the app works, in one place. Collapsed by default so it reads as a table of
// contents rather than a wall of text.

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var open: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        intro
                        ForEach(Self.topics) { topic in
                            section(topic)
                        }
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("How to use Omedetou")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Two things to know")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.appText)
            Text("**The Textbook is always open.** Every level, chapter and word can be read at any time, in any order. Nothing is locked.\n\n**The tests are the path.** They go in order, they're graded, and the grade is what moves you forward. There's no streak to keep alive, but each test does carry a deadline — miss it and that test sits at 0 until you take it.")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
    }

    private var footer: some View {
        Text("Some parts of the app aren't listed here. They're not broken — you just haven't found them yet.")
            .font(.system(size: 12))
            .foregroundColor(.appTextSecondary)
            .italic()
            .padding(.top, 6)
    }

    private func section(_ topic: Topic) -> some View {
        let isOpen = open.contains(topic.id)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if isOpen { open.remove(topic.id) } else { open.insert(topic.id) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: topic.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(topic.color)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(topic.color.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(topic.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.appText)
                        Text(topic.summary)
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.appTextSecondary)
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(topic.body.enumerated()), id: \.offset) { _, para in
                        Text(.init(para))
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
    }

    // MARK: - Content

    struct Topic: Identifiable {
        let id: String
        let icon: String
        let color: Color
        let title: String
        let summary: String
        let body: [String]
    }

    static var topics: [Topic] {
        [
            Topic(id: "tests", icon: "graduationcap.fill", color: .themeTile(1),
                  title: "Tests & your report card",
                  summary: "How you move forward",
                  body: [
                    "The graded track runs **Hiragana → Katakana → Levels 1–5**. Each syllabary is split into three parts, and every grammar chapter has its own test.",
                    "**Kana first, or skip it.** Alongside the three parts, each syllabary has a single **test-out** paper covering every character. Score an A on that and the whole syllabary is done — you never sit the parts. It's open from the very start, so if you already read kana you can be on Level 1 in two sittings.",
                    "Each chapter test is **24 questions** drawn from that chapter's grammar, vocabulary and kanji — roughly 40% grammar, 35% vocab, 25% kanji. A kana part is 20 questions; a test-out is 40. Questions are drawn fresh every time, so sitting a paper twice never gives you the same one.",
                    "**Three marks matter.** 60% passes a lesson and lets you move on. **A B (83%) clears it**, and every lesson in a level must be cleared before the next level unlocks. A **test-out needs an A (93%)**, because that one paper stands in for the whole syllabary.",
                    "So a C lets you keep moving inside a level but leaves a debt to come back and settle. That's deliberate: the aim is to do well, not to do the minimum.",
                    "**If you fail**, take it again whenever you like — there's no waiting period — or skip the lesson and carry on. Either way the grade stays on your report card: a failure you later rescued still shows as an earlier fail.",
                    "You can also **retake anything to improve it**, including lessons you've already cleared.",
                    "The **report card** keeps every attempt, with a grade per lesson, a breakdown by grammar/vocab/kanji, and a GPA for each level and overall. Find it under Study ▸ Progress, or the test bar on the home screen.",
                  ]),

            Topic(id: "schedule", icon: "calendar", color: .themeTile(4),
                  title: "Deadlines",
                  summary: "Set your own pace",
                  body: [
                    "Tests aren't scheduled to *start* — they have a **deadline**. The test in front of you is always available; what you get is a date to finish it by. By default that's 7 days out, landing on a Friday.",
                    "**Miss the deadline and that test scores 0** on your report card. It stays at 0 until you actually sit it, at which point your real grade replaces it. No new deadline is issued in the meantime, so there's nothing further to lose.",
                    "Both numbers are yours in **Options ▸ Tests**: how many days you get, and whether deadlines land on a fixed weekday at all. Want to move fast? Set one day. Prefer a fortnight? Set 14.",
                    "Only one deadline is ever outstanding — the next is set when you finish the current test.",
                  ]),

            Topic(id: "studylist", icon: "list.bullet.clipboard.fill", color: .themeTile(3),
                  title: "What's on the test",
                  summary: "Your study list for the week",
                  body: [
                    "Tapping the test bar on the home screen opens the study list: **everything the next test can ask about**, in one place.",
                    "Every grammar point, every vocabulary word and every kanji for that chapter, with your checkmarks shown against them, and links through to the full chapter in the Textbook.",
                    "It's available for the whole run-up to the test, not just on the day.",
                  ]),

            Topic(id: "reviews", icon: "bolt.fill", color: .themeTile(11),
                  title: "Reviews",
                  summary: "Spaced repetition, as test prep",
                  body: [
                    "Reviews use **spaced repetition**: each item is scheduled for roughly the moment you're about to forget it, so a little often beats cramming.",
                    "Things enter your review schedule three ways: **you get them wrong on a test**, you mark them Confident or Needs Work on a flashcard, or you seed the schedule from everything you've already checked off.",
                    "When you review, grade yourself honestly with **Again / Hard / Good / Easy**. Each button shows how far it pushes the card before you press it. Getting something wrong brings it back in about ten minutes, not next month.",
                    "Reviews are a **tool, not a chore**. There's no streak, nothing is ever owed, and a round is always available — if nothing is ripe, it just picks whatever you've been finding hardest. Since missed test questions land here, it's the most direct way to prepare for a retake.",
                    "Optionally, **Options ▸ Practice** can offer you one short round a day at a time you choose. It's off unless you turn it on, it never counts anything at you, and ignoring it costs you nothing.",
                  ]),

            Topic(id: "textbook", icon: "books.vertical.fill", color: .themeTile(0),
                  title: "Textbook",
                  summary: "All the teaching material",
                  body: [
                    "**Kana** — Hiragana and Katakana, character by character, with pronunciation notes.",
                    "**Grammar** — Levels 1 to 5, each a set of chapters. A chapter has its grammar points (with explanations, formation rules, diagrams and example sentences), its vocabulary, and its kanji.",
                    "**Slang** and **Culture** sit outside the graded track — read them whenever, they're never tested.",
                    "**Favorites** collects anything you star while studying.",
                    "**Custom** lets you build a lesson from any mix of grammar points, words and kanji. It starts with ready-made sets for the things learners most often mix up — the four \"if\"s, られる, こそあど, look-alike kanji — and you can delete any you don't want.",
                    "To build your own, tap **+** in the Custom section, or long-press any point, word or kanji in a chapter and add it. Each lesson studies as its own deck.",
                    "Tap the checkmark on any point, word or kanji to mark it done. Those checkmarks drive the chapter progress badges, and can seed your review schedule.",
                  ]),

            Topic(id: "study", icon: "brain.head.profile", color: .themeTile(3),
                  title: "Study",
                  summary: "Drills, flashcards and quizzes",
                  body: [
                    "**Progress** — your report card, and a practice round drawn from whatever you've been getting wrong.",
                    "**Kana Pronunciation** — sound drills for Hiragana and Katakana.",
                    "**Vocab and Kanji flashcards** — tap Check to reveal, then Needs Work or Confident. Confident also ticks the item off.",
                    "**Grammar Quizzes** — one per level, plus one for Slang. Multiple choice on the grammar of that level.",
                    "**Conjugation** — pick the right form of a verb or adjective. The wrong answers are that same word's other forms, which is where conjugation actually goes wrong.",
                    "**Reading** — full passages with comprehension questions. Press and hold any word to see its meaning, and use Listen to hear the whole passage.",
                  ]),

            Topic(id: "flashcards", icon: "rectangle.stack.fill", color: .themeTile(5),
                  title: "Flashcard priority",
                  summary: "What appears in your decks",
                  body: [
                    "In **Options ▸ Flashcard Priority** there are two modes, and they apply to every deck.",
                    "**No Priority** — an even shuffle, and anything you've checked off is hidden. Good for clearing new material.",
                    "**Prioritize Needs Work** — everything stays in rotation, including checked items, but cards you've marked Needs Work come up more often. The slider controls how much more.",
                  ]),

            Topic(id: "dictionary", icon: "magnifyingglass", color: .themeTile(6),
                  title: "Dictionary",
                  summary: "4,100 entries, offline",
                  body: [
                    "Search in English or Japanese — it works out which you typed.",
                    "Verb and adjective entries include **full conjugation tables**: plain and polite, positive and negative, past, te-form, conditional, potential, passive, causative, imperative and volitional.",
                    "Star anything to keep it in your dictionary favourites.",
                  ]),

            Topic(id: "audio", icon: "speaker.wave.2.fill", color: .themeTile(8),
                  title: "Audio",
                  summary: "Hearing the Japanese",
                  body: [
                    "Speaker buttons appear on vocabulary cards, dictionary entries, kana characters, example sentences and reading passages.",
                    "Audio uses your device's Japanese voice and works offline. Crucially it's **guided by the app's own furigana**, so it reads 二時 as にじ rather than guessing.",
                    "For a much better voice, install a Japanese Siri voice in **iOS Settings ▸ Accessibility ▸ Spoken Content ▸ Voices ▸ Japanese** — the app picks the best one you have automatically.",
                    "Speed and on/off are in Options ▸ Audio.",
                  ]),

            Topic(id: "reading", icon: "textformat.size", color: .themeTile(10),
                  title: "Furigana & text size",
                  summary: "Making it readable",
                  body: [
                    "Furigana are the small kana printed above kanji, showing how they're read.",
                    "They render at about half the size of the text beneath, so if they're hard to read, **Options ▸ Reading** has a Japanese text size slider with a live preview. It applies everywhere Japanese appears.",
                  ]),

            Topic(id: "appearance", icon: "paintbrush.fill", color: .themeTile(9),
                  title: "Appearance",
                  summary: "Themes",
                  body: [
                    "**Options ▸ Appearance** has 42 colour themes. Each one repaints the whole app — backgrounds, buttons, tiles and the subtle patterns behind each section.",
                    "Every swatch is a miniature of the real home screen, so you can see what you're picking.",
                  ]),

            Topic(id: "backup", icon: "externaldrive.fill", color: .themeTile(2),
                  title: "Backup & restore",
                  summary: "Don't lose your progress",
                  body: [
                    "There's no account and no cloud sync, which means **deleting the app deletes everything** — grades, review schedule, custom lessons, favourites and settings.",
                    "**Options ▸ Backup & Restore** exports the lot into a single file you can save anywhere or send to yourself. The same file restores onto a new phone.",
                    "Worth doing occasionally, and definitely before changing devices.",
                  ]),
        ]
    }
}
