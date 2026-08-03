import SwiftUI
import UserNotifications

// An optional daily nudge to practise.
//
// Deliberately not a queue notification. Counting what's "due" or "waiting" turns
// practice into a backlog with a number attached, which is the same pressure the
// streak used to apply — and the tests are where the app's pressure belongs. This
// just offers a few minutes on whatever the model reckons is shakiest, and says
// nothing at all if the user would rather it didn't.
//
// Off by default. There is no badge.

final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled { requestAuthorization() } else { cancelAll() }
        }
    }
    /// Reminder time, stored as minutes past midnight.
    @Published var reminderMinutes: Int {
        didSet {
            UserDefaults.standard.set(reminderMinutes, forKey: Keys.time)
            reschedule()
        }
    }
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private enum Keys {
        static let enabled = "ReminderEnabled"
        static let time = "ReminderMinutes"
    }
    private let identifierPrefix = "practice-nudge-"
    /// A week of reminders, rewritten whenever the app is opened.
    private let daysAhead = 7

    private init() {
        let d = UserDefaults.standard
        // Off unless the user asks for it.
        isEnabled = d.object(forKey: Keys.enabled) as? Bool ?? false
        reminderMinutes = d.object(forKey: Keys.time) as? Int ?? 19 * 60      // 7pm
        refreshAuthorization()
    }
    // MARK: - Authorization

    func refreshAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorization = settings.authorizationStatus
                if settings.authorizationStatus == .authorized { self.reschedule() }
            }
        }
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    self.authorization = granted ? .authorized : .denied
                    if granted { self.reschedule() } else { self.isEnabled = false }
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

        guard isEnabled, authorization == .authorized,
              SRSStore.shared.enrolledCount > 0 else { return }

        let cal = Calendar.current
        let now = Date()

        for day in 0...daysAhead {
            guard let fireDate = fireDate(dayOffset: day, calendar: cal),
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

    /// Rotated so a daily reminder doesn't read like the same alarm every evening.
    /// None of these mention a count, a queue, or anything being owed.
    private static let prompts = [
        "Run through a few of the points you've been slipping on.",
        "A quick round on the grammar that keeps catching you out.",
        "Fancy a short practice? It'll pick your shakiest items.",
        "A few cards on what you've been finding hardest.",
        "Short practice round, whenever suits.",
        "Want to shore up the bits that keep going wrong?",
        "A couple of minutes on your weakest points.",
        "Quick practice — no pressure, no queue.",
    ]

    private func fireDate(dayOffset: Int, calendar cal: Calendar) -> Date? {
        guard let day = cal.date(byAdding: .day, value: dayOffset, to: Date()) else { return nil }
        return cal.date(bySettingHour: reminderMinutes / 60,
                        minute: reminderMinutes % 60, second: 0, of: day)
    }
}
