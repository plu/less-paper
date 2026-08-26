#if DEBUG
import ApiInterface
import Foundation
import IssueReporting

// The payloads under Screenshots/Fixtures are the raw API responses, downloaded once from the
// seeded dev instance by Screenshots/fetch_fixtures.py. Decoding them with the same decoder the
// app uses keeps the fixtures honest: anything the real decoder would reject fails here too.
//
// They are read from the repository rather than bundled, so nothing screenshot-shaped ships in a
// release build. That limits screenshot mode to a simulator, which is where it runs anyway.
public enum SnapshotFixtures {

    public static func correspondents() -> [Correspondent] {
        load("correspondents")
    }

    public static func customFields() -> [CustomField] {
        load("custom_fields")
    }

    public static func documentTypes() -> [DocumentType] {
        load("document_types")
    }

    public static func savedViews() -> [SavedView] {
        load("saved_views")
    }

    public static func storagePaths() -> [StoragePath] {
        load("storage_paths")
    }

    public static func tags() -> [Tag] {
        load("tags")
    }

    // Every document the instance holds. A corpus narrows this down; the catalogues above stay
    // whole, because a real server's tag and correspondent lists are not filtered by language
    // either and the settings screens read better full.
    public static func documents() -> [Document] {
        load("documents")
    }

    public static func thumbnail(for document: Document.Id) -> Data? {
        try? Data(contentsOf: thumbnailsDirectory.appending(path: "\(document).webp"))
    }

    // MARK: - Private

    private static var fixturesDirectory: URL {
        URL.projectRoot.appending(path: "Screenshots/Fixtures")
    }

    private static var thumbnailsDirectory: URL {
        URL.projectRoot.appending(path: "Screenshots/Thumbnails")
    }

    private static func load<Value: Decodable>(_ name: String) -> [Value] {
        let url = fixturesDirectory.appending(path: "\(name).json")
        guard let data = try? Data(contentsOf: url) else {
            reportIssue("Missing screenshot fixture \(name).json. Run Screenshots/fetch_fixtures.py.")
            return []
        }

        do {
            return try JSONDecoder.apiDecoder.decode([Value].self, from: data)
        } catch {
            reportIssue("Could not decode screenshot fixture \(name).json: \(error)")
            return []
        }
    }
}
#endif
