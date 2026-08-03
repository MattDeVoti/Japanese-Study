import Foundation

// Shared Codable helpers so every service/store uses one decode/encode path
// instead of repeating the `url → Data → JSONDecoder` and `data(forKey:)` dance.

extension Bundle {
    /// Decode a bundled JSON resource, returning nil if it's missing or malformed.
    func decodeJSON<T: Decodable>(_ type: T.Type, resource: String, ext: String = "json") -> T? {
        guard let url = url(forResource: resource, withExtension: ext),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

extension UserDefaults {
    /// Decode a JSON-encoded value stored under `key`, or nil if absent/malformed.
    func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// JSON-encode and store a value under `key` (no-op if encoding fails).
    func encode<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) { set(data, forKey: key) }
    }
}
