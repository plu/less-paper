@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.apiCache.customField = { id, _ in
            guard let id else {
                return nil
            }
            return customFieldFixtures[id: id]
        }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentFormCustomFieldsViewTests {

    @Test(
        arguments: [
            ("noneDefined", "cfNoneDefined", [CustomField](), [DocumentFormCustomField]()),
            ("noneAttached", "cfNoneAttached", customFieldFixtures.elements, []),
            ("simpleTypes", "cfSimple", customFieldFixtures.elements, [
                DocumentFormCustomField(id: 1, value: .text("Invoice 2026-08")),
                DocumentFormCustomField(
                    id: 2,
                    value: .date(Date(timeIntervalSince1970: 1_787_529_600))
                ),
                DocumentFormCustomField(id: 3, value: .boolean(true)),
                DocumentFormCustomField(id: 7, value: .number("12")),
            ]),
            ("unsetDate", "cfUnsetDate", customFieldFixtures.elements, [
                DocumentFormCustomField(id: 2, value: .date(nil)),
            ]),
            ("invalidNumber", "cfInvalid", customFieldFixtures.elements, [
                DocumentFormCustomField(id: 7, value: .number("abc")),
            ]),
            ("unsupported", "cfUnsupported", customFieldFixtures.elements, [
                DocumentFormCustomField(id: 8, value: .unsupported(.string("something new"))),
            ]),
            ("richTypes", "cfRich", customFieldFixtures.elements, [
                DocumentFormCustomField(id: 4, value: .monetary(currency: "EUR", amount: "1234.50")),
                DocumentFormCustomField(id: 5, value: .select("aqgT3m4XZw8aw3Ou")),
                DocumentFormCustomField(id: 6, value: .documentLink([2, 3])),
            ]),
            ("richTypesEmpty", "cfRichEmpty", customFieldFixtures.elements, [
                DocumentFormCustomField(id: 4, value: .monetary(currency: "EUR", amount: "")),
                DocumentFormCustomField(id: 5, value: .select(nil)),
                DocumentFormCustomField(id: 6, value: .documentLink([])),
            ]),
            ("invalidAmount", "cfInvalidAmount", customFieldFixtures.elements, [
                DocumentFormCustomField(id: 4, value: .monetary(currency: "EUR", amount: "1.234")),
            ]),
        ]
    )
    func snapshot(
        name: String,
        serverId: String,
        definitions: [CustomField],
        attached: [DocumentFormCustomField]
    ) async throws {
        var state = DocumentFormReducer.State.testValue(
            customFields: IdentifiedArray(uniqueElements: definitions),
            section: .customFields,
            server: .testValue(id: serverId)
        )
        state.input.customFields = IdentifiedArray(uniqueElements: attached)
        state.linkedCustomFieldDocuments = [
            .testValue(id: 2, title: "Invoice 2026-07"),
            .testValue(id: 3, title: "Delivery note"),
        ]

        assertSnapshot(
            of: DocumentFormView(
                store: Store(initialState: state) {
                    EmptyReducer()
                }
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: name
        )
    }
}
