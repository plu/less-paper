@testable import ImageFeature

import Dependencies
import Nuke
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentImageTests {
    @Test
    func testSnapshot_success() async throws {
        assertSnapshot(
            of: DocumentImage.testValue(),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        withDependencies {
            $0.imagePipeline = .loadingValue
        } operation: {
            assertSnapshot(
                of: DocumentImage.testValue(),
                as: .image(layout: .device(config: .iPhone12))
            )
        }
    }
}
