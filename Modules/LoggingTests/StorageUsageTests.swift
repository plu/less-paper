@testable import Logging

import Foundation
import Testing

@Suite
struct StorageUsageTests {

    @Test
    func test_measure_sumsTheFilesInADirectory() throws {
        let directory = try Self.directory(withFiles: ["a": 100, "b": 250])

        let usage = StorageUsageClient.liveValue.measure([directory])

        #expect(usage.fileCount == 2)
        #expect(usage.bytes == 350)
    }

    @Test
    func test_measure_descendsIntoSubdirectories() throws {
        let directory = try Self.directory(withFiles: ["a": 100])
        let nested = directory.appending(path: "nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(count: 40).write(to: nested.appending(path: "b"))

        let usage = StorageUsageClient.liveValue.measure([directory])

        #expect(usage.fileCount == 2)
        #expect(usage.bytes == 140)
    }

    @Test
    func test_measure_acceptsIndividualFilesAsWellAsDirectories() throws {
        let directory = try Self.directory(withFiles: ["a": 100, "b": 250])

        let usage = StorageUsageClient.liveValue.measure([directory.appending(path: "a")])

        #expect(usage.fileCount == 1)
        #expect(usage.bytes == 100)
    }

    // A cache that has never been written is the normal state on first launch, and measuring it
    // must not be the thing that fails a launch line.
    @Test
    func test_measure_returnsZeroForAMissingPath() {
        let missing = URL.temporaryDirectory.appending(path: "absent-\(UUID().uuidString)")

        #expect(StorageUsageClient.liveValue.measure([missing]) == .zero)
    }

    @Test
    func test_measure_returnsZeroForNoPaths() {
        #expect(StorageUsageClient.liveValue.measure([]) == .zero)
    }

    // The log is read by whoever a user sends it to, not only by the user, so the units must not
    // change with the device's locale.
    @Test
    func test_formatted_isStableAcrossLocales() {
        #expect(StorageUsage(bytes: 1_200_000, fileCount: 14).formatted() == "1.2 MB / 14 files")
        #expect(StorageUsage(bytes: 1_200_000, fileCount: 1).formatted() == "1.2 MB / 1 file")
        #expect(StorageUsage(bytes: 0, fileCount: 0).formatted() == "Zero kB / 0 files")
    }

    private static func directory(withFiles files: [String: Int]) throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "StorageUsageTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, size) in files {
            try Data(count: size).write(to: directory.appending(path: name))
        }
        return directory
    }
}
