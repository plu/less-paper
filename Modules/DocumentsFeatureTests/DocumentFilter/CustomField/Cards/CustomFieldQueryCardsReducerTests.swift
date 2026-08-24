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
            $0.editor = $0.makeEditor(atom: atom, path: [0])
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
            $0.editor = $0.makeEditor(atom: atom, path: [0])
        }
    }

    // A negation is drawn as a modifier on the row it wraps, so the tap target is what is inside.
    @Test
    func tappingANegatedAtomRowEditsTheAtomInside() async {
        let atom = CustomFieldQuery.Atom(field: 1, op: .exists, value: .bool(true))
        let store = Self.store(.testValue(query: .group(.and, [.negation(.atom(atom))])))

        await store.send(.view(.rowTapped([0]))) {
            $0.editor = $0.makeEditor(atom: atom, path: [0, 0])
        }
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
