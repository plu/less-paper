@testable import LicensesFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct LicenseViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: LicenseView(license: .testValue()),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
