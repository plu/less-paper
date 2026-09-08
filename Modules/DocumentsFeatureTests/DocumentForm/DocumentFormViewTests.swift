@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Dependencies
import Intelligence
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    // Rendering sends onAppear, which now reads this dependency; stubbing it false matches
    // `canSuggestTitle`'s own default so every snapshot here stays exactly what it was before the
    // suggest button existed.
    .dependencies {
        $0.titleSuggestion.isAvailable = { false }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // The pickers sit in the rendered body, so unlike toolbar chrome this image genuinely
    // discriminates. Seeded explicitly: a nil cache fails open and would render every field,
    // making a "gated" reference identical to the ungated one.
    @Test
    func testSnapshot_pickersHidden() async throws {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .changeDocument] }

        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(server: server),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "pickersHidden"
        )
    }

    @Test
    func testSnapshot_content() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(
                        content: "Some invoice, and all the rest of the OCR text the server holds.",
                        section: .content
                    ),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "content"
        )
    }

    // Dark mode: the editor's fill and outline are the whole point of the treatment, and
    // m3SurfaceContainerLow only differs from m3Surface enough to judge in dark.
    @Test
    func testSnapshot_contentDarkMode() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(
                        content: "Some invoice, and all the rest of the OCR text the server holds.",
                        section: .content
                    ),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "contentDarkMode"
        )
    }

    @Test
    func testSnapshot_contentLoading() async throws {
        // The stub never returns, so the section stays in its loading state for the capture.
        withDependencies {
            $0.getDocument.execute = { _, _ in
                try await Task.sleep(for: .seconds(60))
                return .testValue()
            }
        } operation: {
            assertSnapshot(
                of: DocumentFormView(
                    store: Store(
                        initialState: DocumentFormReducer.State.testValue(section: .content),
                        reducer: {
                            DocumentFormReducer()
                        }
                    )
                ),
                as: .image(layout: .device(config: .iPhone12)),
                named: "contentLoading"
            )
        }
    }

    @Test
    func testSnapshot_contentError() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(
                        loadError: "The request timed out.",
                        section: .content
                    ),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "contentError"
        )
    }

    @Test
    func testSnapshot_notes() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(
                        notes: [.testValue()],
                        section: .notes
                    ),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "notes"
        )
    }

    // Existence, not enablement: without add_note the composer is gone entirely, not merely
    // disabled — canCreate (draft validity) is a separate condition and stays untested here.
    @Test
    func testSnapshot_notes_addNoteHidden() async throws {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .viewNote] }

        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(
                        notes: [.testValue()],
                        section: .notes,
                        server: server
                    ),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "notesAddNoteHidden"
        )
    }

    @Test
    func testSnapshot_canSuggestTitle() async throws {
        var state = DocumentFormReducer.State.testValue(content: "Electricity for August.")
        state.canSuggestTitle = true

        // Rendering fires onAppear on this real Store, which would otherwise overwrite the
        // state above with the suite's default `false`.
        withDependencies {
            $0.titleSuggestion.isAvailable = { true }
        } operation: {
            assertSnapshot(
                of: DocumentFormView(
                    store: Store(
                        initialState: state,
                        reducer: {
                            DocumentFormReducer()
                        }
                    )
                ),
                as: .image(layout: .device(config: .iPhone12)),
                named: "canSuggestTitle"
            )
        }
    }
}
