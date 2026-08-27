@testable import Logging

import Foundation
import Testing

@Suite
struct LogWriterTests {

    @Test
    func test_record_roundTripsThroughTheFile() async {
        let writer = LogWriter(directory: Self.temporaryDirectory())

        await writer.record("getDocuments failed: 500", level: .error, category: .api)
        let entries = await writer.entries()

        #expect(entries.count == 1)
        #expect(entries.first?.level == .error)
        #expect(entries.first?.category == .api)
        #expect(entries.first?.message == "getDocuments failed: 500")
    }

    @Test
    func test_entries_areNewestFirst() async {
        let writer = LogWriter(directory: Self.temporaryDirectory())
        let start = Date(timeIntervalSince1970: 1_000_000)

        await writer.record("first", level: .info, category: .api, date: start)
        await writer.record("second", level: .info, category: .api, date: start.addingTimeInterval(60))

        let entries = await writer.entries()

        #expect(entries.map(\.message) == ["second", "first"])
    }

    // A message containing double spaces would break a naive column split, and messages come from
    // error descriptions nobody controls.
    @Test
    func test_record_survivesAMessageContainingTheColumnSeparator() async {
        let writer = LogWriter(directory: Self.temporaryDirectory())

        await writer.record("failed:  two spaces  inside", level: .warning, category: .storage)
        let entries = await writer.entries()

        #expect(entries.first?.message == "failed:  two spaces  inside")
    }

    @Test
    func test_rotation_doesNotHappenBelowTheLimit() async {
        let directory = Self.temporaryDirectory()
        let writer = LogWriter(directory: directory, maximumSize: 100_000)

        await writer.record("small", level: .info, category: .api)

        #expect(await writer.fileURLs().count == 1)
    }

    @Test
    func test_rotation_keepsTheOlderFileReadable() async {
        let directory = Self.temporaryDirectory()
        // Small enough that the second line forces a rotation.
        let writer = LogWriter(directory: directory, maximumSize: 120)

        await writer.record("first line, which fills the file", level: .info, category: .api)
        await writer.record("second line, after the rotation", level: .info, category: .api)

        let urls = await writer.fileURLs()
        let entries = await writer.entries()

        #expect(urls.count == 2)
        // Both are still readable: a user who hits a bug today keeps yesterday's context.
        #expect(entries.map(\.message).sorted() == [
            "first line, which fills the file",
            "second line, after the rotation",
        ])
    }

    @Test
    func test_clear_removesEverything() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumSize: 120)

        await writer.record("first line, which fills the file", level: .info, category: .api)
        await writer.record("second line, after the rotation", level: .info, category: .api)
        await writer.clear()

        #expect(await writer.entries().isEmpty)
        #expect(await writer.fileURLs().isEmpty)
    }

    private static func temporaryDirectory() -> URL {
        URL.temporaryDirectory.appending(path: "LogWriterTests-\(UUID().uuidString)")
    }
}
