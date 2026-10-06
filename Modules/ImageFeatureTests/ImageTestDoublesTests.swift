@testable import ImageFeature

import Foundation
import Nuke
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct ImageTestDoublesTests {

    @Test
    func testImageLoader_reportsAFailure() {
        let loader = TestImageLoader(result: .failure(URLError(.networkConnectionLost)))
        let received = LockBox<Error?>()

        let cancellable = loader.loadData(
            with: URLRequest(url: URL(string: "https://paperless.example.com/thumb/")!),
            didReceiveData: { _, _ in Issue.record("a failure must not deliver data") },
            completion: { received.set($0) }
        )

        #expect(cancellable is AnyCancellable)
        #expect((received.get() as? URLError)?.code == .networkConnectionLost)
    }

    @Test
    func testImageLoader_deliversASuccess() {
        let loader = TestImageLoader()
        let received = LockBox<Data>()
        let completed = LockBox<Error?>()

        _ = loader.loadData(
            with: URLRequest(url: URL(string: "https://paperless.example.com/thumb/")!),
            didReceiveData: { data, _ in received.set(data) },
            completion: { completed.set($0) }
        )

        #expect(!received.get().isEmpty)
        #expect(completed.get() == nil)
    }

    @Test
    func testImageLoader_staysSilentWithoutAResult() {
        let loader = TestImageLoader(result: nil)
        let delivered = LockBox(initially: false)

        _ = loader.loadData(
            with: URLRequest(url: URL(string: "https://paperless.example.com/thumb/")!),
            didReceiveData: { _, _ in delivered.set(true) },
            completion: { _ in delivered.set(true) }
        )

        #expect(!delivered.get())
    }

    @Test
    func testImageCache_servesItsImage() {
        let cache = TestImageCache()

        #expect(cache[.testValue()]?.image != nil)
    }

    @Test
    func testImageCache_answersNilWithoutAnImage() {
        let cache = TestImageCache(image: nil)

        #expect(cache[.testValue()] == nil)
    }

    @Test
    func testImageCache_toleratesWritesAndAClear() {
        let cache = TestImageCache()

        cache[.testValue()] = nil
        cache.removeAll()

        #expect(cache[.testValue()]?.image != nil)
    }

    @Test
    func anyCancellable_runsItsClosureOnCancel() {
        let ran = LockBox(initially: false)

        AnyCancellable { ran.set(true) }.cancel()

        #expect(ran.get())
    }
}

private extension Nuke.ImageCacheKey {

    static func testValue() -> Self {
        .init(key: "test")
    }
}

private final class LockBox<Value>: @unchecked Sendable {

    init(initially value: Value) where Value == Bool {
        self.value = value
    }

    init() where Value == Data {
        value = Data()
    }

    init() where Value == Error? {
        value = nil
    }

    func set(_ value: Value) {
        lock.withLock { self.value = value }
    }

    func get() -> Value {
        lock.withLock { value }
    }

    private let lock = NSLock()

    private var value: Value
}
