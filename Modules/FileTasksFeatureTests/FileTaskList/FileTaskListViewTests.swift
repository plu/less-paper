@testable import FileTasksFeature

import ApiInterface
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
struct FileTaskListViewTests {

    @Test
    func testSnapshot_failed() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: FileTaskListReducer.State.testValue(
                        segment: .failed,
                        tasks: [
                            .testValue(
                                documentId: nil,
                                fileName: "invoice-march.pdf",
                                id: 1,
                                message: "Not consuming invoice-march.pdf: It is a duplicate of invoice-february.pdf",
                                status: .failed
                            ),
                            .testValue(
                                documentId: nil,
                                fileName: "scan_0012.pdf",
                                id: 2,
                                message: "Error while consuming document scan_0012.pdf: unsupported mime type",
                                status: .failed
                            )
                        ]
                    ),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_complete() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: FileTaskListReducer.State.testValue(
                        segment: .complete,
                        tasks: [
                            .testValue(documentId: 42, fileName: "invoice.pdf", id: 1),
                            .testValue(documentId: 43, fileName: "letter.pdf", id: 2),
                            // No file name: v9's task_file_name and v10's input_data.filename can
                            // both be absent, so the row has to fall back to a placeholder.
                            .testValue(documentId: 44, fileName: nil, id: 3),
                            // What paperless records for a file this app uploaded with a space in
                            // its name. The row has to read "sonos one.pdf", not "sonos%20one.pdf" -
                            // see the comment on FileTaskRowView.fileName.
                            .testValue(documentId: 45, fileName: "sonos%20one.pdf", id: 4)
                        ]
                    ),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: FileTaskListReducer.State.testValue(segment: .queued, tasks: []),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: FileTaskListReducer.State.testValue(tasks: [], isLoaded: false),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loading"
        )
    }

    @Test
    func testSnapshot_failedDarkMode() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: FileTaskListReducer.State.testValue(
                        segment: .failed,
                        tasks: [
                            .testValue(
                                documentId: nil,
                                fileName: "invoice-march.pdf",
                                id: 1,
                                message: "It is a duplicate of invoice-february.pdf",
                                status: .failed
                            )
                        ]
                    ),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }
}
