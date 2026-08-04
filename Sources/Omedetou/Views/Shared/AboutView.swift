import SwiftUI

// About & Sources.
//
// This screen exists because the dictionary data is licensed, not because an
// app needs an about page. JMdict/EDICT and KANJIDIC are published by the
// Electronic Dictionary Research and Development Group under CC BY-SA 4.0, and
// that licence sets out specifically how a phone app must credit them:
// acknowledgement on a screen reached from a menu, with links to the source and
// licence. It says in as many words that mentioning it only on a launch screen
// is not enough — hence a real screen, reachable from Options.
//
// The licence does NOT require the app itself to be open source, and places no
// restriction on selling it. Share-alike covers the dictionary data and things
// derived from it, not the software that reads it.

private struct DataSource: Decodable {
    let name: String
    let usedFor: String
    let licence: String
    let projectURL: String
    let upstreamVersion: String
    let retrievedOn: String
}

struct AboutView: View {
    /// Read from data_sources.json so the screen always states what is actually
    /// bundled, rather than a number someone remembered to update by hand.
    private var sources: [DataSource] {
        guard let url = Bundle.main.url(forResource: "data_sources", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode([String: [DataSource]].self, from: raw)
        else { return [] }
        return wrapper["sources"] ?? []
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Omedetou")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appText)
                    Spacer()
                    Text(version)
                        .font(.system(size: 15).monospacedDigit())
                        .foregroundColor(.appTextSecondary)
                }
            } footer: {
                Text("A Japanese study app — textbook, flashcards, graded tests and a dictionary, all on your device.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("The dictionary and kanji information in this app come from the JMdict/EDICT and KANJIDIC projects.")
                        .font(.system(size: 14))
                        .foregroundColor(.appText)
                    Text("These files are copyright © the Electronic Dictionary Research and Development Group and are used under the Creative Commons Attribution-ShareAlike 4.0 licence. This app claims no copyright over that material.")
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.vertical, 4)

                ForEach(sources, id: \.name) { src in
                    HStack(alignment: .firstTextBaseline) {
                        Text(src.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appText)
                        Spacer()
                        Text(src.upstreamVersion == "unknown"
                             ? "version not recorded"
                             : "\(src.upstreamVersion) · \(src.retrievedOn)")
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                    }
                }

                Link(destination: URL(string: "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project")!) {
                    Label("JMdict / EDICT project", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project")!) {
                    Label("KANJIDIC project", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://www.edrdg.org/edrdg/licence.html")!) {
                    Label("EDRDG licence", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!) {
                    Label("CC BY-SA 4.0", systemImage: "arrow.up.right.square")
                }
            } header: {
                Label("Dictionary data", systemImage: "character.book.closed.fill")
            } footer: {
                Text("The Electronic Dictionary Research and Development Group does not endorse this app.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Everything you do stays on this device.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appText)
                    Text("There are no accounts, no analytics, and no third-party services. Your progress is written to this device's storage and nowhere else. If you turn on iCloud sync, it is copied to your own private iCloud, which only you can read.")
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.vertical, 4)
            } header: {
                Label("Privacy", systemImage: "lock.fill")
            }
        }
        .standardNavBar("About & Sources")
    }
}
