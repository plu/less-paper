@testable import CorrespondentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
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
                        correspondent: $0,
                        server: .testValue()
                    )
                }
            )
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }
}
