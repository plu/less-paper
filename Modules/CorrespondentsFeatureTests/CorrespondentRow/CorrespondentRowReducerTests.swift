@testable import CorrespondentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct CorrespondentRowReducerTests {

    @Test
    func test_destination_confirmation_deleteButtonTapped() async throws {
        let store = TestStore(initialState: CorrespondentRowReducer.State(
            correspondent: .testValue(),
            destination: .confirmation(.confirmDelete(name: "Inbox")),
            server: .testValue()
        )) {
            CorrespondentRowReducer()
        }

        await store.send(.destination(.presented(.confirmation(.deleteButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.delegate, .deleteCorrespondent)
    }

    @Test
    func test_view_deleteButtonTapped() async throws {
        let correspondent = Correspondent.testValue()
        let store = TestStore(initialState: CorrespondentRowReducer.State(
            correspondent: correspondent,
            server: .testValue()
        )) {
            CorrespondentRowReducer()
        }

        await store.send(.view(.deleteButtonTapped)) {
            $0.destination = .confirmation(.confirmDelete(name: correspondent.name))
        }
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: CorrespondentRowReducer.State(
            correspondent: .testValue(),
            server: .testValue()
        )) {
            CorrespondentRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editCorrespondent)
    }
}
