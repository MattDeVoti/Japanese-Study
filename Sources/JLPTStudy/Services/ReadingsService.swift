import Foundation

/// Loads reading-comprehension passages from `readings.json` (bundled).
final class ReadingsService {
    static let shared = ReadingsService()

    private(set) var readings: [Reading] = []
    private var loaded = false

    private init() {}

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let bundled = Bundle.main.decodeJSON([Reading].self, resource: "readings") {
            readings = bundled
            return
        }
        // Dev fallback: read straight from the source tree when unbundled.
        let devURL = URL(fileURLWithPath: "/Users/mattdevoti1/Documents/Claude Code/Japanese Study/Sources/JLPTStudy/Resources/readings.json")
        if let data = try? Data(contentsOf: devURL),
           let decoded = try? JSONDecoder().decode([Reading].self, from: data) {
            readings = decoded
        }
    }

    /// Readings for one JLPT level, sorted easiest → hardest.
    func readings(forLevel jlptLevel: String) -> [Reading] {
        readings.filter { $0.jlptLevel == jlptLevel }.sorted { $0.order < $1.order }
    }

    /// Distinct JLPT levels present, ordered N5 → N1 (easiest first).
    var levelsPresent: [String] {
        let order = ["N5", "N4", "N3", "N2", "N1"]
        let have = Set(readings.map(\.jlptLevel))
        return order.filter { have.contains($0) }
    }
}
