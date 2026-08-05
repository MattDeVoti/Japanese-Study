import Foundation
import UIKit

// Sends written feedback to the developer, without opening Mail.
//
// iOS gives an app no way to send email itself — the only built-in route is the
// mail composer, which hands the draft to the user. So the message goes to a
// form-relay service over HTTPS and the relay emails it on. The developer's
// address lives in that service's dashboard and never appears in this app or in
// anything shipped to a device.
//
// The alternative — SMTP straight from the app — would mean compiling a mailbox
// password into the binary, where `strings` on the IPA would find it. That is
// not a trade-off worth making for a feedback box.
//
// The only thing that leaves the device is what the user typed, plus the app and
// OS version so a bug report can be placed. No identifier, no name, no study
// data, nothing gathered in the background.

enum FeedbackService {

    // MARK: - Configuration

    /// Web3Forms access key — paste yours from https://web3forms.com here.
    ///
    /// This is a **public** key by design: it names one form, cannot read
    /// anything, and can only submit to that form. Form services expect it to
    /// sit in a web page's HTML, so shipping it inside an app is the intended
    /// use. It is not an email address and not a password.
    ///
    /// To move to a different relay (Formspree, FormSubmit), change this and
    /// `endpoint` — the rest of the file is service-agnostic.
    private static let accessKey = "057464e5-d789-4f33-92c4-2e0af39a2348"
    private static let endpoint = URL(string: "https://api.web3forms.com/submit")!

    /// False until a real key is pasted in, so the screen can say so plainly
    /// instead of failing with a network error the user can't act on.
    static var isConfigured: Bool {
        !accessKey.isEmpty && !accessKey.hasPrefix("PASTE_YOUR")
    }

    static let characterLimit = 2000

    // MARK: - Throttling
    //
    // A shipped app's form endpoint is public, so a stuck finger — or one
    // annoyed user — could fill an inbox. These caps are a courtesy to the
    // developer, not a security boundary; the relay does the real spam filtering.

    private static let minimumGap: TimeInterval = 30
    private static let dailyCap = 10
    private static let lastSentKey = "FeedbackLastSentAt"
    private static let dayCountKey = "FeedbackCountToday"
    private static let dayStampKey = "FeedbackCountDay"

    enum Failure: LocalizedError {
        case notConfigured
        case tooSoon(Int)
        case dailyCapReached
        case offline
        case rejected(String)
        case server

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Feedback isn't set up in this build yet."
            case .tooSoon(let seconds):
                return "Just a moment — you can send again in \(seconds)s."
            case .dailyCapReached:
                return "That's a lot of feedback for one day. Please try again tomorrow."
            case .offline:
                return "No connection. Your message hasn't been sent."
            case .rejected(let why):
                return why
            case .server:
                return "Couldn't reach the feedback service. Please try again later."
            }
        }
    }

    // MARK: - Sending

    static func send(_ raw: String) async throws {
        guard isConfigured else { throw Failure.notConfigured }

        let message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { throw Failure.rejected("Write something first.") }

        try checkThrottle()

        let defaults = UserDefaults.standard
        let body: [String: Any] = [
            "access_key": accessKey,
            "subject": "Omedetou Feedback",
            "from_name": "Omedetou app",
            "message": message,
            // Version context so a bug report can be placed. Deliberately not a
            // device identifier — this narrows down "which build", not "who".
            "app_version": Self.appVersion,
            "ios_version": UIDevice.current.systemVersion,
            // The relay's honeypot: bots fill it in, real clients leave it empty.
            "botcheck": "",
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .timedOut, .cannotConnectToHost, .cannotFindHost:
                throw Failure.offline
            default:
                throw Failure.server
            }
        } catch {
            throw Failure.server
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure.server
        }
        // The relay answers 200 with {"success": false} for a rejected form, so
        // the status code alone isn't enough to call it sent.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ok = json["success"] as? Bool, ok == false {
            throw Failure.rejected((json["message"] as? String) ?? "The message wasn't accepted.")
        }

        defaults.set(Date().timeIntervalSince1970, forKey: lastSentKey)
        defaults.set(todayCount() + 1, forKey: dayCountKey)
        defaults.set(todayStamp(), forKey: dayStampKey)
    }

    // MARK: - Helpers

    private static func checkThrottle() throws {
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: lastSentKey)
        if last > 0 {
            let elapsed = Date().timeIntervalSince1970 - last
            if elapsed < minimumGap { throw Failure.tooSoon(Int((minimumGap - elapsed).rounded(.up))) }
        }
        if todayCount() >= dailyCap { throw Failure.dailyCapReached }
    }

    private static func todayStamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func todayCount() -> Int {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: dayStampKey) == todayStamp() else { return 0 }
        return defaults.integer(forKey: dayCountKey)
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

