import SwiftUI
import UserNotifications

// Two optional nudges, switched on separately and both off by default.
//
// **The daily study nudge** is deliberately not a queue notification. Counting
// what's "due" or "waiting" turns study into a backlog with a number attached,
// which is the same pressure the streak used to apply — and the tests are where
// the app's pressure belongs. It just offers a few minutes on whatever the next
// test covers.
//
// **The test reminder** is the one place a deadline is genuinely worth
// mentioning, so it may — but it is an invitation to revise, never a telling-off.
// It fires only in the run-up to a real deadline on a test not yet sat, stops the
// moment that test is taken, and says nothing once the deadline has passed: by
// then the app has already scored it, and a notification would only be rubbing
// it in.
//
// Neither posts a badge.

final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    /// Set when a notification is tapped: the chapter the next test covers.
    /// The app root watches this and opens that chapter — both nudges are about
    /// the same material, so both land in the same place.
    @Published var tappedChapterId: String?

    /// Registered at launch. Without a delegate a tap just foregrounds the app,
    /// which is a dead end for a notification whose whole point is "go here".
    func registerAsDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled { requestAuthorization() } else { cancelAll() }
        }
    }
    /// Practice-nudge time, stored as minutes past midnight. Early afternoon by
    /// default: a study prompt is most useful when there's still day left to act
    /// on it.
    @Published var reminderMinutes: Int {
        didSet {
            UserDefaults.standard.set(reminderMinutes, forKey: Keys.time)
            reschedule()
        }
    }
    /// Test-reminder time, kept separate from the practice one on purpose. These
    /// two nudges want different hours — "revise sometime today" suits the middle
    /// of the day, "your test is tomorrow" wants the morning, while there is a
    /// whole day left to do something about it.
    @Published var testReminderMinutes: Int {
        didSet {
            UserDefaults.standard.set(testReminderMinutes, forKey: Keys.testTime)
            rescheduleTestReminders()
        }
    }
    /// Nudges to revise while a test's deadline is coming up.
    @Published var testRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(testRemindersEnabled, forKey: Keys.testEnabled)
            if testRemindersEnabled { requestAuthorization() } else { cancelTestReminders() }
            rescheduleTestReminders()
        }
    }
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private enum Keys {
        static let enabled = "ReminderEnabled"
        static let time = "ReminderMinutes"
        static let testEnabled = "TestReminderEnabled"
        static let testTime = "TestReminderMinutes"
    }
    private let identifierPrefix = "practice-nudge-"
    private let testPrefix = "test-nudge-"
    /// A week of reminders, rewritten whenever the app is opened.
    private let daysAhead = 7
    /// How many days before a deadline the test nudges begin. Earlier than this
    /// the deadline isn't news yet, and the practice nudge already covers
    /// ordinary days.
    private let testLeadDays = 5

    private override init() {
        let d = UserDefaults.standard
        // Off unless the user asks for it.
        isEnabled = d.object(forKey: Keys.enabled) as? Bool ?? false
        testRemindersEnabled = d.object(forKey: Keys.testEnabled) as? Bool ?? false
        // Defaults only apply to someone who has never set a time; an explicit
        // choice is stored and left alone.
        reminderMinutes = d.object(forKey: Keys.time) as? Int ?? (12 * 60 + 30)  // 12:30pm
        testReminderMinutes = d.object(forKey: Keys.testTime) as? Int ?? (7 * 60) // 7am
        super.init()
        refreshAuthorization()
    }
    // MARK: - Authorization

    func refreshAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorization = settings.authorizationStatus
                if settings.authorizationStatus == .authorized {
                    self.reschedule()
                    self.rescheduleTestReminders()
                }
            }
        }
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    self.authorization = granted ? .authorized : .denied
                    if granted {
                        self.reschedule()
                        self.rescheduleTestReminders()
                    } else {
                        self.isEnabled = false
                        self.testRemindersEnabled = false
                    }
                }
            }
    }

    // MARK: - Scheduling

    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: (0...daysAhead).map { "\(identifierPrefix)\($0)" })
    }

    /// Rewrites the coming week's nudges. Nothing is scheduled until there's
    /// something to practise, so a new user is never nagged about an empty app.
    func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: (0...daysAhead).map { "\(identifierPrefix)\($0)" })

        // Nothing to nudge toward until there is a test in front of the user, so
        // a brand-new install is never prompted about an empty app.
        guard isEnabled, authorization == .authorized,
              ExamStore.shared.currentLesson != nil else { return }

        let cal = Calendar.current
        let now = Date()

        for day in 0...daysAhead {
            guard let fireDate = fireDate(dayOffset: day, minutes: reminderMinutes, calendar: cal),
                  fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Five minutes?"
            content.body = Self.prompts[day % Self.prompts.count]
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            center.add(UNNotificationRequest(
                identifier: "\(identifierPrefix)\(day)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    /// Rotated so a daily reminder doesn't read like the same alarm every day.
    /// None of these mention a count, a queue, or anything being owed.
    private static let prompts = [
        "A few minutes on this chapter would go a long way.",
        "Fancy a quick round of cards before the day gets away?",
        "Short session? Even ten minutes keeps things ticking over.",
        "Your next chapter's right here whenever you fancy it.",
        "A little and often beats cramming. Got five minutes?",
        "Dip into the current chapter — no pressure, no queue.",
        "Keep the streak of understanding, not of days. A few cards?",
        "Good moment for a bit of Japanese?",
    ]

    // MARK: - Test reminders

    func cancelTestReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: (0...testLeadDays).map { "\(testPrefix)\($0)" })
    }

    /// Rewrites the run-up to the current test's deadline.
    ///
    /// Rewritten rather than accumulated, and always cleared first, so sitting
    /// the test, changing the deadline length or moving on to a new lesson can
    /// never leave a stale reminder about a test already behind you.
    func rescheduleTestReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: (0...testLeadDays).map { "\(testPrefix)\($0)" })

        guard testRemindersEnabled, authorization == .authorized else { return }

        // Only a test that is actually in front of the user, has a deadline, and
        // hasn't been sat. `availability` answers all three: `.due` is precisely
        // "takeable, with time left".
        let store = ExamStore.shared
        guard let lesson = store.currentLesson,
              case let .due(deadline) = store.availability(of: lesson) else { return }

        let cal = Calendar.current
        let now = Date()

        // `daysLeft` counts whole days from the fire date to the deadline, so the
        // wording can match: "tomorrow" only ever fires the day before.
        for offset in 0...testLeadDays {
            guard let fire = fireDate(dayOffset: offset, minutes: testReminderMinutes,
                                      calendar: cal),
                  fire > now, fire < deadline else { continue }
            let daysLeft = cal.dateComponents([.day], from: fire, to: deadline).day ?? 0
            guard daysLeft <= testLeadDays else { continue }

            let content = UNMutableNotificationContent()
            content.title = Self.testTitle(daysLeft: daysLeft)
            content.body = Self.testPrompt(for: lesson.title, daysLeft: daysLeft, slot: offset)
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            center.add(UNNotificationRequest(
                identifier: "\(testPrefix)\(offset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    /// Warmer the further out, more concrete as the day approaches — but never
    /// alarmed. The last day still reads as an invitation.
    private static func testTitle(daysLeft: Int) -> String {
        switch daysLeft {
        case ...0: return "Test day"
        case 1:    return "Test tomorrow"
        case 2:    return "Two days to go"
        default:   return "Test coming up"
        }
    }

    /// Rotated by day so a run-up doesn't read as the same sentence five nights
    /// running, and split by urgency so the tone tracks how close the test is.
    /// Nothing here counts what's unfinished or implies falling behind.
    private static func testPrompt(for lesson: String, daysLeft: Int, slot: Int) -> String {
        let pool: [String]
        switch daysLeft {
        case ...0:
            // Test day. Same encouraging tone, but nothing may say "tomorrow" —
            // the deadline is today.
            pool = [
                "\(lesson) is due today. A quick warm-up round and you're ready.",
                "Today's the day for \(lesson). You've put the work in — go get it.",
                "\(lesson) is up today. A few cards to limber up, then take it.",
                "Last call for \(lesson). Five minutes of review and in you go.",
            ]
        case 1:
            pool = [
                "\(lesson) is up tomorrow. A quick run through the cards tonight and you're set.",
                "Last look at \(lesson)? Even a few minutes now makes tomorrow easier.",
                "\(lesson) tomorrow — you've done the work, this is just the warm-up.",
                "One more pass over \(lesson) and you can go in confident.",
            ]
        case 2...3:
            pool = [
                "A couple of days until \(lesson). Nice time for a steady review.",
                "\(lesson) is close. A short session now beats a long one later.",
                "Chip away at \(lesson) tonight — future you will be grateful.",
                "\(lesson) soon. Ten minutes of kanji words goes a long way.",
            ]
        default:
            pool = [
                "\(lesson) is on the horizon. Fancy a few cards?",
                "Plenty of time before \(lesson) — perfect for a relaxed round.",
                "Getting a head start on \(lesson) now makes the last day painless.",
                "\(lesson) is coming. No rush, but the cards are right there.",
            ]
        }
        return pool[slot % pool.count]
    }

    private func fireDate(dayOffset: Int, minutes: Int, calendar cal: Calendar) -> Date? {
        guard let day = cal.date(byAdding: .day, value: dayOffset, to: Date()) else { return nil }
        return cal.date(bySettingHour: minutes / 60,
                        minute: minutes % 60, second: 0, of: day)
    }
}

// MARK: - Taps

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Both nudges point at the same thing: whatever the next test covers.
    /// Resolved on tap rather than stored in the notification, so a reminder
    /// scheduled days ago still opens the right chapter if the test has moved on.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        if id.hasPrefix(identifierPrefix) || id.hasPrefix(testPrefix) {
            DispatchQueue.main.async {
                self.tappedChapterId = ExamStore.shared.currentLesson?.chapterIds.first
            }
        }
        completionHandler()
    }

    /// Shown even with the app open — otherwise a reminder set for a moment the
    /// user happens to be studying simply vanishes.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
