import Foundation

// Export and restore everything the app remembers as one file.
//
// Deleting the app takes every byte of progress with it, and there is no account
// to fall back on. A file the user holds is the only backup that survives a wiped
// phone, and it doubles as the way to move to a new device.
//
// The payload is a property list of the app's UserDefaults plus every FileStore
// document, base64'd inside a small JSON envelope. Going through plist
// serialisation keeps the original types exactly — Data stays Data, Int stays Int
// — which hand-rolled JSON mapping would not.

enum DataTransferService {

    static let fileExtension = "omedetou"
    private static let formatVersion = 1

    /// Keys owned by the system or other frameworks, which must not travel.
    private static let systemPrefixes = [
        "Apple", "NS", "com.apple", "AK", "PK", "WebKit", "INNext", "MSV",
        "AddingEmojiKeybordHandled", "KeyboardAutocapitalization", "TextInput",
    ]

    fileprivate struct Envelope: Codable {
        var app: String
        var formatVersion: Int
        var appVersion: String?
        var exportedAt: Date
        /// Base64 binary plist of the app's own UserDefaults keys.
        var defaults: String
        /// Base64 of each FileStore document, keyed by file name.
        var files: [String: String]
        /// Purely informational, shown in the restore confirmation.
        var summary: [String: Int]
    }

    // MARK: - Export

    /// Writes a backup into a temporary file and returns its URL, ready for sharing.
    static func exportBundle() throws -> URL {
        var defaults: [String: Any] = [:]
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            guard isOwnKey(key), PropertyListSerialization.propertyList(value, isValidFor: .binary)
            else { continue }
            defaults[key] = value
        }
        let plist = try PropertyListSerialization.data(fromPropertyList: defaults,
                                                      format: .binary, options: 0)

        var files: [String: String] = [:]
        for url in FileStore.allFiles() {
            if let data = try? Data(contentsOf: url) {
                files[url.lastPathComponent] = data.base64EncodedString()
            }
        }

        let envelope = Envelope(
            app: "Omedetou",
            formatVersion: formatVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            exportedAt: Date(),
            defaults: plist.base64EncodedString(),
            files: files,
            summary: summary()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(envelope)

        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withYear, .withMonth, .withDay]
        let name = "Omedetou-\(stamp.string(from: Date())).\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Counts worth showing before someone overwrites their progress.
    static func summary() -> [String: Int] {
        [
            "scheduled": SRSStore.shared.enrolledCount,
            "completedPoints": LessonsProgressStore.shared.completed.count,
            "favouritePoints": LessonsProgressStore.shared.favorites.count,
            "customLessons": CustomLessonsStore.shared.lessons.count,
        ]
    }

    // MARK: - Import

    struct Preview {
        let exportedAt: Date
        let appVersion: String?
        let summary: [String: Int]
        fileprivate let envelope: Envelope
    }

    /// Parses and validates a backup without applying it, so the user can see what
    /// they're about to overwrite.
    static func inspect(_ url: URL) throws -> Preview {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(Envelope.self, from: data)
        guard envelope.app == "Omedetou" else {
            throw Failure.notOurs
        }
        guard envelope.formatVersion <= formatVersion else {
            throw Failure.tooNew
        }
        guard Data(base64Encoded: envelope.defaults) != nil else {
            throw Failure.corrupt
        }
        return Preview(exportedAt: envelope.exportedAt, appVersion: envelope.appVersion,
                       summary: envelope.summary, envelope: envelope)
    }

    /// Applies a previously inspected backup. Everything is replaced, not merged —
    /// merging two divergent review schedules would produce a state neither device
    /// had. The app must be relaunched afterwards for the singletons to reload.
    static func restore(_ preview: Preview) throws {
        let envelope = preview.envelope
        guard let plistData = Data(base64Encoded: envelope.defaults),
              let plist = try PropertyListSerialization.propertyList(
                from: plistData, options: [], format: nil) as? [String: Any]
        else { throw Failure.corrupt }

        // Clear the app's own keys first so keys absent from the backup don't linger.
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where isOwnKey(key) {
            defaults.removeObject(forKey: key)
        }
        for (key, value) in plist where isOwnKey(key) {
            defaults.set(value, forKey: key)
        }

        for url in FileStore.allFiles() {
            try? FileManager.default.removeItem(at: url)
        }
        for (name, base64) in envelope.files {
            // Never let a crafted file name escape the store directory.
            let safe = (name as NSString).lastPathComponent
            guard !safe.isEmpty, safe.hasSuffix(".json"),
                  let data = Data(base64Encoded: base64) else { continue }
            let target = FileStore.url((safe as NSString).deletingPathExtension)
            try? data.write(to: target, options: .atomic)
        }
    }

    private static func isOwnKey(_ key: String) -> Bool {
        !systemPrefixes.contains { key.hasPrefix($0) }
    }

    enum Failure: LocalizedError {
        case notOurs, tooNew, corrupt

        var errorDescription: String? {
            switch self {
            case .notOurs: return "That file isn't an Omedetou backup."
            case .tooNew:  return "That backup was made by a newer version of the app."
            case .corrupt: return "That backup is damaged and can't be read."
            }
        }
    }
}
