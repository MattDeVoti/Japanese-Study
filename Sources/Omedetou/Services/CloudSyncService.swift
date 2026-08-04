import Foundation
import CloudKit
import Combine

// Study progress that follows you between devices, with no server to run.
//
// The private CloudKit database is stored against each user's own iCloud
// account, so it costs the developer nothing however many people use the app,
// and there is nothing to maintain. Apple does not hand us the data either.
//
// The app stays local-first: everything is written to disk first and works
// unchanged with no iCloud account at all. Sync is a second copy that catches
// up, never a dependency. If it fails, the failure is reported and nothing is
// lost — worst case you're back to the export file.
//
// Documents are stored as CKAssets rather than record fields on purpose: a
// record field caps out at 1 MB, and a heavy user's review schedule can reach
// most of that (roughly 180 bytes an item), so a long-time learner would start
// silently failing to sync at the worst possible moment.

/// Whether this build was signed with the iCloud entitlements.
///
/// This has to be a build-time switch, and it has to be checked. A free personal
/// Apple developer team cannot sign the iCloud capability at all — including it
/// makes the app impossible to install on a device — so the default entitlements
/// file leaves it out. And `CKContainer.default()` does not fail politely when
/// the entitlement is missing: it raises an Objective-C exception, which Swift
/// cannot catch. Since sync runs at launch, an unguarded call would crash the app
/// on the phone rather than degrade.
///
/// (Reading the entitlement at runtime would be nicer, but the API for that,
/// SecTaskCopyValueForEntitlement, is macOS-only.)
enum CloudCapability {
#if ICLOUD_SYNC
    static let hasICloud = true
    static let hasKeyValueStore = true
#else
    static let hasICloud = false
    static let hasKeyValueStore = false
#endif
}

@MainActor
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    enum Status: Equatable {
        case idle
        case syncing
        case ok(Date)
        case noAccount
        /// This build wasn't signed for iCloud — nothing is wrong, the feature
        /// simply isn't part of it.
        case unavailable
        case failed(String)

        var isBusy: Bool { self == .syncing }
    }

    @Published private(set) var status: Status = .idle
    /// Set once per launch so a failure isn't retried in a tight loop.
    private var syncing = false

    private let recordType = "StudyDocument"
    private var database: CKDatabase { CKContainer.default().privateCloudDatabase }

    private init() {}

    // MARK: - Entry points

    /// Safe to call on every foreground: it no-ops while a sync is in flight.
    func syncInBackground() {
        guard CloudCapability.hasICloud, !syncing else { return }
        Task { await sync() }
    }

    func sync() async {
        // Checked before anything touches CKContainer, which raises rather than
        // returning an error when the entitlement is absent.
        guard CloudCapability.hasICloud else {
            status = .unavailable
            return
        }
        guard !syncing else { return }
        syncing = true
        status = .syncing
        defer { syncing = false }

        do {
            let account = try await CKContainer.default().accountStatus()
            guard account == .available else {
                status = .noAccount
                return
            }
            try await syncSRS()
            try await syncExams()
            SettingsSync.shared.push()
            status = .ok(Date())
        } catch let e as CKError where e.code == .networkUnavailable || e.code == .networkFailure {
            status = .failed("No connection")
        } catch let e as CKError where e.code == .notAuthenticated {
            status = .noAccount
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - The two documents

    private func syncSRS() async throws {
        let store = SRSStore.shared
        try await reconcile(name: store.snapshotName,
                            local: store.snapshot(),
                            merge: SyncMerge.mergeSRS,
                            adopt: { store.adopt($0) })
    }

    private func syncExams() async throws {
        let store = ExamStore.shared
        try await reconcile(name: store.snapshotName,
                            local: store.snapshot(),
                            merge: SyncMerge.mergeExams,
                            adopt: { store.adopt($0) })
    }

    /// Fetch, merge, write back — the whole protocol for one document.
    private func reconcile<T: Codable>(
        name: String,
        local: T,
        merge: (T, T, SyncMerge.Newer) -> T,
        adopt: @MainActor (T) -> Void
    ) async throws {
        let id = CKRecord.ID(recordName: name)
        let localModified = FileStore.modifiedAt(name) ?? .distantPast

        var remoteRecord: CKRecord?
        do {
            remoteRecord = try await database.record(for: id)
        } catch let e as CKError where e.code == .unknownItem {
            remoteRecord = nil          // nothing up there yet
        }

        var merged = local
        if let record = remoteRecord, let remote: T = decode(record) {
            let newer: SyncMerge.Newer =
                (record.modificationDate ?? .distantPast) > localModified ? .remote : .local
            merged = merge(local, remote, newer)
            if !equalJSON(merged, local) { adopt(merged) }
            // Nothing new to send.
            if equalJSON(merged, remote) { return }
        }

        let record = remoteRecord ?? CKRecord(recordType: recordType, recordID: id)
        try attach(merged, to: record)

        do {
            _ = try await database.save(record)
        } catch let e as CKError where e.code == .serverRecordChanged {
            // Another device wrote between our fetch and our save. Merge onto
            // *their* record and try once more rather than overwriting them.
            guard let server = e.serverRecord else { throw e }
            if let theirs: T = decode(server) {
                let final = merge(merged, theirs, .local)
                if !equalJSON(final, merged) { adopt(final) }
                try attach(final, to: server)
            } else {
                try attach(merged, to: server)
            }
            _ = try await database.save(server)
        }
    }

    // MARK: - Payload

    private func attach<T: Encodable>(_ value: T, to record: CKRecord) throws {
        let data = try JSONEncoder.sync.encode(value)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sync-\(record.recordID.recordName)-\(UUID().uuidString).json")
        try data.write(to: tmp, options: .atomic)
        record["payload"] = CKAsset(fileURL: tmp)
        record["updatedAt"] = Date() as NSDate
    }

    private func decode<T: Decodable>(_ record: CKRecord) -> T? {
        guard let asset = record["payload"] as? CKAsset,
              let url = asset.fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.sync.decode(T.self, from: data)
    }

    /// Cheap structural comparison — the documents aren't Equatable and don't
    /// need to be, and encoding is deterministic with sorted keys.
    private func equalJSON<T: Encodable>(_ a: T, _ b: T) -> Bool {
        guard let x = try? JSONEncoder.sync.encode(a),
              let y = try? JSONEncoder.sync.encode(b) else { return false }
        return x == y
    }
}

extension JSONEncoder {
    /// Sorted keys so the same document always encodes to the same bytes, which
    /// is what makes "has anything actually changed?" answerable.
    static let sync: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let sync: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

// MARK: - Settings

/// Small preferences ride in iCloud's key-value store, which needs no schema and
/// no records. It caps at 1 MB total, which is nowhere near enough for the review
/// schedule but is ample for a handful of settings.
final class SettingsSync {
    static let shared = SettingsSync()

    /// Only keys that are genuinely the user's preference. Anything derived, or
    /// meaningful only on one device, stays local.
    private let keys = [
        "selectedThemeId",
        "UnlockedSecretGames",
        "KanjiInvadersHighScore",
        "ShiritoriBest",
    ]
    /// Scores are records, so the best of the two devices wins rather than the
    /// most recent.
    private let maxima = ["KanjiInvadersHighScore", "ShiritoriBest"]

    private let cloud = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    private init() {}

    func start() {
        guard CloudCapability.hasKeyValueStore else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud, queue: .main
        ) { [weak self] _ in self?.pull() }
        cloud.synchronize()
        pull()
    }

    func push() {
        guard CloudCapability.hasKeyValueStore else { return }
        let d = UserDefaults.standard
        for key in keys {
            if maxima.contains(key) {
                cloud.set(max(d.integer(forKey: key), Int(cloud.longLong(forKey: key))), forKey: key)
            } else if let v = d.object(forKey: key) {
                cloud.set(v, forKey: key)
            }
        }
        cloud.synchronize()
    }

    func pull() {
        guard CloudCapability.hasKeyValueStore else { return }
        let d = UserDefaults.standard
        for key in keys {
            guard let v = cloud.object(forKey: key) else { continue }
            if maxima.contains(key) {
                d.set(max(d.integer(forKey: key), Int(cloud.longLong(forKey: key))), forKey: key)
            } else {
                d.set(v, forKey: key)
            }
        }
        GameUnlocks.shared.reloadFromDefaults()
    }
}
