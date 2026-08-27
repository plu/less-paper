import Foundation

/// Removes anything that would turn a diagnostic file into a credential.
///
/// A denylist, which is the weaker kind of defence - so the stronger one is upstream: request and
/// response bodies are never written at all. That leaves only URLs and header names, both of which
/// can be enumerated, and both of which are covered here.
public enum LogRedaction {

    public static let placeholder = "<redacted>"

    /// Query items whose value is never written. Matched case-insensitively, and by containment, so
    /// `auth_token` and `X-Api-Key` are caught along with the exact spellings.
    static let sensitiveKeys = [
        "auth",
        "cookie",
        "credential",
        "key",
        "password",
        "secret",
        "session",
        "signature",
        "token",
    ]

    /// A URL reduced to what is diagnostic: host, path, and query keys with harmless values kept.
    ///
    /// The path is kept whole - `/api/documents/42/` is the question being asked - and so is a
    /// pagination or ordering value, which is usually the difference between a working request and
    /// a failing one.
    public static func redact(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.path()
        }

        components.queryItems = components.queryItems?.map { item in
            isSensitive(item.name) ? URLQueryItem(name: item.name, value: placeholder) : item
        }

        let path = components.path.isEmpty ? "/" : components.path
        guard let query = components.query, !query.isEmpty else {
            return path
        }
        return "\(path)?\(query)"
    }

    /// Header names only. Values are never logged, whatever the header is - the name alone answers
    /// "was this request authenticated at all", which is the only question a log needs to settle.
    public static func redact(headers: [String: String]) -> [String] {
        headers.keys.sorted()
    }

    static func isSensitive(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return sensitiveKeys.contains { lowercased.contains($0) }
    }
}
