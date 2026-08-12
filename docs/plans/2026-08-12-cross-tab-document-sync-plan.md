# Cross-tab document sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An edit made to a document anywhere in the app updates every on-screen representation of it — rows in both the Inbox and Documents tabs, detail screens in both nav stacks, and any open edit form.

**Architecture:** Split the two concerns currently fused into each tab's document list. Each tab keeps owning **order and membership** in its own `DocumentListReducer.State.documents`. **Content** moves into a single per-server `@Shared` in-memory store keyed by document id. Rows, detail screens and forms hold `Shared<Document>` references into that store, so one write updates all of them and touches no list's ordering.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture 1.25.5, swift-sharing 2.8.0 (aliased to module `SwiftSharing`), Tuist 4.203.4, Swift Testing.

Full design rationale: `docs/plans/2026-08-12-cross-tab-document-sync.md`.

## Global Constraints

- Swift documentation comments follow `.claude/CLAUDE.md`: `///` for single-line, `/** */` for multiline with parameters.
- The shared store is `.inMemory`, never `.fileStorage`.
- An edit made in one tab must never change the other tab's list membership or ordering. Only content propagates.
- `import SwiftSharing`, not `import Sharing` — `Tuist/Package.swift` sets `-module-alias Sharing=SwiftSharing`. `import ComposableArchitecture` also re-exports it.
- Background content refreshes swallow errors. Never route them to `DocumentListReducer.Action.error`, which sets `state.error` and surfaces `DocumentListEmptyView`.
- Run tests with `mise exec -- tuist test <Scheme> -d "iPhone 17 Pro"`, narrowing with `--test-targets TestTarget/TestSuite/testMethod`. Schemes used here: `ApiImplementation`, `DocumentsFeature`.
- Commit after every task.

## Background the implementer needs

**`Shared` compares by value, not by reference.** `Shared: Equatable where Value: Equatable` compares `lhs.wrappedValue == rhs.wrappedValue` (`swift-sharing/Sources/Sharing/Shared.swift:430`). This is why existing assertions like `$0.documents = [.testValue()]` keep working once row state holds a `Shared<Document>` — a detached `Shared(value: doc)` equals a store-backed reference holding the same document.

**Element scoping.** For `@Shared var cache: IdentifiedArrayOf<Document>`, the expression `$cache[id: someID]` yields `Shared<Document?>` (Swift key-path dynamic member lookup forwards subscript syntax), and `Shared(_:)` is a failable initialiser that unwraps it to `Shared<Document>`. Writing through the unwrapped reference writes into the array.

**Dangling references fail soft.** That unwrap produces an `_OptionalReference`, which caches the last value it observed. If an id ever left the store while a row still referenced it, the row would render its last-known content rather than crash.

**Test isolation is automatic.** The `.dependencies()` suite trait (`Modules/TestSupport/Extensions/`) resolves to `_DependenciesTrait`, which assigns a brand-new `DependencyValues()` per test — including a fresh `CachedValues` and therefore a fresh `InMemoryStorage`. Within one test, every `@Shared(.documents(server))` for the same server resolves to the same store; across tests they are isolated. All four `DocumentsFeatureTests` suites already carry this trait. Do not add manual storage resets.

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift` | Input carrying the ids to fetch |
| `Modules/ApiInterface/Documents/GetDocumentsByIdsUseCase.swift` | Use case contract + test/preview values + `DependencyValues` accessor |
| `Modules/ApiImplementation/Documents/GetDocumentsByIdsUseCase.swift` | Live wiring to the repository |
| `Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift` | The end-to-end test of the feature |

**Modified:**

| File | Change |
|---|---|
| `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift` | Add the `documents(_:)` in-memory key |
| `Modules/ApiImplementation/Documents/DocumentsRepository.swift` | Add `getDocumentsByIds` closure, live impl, and its `Request` init |
| `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` | `documentCache`, `cacheDocuments(_:)`/`rows(for:)`, bulk-edit delegate cases, `documentsRefreshed`, delete the `path` propagation case |
| `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift` | `runRefreshDocuments` + chunking helper |
| `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift` | `@Shared` document, delegate carries `Shared<Document>`, form gets `$document` |
| `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift` | `@Shared` document + explicit init, form gets `$document` |
| `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift` | `@Shared` document, write-through save, delegate payload dropped |
| `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer.swift` + `+Effect.swift` | Delegate carries affected ids |
| `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer.swift` + `+Effect.swift` | Delegate carries affected ids |
| The four `+TestValue.swift` helpers and the four reducer test files | Follow the signature changes |

Views (`DocumentRowView`, `DocumentDetailView`, `DocumentFormView`, `DocumentListView`, `InboxView`) need **no changes**: `store.document` still yields a `Document`, because that is `@Shared`'s wrapped value.

---

### Task 1: `GetDocumentsByIdsUseCase`

Fetches specific documents by id so bulk edits can refresh content the initiating list's own re-fetch will not cover. Independent of every other task.

**Files:**
- Create: `Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift`
- Create: `Modules/ApiInterface/Documents/GetDocumentsByIdsUseCase.swift`
- Create: `Modules/ApiImplementation/Documents/GetDocumentsByIdsUseCase.swift`
- Modify: `Modules/ApiImplementation/Documents/DocumentsRepository.swift`
- Test: `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `@Dependency(\.getDocumentsByIds.execute)` with signature `@Sendable (GetDocumentsByIdsInput, Server) async throws -> [Document]`, and `GetDocumentsByIdsInput(ids: [Document.Id])`. Task 5 consumes both.

- [ ] **Step 1: Write the failing tests**

Append these two tests to `DocumentsRepositoryTests.swift`, immediately after `test_getAllDocumentIds` (which ends around line 284). The integration test follows the file's existing pattern — it needs the docker Paperless running (`mise docker:start`, `mise docker:seed`) and is tagged so it can be skipped otherwise. The empty-ids test is a pure unit test and needs no server.

```swift
    @Test
    func test_getDocumentsByIds_emptyIds_returnsEmpty() async throws {
        let documents = try await repository.getDocumentsByIds(
            input: .init(ids: []),
            server: .testValue()
        )

        #expect(documents.isEmpty)
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getDocumentsByIds() async throws {
        let allIds = try await repository.getAllDocumentIds(
            input: .testValue(
                filterRules: [.init(ruleType: .title, value: "Lego")]
            ),
            server: .testValue()
        )
        let ids = allIds.results.map(\.id)

        let documents = try await repository.getDocumentsByIds(
            input: .init(ids: ids),
            server: .testValue()
        )

        #expect(Set(documents.map(\.id)) == Set(ids))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" \
  --test-targets ApiImplementationTests/DocumentsRepositoryTests/test_getDocumentsByIds_emptyIds_returnsEmpty
```

Expected: compile failure — `value of type 'DocumentsRepository' has no member 'getDocumentsByIds'`.

- [ ] **Step 3: Create the input**

`Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift`:

```swift
import Foundation

public struct GetDocumentsByIdsInput: Codable, Equatable, Sendable {

    public let ids: [Document.Id]

    public init(
        ids: [Document.Id]
    ) {
        self.ids = ids
    }
}

public extension GetDocumentsByIdsInput {

    static func testValue(
        ids: [Document.Id] = []
    ) -> Self {
        .init(
            ids: ids
        )
    }
}
```

- [ ] **Step 4: Create the use case contract**

`Modules/ApiInterface/Documents/GetDocumentsByIdsUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetDocumentsByIdsUseCase: Sendable {

    public var execute: @Sendable (
        _ input: GetDocumentsByIdsInput,
        _ server: Server
    ) async throws -> [Document]
}

extension GetDocumentsByIdsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in [] }
    )

    public static let testValue = Self(
        execute: { _, _ in [] }
    )
}

public extension DependencyValues {

    var getDocumentsByIds: GetDocumentsByIdsUseCase {
        get { self[GetDocumentsByIdsUseCase.self] }
        set { self[GetDocumentsByIdsUseCase.self] = newValue }
    }
}
```

- [ ] **Step 5: Add the repository closure**

In `DocumentsRepository.swift`, add to the `@DependencyClient struct DocumentsRepository` declaration, directly after the existing `getDocuments` property (which ends at the line `) async throws -> GetDocumentsOutput`):

```swift
    var getDocumentsByIds: @Sendable (
        _ input: GetDocumentsByIdsInput,
        _ server: Server
    ) async throws -> [Document]
```

Add `getDocumentsByIds: { _, _ in [] },` to **both** `previewValue` and `testValue`, directly after the `getDocuments:` line in each.

Add `getDocumentsByIds: getDocumentsByIds(input:server:),` to `liveValue`, directly after the `getDocuments:` line.

- [ ] **Step 6: Add the live implementation and request**

In `DocumentsRepository.swift`, inside `private extension DocumentsRepository`, add after the existing `getDocuments(input:server:)` function:

```swift
    static func getDocumentsByIds(
        input: GetDocumentsByIdsInput,
        server: Server
    ) async throws -> [Document] {
        guard !input.ids.isEmpty else {
            return []
        }

        return try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
            .results
    }
```

Then add a second initialiser to the existing `private extension Request where Response == GetDocumentsOutput` block, after `init(input: GetDocumentsInput)`:

```swift
    init(input: GetDocumentsByIdsInput) {
        self.init(
            path: "/api/documents/",
            method: .get,
            query: [
                "id__in": input.ids.map { "\($0.rawValue)" }.joined(separator: ","),
                "page": "1",
                "page_size": "\(input.ids.count)",
                "truncate_content": "true",
            ]
        )
    }
```

- [ ] **Step 7: Wire the live use case**

`Modules/ApiImplementation/Documents/GetDocumentsByIdsUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetDocumentsByIdsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension GetDocumentsByIdsUseCase {

    static func execute(
        input: GetDocumentsByIdsInput,
        server: Server
    ) async throws -> [Document] {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.getDocumentsByIds(
            input: input,
            server: server
        )
    }
}
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" \
  --test-targets ApiImplementationTests/DocumentsRepositoryTests
```

Expected: PASS. The integration-tagged test needs docker; if it is not running, confirm at minimum that `test_getDocumentsByIds_emptyIds_returnsEmpty` passes and note the skip.

- [ ] **Step 9: Commit**

```bash
git add Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift \
        Modules/ApiInterface/Documents/GetDocumentsByIdsUseCase.swift \
        Modules/ApiImplementation/Documents/GetDocumentsByIdsUseCase.swift \
        Modules/ApiImplementation/Documents/DocumentsRepository.swift \
        Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift
git commit -m "feat: add use case to fetch documents by id"
```

---

### Task 2: Shared document store, referenced by rows

Introduces the store and makes list rows read their content from it. After this task an external write to the store visibly updates a row, but nothing writes to it yet except fetches.

**Files:**
- Modify: `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift:30-79`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+TestValue.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift:53-215`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces:
  - `SharedReaderKey.documents(_ server: Server)` → `InMemoryKey<IdentifiedArrayOf<Document>>.Default`
  - `DocumentListReducer.State.documentCache: IdentifiedArrayOf<Document>` (a `@Shared` property; projected value `$documentCache`)
  - `DocumentListReducer.State.cacheDocuments(_ documents: [Document])`
  - `DocumentListReducer.State.rows(for documents: [Document]) -> IdentifiedArrayOf<DocumentRowReducer.State>`
  - `DocumentRowReducer.State.init(document: Shared<Document>, server: Server)` and its `$document` projected value. Tasks 3, 4, 5 and 6 all consume these.

- [ ] **Step 1: Write the failing tests**

Add to `DocumentListReducerTests.swift`, at the end of the suite (before the closing brace). The first test proves fetched documents land in the store; the second is the one that matters — it proves rows are *references*, not copies.

```swift
    @Test
    func test_replaceDocuments_cachesDocuments() async throws {
        let document = Document.testValue(id: 7, title: "Invoice")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: []
        )) {
            DocumentListReducer()
        }

        await store.send(.replaceDocuments(.testValue(
            count: 1,
            results: [document]
        ))) {
            $0.documents = [.testValue(document: document)]
            $0.documentSelection.allLoadedDocuments = [7]
            $0.totalNumberOfDocuments = 1
            $0.$documentCache.withLock { $0 = [document] }
        }
    }

    @Test
    func test_rows_referenceDocumentCache() async throws {
        let state = DocumentListReducer.State.testValue(documents: [])
        let rows = state.rows(for: [.testValue(id: 7, title: "Invoice")])

        state.$documentCache.withLock {
            $0[id: 7] = .testValue(id: 7, title: "Renamed")
        }

        #expect(rows[id: 7]?.document.title == "Renamed")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" \
  --test-targets DocumentsFeatureTests/DocumentListReducerTests/test_rows_referenceDocumentCache
```

Expected: compile failure — `value of type 'DocumentListReducer.State' has no member 'rows'`.

- [ ] **Step 3: Add the shared key**

In `SharedReaderKey+Extensions.swift`, insert after the `documentTypes(_:)` extension (which ends at line 43):

```swift
public extension SharedReaderKey where Self == InMemoryKey<IdentifiedArrayOf<Document>>.Default {

    /// Per-server store of document content, keyed by id.
    ///
    /// Used as an `id → Document` map — its ordering is meaningless and nothing displays it.
    /// In-memory rather than file-backed: documents are paginated and far more numerous than
    /// the other cached entities, and there is no offline requirement.
    static func documents(_ server: Server) -> Self {
        Self[
            .inMemory("\(server.id)-documents"),
            default: []
        ]
    }
}
```

- [ ] **Step 4: Make the row hold a reference**

In `DocumentRowReducer.swift`, replace the stored `var document: Document` (line 42) with:

```swift
        @Shared
        var document: Document
```

and replace the initialiser (lines 72-78) with:

```swift
        init(
            document: Shared<Document>,
            server: Server
        ) {
            self._document = document
            self.server = server
        }
```

Leave `id`, the computed properties and the reducer body untouched — `state.document` still yields a `Document`.

- [ ] **Step 5: Update the row test helper**

Replace `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+TestValue.swift` entirely:

```swift
import ApiInterface
import Foundation
import SwiftSharing

extension DocumentRowReducer.State {

    static func testValue(
        document: Document = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            document: Shared(value: document),
            server: server
        )
    }
}
```

A detached `Shared(value:)` is correct here and still compares equal to a store-backed reference holding the same document.

- [ ] **Step 6: Add the store and helpers to the list**

In `DocumentListReducer.swift`, add to `State` after the `correspondents` shared property (line 89):

```swift
        @Shared

        var documentCache: IdentifiedArrayOf<Document>
```

and in the initialiser, alongside the other shared assignments (after line 133):

```swift
            self._documentCache = Shared(wrappedValue: [], .documents(server))
```

Then add these two methods inside `State`, after the initialiser:

```swift
        /// Upserts documents into the shared store without touching this list's membership.
        func cacheDocuments(_ documents: [Document]) {
            $documentCache.withLock { cache in
                for document in documents {
                    cache.updateOrAppend(document)
                }
            }
        }

        /**
         * Caches the given documents and builds rows referencing them.
         *
         * The upsert must happen before the rows are built — each row holds a reference into
         * the store, which has to exist first.
         *
         * - Parameter documents: The documents this list should show, in display order.
         * - Returns: Rows referencing the shared store, in the same order.
         */
        func rows(for documents: [Document]) -> IdentifiedArrayOf<DocumentRowReducer.State> {
            cacheDocuments(documents)
            return IdentifiedArray(uniqueElements: documents.map { document in
                DocumentRowReducer.State(
                    document: Shared($documentCache[id: document.id])!,
                    server: server
                )
            })
        }
```

- [ ] **Step 7: Build rows through the helper**

In the reducer body, replace the `appendDocuments` case (lines 151-161) with:

```swift
            case let .appendDocuments(output):
                let rows = state.rows(for: output.results)
                state.documents.append(contentsOf: rows)
                state.documentSelection.allLoadedDocuments.formUnion(Set(output.results.map(\.id)))
                state.nextPage = output.next
                state.totalNumberOfDocuments = output.count
                return .none
```

and the `replaceDocuments` case (lines 203-215) with:

```swift
            case let .replaceDocuments(output):
                state.documents = state.rows(for: output.results)
                state.documentSelection.allLoadedDocuments = Set(output.results.map(\.id))
                state.nextPage = output.next
                state.totalNumberOfDocuments = output.count
                return .none
```

The local `rows` binding in `appendDocuments` is deliberate: writing `state.documents.append(contentsOf: state.rows(for:))` would open an exclusive access to `state.documents` while `rows(for:)` reads `state`.

- [ ] **Step 8: Update the pre-existing assertions in the suite**

`TestStore` fails on shared-state mutations that are not asserted, and every fetch now writes to `documentCache`. Seven existing tests in `DocumentListReducerTests.swift` need one extra line each.

In these six, add `$0.$documentCache.withLock { $0 = [.testValue()] }` to the assertion block that already contains `$0.documents = [.testValue()]`:

| Line | Test |
|---|---|
| 56 | `test_destination_documentFilter_delegate_filterUpdated` |
| 158 | `test_view_allDocumentsButtonTapped` |
| 256 | `test_view_onAppear_withoutDocuments` |
| 289 | `test_view_refresh` |
| 417 | `test_view_savedViewButtonTapped` |
| 568 | `test_destination_bulkEditCorrespondent_documentsUpdated` |

For example, at line 56 the block becomes:

```swift
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
            $0.$documentCache.withLock { $0 = [.testValue()] }
        }
```

In `test_view_onRowAppear_withNextPage` (line ~347) the append path caches only the appended document, so add:

```swift
            $0.$documentCache.withLock { $0 = [.testValue(id: 4)] }
```

The store starts empty in all of these: the default `documents:` rows from `DocumentListReducer.State.testValue` are built with detached `Shared(value:)` references and never enter the store.

`test_destination_bulkEditTags_documentsUpdated` (line 630) is rewritten wholesale in Task 5 — leave it for now by adding `$0.$documentCache.withLock { $0 = [.testValue()] }` like the others.

- [ ] **Step 9: Run the tests to verify they pass**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" \
  --test-targets DocumentsFeatureTests/DocumentListReducerTests
```

Expected: PASS.

- [ ] **Step 10: Run the whole module**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro"
```

Expected: PASS. Snapshot tests should be unaffected — rendering has not changed.

- [ ] **Step 11: Commit**

```bash
git add Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift \
        Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift \
        Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+TestValue.swift \
        Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift \
        Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift
git commit -m "feat: back document rows with a shared per-server document store"
```

---

### Task 3: Detail screens share the document

Pushes the reference one level deeper, so a detail screen open in either tab's nav stack tracks the store.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift:15-17, 96-98, 107`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift:28-41`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer+TestValue.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift:185-193`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`, `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentRowReducer.State.$document` and `DocumentListReducer.State.rows(for:)` from Task 2.
- Produces: `DocumentRowReducer.Action.Delegate.presentDocumentDetail(Shared<Document>)` and `DocumentDetailReducer.State.init(destination:document:downloadResult:quickLookPreview:server:)` taking `document: Shared<Document>`. Task 4 consumes the latter.

- [ ] **Step 1: Write the failing tests**

Replace the existing `test_view_rowTapped` in `DocumentRowReducerTests.swift` (lines 34-46) with:

```swift
    @Test
    func test_view_rowTapped() async throws {
        let document = Document.testValue()
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: document
        )) {
            DocumentRowReducer()
        }

        await store.send(.view(.rowTapped))
        await store.receive(\.delegate, .presentDocumentDetail(Shared(value: document)))
    }
```

and add `import SwiftSharing` to that file's imports.

Add to `DocumentListReducerTests.swift`, at the end of the suite:

```swift
    @Test
    func test_documentDetail_referencesDocumentCache() async throws {
        let state = DocumentListReducer.State.testValue(documents: [])
        let rows = state.rows(for: [.testValue(id: 7, title: "Invoice")])
        let detail = DocumentDetailReducer.State(
            document: rows[id: 7]!.$document,
            server: state.server
        )

        state.$documentCache.withLock {
            $0[id: 7] = .testValue(id: 7, title: "Renamed")
        }

        #expect(detail.document.title == "Renamed")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" \
  --test-targets DocumentsFeatureTests/DocumentListReducerTests/test_documentDetail_referencesDocumentCache
```

Expected: compile failure — cannot convert `Shared<Document>` to `Document`.

- [ ] **Step 3: Make the delegate carry the reference**

In `DocumentRowReducer.swift`, change the delegate case (line 16) to:

```swift
            case presentDocumentDetail(Shared<Document>)
```

and the `rowTapped` handler (line 97) to:

```swift
                    return .send(.delegate(.presentDocumentDetail(state.$document)))
```

`extension DocumentRowReducer.Action.Delegate: Equatable {}` at line 107 stays as-is — `Shared<Document>` is `Equatable`.

- [ ] **Step 4: Make the detail hold a reference**

In `DocumentDetailReducer.swift`, replace the whole `State` struct (lines 28-41) with:

```swift
    @ObservableState
    public struct State: Equatable {
        @Presents

        var destination: Destination.State?

        @Shared

        var document: Document

        var downloadResult: DownloadResult?

        var quickLookPreview: URL?

        let server: Server

        init(
            destination: Destination.State? = nil,
            document: Shared<Document>,
            downloadResult: DownloadResult? = nil,
            quickLookPreview: URL? = nil,
            server: Server
        ) {
            self.destination = destination
            self._document = document
            self.downloadResult = downloadResult
            self.quickLookPreview = quickLookPreview
            self.server = server
        }
    }
```

The explicit initialiser is required: the synthesised memberwise initialiser does not do the right thing for a `@Shared` property.

- [ ] **Step 5: Update the detail test helper**

Replace `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer+TestValue.swift` entirely:

```swift
import ApiInterface
import Foundation
import SwiftSharing

extension DocumentDetailReducer.State {

    static func testValue(
        destination: DocumentDetailReducer.Destination.State? = nil,
        document: Document = .testValue(),
        downloadResult: DownloadResult? = nil,
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            document: Shared(value: document),
            downloadResult: downloadResult,
            server: server
        )
    }
}
```

- [ ] **Step 6: Verify the list call site still compiles**

`DocumentListReducer.swift` lines 185-193 pass the delegate's payload straight into `DocumentDetailReducer.State(document:server:)`. Both are now `Shared<Document>`, so the existing code is already correct:

```swift
            case let .documents(.element(id: _, action: .delegate(delegateAction))):
                switch delegateAction {
                case let .presentDocumentDetail(document):
                    state.path.append(.documentDetail(DocumentDetailReducer.State(
                        document: document,
                        server: state.server
                    )))
                    return .none
                }
```

Make no edit here. Confirm it compiles in the next step.

- [ ] **Step 7: Run the tests to verify they pass**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift \
        Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift \
        Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer+TestValue.swift \
        Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift \
        Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift
git commit -m "feat: share the document reference with detail screens"
```

---

### Task 4: The form writes through

The payoff task. A save becomes one write to the store, and the three hand-written propagation handlers are deleted.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift:21-24, 46-95, 120-127`
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer+TestValue.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift:84-95`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift:47-50, 56-61`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift:197-202`
- Test: all four `DocumentsFeatureTests` reducer test files

**Interfaces:**
- Consumes: `$document` on row and detail state from Tasks 2 and 3.
- Produces: `DocumentFormReducer.State.init(destination:document:server:)` taking `document: Shared<Document>`, and `DocumentFormReducer.Action.Delegate.documentUpdated` **with no associated value**.

- [ ] **Step 1: Write the failing test**

Replace `test_view_saveButtonTapped_success` in `DocumentFormReducerTests.swift` (lines 182-209) with a version that asserts the write reaches an *external* holder of the same reference — that is the entire feature:

```swift
    @Test
    func test_view_saveButtonTapped_success() async throws {
        let updatedDocument = Document.testValue(title: "some new title")
        let document = Shared(value: Document.testValue())
        let store = TestStore(initialState: DocumentFormReducer.State(
            document: document,
            server: .testValue()
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.updateDocument.execute = { _, _, _ in
                updatedDocument
            }
        }

        await store.send(.binding(.set(\.input.title, "some new title"))) {
            $0.input.title = "some new title"
        }
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isUpdating, true)) {
            $0.isUpdating = true
        }
        await store.receive(\.updateResult.success, updatedDocument) {
            $0.$document.withLock { $0 = updatedDocument }
        }
        await store.receive(\.delegate.documentUpdated)
        await store.receive(\.binding, .set(\.isUpdating, false)) {
            $0.isUpdating = false
        }

        #expect(document.wrappedValue == updatedDocument)
    }
```

Add `import SwiftSharing` to that file's imports.

- [ ] **Step 2: Run the test to verify it fails**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" \
  --test-targets DocumentsFeatureTests/DocumentFormReducerTests/test_view_saveButtonTapped_success
```

Expected: compile failure — cannot convert `Shared<Document>` to `Document`.

- [ ] **Step 3: Make the form hold a reference and drop the delegate payload**

In `DocumentFormReducer.swift`, change the delegate (lines 21-24) to:

```swift
        @CasePathable
        public enum Delegate {
            case documentUpdated
        }
```

Change the stored document (line 52) to:

```swift
        @Shared
        var document: Document
```

and the initialiser (lines 78-94) to:

```swift
        init(
            destination: DocumentFormReducer.Destination.State? = nil,
            document: Shared<Document>,
            server: Server
        ) {
            self.destination = destination
            self._document = document
            self.input = DocumentFormInput(
                document: document.wrappedValue,
                server: server
            )
            self.server = server
            self._correspondents = Shared(wrappedValue: [], .correspondents(server))
            self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            self._tags = Shared(wrappedValue: [], .tags(server))
        }
```

Change the success branch of `.updateResult` (lines 124-126) to:

```swift
                case let .success(document):
                    state.$document.withLock { $0 = document }
                    return .send(.delegate(.documentUpdated))
```

- [ ] **Step 4: Update the form test helper**

Replace `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer+TestValue.swift` entirely:

```swift
import ApiInterface
import Foundation
import SwiftSharing

extension DocumentFormReducer.State {

    static func testValue(
        destination: DocumentFormReducer.Destination.State? = nil,
        document: Document = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            document: Shared(value: document),
            server: server
        )
    }
}
```

- [ ] **Step 5: Update the row**

In `DocumentRowReducer.swift`, change the delegate handler (lines 84-87) to drop the assignment — the store already has the new value:

```swift
            case .destination(.presented(.documentForm(.delegate(.documentUpdated)))):
                state.destination = nil
                return .none
```

and the `editButtonTapped` handler (lines 90-95) to hand over the reference:

```swift
                case .editButtonTapped:
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
                        server: state.server
                    ))
                    return .none
```

- [ ] **Step 6: Update the detail**

In `DocumentDetailReducer.swift`, change the delegate handler (lines 47-50) to:

```swift
            case .destination(.presented(.documentForm(.delegate(.documentUpdated)))):
                state.destination = nil
                return .none
```

and `editDocumentButtonTapped` (lines 56-61) to:

```swift
                case .editDocumentButtonTapped:
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
                        server: state.server
                    ))
                    return .none
```

- [ ] **Step 7: Delete the list's propagation case**

In `DocumentListReducer.swift`, delete this case entirely (lines 197-202):

```swift
            case let .path(.element(
                id: _,
                action: .documentDetail(.destination(.presented(.documentForm(.delegate(.documentUpdated(document))))))
            )):
                state.documents[id: document.id]?.document = document
                return .none
```

Nothing replaces it. The existing catch-all `case .binding, .destination, .documentImport, .documentSelection, .documents, .path:` already handles `.path` actions, and the store write now does the propagation. This deletion is the point of the whole change.

- [ ] **Step 8: Update the remaining delegate assertions**

In `DocumentRowReducerTests.swift`, `test_destination_documentForm_delegate_documentUpdated` (lines 16-31) becomes:

```swift
    @Test
    func test_destination_documentForm_delegate_documentUpdated() async throws {
        let document = Document.testValue()
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            document: document
        )) {
            DocumentRowReducer()
        }

        await store.send(.view(.editButtonTapped)) {
            $0.destination = .documentForm(.testValue())
        }
        await store.send(.destination(.presented(.documentForm(.delegate(.documentUpdated))))) {
            $0.destination = nil
        }
    }
```

In `DocumentDetailReducerTests.swift`, `test_destination_documentForm_delegate_documentUpdated` (lines 16-27) becomes:

```swift
    @Test
    func test_destination_documentForm_delegate_documentUpdated() async throws {
        let store = TestStore(initialState: DocumentDetailReducer.State.testValue(
            destination: .documentForm(.testValue())
        )) {
            DocumentDetailReducer()
        }

        await store.send(.destination(.presented(.documentForm(.delegate(.documentUpdated))))) {
            $0.destination = nil
        }
    }
```

Search the four test files for any remaining `documentUpdated(` with a payload and drop the argument.

- [ ] **Step 9: Run the tests to verify they pass**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: propagate document edits through the shared store"
```

---

### Task 5: Bulk edits refresh affected documents

`BulkEditDocumentsUseCase` returns `Void`, and the initiating list's re-fetch only refreshes what comes back in its own page. This closes the gap for documents held elsewhere.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer.swift:17-20`
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer+Effect.swift:22-25`
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer.swift:17-20`
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer+Effect.swift:20-23`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift:9-19, 162-172`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: `@Dependency(\.getDocumentsByIds.execute)` and `GetDocumentsByIdsInput` from Task 1; `cacheDocuments(_:)` and `documentCache` from Task 2.
- Produces: `DocumentListReducer.Action.documentsRefreshed([Document])`, `Effect.runRefreshDocuments(ids:server:)`, and `documentsUpdated(Set<Document.Id>)` on both bulk-edit delegates.

- [ ] **Step 1: Write the failing test**

Replace `test_destination_bulkEditTags_documentsUpdated` in `DocumentListReducerTests.swift` (lines 601-641) with a version that carries ids and asserts the extra refresh. Document `7` is in the store but *not* in what the list's own re-fetch returns — exactly the case the old behaviour missed:

```swift
    @Test
    func test_destination_bulkEditTags_documentsUpdated() async throws {
        let refetched = Document.testValue(id: 1, title: "Refetched")
        let refreshed = Document.testValue(id: 7, title: "Refreshed")
        let state = DocumentListReducer.State.testValue(
            destination: .bulkEditTags(DocumentBulkEditTagsReducer.State(
                documents: [1, 7],
                server: .testValue(),
                values: []
            )),
            documents: [],
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 7]
            )
        )
        state.cacheDocuments([.testValue(id: 7, title: "Invoice")])

        let store = TestStore(initialState: state) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [refetched]
                )
            }
            $0.getDocumentsByIds.execute = { input, _ in
                #expect(input.ids == [7])
                return [refreshed]
            }
        }

        await store.send(.destination(.presented(.bulkEditTags(.delegate(.documentsUpdated([1, 7])))))) {
            $0.destination = nil
        }
        await store.receive(\.documentsRefreshed, [refreshed]) {
            $0.$documentCache.withLock { $0 = [refreshed] }
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [refetched]
        )) {
            $0.documents = [.testValue(document: refetched)]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
            $0.$documentCache.withLock { $0 = [refreshed, refetched] }
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }
```

If the two effects deliver in the other order, swap the two `receive` blocks and the corresponding `$documentCache` expectations — both effects are merged, so either order is valid; assert whichever the store actually produces.

Also update `test_destination_bulkEditCorrespondent_documentsUpdated` (lines 539-577): change the sent action to `.documentsUpdated([1, 2])`. Its state has an empty `documentCache`, so the intersection is empty, no refresh effect runs, and the rest of the assertions stand unchanged.

- [ ] **Step 2: Run the test to verify it fails**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" \
  --test-targets DocumentsFeatureTests/DocumentListReducerTests/test_destination_bulkEditTags_documentsUpdated
```

Expected: compile failure — `documentsUpdated` takes no arguments.

- [ ] **Step 3: Add the ids to both delegates**

In `DocumentBulkEditTagsReducer.swift` (lines 17-20) and `DocumentBulkEditGenericValueReducer.swift` (lines 17-20), change both to:

```swift
        @CasePathable
        public enum Delegate {
            case documentsUpdated(Set<Document.Id>)
        }
```

In `DocumentBulkEditTagsReducer+Effect.swift`, change line 24 inside `runBulkEdit` to:

```swift
            await send(.delegate(.documentsUpdated(documents)))
```

In `DocumentBulkEditGenericValueReducer+Effect.swift`, change line 22 inside `runBulkEdit` to the same. Both functions already take `documents: Set<Document.Id>`.

- [ ] **Step 4: Add the refresh action**

In `DocumentListReducer.swift`, add to `Action` after `case documents(...)` (line 15):

```swift
        case documentsRefreshed([Document])
```

and handle it in the reducer body, after the `destination` bulk-edit case:

```swift
            case let .documentsRefreshed(documents):
                state.cacheDocuments(documents)
                return .none
```

Do not add `documentsRefreshed` to the catch-all `case .binding, .destination, …` list — it is handled by its own case above.

- [ ] **Step 5: Merge the refresh into the bulk-edit handler**

Replace the bulk-edit delegate case (lines 162-172) with:

```swift
            case let .destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated(ids))))),
                 let .destination(.presented(.bulkEditDocumentType(.delegate(.documentsUpdated(ids))))),
                 let .destination(.presented(.bulkEditStoragePath(.delegate(.documentsUpdated(ids))))),
                 let .destination(.presented(.bulkEditTags(.delegate(.documentsUpdated(ids))))):
                state.destination = nil
                return .merge(
                    .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    ),
                    .runRefreshDocuments(
                        ids: Set(state.documentCache.ids).intersection(ids),
                        server: state.server
                    )
                )
```

The `runGetDocuments` call is unchanged existing behaviour — it updates *this* tab's membership. `runRefreshDocuments` updates content everywhere. Only ids already in the store are fetched; nothing else can be displayed stale.

- [ ] **Step 6: Add the refresh effect**

In `DocumentListReducer+Effect.swift`, add to the `extension Effect` block:

```swift
    /**
     * Re-fetches the given documents and writes them into the shared store.
     *
     * Bulk edit returns no documents, so the affected content has to be re-read. Only ids
     * already present in the store are worth fetching, and the request is chunked because a
     * selection can run to thousands of ids.
     *
     * - Parameters:
     *   - ids: The affected document ids that are present in the shared store.
     *   - server: The server to fetch from.
     */
    static func runRefreshDocuments(
        ids: Set<Document.Id>,
        server: Server
    ) -> Self {
        @Dependency(\.getDocumentsByIds.execute)
        var getDocumentsByIds

        guard !ids.isEmpty else {
            return .none
        }

        let chunks = ids.sorted().chunked(into: refreshChunkSize)

        return .run { send in
            for chunk in chunks {
                let documents = try await getDocumentsByIds(.init(ids: chunk), server)
                await send(.documentsRefreshed(documents), animation: .none)
            }
        } catch: { _, _ in
            // Best-effort content sync. A failure leaves the affected rows showing their
            // previous content until the next fetch. Sending `.error` here would set
            // `state.error` and surface the empty-state view, which would be wrong.
        }
        .cancellable(id: CancelID.refreshDocuments)
    }
```

Add `case refreshDocuments` to the `private enum CancelID` at the bottom of the file, and add these two declarations at file scope below it:

```swift
private let refreshChunkSize = 100

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: refresh bulk-edited documents held outside the editing list"
```

---

### Task 6: Cross-tab test

The test that pins the whole feature down: two lists over one server, an edit through one, and an assertion that the other list's *content* changed while its *membership and order* did not.

**Files:**
- Create: `Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`
- Modify: `docs/plans/2026-08-12-cross-tab-document-sync.md`

**Interfaces:**
- Consumes: everything produced by Tasks 2, 3 and 4.
- Produces: nothing.

**Placement note.** The spec puts this test in `Modules/AppFeatureTests` driving `MainReducer`. That is not workable: `DocumentListReducer.State.documents` and `DocumentListReducer.State.testValue` are internal to `DocumentsFeature`, so `AppFeatureTests` cannot construct the lists or read their rows. Two `DocumentListReducer.State`s built with the same `Server` reproduce the two-tab situation exactly — `MainReducer` does nothing more than hold them — so the test lives in `DocumentsFeatureTests`. Step 4 updates the spec to match.

- [ ] **Step 1: Write the test**

Create `Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct CrossTabDocumentSyncTests {

    /// Both lists resolve the same shared store, so a document loaded by both is one value.
    ///
    /// Mirrors the two tabs: the inbox filtered to inbox tags, the document list to anything
    /// else, overlapping on document 7.
    @Test
    func test_editFromOneList_updatesOtherListRow_withoutChangingMembership() async throws {
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

        let inboxRows = inbox.rows(for: [
            .testValue(id: 15, title: "Warranty"),
            .testValue(id: 9, title: "Receipt"),
            .testValue(id: 7, title: "Invoice"),
        ])
        let documentListRows = documentList.rows(for: [
            .testValue(id: 7, title: "Invoice"),
            .testValue(id: 12, title: "Contract"),
        ])

        let updatedDocument = Document.testValue(id: 7, title: "Renamed")
        let store = TestStore(initialState: DocumentFormReducer.State(
            document: documentListRows[id: 7]!.$document,
            server: server
        )) {
            DocumentFormReducer()
        } withDependencies: {
            $0.updateDocument.execute = { _, _, _ in
                updatedDocument
            }
        }

        await store.send(.binding(.set(\.input.title, "Renamed"))) {
            $0.input.title = "Renamed"
        }
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isUpdating, true)) {
            $0.isUpdating = true
        }
        await store.receive(\.updateResult.success, updatedDocument) {
            $0.$document.withLock { $0 = updatedDocument }
        }
        await store.receive(\.delegate.documentUpdated)
        await store.receive(\.binding, .set(\.isUpdating, false)) {
            $0.isUpdating = false
        }

        // Content propagated to the other list.
        #expect(inboxRows[id: 7]?.document.title == "Renamed")

        // Membership and order did not move in either list.
        #expect(Array(inboxRows.ids) == [15, 9, 7])
        #expect(Array(documentListRows.ids) == [7, 12])

        // Documents not touched by the edit are unaffected.
        #expect(inboxRows[id: 15]?.document.title == "Warranty")
        #expect(inboxRows[id: 9]?.document.title == "Receipt")
    }

    /// A detail screen open in one tab tracks an edit made from the other.
    @Test
    func test_editFromOneList_updatesDetailScreenInOtherList() async throws {
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

        let inboxRows = inbox.rows(for: [.testValue(id: 7, title: "Invoice")])
        let documentListRows = documentList.rows(for: [.testValue(id: 7, title: "Invoice")])

        let inboxDetail = DocumentDetailReducer.State(
            document: inboxRows[id: 7]!.$document,
            server: server
        )

        documentListRows[id: 7]!.$document.withLock {
            $0 = .testValue(id: 7, title: "Renamed")
        }

        #expect(inboxDetail.document.title == "Renamed")
    }
}
```

- [ ] **Step 2: Run the tests to verify they pass**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" \
  --test-targets DocumentsFeatureTests/CrossTabDocumentSyncTests
```

Expected: PASS. If `test_editFromOneList_updatesOtherListRow_withoutChangingMembership` fails on the first `#expect` with `"Invoice"`, the two states resolved different `InMemoryStorage` instances — check that both were constructed with the same `Server.testValue()` and that the suite carries `.dependencies()`.

- [ ] **Step 3: Run the full test suite**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro"
mise exec -- tuist test AppFeature -d "iPhone 17 Pro"
```

Expected: PASS for both.

- [ ] **Step 4: Correct the spec's testing section**

In `docs/plans/2026-08-12-cross-tab-document-sync.md`, under `## Testing`, replace the paragraph beginning "The test that actually pins the feature down is a new cross-tab one in `Modules/AppFeatureTests`" with:

```markdown
The test that actually pins the feature down lives in
`Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`: two `DocumentListReducer.State`s
built with the same `Server` — which is all `MainReducer` does with them — loaded with an
overlapping document, then edited through a real `DocumentFormReducer`. It asserts both that the
other list's row content changed **and** that its order and membership did not. The second half is
what guards the scope decision.

It sits in `DocumentsFeatureTests` rather than `AppFeatureTests` because
`DocumentListReducer.State.documents` and its `testValue` helper are internal to `DocumentsFeature`,
so an `AppFeatureTests` suite can neither seed the lists nor read their rows.
```

Also update the `## Files` section: under "Added", replace `A cross-tab test in `Modules/AppFeatureTests`` with `Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`.

- [ ] **Step 5: Lint**

```bash
mise exec -- tuist install && mise ci:lint
```

Expected: no violations. Fix any `swiftformat`/`swiftlint` findings in the touched files.

- [ ] **Step 6: Commit**

```bash
git add Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift \
        docs/plans/2026-08-12-cross-tab-document-sync.md
git commit -m "test: cover cross-tab document sync end to end"
```

---

## Verification

After Task 6, confirm the feature by hand as well as by test:

1. `mise docker:start && mise docker:seed`
2. Run the app, open the Documents tab, and find a document that also appears in the Inbox.
3. Edit its title from the Documents tab and save.
4. Switch to the Inbox tab. The row shows the new title, and it is still in the same position in the list.
5. Push that document's detail screen in the Inbox, switch to Documents, edit the title again, and switch back. The open detail screen shows the new title.
