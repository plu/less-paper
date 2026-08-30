import ApiInterface
import Dependencies
import Foundation
import Testing

@Suite
struct FavoritesStoreTests {

    // A server per test, so the directories cannot collide. swift-testing runs a suite's tests in
    // parallel, and the byte-count test asserts an exact total over its whole directory — sharing
    // one server would make it flake whenever a sibling's file happened to exist.
    private static func server(_ name: String) -> Server {
        .testValue(id: "favorites-store-tests-\(name)")
    }

    @Test
    func test_writeThenReadThenDelete() async throws {
        let store = FavoritesStore.liveValue
        let server = Self.server("write-read-delete")
        let data = Data("%PDF-1.4 hello".utf8)

        let written = try await store.writePDF(data, 42, server)
        #expect(written == data.count)

        let url = store.pdfURL(42, server)
        #expect(try Data(contentsOf: url) == data)

        try await store.deletePDF(42, server)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    // A second write must replace the file rather than append to or fail over it: refresh
    // re-downloads into the same path.
    @Test
    func test_writeReplacesAnExistingFile() async throws {
        let store = FavoritesStore.liveValue
        let server = Self.server("write-replaces")

        _ = try await store.writePDF(Data(repeating: 0, count: 100), 43, server)
        let second = try await store.writePDF(Data(repeating: 1, count: 10), 43, server)

        #expect(second == 10)
        #expect(try Data(contentsOf: store.pdfURL(43, server)).count == 10)

        try await store.deletePDF(43, server)
    }

    @Test
    func test_totalByteCountSumsTheFilesAndDeleteAllClearsThem() async throws {
        let store = FavoritesStore.liveValue
        let server = Self.server("total-bytes")

        _ = try await store.writePDF(Data(repeating: 0, count: 300), 44, server)
        _ = try await store.writePDF(Data(repeating: 0, count: 700), 45, server)

        #expect(await store.totalByteCount(server) == 1000)

        try await store.deleteAll(server)

        #expect(await store.totalByteCount(server) == 0)
    }
}
