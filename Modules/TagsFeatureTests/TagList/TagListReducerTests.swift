@testable import TagsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct TagListReducerTests {

    @Test
    func test_destination_presented_tagForm_delegate_tagSaved_insert() async throws {
        let store = TestStore(initialState: TagListReducer.State(
            destination: .tagForm(TagFormReducer.State(server: .testValue())),
            server: .testValue(),
            tags: [.testValue()]
        )) {
            TagListReducer()
        }

        await store.send(.destination(.presented(.tagForm(.delegate(.tagSaved(.testValue(id: 2, name: "New name"))))))) {
            $0.destination = nil
            $0.tags = [
                .testValue(),
                .testValue(tag: .testValue(id: 2, name: "New name"))
            ]
        }
    }

    @Test
    func test_destination_presented_tagForm_delegate_tagSaved_update() async throws {
        @Shared(.tags(.testValue()))
        var cachedTags = .init()

        let store = TestStore(initialState: TagListReducer.State(
            destination: .tagForm(TagFormReducer.State(server: .testValue(), tag: .testValue())),
            server: .testValue(),
            tags: [.testValue()]
        )) {
            TagListReducer()
        }

        await store.send(.destination(.presented(.tagForm(.delegate(.tagSaved(.testValue(name: "New name"))))))) {
            $0.destination = nil
            $0.tags = [.testValue(tag: .testValue(name: "New name"))]
        }
    }

    @Test
    func test_tags_element_delegate_deleteTag_error() async throws {
        @Shared(.tags(.testValue()))
        var cachedTags = .init(uniqueElements: [.testValue()])

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: TagListReducer.State(
            server: .testValue(),
            tags: [.testValue()]
        )) {
            TagListReducer()
        } withDependencies: {
            $0.deleteTag.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.tags(.element(id: 1, action: .delegate(.deleteTag))))
        await store.receive(\.isUpdating) {
            $0.tags[id: 1]?.isUpdating = true
        }
        await store.receive(\.error)
        await store.receive(\.isUpdating) {
            $0.tags[id: 1]?.isUpdating = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_tags_element_delegate_deleteTag_success() async throws {
        @Shared(.tags(.testValue()))
        var cachedTags = .init()

        let deleteTagReceived = LockIsolated<ApiInterface.Tag.Id?>(nil)
        let store = TestStore(initialState: TagListReducer.State(
            server: .testValue(),
            tags: [.testValue()]
        )) {
            TagListReducer()
        } withDependencies: {
            $0.deleteTag.execute = { id, _ in
                deleteTagReceived.setValue(id)
            }
        }

        await store.send(.tags(.element(id: 1, action: .delegate(.deleteTag))))
        await store.receive(\.isUpdating) {
            $0.tags[id: 1]?.isUpdating = true
        }
        await store.receive(\.tagDeleted) {
            $0.tags = []
        }
    }

    @Test
    func test_tags_element_delegate_editTag() async throws {
        let store = TestStore(initialState: TagListReducer.State(
            server: .testValue(),
            tags: [.testValue()]
        )) {
            TagListReducer()
        }

        await store.send(.tags(.element(id: 1, action: .delegate(.editTag)))) {
            $0.destination = .tagForm(TagFormReducer.State(
                server: .testValue(),
                tag: .testValue()
            ))
        }
    }

    @Test
    func test_view_createButtonTapped() async throws {
        let store = TestStore(initialState: TagListReducer.State(
            server: .testValue(),
            tags: [.testValue()]
        )) {
            TagListReducer()
        }

        await store.send(.view(.createTagButtonTapped)) {
            $0.destination = .tagForm(TagFormReducer.State(
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_onAppear_success() async throws {
        @Shared(.tags(.testValue()))
        var cachedTags = .init()

        let getTagsResult = [Tag.testValue()]
        let store = TestStore(initialState: TagListReducer.State(server: .testValue())) {
            TagListReducer()
        } withDependencies: {
            $0.getTags.execute = { _ in getTagsResult }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getTagsResult, getTagsResult) {
            $0.tags = IdentifiedArray(
                uniqueElements: getTagsResult.map {
                    TagRowReducer.State(
                        server: .testValue(),
                        tag: $0
                    )
                }
            )
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }
}
