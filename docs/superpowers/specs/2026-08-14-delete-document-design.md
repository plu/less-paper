# Delete document

## Context

`DocumentRowView` shows a context menu with a single item, "Edit document", which presents
`DocumentFormReducer` in a sheet. Deleting a document is not possible from anywhere in the app —
`docs/superpowers/specs/2026-08-12-cross-tab-document-sync-design.md` names it explicitly as out of scope.

The API layer is already most of the way there. `BulkEditDocumentsInput.Method` has a `.delete`
case, encoded as `{"documents": [...], "method": "delete"}`, and
`DocumentsRepository.bulkEditDocuments` sends it to `/api/documents/bulk_edit/`. Six integration
tests in `DocumentsRepositoryTests` already use it — as cleanup, to remove the documents they
create — so the request is exercised against the real Paperless container on every integration
run. What is missing is a use case, and everything above it.

Every other deletable entity in the app follows one shape, established by `DocumentTypeRow`:

- the row owns a confirmation, presented from a `deleteButtonTapped` view action
- confirming sends a `Delegate` action up to the list
- the list runs the effect, dims the row via `isUpdating` while it is in flight, and removes it on
  success

## Goal

"Delete document" in the row context menu, guarded by a confirmation dialog, removing the document
from the server and from every place in the app that references it.

## Scope

Row context menu only. Not the detail screen's toolbar, not a swipe action — document rows have no
swipe actions today and adding a delete-only one would be the first.

The plural naming throughout the API layer (`DeleteDocumentsUseCase`, taking `[Document.Id]`) is
deliberate even though the only caller passes one id. `bulk_edit` is inherently a batch endpoint,
and a "select n documents and delete them" action is a plausible follow-up to the existing bulk
edit UI. Making the use case singular now would mean rewriting it then.

## Design

### API layer

The use case sits alongside its siblings and needs no repository change.

```swift
// Modules/ApiInterface/Documents/DeleteDocumentsUseCase.swift
@DependencyClient
public struct DeleteDocumentsUseCase: Sendable {

    public var execute: @Sendable (
        _ ids: [Document.Id],
        _ server: Server
    ) async throws -> Void
}
```

with the usual `TestDependencyKey` conformance (`previewValue`/`testValue` are bare `Self()`) and a
`deleteDocuments` entry in `DependencyValues`.

The implementation mirrors `DeleteDocumentTypeUseCase` — delegate to the repository, then reconcile
the shared cache:

```swift
// Modules/ApiImplementation/Documents/DeleteDocumentsUseCase.swift
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
```

**Cache removal belongs here, not in the reducer.** `DeleteDocumentTypeUseCase` sets that
precedent, and the alternative is worse: `documentsDeleted` is handled by *both* lists (see
"Cross-tab propagation" below), so putting the mutation there runs it twice for every delete.

`bulk_edit` returns `200` with a body the app ignores, exactly as the existing bulk edit path does.
A document id that no longer exists server-side yields an error, which surfaces as a toast.

### Row

`DocumentRowReducer.Destination` is **unchanged** — it keeps its single `documentForm` case. The
confirmation is not navigation state:

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

`State` gains `var isUpdating = false`, and the view action starts an effect:

```swift
case .deleteButtonTapped:
    return .runConfirmDelete(documentTitle: state.document.title)
```

### The confirmation popup

The app's own `ConfirmationPopupView` (`Modules/Components/Popup/`) is used, not the system
`confirmationDialog`. It is presented through the `popupPresenter` dependency, which shows it via
SwiftMessages at window level and suspends the caller until the user answers — the shape
`DocumentBulkEditConfirmationPresenter` already established.

A new `Modules/DocumentsFeature/DocumentRow/DocumentDeleteConfirmationPresenter.swift` mirrors that
presenter exactly:

```swift
@DependencyClient
struct DocumentDeleteConfirmationPresenter: Sendable {

    /// Presents the delete confirmation popup and suspends until the user confirms or cancels
    var present: @Sendable (_ documentTitle: String) async -> Bool = { _ in false }
}
```

```swift
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
```

`isDestructive: true` gives the confirm button the `.critical` style; the buttons keep the shared
`Confirm`/`Cancel` titles, as the bulk-edit confirmations do.

The effect lives in a new `DocumentRowReducer+Effect.swift` and only reports the answer upwards:

```swift
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
```

**Why not `ConfirmationDialogState`.** The five sibling rows use it, but they trigger from swipe
actions, where iOS renders an action sheet with a visible Cancel. Triggered from a *context menu*,
the same dialog is presented as an anchored popover — and popovers drop the cancel-role button in
favour of tap-outside dismissal. A destructive action with no visible way out is worth avoiding, and
the in-app popup also matches the bulk-edit confirmations the user already sees for other
document operations.

`DocumentRowView` adds the menu item and the dimming:

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

```swift
.opacity(store.isUpdating ? 0.5 : 1.0)
```

### Strings

`deleteConfirmation` already exists and is reused verbatim —
`Do you really want to delete "%@"?` / `Möchtest du wirklich "%@" löschen?` — interpolated with the
document title, matching how the other five rows interpolate their entity's name.

One new key in `Shared/Framework/Resources/Localizable.xcstrings`, `extractionState: manual` like
its neighbours:

| key | en | de |
|---|---|---|
| `deleteDocument` | Delete document | Dokument löschen |

### List

`DocumentListReducer.Action` gains four cases:

```swift
case delegate(Delegate)
case deleteDocumentsFailed(ids: Set<Document.Id>, error: Error)
case documentsDeleted(Set<Document.Id>)
case isUpdating(ids: Set<Document.Id>, isUpdating: Bool)

public enum Delegate: Equatable {
    case documentsDeleted(Set<Document.Id>)
}
```

`DocumentListReducer` has no `Delegate` today; this adds the first one, which `MainReducer` then
has to handle.

The row's delegate starts the effect:

```swift
case let .documents(.element(id: id, action: .delegate(delegateAction))):
    switch delegateAction {
    case .deleteDocument:
        return .runDeleteDocuments(ids: [id], server: state.server)
    case let .presentDocumentDetail(document):
        ...
    }
```

```swift
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

`isUpdating` sets the flag on each addressed row that this list happens to hold:

```swift
case let .isUpdating(ids: ids, isUpdating: isUpdating):
    for id in ids {
        state.documents[id: id]?.isUpdating = isUpdating
    }
    return .none
```

### Failure does not set `state.error`

The failure path does **not** route through the existing `.error` action. It clears the flag and
toasts directly:

```swift
case let .deleteDocumentsFailed(ids: ids, error: error):
    for id in ids {
        state.documents[id: id]?.isUpdating = false
    }
    return .toast(error)
```

Carrying the `Error` in the action rather than sending `.error(error)` first is the whole point of
this case existing — `.error` assigns `state.error`, which is precisely what must not happen here.
`DocumentListReducer.Action` is already non-`Equatable` because of its `error(Error)` case, so the
payload costs nothing.

This deliberately differs from `DocumentTypeListReducer`, whose `.error` case is toast-only.
`DocumentListReducer.error` *also* assigns `state.error`, and `DocumentListEmptyView` renders that
string as a full-screen `ContentUnavailableView` with a reload button whenever the list is empty. A
failed delete has not broken the list, so poisoning `state.error` would mean deleting the last
visible row and, on failure, being shown an error screen for a list that is merely empty. Routing
the failure through its own action keeps `state.error` meaning "the fetch failed".

The same reasoning is already recorded for `runRefreshDocuments` in the cross-tab sync spec.

### Cleaning up local state

```swift
case let .documentsDeleted(ids):
    let countBefore = state.documents.count
    state.documents.removeAll { ids.contains($0.id) }
    state.documentSelection.allLoadedDocuments.subtract(ids)
    state.documentSelection.allMatchingDocuments.subtract(ids)
    state.documentSelection.selectedDocuments.subtract(ids)
    state.path.removeAll { element in
        guard case let .documentDetail(detail) = element else {
            return false
        }
        return ids.contains(detail.document.id)
    }
    state.totalNumberOfDocuments = max(
        0,
        state.totalNumberOfDocuments - (countBefore - state.documents.count)
    )
    return .none
```

Five pieces of state, each for a reason:

- **`documents`** — the row itself.
- **`documentSelection`'s three sets** — `selectedDocuments` and `allLoadedDocuments` are obvious;
  `allMatchingDocuments` is the one easy to miss. It is populated by
  `runGetAllDocumentIds` and only refreshed when empty, so leaving a deleted id in it means the
  next "select all matching" re-selects a document that no longer exists, and the following bulk
  edit fails on it.
- **`path`** — a `documentDetail` screen showing a deleted document would keep rendering its
  last-known content (the `_OptionalReference` behaviour described in the sync spec) and its
  download would fail. Cleared with `state.path[id:] = nil` rather than `removeAll(where:)` —
  the latter rebuilds `StackState` through `replaceSubrange`, which hands the surviving screens
  fresh `StackElementID`s and makes SwiftUI treat them as new pushes.
- **`totalNumberOfDocuments`** — drives "n of m loaded" in `DocumentListStatusBarView`. Decremented
  by the number of rows *this list* actually removed, not by `ids.count`, because the other tab may
  not hold the document at all. `max(0, …)` guards against a double-delivery ever driving it
  negative.

Note the ordering against the API layer: the use case removes the cache entry before
`documentsDeleted` arrives, so for one action's worth of time a row references a missing entry. It
renders its last value and does not crash, and is then removed.

### Cross-tab propagation

`MainReducer` owns `documentList` and `inbox` as two independent `DocumentListReducer.State`s over
the same server, so a document can be on screen in both at once. The cross-tab sync design settled
that an edit propagates *content* but never *membership*. Deletion is the deliberate exception:
the document is gone from the server, so a row for it is not stale content, it is a row for
nothing.

```swift
case let .documentList(.delegate(.documentsDeleted(ids))):
    return .send(.inbox(.documentsDeleted(ids)))
case let .inbox(.delegate(.documentsDeleted(ids))):
    return .send(.documentList(.documentsDeleted(ids)))
```

**Why two actions rather than one.** `documentsDeleted` prunes local state and returns `.none`; it
does *not* emit the delegate. The delegate is emitted by the effect, once, in the list that ran the
delete. If `documentsDeleted` re-emitted it, `MainReducer` would forward it back to the originating
list, which would emit again — an infinite loop. Splitting "prune yourself" from "tell the others"
makes the forwarding terminate structurally rather than by a guard on whether anything changed.

## Out of scope

- **The inbox badge.** Deleting a document that carries an inbox tag leaves `inboxDocumentCount`
  stale, exactly as editing one does today. Already parked in `docs/ideas.md`.
- **Undo / trash restore.** Paperless moves deleted documents to a server-side trash; surfacing and
  restoring from it is a separate feature.
- **Bulk delete from a selection.** The plural API shape leaves the door open, but no UI is added.
- **Deleting from the detail screen.** Row context menu only, per the scope decision.

## Testing

- **`Modules/ApiImplementationTests/Documents/DeleteDocumentsUseCaseTests.swift`** — modelled on
  `DeleteDocumentTypeUseCaseTests`: seed `@Shared(.documents(.testValue()))`, stub
  `documentsRepository.bulkEditDocuments`, assert both the input (`documents: ids`, `method:
  .delete`) and that the ids left the cache.
- **`DocumentRowReducerTests`** — `deleteButtonTapped` presents the popup with the document *title*
  and emits `.delegate(.deleteDocument)` when the presenter returns `true`; emits nothing when it
  returns `false`. The presenter is stubbed through `$0.documentDeleteConfirmation.present`, exactly
  as the bulk-edit reducers stub theirs.
- **`DocumentListReducerTests`** — the row delegate starts the effect with the right id;
  `documentsDeleted` prunes rows, all three selection sets, a matching `path` element and the
  total, while leaving a non-matching `path` element alone; a failing delete clears `isUpdating`,
  toasts, and leaves `state.error` nil.
- **`CrossTabDocumentSyncTests`** — a new case alongside the existing ones. Two lists over one
  server sharing a document; delete it from one and assert it leaves *both*. The existing cases
  assert membership does not move on edit, so this documents the exception next to the rule.
- **`MainReducerTests`** — forwarding in both directions, and that it terminates (the forwarded
  `documentsDeleted` produces no further actions).
- **Snapshot tests** — `DocumentRowViewTests` renders the row, not its context menu, so existing
  snapshots are unaffected. A new snapshot covering `isUpdating: true` is worth having since the
  dimming is otherwise untested.
- **No UI test.** `DocumentsAppTests` runs against the seeded docker container; a delete would
  destroy fixture data other tests assert on.

## Files

Added:

- `Modules/ApiInterface/Documents/DeleteDocumentsUseCase.swift`
- `Modules/ApiImplementation/Documents/DeleteDocumentsUseCase.swift`
- `Modules/ApiImplementationTests/Documents/DeleteDocumentsUseCaseTests.swift`
- `Modules/DocumentsFeature/DocumentRow/DocumentDeleteConfirmationPresenter.swift`
- `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+Effect.swift`

Changed:

- `Shared/Framework/Resources/Localizable.xcstrings` — `deleteDocument`
- `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift` — `deleteButtonTapped`,
  `Delegate.deleteDocument`, `isUpdating`
- `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift` — menu item, opacity
- `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` — the four new actions, the
  `Delegate`, the row-delegate switch
- `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift` — `runDeleteDocuments`
- `Modules/AppFeature/MainReducer.swift` — the two forwarding cases
- `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`
- `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowViewTests.swift`
- `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`
- `Modules/DocumentsFeatureTests/CrossTabDocumentSyncTests.swift`
- `Modules/AppFeatureTests/MainReducerTests.swift`
