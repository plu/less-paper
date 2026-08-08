@testable import DocumentsFeature

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
struct DocumentFilterReducerTests {

    @Test
    func test_destination_correspondentList_delegate_filterUpdated() async throws {
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue(
            destination: .correspondentList(.testValue())
        )) {
            DocumentFilterReducer()
        }

        await store.send(.destination(.presented(.correspondentList(.delegate(.filterUpdated(
            rule: .include,
            selection: [.testValue()]
        )))))) {
            $0.input.correspondent.rule = .include
            $0.input.correspondent.selection = [.testValue()]
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(
                correspondent: .init(rule: .include, selection: [.testValue()])
            )
        ))
    }

    @Test
    func test_destination_documentTypeList_delegate_filterUpdated() async throws {
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue(
            destination: .documentTypeList(.testValue())
        )) {
            DocumentFilterReducer()
        }

        await store.send(.destination(.presented(.documentTypeList(.delegate(.filterUpdated(
            rule: .include,
            selection: [.testValue()]
        )))))) {
            $0.input.documentType.rule = .include
            $0.input.documentType.selection = [.testValue()]
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(
                documentType: .init(rule: .include, selection: [.testValue()])
            )
        ))
    }

    @Test
    func test_destination_savedViewForm_delegate_savedViewSaved() async throws {
        let savedView = SavedView.testValue()
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue(
            destination: .savedViewForm(.testValue())
        )) {
            DocumentFilterReducer()
        }

        await store.send(.destination(.presented(.savedViewForm(.delegate(.savedViewSaved(savedView)))))) {
            $0.destination = nil
            $0.savedView = savedView
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            savedView: savedView
        ))
    }

    @Test
    func test_destination_storagePathList_delegate_filterUpdated() async throws {
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue(
            destination: .storagePathList(.testValue())
        )) {
            DocumentFilterReducer()
        }

        await store.send(.destination(.presented(.storagePathList(.delegate(.filterUpdated(rule: .include, selection: [.testValue()])))))) {
            $0.input.storagePath.rule = .include
            $0.input.storagePath.selection = [.testValue()]
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(
                storagePath: .init(rule: .include, selection: [.testValue()])
            )
        ))
    }

    @Test
    func test_destination_tagList_delegate_filterUpdated() async throws {
        let selection = DocumentFilterTagSelection.testValue(
            all: .testValue(
                exclude: Set([.testValue(id: 1)]),
                include: Set([.testValue(id: 2)])
            ),
            any: Set([.testValue(id: 3)])
        )
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue(
            destination: .tagList(.testValue())
        )) {
            DocumentFilterReducer()
        }

        await store.send(.destination(.presented(.tagList(.delegate(.filterUpdated(rule: .any, selection: selection)))))) {
            $0.input.tag.rule = .any
            $0.input.tag.selection = selection
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(
                tag: .init(rule: .any, selection: selection)
            )
        ))
    }

    @Test
    func test_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue()) {
            DocumentFilterReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.error(ApiError.testValue()))
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_savedViewSaved() async throws {
        let savedView = SavedView.testValue()
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue()) {
            DocumentFilterReducer()
        }

        await store.send(.savedViewSaved(savedView)) {
            $0.savedView = savedView
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            savedView: savedView
        ))
    }

    @Test
    func test_sheetTitle_allDocuments() async throws {
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue()) {
            DocumentFilterReducer()
        }

        #expect(store.state.sheetTitle == .allDocuments)
    }

    @Test
    func test_sheetTitle_savedView() async throws {
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue(
            savedView: .testValue()
        )) {
            DocumentFilterReducer()
        }

        #expect(store.state.sheetTitle == "Test SavedView")
    }

    @Test
    func test_view_asnTypeButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego")
        )) {
            DocumentFilterReducer()
        }

        await store.send(.view(.asnTypeButtonTapped(.lowerThan))) {
            $0.input.asnType = .lowerThan
            $0.input.searchType = .asn
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(
                asnType: .lowerThan,
                searchType: .asn,
                searchValue: "Lego"
            )
        ))
    }

    @Test
    func test_view_applyButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: .testValue()
        )) {
            DocumentFilterReducer()
        }

        await store.send(.view(.applyButtonTapped))
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: .testValue()
        ))
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_correspondentButtonTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterReducer()
        }

        await store.send(.view(.correspondentButtonTapped)) {
            $0.destination = .correspondentList(.testValue())
        }
    }

    @Test
    func test_view_documentTypeButtonTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterReducer()
        }

        await store.send(.view(.documentTypeButtonTapped)) {
            $0.destination = .documentTypeList(.testValue())
        }
    }

    @Test
    func test_view_resetButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: nil
        )) {
            DocumentFilterReducer()
        }

        await store.send(.view(.resetButtonTapped)) {
            $0.input = .init()
            $0.savedView = nil
        }
        await store.receive(\.delegate.filterUpdated, .testValue())
    }

    @Test
    func test_view_resetButtonTapped_savedView() async throws {
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: .testValue()
        )) {
            DocumentFilterReducer()
        }

        await store.send(.view(.resetButtonTapped)) {
            $0.input = .init()
            $0.savedView = .testValue()
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchValue: ""),
            savedView: .testValue()
        ))
    }

    @Test
    func test_view_saveAsButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: .testValue()
        )) {
            DocumentFilterReducer()
        }

        await store.send(.view(.saveAsButtonTapped)) {
            $0.destination = .savedViewForm(.testValue(
                id: nil,
                input: .testValue(
                    filterRules: [.init(ruleType: .titleContent, value: "Lego")],
                    name: .init(focused: true, value: "")
                )
            ))
        }
    }

    @Test
    func test_view_saveButtonTapped() async throws {
        let updatedSavedView = SavedView.testValue(filterRules: [.init(ruleType: .titleContent, value: "Lego")])
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: .testValue(filterRules: [])
        )) {
            DocumentFilterReducer()
        } withDependencies: {
            $0.saveSavedView.execute = { id, input, _ in
                #expect(id == updatedSavedView.id)
                #expect(input.filterRules == [.init(ruleType: .titleContent, value: "Lego")])
                return updatedSavedView
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.savedViewSaved, updatedSavedView) {
            $0.savedView = updatedSavedView
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: updatedSavedView
        ))
    }

    @Test
    func test_view_saveButtonTapped_withoutSavedView() async throws {
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: nil
        )) {
            DocumentFilterReducer()
        } withDependencies: {
            $0.saveSavedView.execute = { _, _, _ in
                Issue.record("saveSavedView.execute should not be called")
                return .testValue()
            }
        }

        await store.send(.view(.saveButtonTapped))
    }

    @Test
    func test_view_savedViewButtonTapped() async throws {
        let savedView = SavedView.testValue(filterRules: [.init(ruleType: .titleContent, value: "Invoice")])
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: nil
        )) {
            DocumentFilterReducer()
        }

        await store.send(.view(.savedViewButtonTapped(savedView))) {
            $0.input = .testValue(searchValue: "Invoice")
            $0.savedView = savedView
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchValue: "Invoice"),
            savedView: savedView
        ))
    }

    @Test
    func test_view_searchTypeButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego")
        )) {
            DocumentFilterReducer()
        }

        await store.send(.view(.searchTypeButtonTapped(.customFields))) {
            $0.input.searchType = .customFields
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(
                searchType: .customFields,
                searchValue: "Lego"
            )
        ))
    }

    @Test
    func test_view_sortDirectionButtonTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterReducer()
        }

        await store.send(.view(.sortDirectionButtonTapped(.ascending))) {
            $0.input.sort.direction = .ascending
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(
                sort: .init(direction: .ascending)
            )
        ))
    }

    @Test
    func test_view_sortFieldButtonTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterReducer()
        }

        await store.send(.view(.sortFieldButtonTapped(.title))) {
            $0.input.sort.field = .title
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(
                sort: .init(field: .title)
            )
        ))
    }

    @Test
    func test_view_storagePathButtonTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterReducer()
        }

        await store.send(.view(.storagePathButtonTapped)) {
            $0.destination = .storagePathList(.testValue())
        }
    }

    @Test
    func test_view_tagButtonTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentFilterReducer()
        }

        await store.send(.view(.tagButtonTapped)) {
            $0.destination = .tagList(.testValue())
        }
    }
}
