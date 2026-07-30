import Foundation

// Durable, atomic JSON storage in Application Support.
//
// UserDefaults was never meant to hold the app's whole study history: it's a
// preferences plist, it's read wholesale into memory, and it offers no atomicity
// so a crash mid-write can lose the lot. Everything meaningful now lives in its
// own file under Application Support, which is included in device and iCloud
// *backups*, so a restore brings progress back.

enum FileStore {
    /// Application Support/JLPTStudy — created on first use.
    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("JLPTStudy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func url(_ name: String) -> URL {
        directory.appendingPathComponent("\(name).json")
    }

    static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    /// Atomic write — a partially written file can never replace a good one.
    static func save<T: Encodable>(_ value: T, _ name: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(name), options: .atomic)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }

    static func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(name).path)
    }

    /// Every file this store manages, for export.
    static func allFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory,
                                                     includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "json" } ?? []
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
