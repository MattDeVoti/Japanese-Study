import Foundation

// TEMPORARY — one-time bring-over of progress from the build that used the old
// bundle id.
//
// To remove once the data is across, delete: this file, the two `LegacyImport`
// lines in OmedetouApp.swift, and the Info.plist keys marked "backup hand-off".
// Nothing else refers to it, and removing it can't affect data already imported
// — the import writes into the app's ordinary storage and this code only ever
// puts data in, never holds it.
//
// Why this exists, and why it can't be a folder fix:
//
// The rename changed the bundle identifier from com.mattdevoti1.jlptstudy to
// com.mattdevoti1.omedetou. iOS keys an app's entire sandbox to that
// identifier, so the new build didn't upgrade the old one — it installed
// alongside it. Both are on the phone, with the same name and icon, and the old
// one still holds every byte of progress in a container this process is not
// permitted to open. No path change, entitlement or migration reaches across
// it; App Groups only share what was deliberately written into a group
// container, and the old build only ever put the widget's word list there.
//
// So the data has to leave the old app as a file. It already can: that build
// carries the same Backup ▸ Export screen, and the format is unchanged — the
// envelope has said "Omedetou" since before the rename. This side is automatic:
// hand the file over once and the next launch applies it without a prompt.
//
// Runs from OmedetouApp.init(), before any store singleton has been touched, so
// the restored state is already on disk by the time anything reads it. That's
// what makes a relaunch unnecessary on the launch path.

enum LegacyImport {

    /// A one-line note for the alert shown on the next screen. Written *after*
    /// the restore, because a restore clears the app's own defaults on its way
    /// in and would erase anything written before it.
    static let reportKey = "LegacyImportReport"

    // MARK: - Launch

    static func runIfNeeded() {
        guard let file = newestBackup() else { return }
        do {
            let preview = try DataTransferService.inspect(file)
            try DataTransferService.restore(preview)
            UserDefaults.standard.set(describe(preview), forKey: reportKey)
            retire(file, as: "imported")
        } catch {
            UserDefaults.standard.set(
                "Couldn't import \(file.lastPathComponent) — \(error.localizedDescription)",
                forKey: reportKey)
            // Renamed either way: a file that fails once fails identically every
            // launch, and an error on every cold start is worse than none.
            retire(file, as: "failed")
        }
    }

    /// Everywhere this app is allowed to find a handed-over file: its own
    /// Documents (visible in Files as "On My iPhone ▸ Omedetou"), and the Inbox
    /// that "Open in Omedetou" drops into.
    private static func searchPaths() -> [URL] {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return [] }
        return [docs, docs.appendingPathComponent("Inbox", isDirectory: true)]
    }

    private static func newestBackup() -> URL? {
        let fm = FileManager.default
        let found = searchPaths().flatMap { dir -> [URL] in
            (try? fm.contentsOfDirectory(at: dir,
                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                         options: [.skipsHiddenFiles])) ?? []
        }
        .filter { $0.pathExtension.lowercased() == DataTransferService.fileExtension }

        // Newest wins, so re-exporting from the old app and dropping the new
        // file in does the obvious thing.
        return found.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return a > b
        }.first
    }

    /// Renames rather than deletes — while both apps are installed this file is
    /// a second copy of everything, and destroying it silently would be
    /// unforgivable if the restore turned out to be wrong.
    private static func retire(_ url: URL, as suffix: String) {
        let target = url.deletingPathExtension()
            .appendingPathExtension("\(DataTransferService.fileExtension).\(suffix)")
        try? FileManager.default.moveItem(at: url, to: target)
    }

    private static func describe(_ preview: DataTransferService.Preview) -> String {
        let when = DateFormatter()
        when.dateStyle = .medium
        when.timeStyle = .short
        let counts = preview.summary
        var parts: [String] = []
        if let n = counts["scheduled"], n > 0 { parts.append("\(n) scheduled items") }
        if let n = counts["completedPoints"], n > 0 { parts.append("\(n) completed points") }
        if let n = counts["favouritePoints"], n > 0 { parts.append("\(n) favourites") }
        if let n = counts["customLessons"], n > 0 { parts.append("\(n) custom lessons") }
        let what = parts.isEmpty ? "your progress" : parts.joined(separator: ", ")
        return "Restored \(what) from the backup made \(when.string(from: preview.exportedAt))."
    }

    // MARK: - A file handed to the app while it's running

    /// Takes a backup opened from Files, AirDrop or a share sheet. Copied into
    /// Documents and applied at the next launch rather than immediately: the
    /// stores are already loaded by this point, and swapping the data underneath
    /// them would leave the running app showing a mix of both.
    ///
    /// Returns true when the URL was ours, so the caller doesn't also try to
    /// read it as a deep link.
    static func accept(_ url: URL) -> Bool {
        guard url.isFileURL,
              url.pathExtension.lowercased() == DataTransferService.fileExtension,
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return false }

        // Files opened in place live outside the sandbox and need the scope held
        // open for the length of the read.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let target = docs.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.copyItem(at: url, to: target)
            UserDefaults.standard.set("Backup received. Reopen Omedetou to finish importing it.",
                                      forKey: reportKey)
        } catch {
            UserDefaults.standard.set("Couldn't read that backup — \(error.localizedDescription)",
                                      forKey: reportKey)
        }
        return true
    }

    // MARK: - Reporting

    /// Reads and clears the note, so it's shown exactly once.
    static func takeReport() -> String? {
        let defaults = UserDefaults.standard
        guard let note = defaults.string(forKey: reportKey) else { return nil }
        defaults.removeObject(forKey: reportKey)
        return note
    }
}
