@testable import SavedViewsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct SavedViewListReducerTests {

    @Test
    func test_destination_presented_savedViewForm_delegate_savedViewSaved_insert() async throws {
        let store = TestStore(initialState: SavedViewListReducer.State(
            savedViews: [.testValue()],
            destination: .savedViewForm(SavedViewFormReducer.State.testValue()),
            server: .testValue()
        )) {
            SavedViewListReducer()
        }

        await store.send(.destination(.presented(.savedViewForm(.delegate(.savedViewSaved(.testValue(
            id: 2,
            name: "New name"
        ))))))) {
            $0.destination = nil
            $0.savedViews = [
                .testValue(savedView: .testValue(id: 2, name: "New name")),
                .testValue()
            ]
        }
    }

    @Test
    func test_destination_presented_savedViewForm_delegate_savedViewSaved_update() async throws {
        @Shared(.savedViews(.testValue()))
        var cachedSavedViews = .init()

        let store = TestStore(initialState: SavedViewListReducer.State(
            savedViews: [.testValue()],
            destination: .savedViewForm(SavedViewFormReducer.State.testValue(
                id: 1,
                input: .testValue()
            )),
            server: .testValue()
        )) {
            SavedViewListReducer()
        }

        await store.send(.destination(.presented(.savedViewForm(.delegate(.savedViewSaved(.testValue(name: "New name"))))))) {
            $0.destination = nil
            $0.savedViews = [.testValue(savedView: .testValue(name: "New name"))]
        }
    }

    @Test
    func test_savedViews_element_delegate_deleteSavedView_error() async throws {
        @Shared(.savedViews(.testValue()))
        var cachedSavedViews = .init(uniqueElements: [.testValue()])

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: SavedViewListReducer.State(
            savedViews: [.testValue()],
            server: .testValue()
        )) {
            SavedViewListReducer()
        } withDependencies: {
            $0.deleteSavedView.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.savedViews(.element(id: 1, action: .delegate(.deleteSavedView))))
        await store.receive(\.isUpdating) {
            $0.savedViews[id: 1]?.isUpdating = true
        }
        await store.receive(\.error)
        await store.receive(\.isUpdating) {
            $0.savedViews[id: 1]?.isUpdating = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_savedViews_element_delegate_deleteSavedView_success() async throws {
        @Shared(.savedViews(.testValue()))
        var cachedSavedViews = .init()

        let deleteSavedViewReceived = LockIsolated<SavedView.Id?>(nil)
        let store = TestStore(initialState: SavedViewListReducer.State(
            savedViews: [.testValue()],
            server: .testValue()
        )) {
            SavedViewListReducer()
        } withDependencies: {
            $0.deleteSavedView.execute = { id, _ in
                deleteSavedViewReceived.setValue(id)
            }
        }

        await store.send(.savedViews(.element(id: 1, action: .delegate(.deleteSavedView))))
        await store.receive(\.isUpdating) {
            $0.savedViews[id: 1]?.isUpdating = true
        }
        await store.receive(\.savedViewDeleted) {
            $0.savedViews = []
        }
    }

    @Test
    func test_savedViews_element_delegate_editSavedView() async throws {
        let store = TestStore(initialState: SavedViewListReducer.State(
            savedViews: [.testValue()],
            server: .testValue()
        )) {
            SavedViewListReducer()
        }

        await store.send(.savedViews(.element(id: 1, action: .delegate(.editSavedView)))) {
            $0.destination = .savedViewForm(SavedViewFormReducer.State(
                id: 1,
                input: .testValue(),
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_createButtonTapped() async throws {
        let store = TestStore(initialState: SavedViewListReducer.State(
            savedViews: [.testValue()],
            server: .testValue()
        )) {
            SavedViewListReducer()
        }

        await store.send(.view(.createSavedViewButtonTapped)) {
            $0.destination = .savedViewForm(SavedViewFormReducer.State.testValue(
                input: .testValue(name: .init(focused: true, value: ""))
            ))
        }
    }

    @Test
    func test_view_onAppear_success() async throws {
        @Shared(.savedViews(.testValue()))
        var cachedSavedViews = .init()

        let getSavedViewsResult = [SavedView.testValue()]
        let store = TestStore(initialState: SavedViewListReducer.State(server: .testValue())) {
            SavedViewListReducer()
        } withDependencies: {
            $0.getSavedViews.execute = { _ in getSavedViewsResult }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getSavedViewsResult, getSavedViewsResult) {
            $0.savedViews = IdentifiedArray(
                uniqueElements: getSavedViewsResult.map {
                    SavedViewRowReducer.State(
                        server: .testValue(),
                        savedView: $0
                    )
                }
            )
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    // The toolbar "+" is gated on .addSavedView, but this project's NavigationStack snapshots do
    // not render nav-bar chrome, so no image can show its absence. This asserts the gate instead -
    // and the third expectation is the one that catches gating saved views on a neighbouring
    // entity's permission, which would compile and look identical.
    @Test
    func listGatesOnSavedViewPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewSavedView] }

        let state = SavedViewListReducer.State(server: server)

        #expect(!state.canCreate)
        #expect(state.permissions.can(.viewSavedView))
        #expect(!state.permissions.can(.addTag))
    }

    // This restates ServerPermissionsTests.nilCacheAllowsEverything: with a nil cache, can
    // returns true for any server, so this passes even if State wired ServerPermissions to a
    // different Server entirely. The genuinely end-to-end fail-open evidence is the pre-existing,
    // unseeded testSnapshot.empty.png in SavedViewListViewTests - it renders every control with no
    // cache seeded at all. This test only re-checks the rule.
    @Test
    func listAllowsEverythingWhenNothingHasBeenRead() {
        let state = SavedViewListReducer.State(server: .testValue())

        #expect(state.canCreate)
    }
}
