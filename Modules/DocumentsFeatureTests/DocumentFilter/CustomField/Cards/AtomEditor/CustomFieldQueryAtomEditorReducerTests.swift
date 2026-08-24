@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import CustomDump
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct CustomFieldQueryAtomEditorReducerTests {

    private static let fields = IdentifiedArray(uniqueElements: [CustomField].previewValue)

    private static let store = { (state: CustomFieldQueryAtomEditorReducer.State) in
        TestStore(initialState: state) {
            CustomFieldQueryAtomEditorReducer()
        }
    }

    private static func editing(_ atom: CustomFieldQuery.Atom) -> CustomFieldQueryAtomEditorReducer.State {
        .testValue(atom: atom, fields: fields)
    }

    @Test
    func changingTheFieldKeepsAnOperatorTheNewTypeStillAdmits() async {
        let store = Self.store(Self.editing(.init(field: 1, op: .icontains, value: .string("invoice"))))

        await store.send(.view(.fieldChanged(4))) {
            $0.atom = .init(field: 4, op: .icontains, value: .string("invoice"))
        }
        await store.receive(\.delegate.atomChanged, .init(field: 4, op: .icontains, value: .string("invoice")))
    }

    @Test
    func changingTheFieldResetsAnOperatorTheNewTypeRejects() async {
        let store = Self.store(Self.editing(.init(field: 1, op: .icontains, value: .string("a"))))

        await store.send(.view(.fieldChanged(3))) {
            $0.atom = .init(field: 3, op: .exists, value: .bool(true))
        }
        await store.receive(\.delegate.atomChanged, .init(field: 3, op: .exists, value: .bool(true)))
    }

    @Test
    func switchingASelectFieldToEqualToSeedsTheFirstOption() async {
        let store = Self.store(Self.editing(.init(field: 5, op: .exists, value: .bool(true))))

        await store.send(.view(.operatorChanged(.exact))) {
            $0.atom = .init(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou"))
        }
        await store.receive(
            \.delegate.atomChanged,
            .init(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou"))
        )
    }

    @Test
    func changingTheValueIsPublished() async {
        let store = Self.store(Self.editing(.init(field: 1, op: .icontains, value: .string(""))))

        await store.send(.view(.valueChanged(.string("invoice")))) {
            $0.atom = .init(field: 1, op: .icontains, value: .string("invoice"))
        }
        await store.receive(\.delegate.atomChanged, .init(field: 1, op: .icontains, value: .string("invoice")))
    }

    @Test
    func openingAndDismissingTheOptionSheet() async {
        let store = Self.store(Self.editing(.init(field: 5, op: .in, value: .array([]))))

        await store.send(.view(.optionsTapped)) {
            $0.isSelectingOptions = true
        }
        await store.send(.view(.optionsDismissed)) {
            $0.isSelectingOptions = false
        }
    }

    @Test
    func togglingAnOptionAddsAndRemovesIt() async {
        let store = Self.store(Self.editing(.init(field: 5, op: .in, value: .array([]))))

        await store.send(.view(.optionToggled("aqgT3m4XZw8aw3Ou"))) {
            $0.atom = .init(field: 5, op: .in, value: .array([.string("aqgT3m4XZw8aw3Ou")]))
        }
        await store.receive(
            \.delegate.atomChanged,
            .init(field: 5, op: .in, value: .array([.string("aqgT3m4XZw8aw3Ou")]))
        )

        await store.send(.view(.optionToggled("aqgT3m4XZw8aw3Ou"))) {
            $0.atom = .init(field: 5, op: .in, value: .array([]))
        }
        await store.receive(\.delegate.atomChanged, .init(field: 5, op: .in, value: .array([])))
    }

    // Set iteration order is not stable, so the emitted value has to be sorted or the same
    // selection would produce different JSON between openings of the sheet.
    @Test
    func selectedOptionsAreSorted() async {
        let store = Self.store(Self.editing(
            .init(field: 5, op: .in, value: .array([.string("MOddUdj2nhfCEsqp")]))
        ))

        await store.send(.view(.optionToggled("aqgT3m4XZw8aw3Ou"))) {
            $0.atom = .init(
                field: 5,
                op: .in,
                value: .array([.string("MOddUdj2nhfCEsqp"), .string("aqgT3m4XZw8aw3Ou")])
            )
        }
        await store.receive(
            \.delegate.atomChanged,
            .init(field: 5, op: .in, value: .array([.string("MOddUdj2nhfCEsqp"), .string("aqgT3m4XZw8aw3Ou")]))
        )
    }
}

@MainActor
@Suite(
    .dependencies()
)
struct CustomFieldQueryAtomEditorDocumentLinkTests {

    private static let fields: IdentifiedArrayOf<CustomField> = [
        .testValue(dataType: .documentLink, id: 6, name: "Link")
    ]

    @Test
    func openingALinkConditionResolvesItsDocumentTitles() async {
        let store = TestStore(
            initialState: .testValue(
                atom: .init(field: 6, op: .contains, value: .array([.number(10)])),
                fields: Self.fields
            )
        ) {
            CustomFieldQueryAtomEditorReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { @Sendable _, _ in [puky] }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.linkedDocumentsLoaded) {
            $0.linkedDocuments = [puky]
        }
    }

    @Test
    func aConditionWithNoLinkedDocumentsResolvesNothing() async {
        let store = TestStore(
            initialState: .testValue(
                atom: .init(field: 6, op: .contains, value: .array([])),
                fields: Self.fields
            )
        ) {
            CustomFieldQueryAtomEditorReducer()
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func aNonLinkConditionResolvesNothing() async {
        let store = TestStore(
            initialState: .testValue(atom: .init(field: 1, op: .icontains, value: .string("a")))
        ) {
            CustomFieldQueryAtomEditorReducer()
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func pickingDocumentsWritesTheirIdsAsNumbers() async {
        let store = TestStore(
            initialState: .testValue(
                atom: .init(field: 6, op: .contains, value: .array([])),
                fields: Self.fields
            )
        ) {
            CustomFieldQueryAtomEditorReducer()
        }

        await store.send(.view(.documentPickerTapped)) {
            $0.documentPicker = .init(selection: [], server: .testValue())
        }
        await store.send(.documentPicker(.presented(.delegate(.selectionChanged([10, 11]))))) {
            $0.atom = .init(field: 6, op: .contains, value: .array([.number(10), .number(11)]))
        }
        await store.receive(
            \.delegate.atomChanged,
            .init(field: 6, op: .contains, value: .array([.number(10), .number(11)]))
        )
    }
}

// File scope rather than a static on the suite: the suite is `@MainActor`, and a `@Sendable`
// dependency closure cannot reach main-actor-isolated state.
private let puky = Document.testValue(id: 10, title: "Puky-Locked")
