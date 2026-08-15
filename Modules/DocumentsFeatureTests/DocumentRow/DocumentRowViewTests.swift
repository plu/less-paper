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
struct DocumentRowViewTests {

    @Test
    func testSnapshot_sizeCategories() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                ForEach(ContentSizeCategory.allCases, id: \.self) { sizeCategory in
                    Section(String(describing: sizeCategory)) {
                        DocumentRowView(
                            store: Store(
                                initialState: DocumentRowReducer.State.testValue(),
                                reducer: {
                                    DocumentRowReducer()
                                }
                            )
                        )
                        .environment(\.sizeCategory, sizeCategory)
                    }
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }

    @Test
    func testSnapshot_contentVariants() async throws {
        let title = "Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book."

        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(
                            document: .testValue(
                                archiveSerialNumber: nil,
                                correspondent: nil,
                                documentType: nil,
                                storagePath: nil,
                                title: title
                            )
                        ),
                        reducer: {
                            DocumentRowReducer()
                        }
                    )
                )

                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(
                            document: .testValue(
                                archiveSerialNumber: .max,
                                correspondent: nil,
                                documentType: nil,
                                storagePath: nil,
                                title: title
                            )
                        ),
                        reducer: {
                            DocumentRowReducer()
                        }
                    )
                )

                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(
                            document: .testValue(
                                archiveSerialNumber: .max,
                                correspondent: 1,
                                documentType: nil,
                                storagePath: nil,
                                title: title
                            )
                        ),
                        reducer: {
                            DocumentRowReducer()
                        }
                    )
                )

                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(
                            document: .testValue(
                                archiveSerialNumber: .max,
                                correspondent: 1,
                                documentType: 1,
                                storagePath: nil,
                                title: title
                            )
                        ),
                        reducer: {
                            DocumentRowReducer()
                        }
                    )
                )

                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(
                            document: .testValue(
                                archiveSerialNumber: .max,
                                correspondent: 1,
                                documentType: 1,
                                storagePath: 1,
                                title: title
                            )
                        ),
                        reducer: {
                            DocumentRowReducer()
                        }
                    )
                )

                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(
                            document: .testValue(
                                archiveSerialNumber: .max,
                                correspondent: 1,
                                documentType: 1,
                                storagePath: 1,
                                tags: Array(1 ... 7),
                                title: title
                            )
                        ),
                        reducer: {
                            DocumentRowReducer()
                        }
                    )
                )
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }

    @Test
    func testSnapshot_isUpdating() async throws {
        assertSnapshot(
            of: DocumentRowView(
                store: Store(
                    initialState: DocumentRowReducer.State.testValue(isUpdating: true),
                    reducer: {
                        DocumentRowReducer()
                    }
                )
            ).frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }
}
