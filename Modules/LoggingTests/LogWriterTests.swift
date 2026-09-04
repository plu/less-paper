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
    func test_clear_removesEverything() async {
        let writer = LogWriter(directory: Self.temporaryDirectory())

        await writer.record("first line, which fills the file", level: .info, category: .api)
        await writer.record("second line, after the rotation", level: .info, category: .api)
        await writer.clear()

        #expect(await writer.entries().isEmpty)
        #expect(await writer.fileURLs().isEmpty)
    }

    @Test
    func test_record_keepsEveryLineBelowTheTrimThreshold() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumLines: 10)

        for index in 1 ... 10 {
            await writer.record("line \(index)", level: .info, category: .api)
        }

        #expect(await writer.entries().count == 10)
    }

    // The trim fires above maximumLines + 10%, not at maximumLines: rewriting the file on every
    // write past the cap is what the high-water mark exists to avoid.
    @Test
    func test_record_trimsToTheCapOnceTheThresholdIsCrossed() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumLines: 10)
        let start = Date(timeIntervalSince1970: 1_000_000)

        for index in 1 ... 12 {
            await writer.record(
                "line \(index)",
                level: .info,
                category: .api,
                date: start.addingTimeInterval(TimeInterval(index))
            )
        }

        let entries = await writer.entries()

        #expect(entries.count == 10)
        #expect(entries.first?.message == "line 12")
        #expect(entries.last?.message == "line 3")
        #expect(!entries.contains { $0.message == "line 1" })
    }

    @Test
    func test_record_leavesTheFileParseableAfterATrim() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumLines: 10)

        for index in 1 ... 12 {
            await writer.record("line \(index)", level: .warning, category: .storage)
        }

        let entries = await writer.entries()

        #expect(entries.allSatisfy { $0.level == .warning })
        #expect(entries.allSatisfy { $0.category == .storage })
    }

    @Test
    func test_fileURLs_returnsASingleFile() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumLines: 10)

        for index in 1 ... 12 {
            await writer.record("line \(index)", level: .info, category: .api)
        }

        #expect(await writer.fileURLs().count == 1)
    }

    // A writer created against a directory that already holds a log must not start counting from
    // zero, or the file grows without bound across launches - which is the whole bug this replaces.
    @Test
    func test_record_countsLinesAlreadyOnDiskFromAPreviousLaunch() async {
        let directory = Self.temporaryDirectory()

        let first = LogWriter(directory: directory, maximumLines: 10)
        for index in 1 ... 9 {
            await first.record("old \(index)", level: .info, category: .api)
        }

        let second = LogWriter(directory: directory, maximumLines: 10)
        for index in 1 ... 3 {
            await second.record("new \(index)", level: .info, category: .api)
        }

        #expect(await second.entries().count == 10)
    }

    // A failed trim must not be trusted as a successful one: appending to the already-open file
    // still succeeds when the directory is read-only, but the atomic rewrite the trim needs (which
    // creates a temp file in that directory) does not - this is what forces the desync in the first
    // place. Restoring permissions afterwards proves the writer recounts from disk and re-enforces
    // the cap rather than staying wedged above it.
    @Test
    func test_record_recoversAfterATrimFails() async {
        let directory = Self.temporaryDirectory()
        let writer = LogWriter(directory: directory, maximumLines: 10)

        for index in 1 ... 11 {
            await writer.record("line \(index)", level: .info, category: .api)
        }

        Self.setDirectoryWritable(directory, false)
        await writer.record("line 12", level: .info, category: .api)
        Self.setDirectoryWritable(directory, true)

        // The trim above the threshold failed, so the untrimmed file is still on disk.
        #expect(await writer.entries().count == 12)

        // lineCount was reset to nil on the failed trim, so this write recounts from disk instead
        // of trusting the stale count, and the cap is re-enforced.
        await writer.record("line 13", level: .info, category: .api)
        let entries = await writer.entries()

        #expect(entries.count == 10)
        #expect(entries.first?.message == "line 13")
    }

    private static func setDirectoryWritable(_ directory: URL, _ writable: Bool) {
        try? FileManager.default.setAttributes(
            [.posixPermissions: writable ? 0o700 : 0o500],
            ofItemAtPath: directory.path()
        )
    }

    private static func temporaryDirectory() -> URL {
        URL.temporaryDirectory.appending(path: "LogWriterTests-\(UUID().uuidString)")
    }
}
