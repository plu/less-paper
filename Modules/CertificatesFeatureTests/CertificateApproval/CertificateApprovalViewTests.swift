@testable import CertificatesFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct CertificateApprovalViewTests {
    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                CertificateApprovalView.testValue()
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
