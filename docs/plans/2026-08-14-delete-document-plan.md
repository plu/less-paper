# Delete Document Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Delete document" item to the document row's context menu that asks for confirmation, deletes the document on the server, and removes it from every place in the app that references it.

**Architecture:** A new `DeleteDocumentsUseCase` wraps the existing `bulk_edit` `.delete` method and evicts the ids from the shared document cache. `DocumentRowReducer` gains a confirmation dialog and a `deleteDocument` delegate, exactly like `DocumentTypeRowReducer`. `DocumentListReducer` runs the delete, prunes its own rows/selection/navigation stack, and emits a `documentsDeleted` delegate that `MainReducer` forwards to the other tab.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture (TCA), swift-dependencies, swift-sharing, Swift Testing, swift-snapshot-testing, Tuist.

**Design doc:** `docs/plans/2026-08-14-delete-document.md` — read it before starting.

## Global Constraints

- **Doc comments:** single-line uses `///`; multi-line with parameters uses `/** * ... */`. See `.claude/CLAUDE.md`.
- **Deployment target:** iOS 18.0.
- **Test runner:** `tuist test <Scheme> -d "iPhone 17 Pro" --no-selective-testing`. Tuist targets use *buildable folders*, so new `.swift` files inside an existing module directory are picked up with no project regeneration. **`--no-selective-testing` is not optional during TDD** — without it Tuist fingerprints the target and reports "The scheme's test action has no tests to run, finishing early" on a re-run, which reads exactly like a pass.
- **Never run a whole test target for `ApiImplementation`** — it contains `.tags(.integrationTests)` tests that require the docker Paperless container. Always pass `-only-testing:`.
- **Naming:** the API layer is plural (`DeleteDocumentsUseCase`, `deleteDocuments`, `[Document.Id]`) even though the only caller deletes one document.
- **Localization:** both `en` and `de` must be filled in, `"extractionState": "manual"`, alphabetical key order in the catalog.
- **Lint:** `mise ci:lint` runs `swiftformat --lint .` and `swiftlint --strict`. Run `swiftformat .` before committing if formatting drifts.
- **Alphabetical member ordering** is enforced by convention throughout this codebase — enum cases, struct properties and switch cases are all alphabetical. Match it.

---

### Task 1: `DeleteDocumentsUseCase`

**Files:**
- Create: `Modules/ApiInterface/Documents/DeleteDocumentsUseCase.swift`
- Create: `Modules/ApiImplementation/Documents/DeleteDocumentsUseCase.swift`
- Test: `Modules/ApiImplementationTests/Documents/DeleteDocumentsUseCaseTests.swift`

**Interfaces:**
- Consumes: `DocumentsRepository.bulkEditDocuments` (existing, `Modules/ApiImplementation/Documents/DocumentsRepository.swift`), `BulkEditDocumentsInput.Method.delete` (existing), `SharedReaderKey.documents(_:)` (existing).
- Produces: `@Dependency(\.deleteDocuments)` → `DeleteDocumentsUseCase` with `execute: @Sendable (_ ids: [Document.Id], _ server: Server) async throws -> Void`. Task 3 depends on this exact signature.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiImplementationTests/Documents/DeleteDocumentsUseCaseTests.swift`. It is modelled on `Modules/ApiImplementationTests/DocumentTypes/DeleteDocumentTypeUseCaseTests.swift` — read that file first.

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct DeleteDocumentsUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache.ids.elements == [1, 2, 3])

        let inputReceived = LockIsolated<BulkEditDocumentsInput?>(nil)
        try await withDependencies {
            $0.documentsRepository.bulkEditDocuments = { input, _ in
                inputReceived.setValue(input)
            }
        } operation: {
            let useCase = DeleteDocumentsUseCase.liveValue

            try await useCase.execute(
                ids: [1, 3],
                server: .testValue()
            )

            #expect(inputReceived.value == BulkEditDocumentsInput(
                documents: [1, 3],
                method: .delete
            ))
        }

        #expect(cache.ids.elements == [2])
    }

    @Shared(.documents(.testValue()))
    private var cache: IdentifiedArrayOf<Document> = .init(uniqueElements: [
        .testValue(id: 1),
        .testValue(id: 2),
        .testValue(id: 3),
    ])
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:ApiImplementationTests/DeleteDocumentsUseCaseTests`

Expected: FAIL — compile error, `cannot find 'DeleteDocumentsUseCase' in scope`.

- [ ] **Step 3: Create the interface**

Create `Modules/ApiInterface/Documents/DeleteDocumentsUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteDocumentsUseCase: Sendable {

    public var execute: @Sendable (
        _ ids: [Document.Id],
        _ server: Server
    ) async throws -> Void
}

extension DeleteDocumentsUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteDocuments: DeleteDocumentsUseCase {
        get { self[DeleteDocumentsUseCase.self] }
        set { self[DeleteDocumentsUseCase.self] = newValue }
    }
}
```

- [ ] **Step 4: Create the implementation**

Create `Modules/ApiImplementation/Documents/DeleteDocumentsUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DeleteDocumentsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(ids:server:)
    )
}

private extension DeleteDocumentsUseCase {

    /**
     * Deletes documents on the server and evicts them from the shared document cache.
     *
     * Deletion goes through `bulk_edit` rather than the per-document endpoint because the
     * endpoint is inherently batched and is already exercised by the repository integration
     * tests.
     *
     * - Parameters:
     *   - ids: The documents to delete.
     *   - server: The server to delete them from.
     */
    static func execute(
        ids: [Document.Id],
        server: Server
    ) async throws {
        @Shared(.documents(server))
        var cache: IdentifiedArrayOf<Document> = []

        @Dependency(\.documentsRepository)
        var documentsRepository

        try await documentsRepository.bulkEditDocuments(
            .init(documents: ids, method: .delete),
            server
        )

        $cache.withLock { cache in
            for id in ids {
                cache.remove(id: id)
            }
        }
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:ApiImplementationTests/DeleteDocumentsUseCaseTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface/Documents/DeleteDocumentsUseCase.swift \
        Modules/ApiImplementation/Documents/DeleteDocumentsUseCase.swift \
        Modules/ApiImplementationTests/Documents/DeleteDocumentsUseCaseTests.swift
git commit -m "feat: add DeleteDocumentsUseCase"
```

---

### Task 2: Row confirmation popup and context menu item

**Files:**
- Create: `Modules/DocumentsFeature/DocumentRow/DocumentDeleteConfirmationPresenter.swift`
- Create: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+Effect.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+TestValue.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` (compile stub only — Task 3 replaces it)
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowViewTests.swift`

**Interfaces:**
- Consumes: `ConfirmationPopupView` and `@Dependency(\.popupPresenter)` from `Components`. Nothing from Task 1.
- Produces: `DocumentRowReducer.Action.Delegate.deleteDocument`, `DocumentRowReducer.Action.View.deleteButtonTapped`, `@Dependency(\.documentDeleteConfirmation)` with `present: @Sendable (_ documentTitle: String) async -> Bool`, `Effect.runConfirmDelete(documentTitle:)`, and `DocumentRowReducer.State.isUpdating: Bool`. Task 3 consumes the delegate and `isUpdating`.

**Use the app's own popup, not the system dialog.** `DocumentRowReducer.Destination` keeps its single `documentForm` case — the confirmation is *not* navigation state. It is presented by a dependency that suspends until the user answers, mirroring `DocumentBulkEditConfirmationPresenter`. Triggered from a context menu, a system `confirmationDialog` renders as an anchored popover, which drops the cancel-role button entirely; `ConfirmationPopupView` always shows Cancel and Confirm.

**Note on the compile stub:** `DocumentListReducer` switches exhaustively over `DocumentRowReducer.Action.Delegate`. Adding `deleteDocument` breaks that switch, so this task adds a placeholder case to keep `DocumentsFeature` compiling. Task 3 replaces it with the real effect.

- [ ] **Step 1: Add the localization key**

In `Shared/Framework/Resources/Localizable.xcstrings`, add a `deleteDocument` entry to the `strings` object, keeping keys alphabetical — it goes between `deleteCorrespondent` and `deleteDocumentType`:

```json
"deleteDocument" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Dokument löschen"
      }
    },
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Delete document"
      }
    }
  }
},
```

- [ ] **Step 2: Write the failing tests**

Add these two tests to `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`, keeping the existing tests and the file's ordering (`test_destination_*` before `test_view_*`). They stub the presenter exactly as `DocumentBulkEditGenericValueReducerTests` stubs its own:

```swift
    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let documentTitle = LockIsolated<String?>(nil)
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: .testValue(title: "Invoice")
        )) {
            DocumentRowReducer()
        } withDependencies: {
            $0.documentDeleteConfirmation.present = { title in
                documentTitle.setValue(title)
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteDocument)

        #expect(documentTitle.value == "Invoice")
    }
```

```swift
    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: .testValue(title: "Invoice")
        )) {
            DocumentRowReducer()
        } withDependencies: {
            $0.documentDeleteConfirmation.present = { _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }
```

The cancelled test asserting *nothing* after the `send` is the point: `TestStore` fails on any unasserted action, so a stray delegate on cancel would be caught.

`store.receive(\.delegate, .deleteDocument)` requires `DocumentRowReducer.Action.Delegate` to stay `Equatable` — it already is, via the `extension DocumentRowReducer.Action.Delegate: Equatable {}` at the bottom of the reducer file.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentRowReducerTests`

Expected: FAIL — compile error, `value of type 'DependencyValues' has no member 'documentDeleteConfirmation'`.

- [ ] **Step 4: Extend the reducer**

In `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`:

Add the delegate and view cases (alphabetical):

```swift
        public enum Delegate {
            case deleteDocument
            case presentDocumentDetail(Shared<Document>)
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
            case rowTapped
        }
```

Leave `Destination` alone — it keeps its single `documentForm` case.

Add to `State`, above `let server: Server`:

```swift
        var isUpdating = false
```

Add `isUpdating` to `State.init` so tests and the list can set it:

```swift
        init(
            destination: Destination.State? = nil,
            document: Shared<Document>,
            isUpdating: Bool = false,
            server: Server
        ) {
            self.destination = destination
            self._document = document
            self.isUpdating = isUpdating
            self.server = server
        }
```

Add the view case, first in the inner switch:

```swift
                case .deleteButtonTapped:
                    return .runConfirmDelete(documentTitle: state.document.title)
```

- [ ] **Step 5: Create the presenter and the effect**

Create `Modules/DocumentsFeature/DocumentRow/DocumentDeleteConfirmationPresenter.swift`, mirroring `DocumentBulkEditConfirmationPresenter`:

```swift
import Components
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct DocumentDeleteConfirmationPresenter: Sendable {

    /// Presents the delete confirmation popup and suspends until the user confirms or cancels
    var present: @Sendable (_ documentTitle: String) async -> Bool = { _ in false }
}

extension DocumentDeleteConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(present: { _ in false })

    static let testValue = Self()
}

extension DocumentDeleteConfirmationPresenter: DependencyKey {

    static let liveValue = Self(present: present(documentTitle:))
}

private extension DocumentDeleteConfirmationPresenter {

    static func present(documentTitle: String) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .deleteDocument,
                message: .deleteConfirmation(documentTitle),
                isDestructive: true,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

extension DependencyValues {

    var documentDeleteConfirmation: DocumentDeleteConfirmationPresenter {
        get { self[DocumentDeleteConfirmationPresenter.self] }
        set { self[DocumentDeleteConfirmationPresenter.self] = newValue }
    }
}
```

Then create `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+Effect.swift`:

```swift
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentRowReducer.Action {

    /**
     * Asks the user to confirm deleting a document, and reports the answer upwards.
     *
     * The popup is presented by a dependency rather than held as navigation state so that the
     * effect stays suspended until the user answers — the same shape the bulk-edit confirmations
     * use.
     *
     * - Parameter documentTitle: The title shown in the confirmation message.
     */
    static func runConfirmDelete(documentTitle: String) -> Self {
        @Dependency(\.documentDeleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(documentTitle) else {
                return
            }
            await send(.delegate(.deleteDocument))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
```

`isDestructive: true` gives the confirm button the `.critical` (red) style; the buttons keep the shared `Confirm`/`Cancel` titles, as the bulk-edit confirmations do.

- [ ] **Step 6: Update the test value helper**

In `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+TestValue.swift`:

```swift
extension DocumentRowReducer.State {

    static func testValue(
        destination: DocumentRowReducer.Destination.State? = nil,
        document: Document = .testValue(),
        isUpdating: Bool = false,
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            document: Shared(value: document),
            isUpdating: isUpdating,
            server: server
        )
    }
}
```

Parameters are alphabetical, matching `DocumentDetailReducer.State.testValue`. The existing
call sites in `DocumentRowReducerTests` and `DocumentListReducer+TestValue.swift` pass `document:`
only, so they keep compiling unchanged.

- [ ] **Step 7: Add the compile stub to `DocumentListReducer`**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`, the `documents` delegate switch is now non-exhaustive. Add the case so the module compiles — Task 3 replaces its body:

```swift
            case let .documents(.element(id: _, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteDocument:
                    // Replaced in Task 3.
                    return .none
                case let .presentDocumentDetail(document):
                    state.path.append(.documentDetail(DocumentDetailReducer.State(
                        document: document,
                        server: state.server
                    )))
                    return .none
                }
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentRowReducerTests`

Expected: PASS, including the two pre-existing tests.

- [ ] **Step 9: Update the view**

In `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift`, replace `contextMenu()`:

```swift
    @ViewBuilder
    private func contextMenu() -> some View {
        Button {
            send(.editButtonTapped)
        } label: {
            Label(.editDocument, systemImage: "square.and.pencil")
        }

        Button(role: .destructive) {
            send(.deleteButtonTapped)
        } label: {
            Label(.deleteDocument, systemImage: "trash")
        }
    }
```

And add one modifier to `body`, immediately after the existing `.contextMenu(menuItems: contextMenu)` line. The popup needs no modifier — `popupPresenter` presents it at window level:

```swift
        .contextMenu(menuItems: contextMenu)
        .opacity(store.isUpdating ? 0.5 : 1.0)
```

- [ ] **Step 10: Add the dimming snapshot test**

Append to `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowViewTests.swift`:

```swift
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
```

- [ ] **Step 11: Record the snapshot**

The suite uses `.snapshots(record: .environment)`, which falls back to `.missing` — a missing snapshot is written to disk and the test *fails on that run*. So run it twice:

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentRowViewTests`
Expected: FAIL, with a new PNG written under `Snapshots/DocumentsFeatureTests/DocumentRowViewTests/`.

Inspect the new PNG and confirm the row is visibly dimmed, then run the same command again.
Expected: PASS.

- [ ] **Step 12: Commit**

```bash
swiftformat .
git add Modules/DocumentsFeature/DocumentRow/ \
        Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift \
        Modules/DocumentsFeatureTests/DocumentRow/ \
        Shared/Framework/Resources/Localizable.xcstrings \
        Snapshots/DocumentsFeatureTests/
git commit -m "feat: add delete confirmation to the document row context menu"
```

---

### Task 3: List-level delete effect and local cleanup

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: `@Dependency(\.deleteDocuments.execute)` from Task 1; `DocumentRowReducer.Action.Delegate.deleteDocument` and `DocumentRowReducer.State.isUpdating` from Task 2.
- Produces: `DocumentListReducer.Action.delegate(.documentsDeleted(Set<Document.Id>))` and `DocumentListReducer.Action.documentsDeleted(Set<Document.Id>)`. Task 4 consumes both.

- [ ] **Step 1: Write the failing tests**

Add to `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`. Note the default `State.testValue()` holds documents with ids 1–4 and `totalNumberOfDocuments: 42`.

```swift
    @Test
    func test_documents_element_delegate_deleteDocument_success() async throws {
        let idsReceived = LockIsolated<[Document.Id]?>(nil)
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                allLoadedDocuments: [1, 2, 3, 4],
                allMatchingDocuments: [1, 2, 3, 4],
                selectedDocuments: [1, 2]
            ),
            path: StackState([.documentDetail(.testValue(document: .testValue(id: 2)))])
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.deleteDocuments.execute = { ids, _ in
                idsReceived.setValue(ids)
            }
        }

        await store.send(.documents(.element(id: 2, action: .delegate(.deleteDocument))))
        await store.receive(\.isUpdating) {
            $0.documents[id: 2]?.isUpdating = true
        }
        await store.receive(\.documentsDeleted, [2]) {
            $0.documents.remove(id: 2)
            $0.documentSelection.allLoadedDocuments = [1, 3, 4]
            $0.documentSelection.allMatchingDocuments = [1, 3, 4]
            $0.documentSelection.selectedDocuments = [1]
            $0.path = StackState()
            $0.totalNumberOfDocuments = 41
        }
        await store.receive(\.delegate, .documentsDeleted([2]))

        #expect(idsReceived.value == [2])
    }
```

```swift
    @Test
    func test_documents_element_delegate_deleteDocument_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        } withDependencies: {
            $0.deleteDocuments.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.documents(.element(id: 2, action: .delegate(.deleteDocument))))
        await store.receive(\.isUpdating) {
            $0.documents[id: 2]?.isUpdating = true
        }
        await store.receive(\.deleteDocumentsFailed) {
            $0.documents[id: 2]?.isUpdating = false
        }

        #expect(toasts.value == [.error("Something went wrong")])
        #expect(store.state.documents.ids.elements == [1, 2, 3, 4])
        #expect(store.state.error == nil)
    }
```

```swift
    @Test
    func test_documentsDeleted_leavesUnrelatedStateAlone() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(selectedDocuments: [1, 3]),
            path: StackState([.documentDetail(.testValue(document: .testValue(id: 3)))])
        )) {
            DocumentListReducer()
        }

        await store.send(.documentsDeleted([99])) {
            $0.totalNumberOfDocuments = 42
        }

        #expect(store.state.documents.ids.elements == [1, 2, 3, 4])
        #expect(store.state.path.count == 1)
    }
```

The last test's trailing closure asserts no change; assigning `totalNumberOfDocuments` to its existing value keeps `TestStore` satisfied that the action was exhaustively handled while documenting the intent. If `TestStore` objects that nothing changed, drop the closure entirely and keep only the `#expect`s.

`ApiError` and `Toast` come from imports already present in the file (`ApiInterface`, `Components`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentListReducerTests`

Expected: FAIL — compile error, `type 'DocumentListReducer.Action' has no member 'documentsDeleted'`.

- [ ] **Step 3: Add the actions**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`, add to `Action` (alphabetical, after `case binding`/before `case destination` as appropriate):

```swift
        case delegate(Delegate)
        case deleteDocumentsFailed(ids: Set<Document.Id>, error: Error)
        case documentsDeleted(Set<Document.Id>)
        case isUpdating(ids: Set<Document.Id>, isUpdating: Bool)
```

And the delegate enum, alongside the existing nested `View` enum:

```swift
        public enum Delegate: Equatable {
            case documentsDeleted(Set<Document.Id>)
        }
```

`Action` is already non-`Equatable` because of its existing `error(Error)` case, so carrying an `Error` costs nothing.

- [ ] **Step 4: Replace the compile stub and add the handlers**

Replace the Task 2 stub:

```swift
                case .deleteDocument:
                    return .runDeleteDocuments(ids: [id], server: state.server)
```

Note this needs the element id, so change the case binding from `.element(id: _, ...)` back to `.element(id: id, ...)`.

Add the three new handlers, in alphabetical position within the outer switch:

```swift
            case let .deleteDocumentsFailed(ids: ids, error: error):
                for id in ids {
                    state.documents[id: id]?.isUpdating = false
                }
                return .toast(error)
```

```swift
            case let .documentsDeleted(ids):
                let countBefore = state.documents.count
                state.documents.removeAll { ids.contains($0.id) }
                state.documentSelection.allLoadedDocuments.subtract(ids)
                state.documentSelection.allMatchingDocuments.subtract(ids)
                state.documentSelection.selectedDocuments.subtract(ids)
                // Cleared by id rather than with `removeAll(where:)`: the latter rebuilds the
                // stack through `replaceSubrange`, which hands the surviving screens fresh
                // `StackElementID`s and makes SwiftUI treat them as new pushes.
                for elementId in state.path.ids {
                    guard case let .documentDetail(detail) = state.path[id: elementId],
                          ids.contains(detail.document.id)
                    else {
                        continue
                    }
                    state.path[id: elementId] = nil
                }
                state.totalNumberOfDocuments = max(
                    0,
                    state.totalNumberOfDocuments - (countBefore - state.documents.count)
                )
                return .none
```

```swift
            case let .isUpdating(ids: ids, isUpdating: isUpdating):
                for id in ids {
                    state.documents[id: id]?.isUpdating = isUpdating
                }
                return .none
```

Finally add `delegate` to the catch-all case at the bottom of the switch:

```swift
            case .binding, .delegate, .destination, .documentImport, .documentSelection, .documents, .path:
                return .none
```

**Do not** route the failure through the existing `.error` case — it assigns `state.error`, which `DocumentListEmptyView` renders as a full-screen error state. That is the entire reason `deleteDocumentsFailed` exists.

**Do not** clear the `path` with `removeAll(where:)`, even though `StackState` conforms to
`RangeReplaceableCollection`. Its default implementation rebuilds the collection through
`replaceSubrange`, which assigns fresh `StackElementID`s from `stackElementID.next()` to the
surviving elements — SwiftUI would then treat untouched pushed screens as brand-new pushes.
Assigning `state.path[id:] = nil` clears the entry from the backing dictionary and leaves every
other id intact. `test_documentsDeleted_leavesUnrelatedStateAlone` is what catches this, since
`StackState`'s `Equatable` conformance compares ids.

`DocumentListReducer.swift` must also gain `import Tagged` — `Set<Document.Id>` needs the
`Hashable` conformance of `Tagged` to be visible in the file that declares it.

- [ ] **Step 5: Add the effect**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift`, add the effect (alphabetically first, before `runGetDocuments`):

```swift
    /**
     * Deletes documents on the server, then announces the removal locally and to the other tab.
     *
     * The rows are dimmed for the duration rather than removed optimistically, so a failure
     * leaves the list exactly as it was.
     *
     * - Parameters:
     *   - ids: The documents to delete.
     *   - server: The server to delete them from.
     */
    static func runDeleteDocuments(
        ids: Set<Document.Id>,
        server: Server
    ) -> Self {
        @Dependency(\.deleteDocuments.execute)
        var deleteDocuments

        return .run { send in
            await send(.isUpdating(ids: ids, isUpdating: true))
            try await deleteDocuments(ids.sorted(), server)
            await send(.documentsDeleted(ids), animation: .default)
            await send(.delegate(.documentsDeleted(ids)))
        } catch: { error, send in
            await send(.deleteDocumentsFailed(ids: ids, error: error))
        }
        .cancellable(id: CancelID.deleteDocuments)
    }
```

And add to the `CancelID` enum at the bottom of the file (alphabetical):

```swift
private enum CancelID {
    case deleteDocuments
    case getDocuments
    case getMoreDocuments
    case refreshDocuments
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentListReducerTests`

Expected: PASS, including all pre-existing tests in the suite.

- [ ] **Step 7: Commit**

```bash
swiftformat .
git add Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift \
        Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift \
        Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift
git commit -m "feat: delete a document from the document list"
```

---

### Task 4: Cross-tab forwarding in `MainReducer`

**Files:**
- Modify: `Modules/AppFeature/MainReducer.swift`
- Test: `Modules/AppFeatureTests/MainReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentListReducer.Action.delegate(.documentsDeleted(Set<Document.Id>))` and `DocumentListReducer.Action.documentsDeleted(Set<Document.Id>)` from Task 3. Both must be `public` — `Action` and its nested `Delegate` already are.
- Produces: nothing further.

- [ ] **Step 1: Write the failing tests**

Add to `Modules/AppFeatureTests/MainReducerTests.swift`. `MainReducer.State.init` builds both lists empty, so seed them through the store's state before sending.

```swift
    @Test
    func test_documentList_delegate_documentsDeleted_forwardsToInbox() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: MainReducer.State(server: server),
            reducer: { MainReducer() }
        )

        await store.send(.documentList(.delegate(.documentsDeleted([7]))))
        await store.receive(\.inbox.documentsDeleted, [7])
    }
```

```swift
    @Test
    func test_inbox_delegate_documentsDeleted_forwardsToDocumentList() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: MainReducer.State(server: server),
            reducer: { MainReducer() }
        )

        await store.send(.inbox(.delegate(.documentsDeleted([7]))))
        await store.receive(\.documentList.documentsDeleted, [7])
    }
```

The absence of any further `receive` in each test is the assertion that forwarding terminates — `TestStore` fails the test if an action goes unasserted. That is what makes the two-action split (see the design doc) verifiable rather than merely intended.

`MainReducerTests` is currently declared as a bare `@Suite`, unlike every other suite in the
codebase. Give it the project's standard trait and `import TestSupport`:

```swift
@MainActor
@Suite(
    .dependencies()
)
struct MainReducerTests {
```

`.dependencies()` sets `$0.timeZone = .gmt`. Without it, whichever test first triggers the lazily
initialized `DateFormatter.createdDate` (`ApiInterface/Extensions/DateFormatter+Extensions.swift`)
fails with "`@Dependency(\.timeZone)` has no test implementation" — an ordering artifact that lands
on whichever test happens to run first, not on the one that is actually wrong.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test AppFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:AppFeatureTests/MainReducerTests`

Expected: FAIL — compile error, `type 'DocumentListReducer.Action' has no member 'delegate'` is resolvable but the reducer does not forward, so the `receive` times out with "expected to receive an action, but received none".

- [ ] **Step 3: Add the forwarding**

In `Modules/AppFeature/MainReducer.swift`, add two cases to the `Reduce` switch, before the existing catch-all:

```swift
            case let .documentList(.delegate(.documentsDeleted(ids))):
                return .send(.inbox(.documentsDeleted(ids)))
            case let .inbox(.delegate(.documentsDeleted(ids))):
                return .send(.documentList(.documentsDeleted(ids)))
```

The catch-all `case .documentList, .inbox, .settingList:` stays as-is and absorbs everything else, including the forwarded `documentsDeleted` — which is exactly why the loop terminates.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tuist test AppFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:AppFeatureTests/MainReducerTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
swiftformat .
git add Modules/AppFeature/MainReducer.swift Modules/AppFeatureTests/MainReducerTests.swift
git commit -m "feat: remove a deleted document from both document tabs"
```

---

### Task 5: Cross-tab deletion integration test

**Files:**
- Test: `Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–3. No production code changes.

This task adds no implementation. Its purpose is to pin down the *exception* to the rule the existing tests in this file establish: an edit never moves membership, but a delete does.

- [ ] **Step 1: Write the test**

Append to `Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`. Read the existing tests first — this one follows their shape, but drives a real `DocumentListReducer` rather than a `DocumentFormReducer`.

```swift
    @Test
    func test_deleteFromOneList_removesRowFromBothLists() async throws {
        let server = Server.testValue()
        let inbox = DocumentListReducer.State.testValue(
            documents: [],
            filter: .inbox(server: server),
            server: server
        )
        let documentList = DocumentListReducer.State.testValue(
            documents: [],
            server: server
        )

        var inboxState = inbox
        inboxState.documents = inboxState.rows(for: [
            .testValue(id: 15, title: "Warranty"),
            .testValue(id: 7, title: "Invoice"),
        ])
        var documentListState = documentList
        documentListState.documents = documentListState.rows(for: [
            .testValue(id: 7, title: "Invoice"),
            .testValue(id: 12, title: "Contract"),
        ])

        let documentListStore = TestStore(initialState: documentListState) {
            DocumentListReducer()
        } withDependencies: {
            $0.deleteDocuments.execute = { _, _ in }
        }
        let inboxStore = TestStore(initialState: inboxState) {
            DocumentListReducer()
        }

        await documentListStore.send(.documents(.element(id: 7, action: .delegate(.deleteDocument))))
        await documentListStore.receive(\.isUpdating) {
            $0.documents[id: 7]?.isUpdating = true
        }
        await documentListStore.receive(\.documentsDeleted, [7]) {
            $0.documents.remove(id: 7)
            $0.totalNumberOfDocuments = 41
        }
        await documentListStore.receive(\.delegate, .documentsDeleted([7]))

        // MainReducer forwards the delegate to the other tab; this is that hop.
        await inboxStore.send(.documentsDeleted([7])) {
            $0.documents.remove(id: 7)
            $0.totalNumberOfDocuments = 41
        }

        // The document is gone from both tabs...
        #expect(documentListStore.state.documents.ids.elements == [12])
        #expect(inboxStore.state.documents.ids.elements == [15])

        // ...and the surviving rows kept their order and content.
        #expect(inboxStore.state.documents[id: 15]?.document.title == "Warranty")
        #expect(documentListStore.state.documents[id: 12]?.document.title == "Contract")
    }
```

- [ ] **Step 2: Run the test**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/CrossTabDocumentSyncTests`

Expected: PASS. If `totalNumberOfDocuments` assertions fail, check the actual default in `DocumentListReducer.State.testValue` (42 at time of writing) and adjust — the point of the assertion is the decrement of exactly one, not the absolute number.

- [ ] **Step 3: Commit**

```bash
swiftformat .
git add Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift
git commit -m "test: cover cross-tab removal of a deleted document"
```

---

### Task 6: Full verification

**Files:** none.

- [ ] **Step 1: Run the whole test suite**

Run: `mise ci:test`

Expected: PASS. This runs every module's tests on `iPhone 17 Pro`, including the `ApiImplementation` integration tests — those need the docker Paperless container. If it is not running, start it with the `mise docker:*` tasks (see `mise/tasks/docker/`) or accept and note the integration-test failures as pre-existing/environmental rather than caused by this change.

- [ ] **Step 2: Lint**

Run: `mise ci:lint`

Expected: PASS — `swiftformat --lint`, `swiftlint --strict`, and `tuist inspect dependencies --only implicit` all clean. `tuist inspect dependencies` matters here: `DocumentsFeature` now uses `\.deleteDocuments` from `ApiInterface`, which it already depends on, so no new module dependency should appear.

- [ ] **Step 3: Manual check in the simulator**

Run the `Less Paper` scheme against the seeded docker server and confirm:

1. Long-pressing a document row shows "Edit document" and a red "Delete document".
2. Tapping "Delete document" shows a dialog reading `Do you really want to delete "<title>"?` with a red "Delete document" and a "Cancel".
3. Cancelling leaves the row untouched.
4. Confirming dims the row briefly, then animates it out.
5. The same document, if visible in the other tab, is gone there too when you switch tabs.
6. The "n of m loaded" status bar decremented by one.

- [ ] **Step 4: Push and open a PR**

```bash
git push -u origin delete_context_menu
gh pr create --title "feat: delete a document from the row context menu" --body "$(cat <<'EOF'
Adds a "Delete document" item to the document row context menu, guarded by a confirmation dialog.

Deletion goes through a new `DeleteDocumentsUseCase` over the existing `bulk_edit` `.delete`
method. On success the document is removed from the shared document cache, from both tabs' lists,
from the selection sets, and from any navigation stack showing its detail screen.

Design: `docs/plans/2026-08-14-delete-document.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01BWdim7BJpRRU4xhSMVKyYr
EOF
)"
```

---

## Notes for the implementer

**Why `deleteDocumentsFailed` carries its own `Error`.** The obvious move is `await send(.error(error))`, reusing the list's existing error action. Do not. That case assigns `state.error`, and `DocumentListEmptyView` turns a non-nil `state.error` into a full-screen "something went wrong" view whenever the list is empty. Delete the last visible row, have the request fail, and the user is looking at an error screen for a list that is merely empty. `state.error` means "the fetch failed" and nothing else.

**Why two actions instead of one.** `documentsDeleted` prunes and returns `.none`. It does *not* emit `delegate(.documentsDeleted)` — the effect does that, once, in whichever list ran the delete. If `documentsDeleted` re-emitted the delegate, `MainReducer` would forward it back and the two lists would ping-pong forever. The `MainReducerTests` in Task 4 assert termination.

**Ordering of cache eviction.** `DeleteDocumentsUseCase` removes the cache entry before `documentsDeleted` reaches the reducers, so for one action's worth of time a row references a missing cache entry. `Shared($documentCache[id:])` produces an `_OptionalReference` that retains its last observed value, so the row renders its old content for that instant and is then removed. No crash, no blank cell. This is documented in `docs/plans/2026-08-12-cross-tab-document-sync.md`.
