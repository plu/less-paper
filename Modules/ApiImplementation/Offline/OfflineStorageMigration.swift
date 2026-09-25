import ApiInterface
import Foundation

// Favorites became Offline, and the two paths carrying the old name hold the user's downloaded
// PDFs. Getting this wrong does not throw: the list comes up empty, and the bytes stay on disk
// where nothing will ever read or reclaim them.
//
// No server list is needed, which is the point - this runs before anything that could supply one.
// Every server's PDFs sit inside one `Favorites` directory, so moving it moves all of them, and
// the per-server record files are found by suffix.
public enum OfflineStorageMigration {

    public static func run(in directory: URL = .applicationGroupDirectory) {
        let manager = FileManager.default
        let legacyDirectory = directory.appending(component: "Favorites")
        let offlineDirectory = directory.appending(component: "Offline")

        // One server at a time rather than the whole directory at once. Moving it wholesale would
        // skip as soon as `Offline` exists, which is exactly what a downgrade leaves behind: one
        // server migrated by an earlier launch, another written under the old name by the old
        // build. The second server's record file would still move across on its own - its
        // destination being free - and the list would come up full of documents whose PDFs are not
        // there.
        let legacyServers = (try? manager.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        if !legacyServers.isEmpty {
            try? manager.createDirectory(at: offlineDirectory, withIntermediateDirectories: true)
        }

        for server in legacyServers {
            move(server, to: offlineDirectory.appending(component: server.lastPathComponent))
        }

        // Removed only once it is empty. `move` skips a server that already exists at the new path,
        // and deleting what it skipped is the one outcome nobody can undo.
        if let remaining = try? manager.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: nil
        ), remaining.isEmpty {
            try? manager.removeItem(at: legacyDirectory)
        }

        let contents = (try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        for url in contents where url.lastPathComponent.hasSuffix("-favorites.json") {
            let renamed = url.lastPathComponent
                .replacingOccurrences(of: "-favorites.json", with: "-offline.json")
            move(url, to: directory.appending(component: renamed))
        }
    }

    // A destination that already exists means this has run before, or that a downgrade wrote the
    // legacy path again beside data the new one already holds. The new path is what the app reads,
    // so it wins and the legacy file is left standing: keeping a file nobody reads costs disk, and
    // overwriting the wrong one costs documents.
    //
    // Nothing here throws. A file that cannot be moved must not stop the app from launching.
    private static func move(_ source: URL, to destination: URL) {
        let manager = FileManager.default
        guard manager.fileExists(atPath: source.path),
              !manager.fileExists(atPath: destination.path)
        else {
            return
        }
        try? manager.moveItem(at: source, to: destination)
    }
}
