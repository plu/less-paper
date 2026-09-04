@testable import ImageFeature

import Foundation
import Logging
import Testing

@Suite
struct ImageCacheUsageTests {

    @Test
    func test_testValue_isZero() async {
        #expect(await ImageCacheUsage.testValue.read() == .zero)
    }

    // Nuke's totalSize and totalCount both walk the cache directory, so this must never be called
    // from a path that blocks a launch. The assertion here is only that it answers.
    @Test
    func test_liveValue_answersWithoutThrowing() async {
        let usage = await ImageCacheUsage.liveValue.read()

        #expect(usage.bytes >= 0)
        #expect(usage.fileCount >= 0)
    }
}
