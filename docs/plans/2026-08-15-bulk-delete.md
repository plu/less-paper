# Bulk delete from a selection

## Context

`DeleteDocumentsUseCase` (#130) already takes `[Document.Id]` and goes through `bulk_edit`,
deliberately so that deleting a selection would need no API work. Until now nothing called it with
more than one id — the row context menu was the only entry point.

The bottom toolbar already hosts four bulk edit actions (correspondent, document type, storage
path, tags), each disabled while the selection is empty.

## Design

### Placement

The four edit icons stay as they are. Delete sits behind a trailing overflow `Menu`
(`ellipsis.circle`, labelled `moreActions` — the same pattern the top trailing toolbar already
uses), holding a single destructive "Delete documents".

Deliberate: a destructive, irreversible action should not be one mistap away from four reversible
ones in a row of equally-weighted icons. The cost is discoverability, which the confirmation popup
would not have bought back.

### Confirmation

Reuses `ConfirmationPopupView` through `DocumentDeleteConfirmationPresenter`, which gains a second
entry point alongside the existing single-document one:

```swift
var present: @Sendable (_ documentTitle: String) async -> Bool
var presentMany: @Sendable (_ documentCount: Int) async -> Bool
```

Two entry points rather than one generic message, mirroring how
`DocumentBulkEditConfirmationPresenter` has both `present` and `presentTags`.

The message names the **count**, not the documents: a selection can run to thousands after "select
all matching", so listing them is not an option. `deleteDocumentsConfirmation` is plural-aware, so
a selection of one reads "Do you really want to delete 1 document?" rather than "1 documents".

### Flow

```
view(.deleteSelectedButtonTapped)
  └─ guard selection is not empty          — nothing to confirm, no popup
  └─ runConfirmDeleteSelected(documentCount:)
       └─ presentMany → false: nothing happens
       └─ presentMany → true:  deleteSelectedConfirmed
            └─ documentSelection.isActive = false
            └─ runDeleteDocuments(ids:server:)     — unchanged from #130
                 ├─ isUpdating(ids:isUpdating: true)
                 ├─ documentsDeleted(ids)          — unchanged from #130
                 └─ delegate(.documentsDeleted(ids))
```

Everything below `runDeleteDocuments` is reused as-is. `documentsDeleted` already prunes rows, all
three selection sets, the navigation stack and the total for a *set* of ids, so it needed no
changes at all.

### Where selection mode is exited

`isActive = false` is set in `deleteSelectedConfirmed`, **not** in `documentsDeleted`.

`documentsDeleted` is the shared prune action that `MainReducer` forwards to the other tab. Closing
selection mode there would yank the other tab out of a selection the user is still building. Doing
it on confirm keeps it local to the list that initiated the delete, and has the nicer side effect of
collapsing the toolbar the moment the user commits, while the rows dim.

### Failure

`deleteDocumentsFailed` already toasts and clears `isUpdating`, so the rows un-dim and stay.
Selection mode stays closed rather than springing back open — re-entering it would be more
surprising than leaving the user on the list with a toast.

## Testing

- `DocumentListReducerTests` — confirmed (popup receives the right count, selection mode closes on
  commit, the right ids reach the use case, rows and selection are pruned), cancelled (nothing
  happens, `deleteDocuments` left unimplemented so reaching it fails the test), and empty selection
  (the popup is never presented).
- Verified by hand in the simulator against the seeded container with a temporary UI test that
  opened the menu and **cancelled**, so no fixture data was touched. It asserted the exact singular
  string, which is what pins the plural handling.

## Out of scope

- No undo. Paperless moves deleted documents to a server-side trash; surfacing it is parked in
  `docs/ideas.md`.
- No cap on selection size. `bulk_edit` takes the whole set in one request, which is what the web UI
  does.
