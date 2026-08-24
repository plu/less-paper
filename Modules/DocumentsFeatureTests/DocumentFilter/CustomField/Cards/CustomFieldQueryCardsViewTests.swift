@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct CustomFieldQueryCardsViewTests {

    @Test(
        arguments: [
            ("empty", CustomFieldQuery?.none, true),
            ("conditions", nested, true),
            ("deep", deep, true),
            ("negatedGroup", .negation(.group(.and, [
                .atom(.init(field: 3, op: .exists, value: .bool(true)))
            ])), true),
            ("atomLimit", .group(.and, (1 ... 5).map {
                .atom(.init(field: .init(rawValue: $0), op: .exists, value: .bool(true)))
            }), true),
            ("noCustomFields", nil, false),
        ]
    )
    func snapshot(name: String, query: CustomFieldQuery?, hasFields: Bool) async throws {
        let state = CustomFieldQueryCardsReducer.State.testValue(
            fields: hasFields ? IdentifiedArray(uniqueElements: [CustomField].previewValue) : [],
            query: query
        )

        assertSnapshot(
            of: CustomFieldQueryCardsView(
                store: Store(initialState: state) {
                    CustomFieldQueryCardsReducer()
                }
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: name
        )
    }
}

// File scope rather than statics on the suite: the suite is `@MainActor`, and a `@Test`
// `arguments:` expression is evaluated outside that isolation.
private let nested = CustomFieldQuery.group(.and, [
    .atom(.init(field: 4, op: .gt, value: .number(100))),
    .negation(.atom(.init(field: 3, op: .exists, value: .bool(true)))),
    .group(.or, [
        .atom(.init(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou"))),
        .atom(.init(field: 2, op: .gte, value: .string("2026-09-01")))
    ])
])

// Depth 4 is the limit, and the innermost card's width on a small phone is the specific thing this
// variant is being judged on.
private let deep = CustomFieldQuery.group(.and, [
    .atom(.init(field: 1, op: .icontains, value: .string("a"))),
    .group(.or, [
        .group(.and, [
            .group(.or, [
                .atom(.init(field: 4, op: .gt, value: .number(100)))
            ])
        ])
    ])
])
