@testable import PdfPasswordsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.getPdfPasswords.execute = { [] }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct PdfPasswordListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: NavigationStack { PdfPasswordListView(
                store: Store(
                    initialState: .testValue(pdfPasswords: [
                        PdfPassword.testValue(filename: "bank-statement.pdf", id: "1", password: "s3cr3t"),
                        PdfPassword.testValue(filename: "payslip-2026-08.pdf", id: "2", password: "hunter2")
                    ]),
                    reducer: {
                        PdfPasswordListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: NavigationStack { PdfPasswordListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        PdfPasswordListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }
}
