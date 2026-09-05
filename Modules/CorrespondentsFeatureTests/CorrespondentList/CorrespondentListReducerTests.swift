@testable import CorrespondentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct CorrespondentListReducerTests {

    @Test
    func test_destination_presented_correspondentForm_delegate_correspondentSaved_insert() async throws {
        let store = TestStore(initialState: CorrespondentListReducer.State(
            correspondents: [.testValue()],
            destination: .correspondentForm(CorrespondentFormReducer.State(server: .testValue())),
            server: .testValue()
        )) {
            CorrespondentListReducer()
        }

        await store.send(.destination(.presented(.correspondentForm(.delegate(.correspondentSaved(.testValue(
            id: 2,
            name: "New name"
        ))))))) {
            $0.destination = nil
            $0.correspondents = [
                .testValue(correspondent: .testValue(id: 2, name: "New name")),
                .testValue()
            ]
        }
    }

    @Test
    func test_destination_presented_correspondentForm_delegate_correspondentSaved_update() async throws {
        @Shared(.correspondents(.testValue()))
        var cachedCorrespondents = .init()

        let store = TestStore(initialState: CorrespondentListReducer.State(
            correspondents: [.testValue()],
            destination: .correspondentForm(CorrespondentFormReducer.State(correspondent: .testValue(), server: .testValue())),
            server: .testValue()
        )) {
            CorrespondentListReducer()
        }

        await store.send(.destination(.presented(.correspondentForm(.delegate(.correspondentSaved(.testValue(name: "New name"))))))) {
            $0.destination = nil
            $0.correspondents = [.testValue(correspondent: .testValue(name: "New name"))]
        }
    }

    @Test
    func test_correspondents_element_delegate_deleteCorrespondent_error() async throws {
        @Shared(.correspondents(.testValue()))
        var cachedCorrespondents = .init(uniqueElements: [.testValue()])

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: CorrespondentListReducer.State(
            correspondents: [.testValue()],
            server: .testValue()
        )) {
            CorrespondentListReducer()
        } withDependencies: {
            $0.deleteCorrespondent.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.correspondents(.element(id: 1, action: .delegate(.deleteCorrespondent))))
        await store.receive(\.isUpdating) {
            $0.correspondents[id: 1]?.isUpdating = true
        }
        await store.receive(\.error)
        await store.receive(\.isUpdating) {
            $0.correspondents[id: 1]?.isUpdating = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_correspondents_element_delegate_deleteCorrespondent_success() async throws {
        @Shared(.correspondents(.testValue()))
        var cachedCorrespondents = .init()

        let deleteCorrespondentReceived = LockIsolated<Correspondent.Id?>(nil)
        let store = TestStore(initialState: CorrespondentListReducer.State(
            correspondents: [.testValue()],
            server: .testValue()
        )) {
            CorrespondentListReducer()
        } withDependencies: {
            $0.deleteCorrespondent.execute = { id, _ in
                deleteCorrespondentReceived.setValue(id)
            }
        }

        await store.send(.correspondents(.element(id: 1, action: .delegate(.deleteCorrespondent))))
        await store.receive(\.isUpdating) {
            $0.correspondents[id: 1]?.isUpdating = true
        }
        await store.receive(\.correspondentDeleted) {
            $0.correspondents = []
        }
    }

    @Test
    func test_correspondents_element_delegate_editCorrespondent() async throws {
        let store = TestStore(initialState: CorrespondentListReducer.State(
            correspondents: [.testValue()],
            server: .testValue()
        )) {
            CorrespondentListReducer()
        }

        await store.send(.correspondents(.element(id: 1, action: .delegate(.editCorrespondent)))) {
            $0.destination = .correspondentForm(CorrespondentFormReducer.State(
                correspondent: .testValue(),
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_createButtonTapped() async throws {
        let store = TestStore(initialState: CorrespondentListReducer.State(
            correspondents: [.testValue()],
            server: .testValue()
        )) {
            CorrespondentListReducer()
        }

        await store.send(.view(.createCorrespondentButtonTapped)) {
            $0.destination = .correspondentForm(CorrespondentFormReducer.State(
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_onAppear_success() async throws {
        @Shared(.correspondents(.testValue()))
        var cachedCorrespondents = .init()

        let getCorrespondentsResult = [Correspondent.testValue()]
        let store = TestStore(initialState: CorrespondentListReducer.State(server: .testValue())) {
            CorrespondentListReducer()
        } withDependencies: {
            $0.getCorrespondents.execute = { _ in getCorrespondentsResult }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getCorrespondentsResult, getCorrespondentsResult) {
            $0.correspondents = IdentifiedArray(
                uniqueElements: getCorrespondentsResult.map {
                    CorrespondentRowReducer.State(
                        server: .testValue(),
                        correspondent: $0
                    )
                }
            )
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    // The toolbar "+" is gated on .addCorrespondent, but this project's NavigationStack snapshots do
    // not render nav-bar chrome, so no image can show its absence. This asserts the gate instead -
    // and the third expectation is the one that catches gating correspondents on a neighbouring
    // entity's permission, which would compile and look identical.
    @Test
    func listGatesOnCorrespondentPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewCorrespondent] }

        let state = CorrespondentListReducer.State(server: server)

        #expect(!state.canCreate)
        #expect(state.permissions.can(.viewCorrespondent))
        #expect(!state.permissions.can(.addTag))
    }

    // This restates ServerPermissionsTests.nilCacheAllowsEverything: with a nil cache, can
    // returns true for any server, so this passes even if State wired ServerPermissions to a
    // different Server entirely. The genuinely end-to-end fail-open evidence is the pre-existing,
    // unseeded testSnapshot.empty.png in CorrespondentListViewTests - it renders every control
    // with no cache seeded at all. This test only re-checks the rule.
    @Test
    func listAllowsEverythingWhenNothingHasBeenRead() {
        let state = CorrespondentListReducer.State(server: .testValue())

        #expect(state.canCreate)
    }
}
