@testable import ApiInterface

import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct ApiCacheTests {

    @Test
    func correspondent_hit() async throws {
        @Shared(.correspondents(.testValue()))
        var correspondents: IdentifiedArrayOf<Correspondent> = [.testValue()]
        let cache = ApiCache.liveValue

        let result = cache.correspondent(
            id: 1,
            server: .testValue()
        )

        #expect(result == .testValue())
    }

    @Test
    func correspondent_miss() async throws {
        let cache = ApiCache.liveValue

        let result = cache.correspondent(
            id: 999,
            server: .testValue()
        )

        #expect(result == nil)
    }

    @Test
    func documentType_hit() async throws {
        @Shared(.documentTypes(.testValue()))
        var documentTypes: IdentifiedArrayOf<DocumentType> = [.testValue()]
        let cache = ApiCache.liveValue

        let result = cache.documentType(
            id: 1,
            server: .testValue()
        )

        #expect(result == .testValue())
    }

    @Test
    func documentType_miss() async throws {
        let cache = ApiCache.liveValue

        let result = cache.documentType(
            id: 999,
            server: .testValue()
        )

        #expect(result == nil)
    }

    @Test
    func group_hit() async throws {
        @Shared(.groups(.testValue()))
        var groups: IdentifiedArrayOf<Group> = [.testValue()]
        let cache = ApiCache.liveValue

        let result = cache.group(
            id: 1,
            server: .testValue()
        )

        #expect(result == .testValue())
    }

    @Test
    func group_miss() async throws {
        let cache = ApiCache.liveValue

        let result = cache.group(
            id: 999,
            server: .testValue()
        )

        #expect(result == nil)
    }

    @Test
    func storagePath_hit() async throws {
        @Shared(.storagePaths(.testValue()))
        var storagePaths: IdentifiedArrayOf<StoragePath> = [.testValue()]
        let cache = ApiCache.liveValue

        let result = cache.storagePath(
            id: 1,
            server: .testValue()
        )

        #expect(result == .testValue())
    }

    @Test
    func storagePath_miss() async throws {
        let cache = ApiCache.liveValue

        let result = cache.storagePath(
            id: 999,
            server: .testValue()
        )

        #expect(result == nil)
    }

    @Test
    func tag_hit() async throws {
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [.testValue()]
        let cache = ApiCache.liveValue

        let result = cache.tag(
            id: 1,
            server: .testValue()
        )

        #expect(result == .testValue())
    }

    @Test
    func tag_miss() async throws {
        let cache = ApiCache.liveValue

        let result = cache.tag(
            id: 999,
            server: .testValue()
        )

        #expect(result == nil)
    }

    @Test
    func user_hit() async throws {
        @Shared(.users(.testValue()))
        var tags: IdentifiedArrayOf<User> = [.testValue()]
        let cache = ApiCache.liveValue

        let result = cache.user(
            id: 1,
            server: .testValue()
        )

        #expect(result == .testValue())
    }

    @Test
    func user_miss() async throws {
        let cache = ApiCache.liveValue

        let result = cache.user(
            id: 999,
            server: .testValue()
        )

        #expect(result == nil)
    }
}
