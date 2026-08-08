@testable import TagsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct TagRowReducerTests {

    @Test
    func test_destination_confirmation_deleteButtonTapped() async throws {
        let store = TestStore(initialState: TagRowReducer.State(
            destination: .confirmation(.confirmDelete(name: "Inbox")),
            server: .testValue(),
            tag: .testValue()
        )) {
            TagRowReducer()
        }

        await store.send(.destination(.presented(.confirmation(.deleteButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.delegate, .deleteTag)
    }

    @Test
    func test_view_deleteButtonTapped() async throws {
        let tag = Tag.testValue()
        let store = TestStore(initialState: TagRowReducer.State(
            server: .testValue(),
            tag: tag
        )) {
            TagRowReducer()
        }

        await store.send(.view(.deleteButtonTapped)) {
            $0.destination = .confirmation(.confirmDelete(name: tag.name))
        }
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: TagRowReducer.State(
            server: .testValue(),
            tag: .testValue()
        )) {
            TagRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editTag)
    }
}
