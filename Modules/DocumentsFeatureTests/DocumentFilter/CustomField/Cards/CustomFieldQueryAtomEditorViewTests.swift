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
struct CustomFieldQueryAtomEditorViewTests {

    @Test(
        arguments: [
            ("string", CustomFieldQuery.Atom(field: 1, op: .icontains, value: .string("invoice"))),
            ("boolean", .init(field: 3, op: .exists, value: .bool(true))),
            ("booleanOff", .init(field: 3, op: .exists, value: .bool(false))),
            ("number", .init(field: 4, op: .gt, value: .number(100))),
            ("date", .init(field: 2, op: .gte, value: .string("2026-09-01"))),
            ("select", .init(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou"))),
            ("selectSubsetEmpty", .init(field: 5, op: .in, value: .array([]))),
            ("selectSubset", .init(
                field: 5,
                op: .in,
                value: .array([.string("aqgT3m4XZw8aw3Ou"), .string("MOddUdj2nhfCEsqp")])
            )),
            // A saved view can name an option the field no longer has.
            ("selectUnknownOption", .init(field: 5, op: .exact, value: .string("gone"))),
        ]
    )
    func snapshot(name: String, atom: CustomFieldQuery.Atom) async throws {
        assertSnapshot(
            of: CustomFieldQueryAtomEditorView(
                editor: .init(atom: atom, path: [0]),
                fields: IdentifiedArray(uniqueElements: [CustomField].previewValue),
                onViewAction: { _ in }
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: name
        )
    }

    @Test(
        arguments: [
            ("none", Set<String>()),
            ("some", Set(["aqgT3m4XZw8aw3Ou"])),
            ("all", Set(["aqgT3m4XZw8aw3Ou", "MOddUdj2nhfCEsqp"])),
        ]
    )
    func optionsSnapshot(name: String, selected: Set<String>) async throws {
        let fields = IdentifiedArray(uniqueElements: [CustomField].previewValue)

        assertSnapshot(
            of: CustomFieldQuerySelectOptionsView(
                field: fields[id: 5],
                onViewAction: { _ in },
                selected: selected
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: name
        )
    }
}
