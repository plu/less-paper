@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentCustomFieldsViewTests {

    @Test(
        arguments: [
            ("empty", "cfvEmpty", [DocumentCustomField]()),
            ("plainTypes", "cfvPlain", [
                DocumentCustomField(field: 1, value: .string("Invoice 2026-08")),
                DocumentCustomField(field: 3, value: .bool(true)),
                DocumentCustomField(field: 7, value: .number(12)),
            ]),
            ("links", "cfvLinks", [
                DocumentCustomField(field: 6, value: .array([.number(2), .number(3)])),
            ]),
            ("mixed", "cfvMixed", [
                DocumentCustomField(field: 1, value: .string("Invoice 2026-08")),
                DocumentCustomField(field: 6, value: .array([.number(2)])),
            ]),
        ]
    )
    func snapshot(
        name: String,
        serverId: String,
        fields: [DocumentCustomField]
    ) async throws {
        let server = Server.testValue(id: serverId)
        var state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(customFields: fields, id: 1),
            server: server
        )
        state.$customFields.withLock { $0 = customFieldFixtures }
        // onAppear does not fire under ImageRenderer, so the resolved titles are seeded directly.
        // Without this every snapshot would show the unresolved "#id" capsule.
        state.linkedDocuments = [
            .testValue(id: 2, title: "Contract"),
            .testValue(id: 3, title: "Appendix"),
        ]

        let store = Store(initialState: state) {
            DocumentCustomFieldsReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { @Sendable _, _ in
                [
                    .testValue(id: 2, title: "Contract"),
                    .testValue(id: 3, title: "Appendix"),
                ]
            }
        }

        assertSnapshot(
            of: DocumentCustomFieldsView(store: store),
            as: .image(layout: .device(config: .iPhone12)),
            named: name
        )
    }
}
