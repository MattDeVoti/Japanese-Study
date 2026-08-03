import Foundation
import SQLite3

final class DictionaryService: ObservableObject {
    static let shared = DictionaryService()

    enum SortOrder { case english, japanese }

    private var db: OpaquePointer?
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init() {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "db"),
              sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            db = nil
            return
        }
    }

    deinit { sqlite3_close(db) }

    // MARK: - Browse (paginated)

    /// Every entry, for the word games. Cached by the caller — this is a full
    /// table scan and shouldn't be run per frame.
    func allEntries() -> [DictionaryEntry] {
        run("SELECT id,word,reading,definitions,parts_of_speech,sort_key_en,sort_key_jp "
            + "FROM entries", [])
    }

    func browse(offset: Int, limit: Int = 100, sort: SortOrder = .english) -> [DictionaryEntry] {
        let orderBy = (sort == .english) ? "sort_key_en" : "sort_key_jp"
        return run(
            "SELECT id,word,reading,definitions,parts_of_speech,sort_key_en,sort_key_jp FROM entries ORDER BY \(orderBy) LIMIT ? OFFSET ?",
            [limit, offset]
        )
    }

    /// Every entry `ConjugationEngine` can inflect — the pool the conjugation
    /// drills draw from. Cached because it's a full-table scan over ~4k rows.
    private var conjugableCache: [DictionaryEntry]?

    func conjugableEntries() -> [DictionaryEntry] {
        if let c = conjugableCache { return c }
        let kinds = ["godan verb", "ichidan verb", "suru verb", "kuru verb",
                     "i-adjective", "na-adjective"]
        let clause = kinds.map { _ in "parts_of_speech LIKE ?" }.joined(separator: " OR ")
        let rows = run(
            "SELECT id,word,reading,definitions,parts_of_speech,sort_key_en,sort_key_jp "
            + "FROM entries WHERE \(clause)",
            kinds.map { "%\($0)%" }
        )
        // Keep only the ones that really produce forms; a few entries carry the tag
        // but have a shape the engine declines to inflect.
        let usable = rows.filter {
            ConjugationEngine.conjugate(word: $0.word, reading: $0.reading,
                                        partsOfSpeech: $0.partsOfSpeech) != nil
        }
        conjugableCache = usable
        return usable
    }

    // MARK: - Search

    // Auto-detects Japanese vs English by character range.
    func searchCombined(_ query: String, limit: Int = 60) -> [DictionaryEntry] {
        guard !query.isEmpty else { return [] }
        let hasJapanese = query.unicodeScalars.contains { $0.value >= 0x3000 }
        return hasJapanese ? search(prefix: query, limit: limit) : searchEN(query, limit: limit)
    }

    // Japanese prefix search on word or reading column.
    func search(prefix: String, limit: Int = 60) -> [DictionaryEntry] {
        guard !prefix.isEmpty else { return [] }
        let q = prefix + "%"
        return run(
            "SELECT id,word,reading,definitions,parts_of_speech,sort_key_en,sort_key_jp FROM entries WHERE word LIKE ? OR reading LIKE ? ORDER BY LENGTH(word) LIMIT ?",
            [q, q, limit]
        )
    }

    // English substring search on definitions JSON text.
    func searchEN(_ query: String, limit: Int = 60) -> [DictionaryEntry] {
        let q = "%\(query.lowercased())%"
        return run(
            "SELECT id,word,reading,definitions,parts_of_speech,sort_key_en,sort_key_jp FROM entries WHERE LOWER(definitions) LIKE ? ORDER BY LENGTH(definitions) LIMIT ?",
            [q, limit]
        )
    }

    // Exact match on word or reading.
    func lookup(_ text: String) -> [DictionaryEntry] {
        run("SELECT id,word,reading,definitions,parts_of_speech,sort_key_en,sort_key_jp FROM entries WHERE word=? OR reading=? LIMIT 30",
            [text, text])
    }

    // Best single entry for a vocab word: prefer an exact word+reading match,
    // then the richest match on the written form. (We deliberately do NOT fall
    // back to a reading-only match, which could return a different homophone —
    // e.g. 科学 → 化学. Words with no written-form match get their own entry.)
    func entry(word: String, reading: String?) -> DictionaryEntry? {
        let cols = "id,word,reading,definitions,parts_of_speech,sort_key_en,sort_key_jp"
        if let reading, reading != word,
           let e = run("SELECT \(cols) FROM entries WHERE word=? AND reading=? LIMIT 1", [word, reading]).first {
            return e
        }
        return run("SELECT \(cols) FROM entries WHERE word=? ORDER BY LENGTH(definitions) DESC LIMIT 1", [word]).first
    }

    /// Exact entry by row id — used where something already knows which entry
    /// it means and must not risk matching a homophone.
    func entry(id: Int) -> DictionaryEntry? {
        let cols = "id,word,reading,definitions,parts_of_speech,sort_key_en,sort_key_jp"
        return run("SELECT \(cols) FROM entries WHERE id=? LIMIT 1", [id]).first
    }

    // MARK: - Letter boundaries (for A-Z index bar)

    // Returns a dict of first-char → cumulative row offset in EN sort order.
    // Digits/symbols are keyed as "#".
    func letterBoundaries() -> [String: Int] {
        guard let db else { return [:] }
        let sql = """
            SELECT LOWER(SUBSTR(sort_key_en,1,1)) AS ch, COUNT(*) AS cnt
            FROM entries
            WHERE sort_key_en != ''
            GROUP BY ch ORDER BY ch
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }

        var result: [String: Int] = [:]
        var cumulative = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ch = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            let key = (ch.first?.isLetter == true) ? ch : "#"
            if result[key] == nil { result[key] = cumulative }
            cumulative += count
        }
        return result
    }

    // MARK: - Kana boundaries (for kana index bar)

    // Returns a dict of first-char → cumulative row offset in Japanese sort order.
    func kanaBoundaries() -> [String: Int] {
        guard let db else { return [:] }
        let sql = """
            SELECT SUBSTR(sort_key_jp, 1, 1) AS ch, COUNT(*) AS cnt
            FROM entries
            WHERE sort_key_jp != ''
            GROUP BY ch ORDER BY sort_key_jp
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }

        var result: [String: Int] = [:]
        var cumulative = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ch = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            result[ch] = cumulative
            cumulative += count
        }
        return result
    }

    // MARK: - Favorites

    private let favKey = "DictionaryFavorites"

    private var favoriteIds: Set<Int> {
        Set(UserDefaults.standard.array(forKey: favKey) as? [Int] ?? [])
    }

    func isFavorite(id: Int) -> Bool { favoriteIds.contains(id) }

    @discardableResult
    func toggleFavorite(id: Int) -> Bool {
        var favs = favoriteIds
        let next = !favs.contains(id)
        if next { favs.insert(id) } else { favs.remove(id) }
        UserDefaults.standard.set(Array(favs), forKey: favKey)
        objectWillChange.send()
        return next
    }

    // MARK: - Private

    private func run(_ sql: String, _ params: [Any]) -> [DictionaryEntry] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        for (i, p) in params.enumerated() {
            let col = Int32(i + 1)
            switch p {
            case let s as String: sqlite3_bind_text(stmt, col, s, -1, SQLITE_TRANSIENT)
            case let n as Int:    sqlite3_bind_int64(stmt, col, Int64(n))
            default: break
            }
        }

        var results: [DictionaryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id         = Int(sqlite3_column_int64(stmt, 0))
            let word       = String(cString: sqlite3_column_text(stmt, 1))
            let reading    = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let defsText   = String(cString: sqlite3_column_text(stmt, 3))
            let posText    = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "[]"
            let sortKeyEn  = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
            let sortKeyJp  = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""
            let defs       = decode([String].self, from: defsText) ?? []
            let pos        = decode([String].self, from: posText)  ?? []
            results.append(DictionaryEntry(id: id, word: word, reading: reading,
                                           definitions: defs, partsOfSpeech: pos,
                                           sortKeyEn: sortKeyEn, sortKeyJp: sortKeyJp))
        }
        return results
    }

    private func decode<T: Decodable>(_ type: T.Type, from text: String) -> T? {
        try? JSONDecoder().decode(T.self, from: Data(text.utf8))
    }
}
