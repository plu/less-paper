@testable import DocumentsFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentListEmptyViewTests {

    @Test
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                error: "Something went wrong",
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    @Test
    func testSnapshot_inboxWithoutInboxTag() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                filter: .testValue(isInbox: true),
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "inboxWithoutInboxTag"
        )
    }

    @Test
    func testSnapshot_inboxAllCaughtUp() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                filter: .testValue(
                    input: .testValue(tag: .init(rule: .any, selection: .init(any: [.testValue()]))),
                    isInbox: true
                ),
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "inboxAllCaughtUp"
        )
    }

    @Test
    func testSnapshot_noMatchingDocuments() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                filter: .testValue(input: .testValue(searchValue: "Lego")),
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "noMatchingDocuments"
        )
    }

    @Test
    func testSnapshot_noDocuments() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "noDocuments"
        )
    }

    // `EmptyReducer` rather than the real reducer: these are snapshots of five layouts, and the real
    // reducer would start network effects on any action.
    private func view(state: DocumentListReducer.State) -> some View {
        DocumentListEmptyView(
            store: Store(initialState: state) {
                EmptyReducer<DocumentListReducer.State, DocumentListReducer.Action>()
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.m3Surface)
    }
}
