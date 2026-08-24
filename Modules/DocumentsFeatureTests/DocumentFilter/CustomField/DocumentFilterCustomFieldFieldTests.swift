@testable import DocumentsFeature

import ApiInterface
import IdentifiedCollections
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentFilterCustomFieldFieldTests {

    private static let fields = IdentifiedArray(uniqueElements: [CustomField].previewValue)

    @Test(
        arguments: [
            ("empty", CustomFieldQuery?.none),
            ("atom", .atom(.init(field: 4, op: .gt, value: .number(100)))),
            ("group", .group(.and, [
                .atom(.init(field: 4, op: .gt, value: .number(100))),
                .atom(.init(field: 3, op: .exists, value: .bool(true)))
            ])),
            ("nested", .group(.and, [
                .atom(.init(field: 4, op: .gt, value: .number(100))),
                .group(.or, [
                    .atom(.init(field: 3, op: .exists, value: .bool(true))),
                    .negation(.atom(.init(field: 2, op: .gte, value: .string("2026-09-01"))))
                ])
            ])),
            ("unknownField", .atom(.init(field: 999, op: .exists, value: .bool(true)))),
        ]
    )
    func snapshot(name: String, query: CustomFieldQuery?) async throws {
        assertSnapshot(
            of: DocumentFilterCustomFieldField(fields: Self.fields, query: query)
                .padding()
                .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: name
        )
    }
}
