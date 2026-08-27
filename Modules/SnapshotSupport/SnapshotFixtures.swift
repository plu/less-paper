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

    // The catalogues the German screenshots rename. Correspondents are not among them: those are
    // names rather than words.

    public static func customFields() -> [CustomField] {
        load("custom_fields")
    }

    public static func documentTypes(in corpus: SnapshotConfiguration.Corpus) -> [DocumentType] {
        load("document_types", renaming: corpus.localized)
    }

    public static func savedViews() -> [SavedView] {
        load("saved_views")
    }

    public static func storagePaths(in corpus: SnapshotConfiguration.Corpus) -> [StoragePath] {
        load("storage_paths", renaming: corpus.localized)
    }

    public static func tags(in corpus: SnapshotConfiguration.Corpus) -> [Tag] {
        load("tags", renaming: corpus.localized)
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

    private static func load<Value: Decodable>(
        _ name: String,
        renaming: ((String) -> String)? = nil
    ) -> [Value] {
        let url = fixturesDirectory.appending(path: "\(name).json")
        guard var data = try? Data(contentsOf: url) else {
            reportIssue("Missing screenshot fixture \(name).json. Run Screenshots/fetch_fixtures.py.")
            return []
        }

        // Renaming the payload rather than the decoded value: name is a let on every one of these
        // models, and rebuilding them would mean repeating an initialiser per type.
        if let renaming {
            data = renamed(data, by: renaming) ?? data
        }

        do {
            return try JSONDecoder.apiDecoder.decode([Value].self, from: data)
        } catch {
            reportIssue("Could not decode screenshot fixture \(name).json: \(error)")
            return []
        }
    }

    private static func renamed(
        _ data: Data,
        by renaming: (String) -> String
    ) -> Data? {
        guard let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        let renamedObjects = objects.map { object -> [String: Any] in
            guard let name = object["name"] as? String else {
                return object
            }
            var object = object
            object["name"] = renaming(name)
            return object
        }

        return try? JSONSerialization.data(withJSONObject: renamedObjects)
    }
}
#endif
