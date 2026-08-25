# Cross-tab document sync

## Context

`MainReducer` owns two independent `DocumentListReducer.State`s:

- `inbox`, fixed to `DocumentFilter.inbox(server:)` — documents carrying any inbox tag, no further filtering
- `documentList`, with an arbitrary user-controlled filter

Their results overlap freely: a document with an inbox tag and a correspondent of "ACME" is visible in both at once. From either tab the user can edit a document — via the row's edit sheet, via the detail screen's edit sheet, or via bulk edit on a selection — and can push a `documentDetail` screen onto that tab's own `StackState`.

Today a `Document` is *copied* into every place that displays it, and updates are hand-propagated back up through `DocumentFormReducer.Action.Delegate.documentUpdated(Document)`:

- `DocumentRowReducer` assigns `state.document` when its own form saves
- `DocumentDetailReducer` assigns `state.document` when its own form saves
- `DocumentListReducer` assigns `state.documents[id:]?.document` when a form nested under `path` saves

Each hop is written by hand, and no hop crosses the tab boundary. Editing a document from the Documents tab leaves the Inbox tab's row for that same document showing stale content — and leaves a `documentDetail` screen open in the Inbox's nav stack showing stale content too.

## Goal

An edit made anywhere updates every on-screen representation of that document: rows in both tabs, detail screens in both nav stacks, and any open edit form.

## Scope decision: content, not membership

Only document **content** propagates. **Membership and ordering of each tab's list are untouched** by an edit made elsewhere.

Concretely: removing a document's inbox tag from the Documents tab updates the Inbox row in place — it re-renders without the inbox chip — but the row stays where it is. It leaves the Inbox only on the Inbox's next fetch.

The alternatives were rejected deliberately:

- Evaluating filters client-side would require a full filter-rule engine for the Documents tab's arbitrary `FilterRule` sets — large and error-prone — and still could not discover documents that *start* matching a filter.
- Re-fetching the other tab on next appearance is always server-accurate but discards its scroll position and loaded pages.

## Design

The problem is that content is duplicated. The fix is to split the two concerns that are currently fused into one `IdentifiedArrayOf<DocumentRowReducer.State>`:

| | owns | lives in |
|---|---|---|
| **Order + membership** — which documents this tab shows, in what sequence, how far it has paged | per tab | `DocumentListReducer.State.documents`, unchanged in type and role |
| **Content** — the title/tags/correspondent of document #7 | one per server | a new shared store, keyed by id |

The store is used purely as an `id → Document` map. Nothing iterates it for display and its own ordering is meaningless insertion order. It is an `IdentifiedArrayOf<Document>` rather than a `[Document.Id: Document]` only because `Shared`'s element scoping requires `_MutableIdentifiedCollection`, which `IdentifiedArray` conforms to and `Dictionary` does not.

```
  Inbox.documents            Documents.documents
  ┌──────────┐               ┌──────────┐
  │ Row(15)  │               │ Row(7)   │
  │ Row(9)   │               │ Row(12)  │
  │ Row(7)   │               │ Row(21)  │
  └────┬─────┘               └────┬─────┘
       │   each Row holds a Shared<Document>
       └───────────┬────────────────┘
                   ▼
     documentCache  (id → Document, unordered)
     { 7, 9, 12, 15, 21 }
```

Document `7` sits at position 3 in one list and position 1 in the other. Two rows, two positions, one underlying `Document`. Writing that `Document` re-renders both rows and changes neither array — which *is* the scope decision above, enforced structurally rather than by convention.

### The shared key

Added to `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, alongside the existing per-server keys:

```swift
public extension SharedReaderKey where Self == InMemoryKey<IdentifiedArrayOf<Document>>.Default {

    static func documents(_ server: Server) -> Self {
        Self[
            .inMemory("\(server.id)-documents"),
            default: []
        ]
    }
}
```

`.inMemory`, not `.fileStorage` like the neighbouring keys. Documents are paginated and far more numerous than tags or correspondents, and there is no offline requirement — persisting them would mean rewriting a large JSON file on every list fetch for no user-visible gain. Nothing survives app restart, which matches today's behaviour, since both lists fetch on appear.

`.inMemory` resolves through `@Dependency(\.defaultInMemoryStorage)`, so tests get an isolated store for free.

### No eviction

Entries accumulate for every document loaded during a session and are never removed. This is acceptable because `DocumentsRepository` sends `truncate_content=true` on the list fetch (`DocumentsRepository.swift:223`), so `Document.content` — the only large field — arrives truncated. Entries are small.

Two supporting facts: `Document.content` is never rendered anywhere in `DocumentsFeature`, so truncation costs nothing; and the incremental memory cost over today is only the *orphans*, since row states already retain every loaded document.

### Reducer state changes

**`DocumentListReducer.State`** gains one field, initialised like its siblings:

```swift
@Shared
var documentCache: IdentifiedArrayOf<Document>

// in init:
self._documentCache = Shared(wrappedValue: [], .documents(server))
```

Everything else — `filter`, `documents`, `nextPage`, `totalNumberOfDocuments`, `isLoadingMore`, `path`, `documentSelection` — stays exactly as it is. `MainReducer` already constructs both lists with the same `server`, so both resolve to the same store.

**`DocumentRowReducer.State.document`** changes from a stored `Document` to `@Shared var document: Document`. `id` remains `document.id`, so the `IdentifiedArray` keying, the `.forEach(\.documents, action: \.documents)` scoping, and `DocumentSelectionReducer`'s `Set<Document.Id>` are all untouched.

**`DocumentDetailReducer.State.document`** and **`DocumentFormReducer.State.document`** likewise become `@Shared var document: Document`.

`DocumentRowReducer.Action.Delegate.presentDocumentDetail` carries `Shared<Document>` instead of `Document`, so the detail screen is handed the reference rather than a copy. `DocumentDetailReducer` passes `state.$document` into `DocumentFormReducer.State`.

### Reading documents into the store

Rows are built from references into the store, so a store entry must exist before its row is constructed — `Shared($documentCache[id: id])!` force-unwraps. Both `replaceDocuments` and `appendDocuments` need the same upsert-then-build sequence, so it lives in one helper on `DocumentListReducer.State` rather than being duplicated at the two call sites:

```swift
extension DocumentListReducer.State {

    func rows(for documents: [Document]) -> IdentifiedArrayOf<DocumentRowReducer.State> {
        $documentCache.withLock { cache in
            for document in documents {
                cache[id: document.id] = document
            }
        }
        return IdentifiedArray(uniqueElements: documents.map {
            DocumentRowReducer.State(
                document: Shared($documentCache[id: $0.id])!,
                server: server
            )
        })
    }
}
```

`replaceDocuments` assigns the result to `state.documents`; `appendDocuments` appends it. A side effect worth naming: because a fetch upserts into the shared store, refreshing one tab also refreshes the *content* of overlapping rows in the other tab, without that tab fetching anything.

### Writing: single-document edits

`DocumentFormReducer`'s `.updateResult(.success(document))` becomes a single write:

```swift
state.$document.withLock { $0 = document }
return .send(.delegate(.documentUpdated))
```

That one write is observed by the form, the detail screen beneath it, this tab's row, the other tab's row, and a detail screen open in the other tab's nav stack.

`Delegate.documentUpdated` loses its `Document` payload — it now means only "dismiss the sheet". The three handlers that currently re-assign a copied `Document` are deleted:

- `DocumentRowReducer` — keeps `state.destination = nil`, drops the assignment
- `DocumentDetailReducer` — keeps `state.destination = nil`, drops the assignment
- `DocumentListReducer` — the `path` → `documentDetail` → `documentForm` case is deleted outright; it existed only to propagate the copy

That deletion is the point of the change: propagation stops being per-screen plumbing that every new screen has to re-implement.

### Writing: bulk edits

`BulkEditDocumentsUseCase` returns `Void`, so nothing learns the resulting documents. The initiating list's existing self-re-fetch only refreshes store entries that come back in its own first page — a document bulk-edited from the Documents tab but sitting beyond that page would stay stale in the Inbox.

Resolved by re-fetching the affected documents by id.

**A dedicated use case, not a new `FilterRuleType`.** The raw values of `FilterRuleType` mirror Paperless's saved-view rule types and are serialised into saved views; a synthetic `id__in` case would pollute a persisted model. `GetAllDocumentIdsUseCase` already sets a precedent for a bespoke query against `/api/documents/`.

```swift
// Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift
public struct GetDocumentsByIdsInput: Codable, Equatable, Sendable {
    public let ids: [Document.Id]
}

// Modules/ApiInterface/Documents/GetDocumentsByIdsUseCase.swift
@DependencyClient
public struct GetDocumentsByIdsUseCase: Sendable {
    public var execute: @Sendable (
        _ input: GetDocumentsByIdsInput,
        _ server: Server
    ) async throws -> [Document]
}
```

The request reuses `GetDocumentsOutput` and returns `output.results`:

```swift
query: [
    "id__in": input.ids.map { "\($0.rawValue)" }.joined(separator: ","),
    "page": "1",
    "page_size": "\(input.ids.count)",
    "truncate_content": "true",
]
```

**Two bounds on request size.** Selections can be enormous — `GetAllDocumentIdsUseCase` uses `page_size=1000000`, so "select all" can mean thousands of ids, well past any workable URL length. Therefore:

1. Only `affectedIds ∩ documentCache.ids` are fetched. A document nobody has loaded cannot be displayed stale, so fetching it is pointless.
2. The remainder is chunked at 100 ids per request, one action emitted per chunk.

**Wiring.** `Delegate.documentsUpdated` gains the affected ids in all four bulk-edit reducers — `DocumentBulkEditTagsReducer` and the three `DocumentBulkEditGenericValueReducer<T>` instantiations — becoming `documentsUpdated(Set<Document.Id>)`. Each already holds `state.documents: Set<Document.Id>`, so the payload is at hand.

`DocumentListReducer` then does both jobs:

```swift
case let .destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated(ids))))),
     let .destination(.presented(.bulkEditDocumentType(.delegate(.documentsUpdated(ids))))),
     let .destination(.presented(.bulkEditStoragePath(.delegate(.documentsUpdated(ids))))),
     let .destination(.presented(.bulkEditTags(.delegate(.documentsUpdated(ids))))):
    state.destination = nil
    return .merge(
        .runGetDocuments(                                   // membership, this tab (existing behaviour)
            filterRules: state.filter.input.filterRules,
            server: state.server,
            sortDirection: state.filter.input.sort.direction,
            sortField: state.filter.input.sort.field
        ),
        .runRefreshDocuments(                               // content, everywhere
            ids: Set(state.documentCache.ids).intersection(ids),
            server: state.server
        )
    )
```

The existing self-re-fetch stays: it is what updates *this* tab's membership after a bulk edit, which is current behaviour and orthogonal to the scope decision. The overlap between the two effects is harmless — both write the server's truth.

`runRefreshDocuments` chunks, fetches, and sends `.documentsRefreshed([Document])` per chunk; the reducer upserts those into `documentCache` without touching `state.documents`. Existing rows re-render; membership does not move.

**Failures are swallowed.** This is best-effort content sync, not a user-initiated load. Routing it to `.error` would set `state.error`, which drives `DocumentListEmptyView`. On failure the affected rows keep their previous content until something re-fetches.

### Consequence: an open form tracks external edits

`DocumentFormReducer.State.isModified` compares `input` against `DocumentFormInput(document:server:)`.
With `document` shared, an edit to the same document from the other tab now moves that baseline
underneath an open form: unsaved changes that happen to match the incoming edit will read as
unmodified, and untouched fields will show as modified against the new baseline.

This is the correct reading of "the form edits *the* document" rather than a copy of it, and it
requires two screens open on one document at once, so it is accepted rather than worked around.
Noted here because it is a real behavioural change and not obvious from the diff.

### Failure mode of a dangling reference

`Shared($documentCache[id: id])!` produces an `_OptionalReference`, which retains the last value it observed. If an id were ever absent from the store while a row still referenced it, that row would render its last-known content and stop receiving updates — no crash, no blank cell. With no eviction this should not arise, but the degradation is graceful rather than fatal.

## Out of scope

- **Document creation.** Share-extension import adds documents, which is membership, not content. Neither list refreshes after an import today; that is unchanged.
- **The Inbox badge.** `inboxDocumentCount` is written only by `GetStatisticsUseCase` via `updateCache`, which runs when the selected server changes. Removing an inbox tag leaves it stale — equally so today when editing from the Inbox itself. Tracked in `docs/ideas.md`.
- **Document deletion.** Does not exist in the app yet.

## Testing

Per-reducer `TestStore` coverage for the changed reducers, asserting on shared-store mutations:

- `DocumentFormReducerTests` — a successful save writes through `$document`
- `DocumentRowReducerTests`, `DocumentDetailReducerTests` — the payload-less `documentUpdated` dismisses, and the displayed document reflects the store
- `DocumentListReducerTests` — `replaceDocuments`/`appendDocuments` upsert into the store and build rows from it; the bulk-edit delegate merges both effects

The test that actually pins the feature down lives in
`Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`: two `DocumentListReducer.State`s
built with the same `Server` — which is all `MainReducer` does with them — loaded with an
overlapping document, then edited through a real `DocumentFormReducer`. It asserts both that the
other list's row content changed **and** that its order and membership did not. The second half is
what guards the scope decision.

It sits in `DocumentsFeatureTests` rather than `AppFeatureTests` because
`DocumentListReducer.State.documents` and its `testValue` helper are internal to `DocumentsFeature`,
so an `AppFeatureTests` suite can neither seed the lists nor read their rows.

Snapshot tests under `Snapshots/DocumentsFeatureTests` are unaffected — rendering is unchanged.

## Files

Changed:

- `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift` — the `documents(_:)` key
- `Modules/ApiImplementation/Documents/DocumentsRepository.swift` — `getDocumentsByIds` + its `Request`
- `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` — `documentCache`, the `rows(for:)` helper, the bulk-edit delegate cases, deletion of the `path` propagation case
- `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift` — `runRefreshDocuments`
- `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift` — shared `document`, delegate payload
- `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift` — shared `document`
- `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift` — shared `document`, write-through save, delegate payload dropped
- `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer.swift` and `GenericValue/DocumentBulkEditGenericValueReducer.swift` — delegate payload
- The corresponding `+TestValue.swift` helpers and the four test files above

Added:

- `Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift`
- `Modules/ApiInterface/Documents/GetDocumentsByIdsUseCase.swift`
- `Modules/ApiImplementation/Documents/GetDocumentsByIdsUseCase.swift`
- `Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`
