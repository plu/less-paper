import ApiInterface
import Foundation
import Testing

@testable import ApiImplementation
import TestSupport

@Suite(
    .testDependencies()
)
struct OfflineStorageMigrationTests {

    // A directory per test: swift-testing runs a suite's tests in parallel, and these all write.
    private static func directory() throws -> URL {
        let url = URL.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }

    @Test
    func movesTheRecordFileAndThePdfDirectory() async throws {
        let directory = try Self.directory()
        try Self.write("[]", to: directory.appending(component: "7-favorites.json"))
        try Self.write("%PDF", to: directory.appending(path: "Favorites/7/42.pdf"))

        OfflineStorageMigration.run(in: directory)

        let manager = FileManager.default
        #expect(manager.fileExists(atPath: directory.appending(component: "7-offline.json").path))
        #expect(manager.fileExists(atPath: directory.appending(path: "Offline/7/42.pdf").path))
        #expect(!manager.fileExists(atPath: directory.appending(component: "7-favorites.json").path))
        #expect(!manager.fileExists(atPath: directory.appending(path: "Favorites").path))
    }

    // Review Focus 4. One directory move carries every server's PDFs, but the JSON files are one
    // per server and are found by suffix - so a loop that stopped at the first would strand the
    // rest, and nothing would say so.
    @Test
    func movesEveryServersRecordFile() async throws {
        let directory = try Self.directory()
        try Self.write("[]", to: directory.appending(component: "7-favorites.json"))
        try Self.write("[]", to: directory.appending(component: "9-favorites.json"))
        try Self.write("%PDF", to: directory.appending(path: "Favorites/7/1.pdf"))
        try Self.write("%PDF", to: directory.appending(path: "Favorites/9/2.pdf"))

        OfflineStorageMigration.run(in: directory)

        let manager = FileManager.default
        #expect(manager.fileExists(atPath: directory.appending(component: "7-offline.json").path))
        #expect(manager.fileExists(atPath: directory.appending(component: "9-offline.json").path))
        #expect(manager.fileExists(atPath: directory.appending(path: "Offline/7/1.pdf").path))
        #expect(manager.fileExists(atPath: directory.appending(path: "Offline/9/2.pdf").path))
    }

    // Review Focus 1. Every launch runs this.
    @Test
    func runningTwiceChangesNothing() async throws {
        let directory = try Self.directory()
        try Self.write("[{\"id\":1}]", to: directory.appending(component: "7-favorites.json"))
        try Self.write("%PDF", to: directory.appending(path: "Favorites/7/42.pdf"))

        OfflineStorageMigration.run(in: directory)
        OfflineStorageMigration.run(in: directory)

        let records = directory.appending(component: "7-offline.json")
        #expect(try Data(contentsOf: records) == Data("[{\"id\":1}]".utf8))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Offline/7/42.pdf").path))
    }

    // Review Focus 2. A downgrade writes the legacy paths again beside data the new ones already
    // hold. The new path is the one the app reads, so it wins - and the legacy file is left where
    // it is rather than overwritten, because destroying it is the one outcome nobody can undo.
    @Test
    func aNewPathThatAlreadyHasDataIsNotOverwritten() async throws {
        let directory = try Self.directory()
        try Self.write("legacy", to: directory.appending(component: "7-favorites.json"))
        try Self.write("current", to: directory.appending(component: "7-offline.json"))

        OfflineStorageMigration.run(in: directory)

        #expect(try Data(contentsOf: directory.appending(component: "7-offline.json"))
            == Data("current".utf8))
        #expect(try Data(contentsOf: directory.appending(component: "7-favorites.json"))
            == Data("legacy".utf8))
    }

    // Review Focus 3. The ordinary case for every new install, on every launch.
    @Test
    func aDirectoryWithNothingToMigrateIsLeftAlone() async throws {
        let directory = try Self.directory()

        OfflineStorageMigration.run(in: directory)

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        #expect(contents.isEmpty)
    }

    // The half of the downgrade case the record-file test does not reach. A downgrade writes the
    // legacy paths again beside data the new ones already hold: `Offline/7` survives an earlier
    // migration while the old build stores server 9 under `Favorites/9`. Moving the directory
    // wholesale skips - `Offline` exists - and strands server 9's PDFs while its record file moves
    // across on its own, which is an Offline list whose documents cannot be opened.
    @Test
    func aLegacyDirectoryIsMergedIntoOneThatAlreadyExists() async throws {
        let directory = try Self.directory()
        try Self.write("%PDF migrated", to: directory.appending(path: "Offline/7/42.pdf"))
        try Self.write("%PDF from the old build", to: directory.appending(path: "Favorites/9/1.pdf"))
        try Self.write("[]", to: directory.appending(component: "9-favorites.json"))

        OfflineStorageMigration.run(in: directory)

        let manager = FileManager.default
        #expect(manager.fileExists(atPath: directory.appending(path: "Offline/9/1.pdf").path))
        #expect(manager.fileExists(atPath: directory.appending(component: "9-offline.json").path))
        #expect(try Data(contentsOf: directory.appending(path: "Offline/7/42.pdf"))
            == Data("%PDF migrated".utf8))
    }

    // Same rule one level down: a server that exists at both paths keeps what the new path holds,
    // and its legacy directory is left standing rather than deleted.
    @Test
    func aServerAtBothPathsKeepsTheMigratedCopy() async throws {
        let directory = try Self.directory()
        try Self.write("%PDF migrated", to: directory.appending(path: "Offline/7/42.pdf"))
        try Self.write("%PDF stale", to: directory.appending(path: "Favorites/7/42.pdf"))

        OfflineStorageMigration.run(in: directory)

        #expect(try Data(contentsOf: directory.appending(path: "Offline/7/42.pdf"))
            == Data("%PDF migrated".utf8))
        #expect(try Data(contentsOf: directory.appending(path: "Favorites/7/42.pdf"))
            == Data("%PDF stale".utf8))
    }
}
