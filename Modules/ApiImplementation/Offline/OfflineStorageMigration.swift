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
        move(
            directory.appending(component: "Favorites"),
            to: directory.appending(component: "Offline")
        )

        let contents = (try? FileManager.default.contentsOfDirectory(
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
