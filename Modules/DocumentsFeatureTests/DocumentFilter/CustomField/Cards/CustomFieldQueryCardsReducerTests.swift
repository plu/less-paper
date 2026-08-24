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
struct CustomFieldQueryCardsReducerTests {

    private static let store = { (state: CustomFieldQueryCardsReducer.State) in
        TestStore(initialState: state) {
            CustomFieldQueryCardsReducer()
        }
    }

    // A bare atom is a legal query, but the sheet needs a group to add siblings to.
    @Test
    func aBareAtomIsWrappedInAGroup() {
        let state = CustomFieldQueryCardsReducer.State.testValue(
            query: .atom(.init(field: 1, op: .exists, value: .bool(true)))
        )

        expectNoDifference(state.query, .group(.and, [.atom(.init(field: 1, op: .exists, value: .bool(true)))]))
    }

    @Test
    func anAbsentQueryStartsAsAnEmptyGroup() {
        expectNoDifference(CustomFieldQueryCardsReducer.State.testValue().query, .group(.and, []))
    }

    @Test
    func addingAConditionSeedsItAndOpensTheEditor() async {
        let store = Self.store(.testValue())

        await store.send(.view(.addConditionTapped([]))) {
            let atom = CustomFieldQuery.Atom(field: 1, op: .exists, value: .bool(true))
            $0.query = .group(.and, [.atom(atom)])
            $0.editor = .init(atom: atom, path: [0])
        }
    }

    @Test
    func addingAGroupNestsAnEmptyOne() async {
        let store = Self.store(.testValue())

        await store.send(.view(.addGroupTapped([]))) {
            $0.query = .group(.and, [.group(.and, [])])
        }
    }

    @Test
    func tappingAnAtomRowOpensTheEditor() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .exists, value: .bool(true))
        let store = Self.store(.testValue(query: .group(.and, [.atom(atom)])))

        await store.send(.view(.rowTapped([0]))) {
            $0.editor = .init(atom: atom, path: [0])
        }
    }

    // A negation is drawn as a modifier on the row it wraps, so the tap target is what is inside.
    @Test
    func tappingANegatedAtomRowEditsTheAtomInside() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .exists, value: .bool(true))
        let store = Self.store(.testValue(query: .group(.and, [.negation(.atom(atom))])))

        await store.send(.view(.rowTapped([0]))) {
            $0.editor = .init(atom: atom, path: [0, 0])
        }
    }

    @Test
    func changingTheFieldWritesThroughAndPublishes() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .icontains, value: .string("a"))
        let store = Self.store(.testValue(
            editor: .init(atom: atom, path: [0]),
            query: .group(.and, [.atom(atom)])
        ))

        await store.send(.view(.editorFieldChanged(2))) {
            let updated = CustomFieldQuery.Atom(field: 2, op: .exists, value: .bool(true))
            $0.editor?.atom = updated
            $0.query = .group(.and, [.atom(updated)])
        }
        await store.receive(\.delegate.filterUpdated, .group(.and, [.atom(.init(field: 2, op: .exists, value: .bool(true)))]))
    }

    @Test
    func changingTheValuePublishesThePrunedQuery() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .icontains, value: .string(""))
        let store = Self.store(.testValue(
            editor: .init(atom: atom, path: [0]),
            query: .group(.and, [.atom(atom)])
        ))

        await store.send(.view(.editorValueChanged(.string("invoice")))) {
            let updated = CustomFieldQuery.Atom(field: 1, op: .icontains, value: .string("invoice"))
            $0.editor?.atom = updated
            $0.query = .group(.and, [.atom(updated)])
        }
        await store.receive(
            \.delegate.filterUpdated,
            .group(.and, [.atom(.init(field: 1, op: .icontains, value: .string("invoice")))])
        )
    }

    // An incomplete atom must never reach the server: the match count refreshes on every keystroke.
    @Test
    func anIncompleteAtomIsPrunedFromWhatIsPublished() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .icontains, value: .string("a"))
        let store = Self.store(.testValue(
            editor: .init(atom: atom, path: [0]),
            query: .group(.and, [.atom(atom)])
        ))

        await store.send(.view(.editorValueChanged(.string("")))) {
            let updated = CustomFieldQuery.Atom(field: 1, op: .icontains, value: .string(""))
            $0.editor?.atom = updated
            $0.query = .group(.and, [.atom(updated)])
        }
        await store.receive(\.delegate.filterUpdated, nil)
    }

    @Test
    func togglingNegationWrapsAndUnwrapsARow() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .exists, value: .bool(true))
        let store = Self.store(.testValue(query: .group(.and, [.atom(atom)])))

        await store.send(.view(.negationToggled([0]))) {
            $0.query = .group(.and, [.negation(.atom(atom))])
        }
        await store.receive(\.delegate.filterUpdated, .group(.and, [.negation(.atom(atom))]))

        await store.send(.view(.negationToggled([0]))) {
            $0.query = .group(.and, [.atom(atom)])
        }
        await store.receive(\.delegate.filterUpdated, .group(.and, [.atom(atom)]))
    }

    @Test
    func switchingTheLogicalOperatorKeepsTheChildren() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .exists, value: .bool(true))
        let store = Self.store(.testValue(query: .group(.and, [.atom(atom)])))

        await store.send(.view(.logicalOperatorTapped([], .or))) {
            $0.query = .group(.or, [.atom(atom)])
        }
        await store.receive(\.delegate.filterUpdated, .group(.or, [.atom(atom)]))
    }

    @Test
    func deletingTheLastConditionPublishesNothing() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .exists, value: .bool(true))
        let store = Self.store(.testValue(query: .group(.and, [.atom(atom)])))

        await store.send(.view(.deleteTapped([0]))) {
            $0.query = .group(.and, [])
        }
        await store.receive(\.delegate.filterUpdated, nil)
    }

    @Test
    func deletingAGroupRemovesItWholesale() async {
        let store = Self.store(.testValue(
            query: .group(.and, [.group(.or, []), .group(.or, [])])
        ))

        await store.send(.view(.deleteTapped([1]))) {
            $0.query = .group(.and, [.group(.or, [])])
        }
        await store.receive(\.delegate.filterUpdated, nil)
    }

    @Test
    func theAtomLimitStopsFurtherConditions() {
        let atoms = (1 ... 5).map { CustomFieldQuery.atom(.init(field: .init(rawValue: $0), op: .exists, value: .bool(true))) }
        let state = CustomFieldQueryCardsReducer.State.testValue(query: .group(.and, atoms))

        #expect(!state.canAddCondition(at: []))
    }

    @Test
    func theDepthLimitStopsFurtherGroups() {
        let state = CustomFieldQueryCardsReducer.State.testValue()

        #expect(state.canAddGroup(at: []))
        #expect(state.canAddGroup(at: [0, 0]))
        #expect(!state.canAddGroup(at: [0, 0, 0]))
    }

    @Test
    func aServerWithNoCustomFieldsCannotAddAConditionAtAll() {
        let state = CustomFieldQueryCardsReducer.State.testValue(fields: [])

        #expect(!state.canAddCondition(at: []))
    }
}

@MainActor
@Suite(
    .dependencies()
)
struct CustomFieldQueryCardsSelectOptionTests {

    private static let fields = IdentifiedArray(uniqueElements: [CustomField].previewValue)

    private static let store = { (state: CustomFieldQueryCardsReducer.State) in
        TestStore(initialState: state) {
            CustomFieldQueryCardsReducer()
        }
    }

    private static func editing(_ atom: CustomFieldQuery.Atom) -> CustomFieldQueryCardsReducer.State {
        .testValue(
            editor: .init(atom: atom, path: [0]),
            fields: fields,
            query: .group(.and, [.atom(atom)])
        )
    }

    // Field 5 in the preview data is a select with options "Open" and "Closed". Switching it to a
    // string operator used to leave an empty value, which renders as a blank picker and logs
    // "the selection ... is invalid and does not have an associated tag".
    @Test
    func switchingASelectFieldToEqualToSeedsTheFirstOption() async {
        let atom = CustomFieldQuery.Atom(field: 5, op: .exists, value: .bool(true))
        let store = Self.store(Self.editing(atom))

        await store.send(.view(.editorOperatorChanged(.exact))) {
            let updated = CustomFieldQuery.Atom(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou"))
            $0.editor?.atom = updated
            $0.query = .group(.and, [.atom(updated)])
        }
        await store.receive(
            \.delegate.filterUpdated,
            .group(.and, [.atom(.init(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou")))])
        )
    }

    @Test
    func choosingASelectFieldSeedsTheFirstOption() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .exact, value: .string("free text"))
        let store = Self.store(Self.editing(atom))

        await store.send(.view(.editorFieldChanged(5))) {
            let updated = CustomFieldQuery.Atom(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou"))
            $0.editor?.atom = updated
            $0.query = .group(.and, [.atom(updated)])
        }
        await store.receive(
            \.delegate.filterUpdated,
            .group(.and, [.atom(.init(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou")))])
        )
    }

    @Test
    func openingAndDismissingTheOptionSheet() async {
        let store = Self.store(Self.editing(.init(field: 5, op: .in, value: .array([]))))

        await store.send(.view(.editorOptionsTapped)) {
            $0.editor?.isSelectingOptions = true
        }
        await store.send(.view(.editorOptionsDismissed)) {
            $0.editor?.isSelectingOptions = false
        }
    }

    @Test
    func togglingAnOptionAddsAndRemovesIt() async {
        let store = Self.store(Self.editing(.init(field: 5, op: .in, value: .array([]))))

        await store.send(.view(.editorOptionToggled("aqgT3m4XZw8aw3Ou"))) {
            let updated = CustomFieldQuery.Atom(
                field: 5,
                op: .in,
                value: .array([.string("aqgT3m4XZw8aw3Ou")])
            )
            $0.editor?.atom = updated
            $0.query = .group(.and, [.atom(updated)])
        }
        await store.receive(
            \.delegate.filterUpdated,
            .group(.and, [.atom(.init(field: 5, op: .in, value: .array([.string("aqgT3m4XZw8aw3Ou")])))])
        )

        // An empty subset is an unfinished condition, so it prunes away rather than being sent.
        await store.send(.view(.editorOptionToggled("aqgT3m4XZw8aw3Ou"))) {
            let updated = CustomFieldQuery.Atom(field: 5, op: .in, value: .array([]))
            $0.editor?.atom = updated
            $0.query = .group(.and, [.atom(updated)])
        }
        await store.receive(\.delegate.filterUpdated, nil)
    }

    // Set iteration order is not stable, so the emitted rule has to be sorted or the same
    // selection would produce different JSON between openings of the sheet.
    @Test
    func selectedOptionsAreEmittedInASortedOrder() async {
        let store = Self.store(Self.editing(
            .init(field: 5, op: .in, value: .array([.string("MOddUdj2nhfCEsqp")]))
        ))

        await store.send(.view(.editorOptionToggled("aqgT3m4XZw8aw3Ou"))) {
            let updated = CustomFieldQuery.Atom(
                field: 5,
                op: .in,
                value: .array([.string("MOddUdj2nhfCEsqp"), .string("aqgT3m4XZw8aw3Ou")])
            )
            $0.editor?.atom = updated
            $0.query = .group(.and, [.atom(updated)])
        }
        await store.receive(
            \.delegate.filterUpdated,
            .group(.and, [.atom(.init(
                field: 5,
                op: .in,
                value: .array([.string("MOddUdj2nhfCEsqp"), .string("aqgT3m4XZw8aw3Ou")])
            ))])
        )
    }
}
