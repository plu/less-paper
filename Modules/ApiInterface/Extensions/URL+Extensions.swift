import Foundation

public extension URL {

    static var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func testValue(
        string: String = #bundle.infoDictionary?["PAPERLESS_TEST_URL"] as? String ?? "http://localhost:8000"
    ) -> URL {
        URL(string: string)!
    }

    static let empty = URL(string: "about:blank")!

    var hostAndPort: String? {
        guard let port else {
            return host()
        }
        return [host(), String(port)].compactMap(\.self).joined(separator: ":")
    }
}
