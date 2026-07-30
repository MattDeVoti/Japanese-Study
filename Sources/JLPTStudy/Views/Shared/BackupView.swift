import SwiftUI
import UniformTypeIdentifiers

/// Backup and restore. Presented from the options sheet.
struct BackupView: View {
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showImporter = false
    @State private var pending: DataTransferService.Preview?
    @State private var importError: String?
    @State private var restored = false

    var body: some View {
        List {
            Section {
                if let url = exportURL {
                    ShareLink(item: url) {
                        Label("Share backup file", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    makeBackup()
                } label: {
                    Label(exportURL == nil ? "Create backup" : "Create a fresh backup",
                          systemImage: "arrow.down.doc")
                }
                if let exportError {
                    Text(exportError)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            } header: {
                Label("Back up", systemImage: "externaldrive")
            } footer: {
                Text("Saves your progress, review schedule, custom lessons, favourites and settings into one file. Keep it somewhere off the phone — deleting the app erases everything, and there's no account to restore from.")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Restore from a backup", systemImage: "arrow.up.doc")
                }
                if let importError {
                    Text(importError)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            } header: {
                Label("Restore", systemImage: "clock.arrow.circlepath")
            } footer: {
                Text("Replaces everything currently on this device. You'll see what's in the file before anything changes.")
            }

            Section {
                let s = DataTransferService.summary()
                row("Scheduled for review", s["scheduled"] ?? 0)
                row("Completed points", s["completedPoints"] ?? 0)
                row("Favourites", s["favouritePoints"] ?? 0)
                row("Custom lessons", s["customLessons"] ?? 0)
            } header: {
                Text("On this device")
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json, .data],
                      allowsMultipleSelection: false) { result in
            importError = nil
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                // A picked file lives outside the sandbox until opened.
                let needsScope = url.startAccessingSecurityScopedResource()
                defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                do { pending = try DataTransferService.inspect(url) }
                catch { importError = error.localizedDescription }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Restore this backup?", isPresented: Binding(
            get: { pending != nil },
            set: { if !$0 { pending = nil } }
        ), presenting: pending) { preview in
            Button("Replace everything", role: .destructive) {
                do {
                    try DataTransferService.restore(preview)
                    restored = true
                } catch {
                    importError = error.localizedDescription
                }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: { preview in
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            let s = preview.summary
            return Text("From \(f.string(from: preview.exportedAt)).\n\n"
                        + "\(s["scheduled"] ?? 0) scheduled for review, "
                        + "\(s["completedPoints"] ?? 0) completed points, "
                        + "\(s["customLessons"] ?? 0) custom lessons.\n\n"
                        + "Everything on this device will be replaced.")
        }
        .alert("Restored", isPresented: $restored) {
            Button("OK") {}
        } message: {
            Text("Quit and reopen Omedetou to finish loading the restored data.")
        }
    }

    private func row(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .foregroundColor(.appTextSecondary)
                .monospacedDigit()
        }
    }

    private func makeBackup() {
        exportError = nil
        do { exportURL = try DataTransferService.exportBundle() }
        catch { exportError = error.localizedDescription }
    }
}
