# Merge selected documents

## Context

Bulk edit today can set a correspondent, a document type, a storage path, tags and a title across a
selection, and delete it. All six are *field* edits: they change metadata on documents that already
exist, and none of them cares what order the selection is in.

Merge is the first bulk action that produces a **new** document, and the first where the order of
the selection is part of the input rather than an implementation detail.

### What the server actually offers

Probed against the `paperless-ngx:3.0.5` instance this repo runs in `docker/`, reading both the
OpenAPI schema and the source inside the container.

```
POST /api/documents/merge/          → {"result": "OK"}
POST /api/documents/bulk_edit/      {"method": "merge", …} → {"result": "OK"}
```

The request body:

| Field | Default | Meaning |
| --- | --- | --- |
| `documents` | required | **Ordered.** Page order of the result follows this array. |
| `metadata_document_id` | `null` | Copies that document's metadata onto the result; title becomes `"<title> (merged)"`. |
| `delete_originals` | `false` | Deletes the sources *after* the merged document is consumed. |
| `archive_fallback` | `false` | For a non-PDF source with an archive version, merge the archive instead. |
| `source_mode` | `latest_version` | `latest_version` or `explicit_selection`. |

Four things follow from the probe, and they shape the whole design:

1. **Merge is asynchronous.** `bulk_edit.merge` writes a temporary PDF and hands it to `consume_file`
   (`src/documents/bulk_edit.py:505`). The merged document does not exist when the call returns; it
   appears only once consumption finishes. `delete_originals` is wired as a `link=[delete.si(…)]`
   callback on that task, so the originals also survive until then.
2. **Order is explicit and preserved.** The implementation iterates `doc_ids` rather than the
   queryset specifically to keep the caller's order.
3. **Failures are silent.** Each source is opened with `pikepdf` inside a `try`; on failure the
   document is logged and excluded, and the merge proceeds without it. If *every* source fails the
   endpoint still returns `"OK"` having merged nothing.
4. **The server rejects bad selections.** `DocumentListSerializer._validate_document_id_list`
   (`src/documents/serialisers.py:1603`) rejects ids that don't exist or are listed twice.

### The app cannot use `/api/documents/merge/`

`ApiVersion.minimumSupported` is `9` (`Modules/ApiInterface/Shared/ApiVersion.swift:7`). Merge only
moved onto its own endpoint in API v10 — on a v9 server `/api/documents/merge/` is not there.

The v10 server still accepts `method: "merge"` on `bulk_edit`. `MOVED_DOCUMENT_ACTION_ENDPOINTS`
(`src/documents/serialisers.py:1764`) keeps the legacy methods in the `method` choices, and the view
(`src/documents/views.py:2949`) only logs a deprecation warning before dispatching normally:

> Deprecated bulk_edit method '%s' requested on API version %s. Use '%s' instead.

So `bulk_edit` is one code path that works on both versions. The app already routes `delete` — also
a legacy method — through it (`Modules/ApiImplementation/Documents/DocumentsRepository.swift:123`),
so this stays consistent rather than introducing a second style. Dropping v9 later turns this into a
localised change behind the existing use case.

`_validate_parameters_merge` (`src/documents/serialisers.py:2040`) accepts `delete_originals` and
`archive_fallback` on the `bulk_edit` path, so nothing is lost by taking it.

### The selection is a `Set`

`DocumentSelectionReducer.State.selectedDocuments` is a `Set<Document.Id>`
(`Modules/DocumentsFeature/DocumentList/DocumentSelection/DocumentSelectionReducer.swift:32`). Every
existing bulk action is order-independent, so nothing has needed order until now.

Worse, `selectAllMatchingButtonTapped` fills the selection from `allMatchingDocuments`, which is a
bare id list fetched by `getAllDocumentIds`. Those ids may never have been loaded, so the app holds
no title for them and cannot display or order them without a fetch.

## Design

### API layer

Extend the existing method enum rather than adding an endpoint:

```swift
public enum Method: Equatable, Sendable {
    case delete
    case merge(Merge)
    case modifyTags(ModifyTags)
    // …
}

struct Merge: Encodable, Equatable, Sendable {
    public let archiveFallback: Bool
    public let deleteOriginals: Bool
}
```

`key` is `"merge"`; the payload encodes into `parameters` like every other parameterised method.
`JSONEncoder.apiEncoder` uses `.convertToSnakeCase`
(`Modules/ApiInterface/Extensions/JSONEncoder+Extensions.swift:8`), so `deleteOriginals` becomes
`delete_originals` without `CodingKeys`.

`documents` is already `[Document.Id]` — an ordered array — which is exactly what page order needs.
The reducer must pass the user's order, not `Array(someSet)`.

Two parameters are fixed rather than exposed:

- `archiveFallback` is always `true`. It can only help: a non-PDF with an archive version merges
  instead of being dropped.
- `metadataDocumentId` and `sourceMode` are not sent at all. The merged document is consumed fresh
  with no metadata, and `source_mode` stays at the server default.

`BulkEditDocumentsUseCase` is reused unchanged. It returns `Void` and refreshes statistics; it does
not touch the document cache, which is correct here because nothing has actually changed yet.

### Ordering comes from the server

`GetDocumentsByIdsInput` sends no `ordering` today, so `id__in` returns the server's default order
(`Modules/ApiImplementation/Documents/DocumentsRepository.swift:272`). Add optional sort field and
direction to it and pass `ordering` through, exactly as `GetDocumentsInput` already does at
`:264`.

Sorting client-side was rejected: with "select all matching" the sheet shows documents the app never
loaded, and sorting those by title in Swift uses a different collation than the server used for the
list behind the sheet. Letting the server sort reproduces the on-screen order exactly.

### Feature layer

A new `Modules/DocumentsFeature/DocumentBulkEdit/Merge/`, following the shape `Tags/` already
establishes: `DocumentBulkEditMergeReducer`, `+Effect`, `+TestValue`, `DocumentBulkEditMergeView`.

State:

```swift
var deleteOriginals = false
var documents: [Document] = []
var isLoading = false
var isSaving = false
let selectedDocuments: Set<Document.Id>
let server: Server
let sort: DocumentFilterInput.SortFilter
```

`sort` is the list's own `state.filter.input.sort` passed straight through — the same
`DocumentFilterInput.SortFilter` that already carries `field` and `direction`
(`Modules/DocumentsFeature/DocumentFilter/DocumentFilterInput.swift:35`). The effect unpacks it into
`GetDocumentsByIdsInput`, which takes the bare `SortField` and `SortDirection` because it lives in
`ApiInterface` and cannot see the feature type.

Flow:

- `onAppear` → `runGetDocumentsByIds` with the list's sort → `documentsLoaded` populates `documents`
  in display order.
- The view is a `List` over `documents` with `.onMove`, held in
  `.environment(\.editMode, .constant(.active))` so rows are draggable without an Edit button, plus
  a "Delete originals" `Toggle` bound to `deleteOriginals`.
- `mergeButtonTapped` → `runConfirmMerge` → a new `presentMerge` case on
  `DocumentBulkEditConfirmationPresenter`, rendering `ConfirmationPopupView`. Never
  `.confirmationDialog` — see `AGENTS.md`.
- `mergeConfirmed` → `runBulkEdit` with `documents.map(\.id)` in their current order →
  `delegate(.documentsMerged)`.

The view carries the `@ViewAction(for:)` annotation — it is not generic, unlike
`DocumentBulkEditGenericValueView` — so it sends with `send`, never `store.send`, in `.task` as well
as in button actions.

### Entry point

The bottom toolbar's overflow menu. The comment there records that a sixth icon spans 411pt on a
402pt iPhone 17 Pro and clips at both ends, so merge cannot be a seventh icon.

Merge sits **above** the divider, with Edit title — it creates a document, it does not destroy one,
so it does not belong in the destructive group even when "delete originals" is on. Symbol is
`arrow.trianglehead.merge`, available on the iOS 18 deployment target.

The menu item is disabled below two selected documents. One document would merge into a copy of
itself, which is never what anyone means.

### After a successful merge

Dismiss the sheet, exit selection mode, leave the list untouched.

The merged document appears on the next pull-to-refresh or `onAppear`, exactly as an imported
document does today. No delayed refresh, no polling, no optimistic removal of the originals: the
server deletes them only after consumption succeeds, so removing them locally would make them
silently reappear on the next fetch if consumption failed.

This is the gap already recorded in `docs/ideas.md` under "Refresh lists after an import". Merge
makes it slightly more visible but does not change its shape, and closing it is out of scope here.

## Accepted limitations

**Partial merges are undetectable.** If a selected document is not a PDF and has no archive version,
the server skips it and the merged document is missing its pages — with a `"OK"` response either
way. The app cannot pre-empt this: `Document` carries no `mime_type`, only `originalFileName` and
`archivedFileName`. A filename-extension heuristic would be wrong in both directions — blocking
merges that would have worked via the archive, and permitting ones that will still fail — so it is
deliberately not built. `archiveFallback: true` narrows the window as far as the client can.

**The selection is uncapped.** "Select all matching" could feed hundreds of documents into one PDF.
The reorderable list makes a large selection self-evidently unwieldy, and any specific limit would
be a guess, so none is imposed.

## Testing

- `Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift` — `.merge` encodes to
  `method: "merge"` with `parameters.delete_originals` and `parameters.archive_fallback`, and
  `documents` preserves array order.
- `DocumentBulkEditMergeReducerTests` — load, reorder, toggle, confirm, cancel, error. The confirmed
  path asserts the ids reach `bulkEditDocuments` in the reordered order, which is the one thing that
  silently produces a wrong PDF if broken.
- `DocumentBulkEditMergeViewTests` — snapshots in light and dark, following the convention the other
  bulk edit views use. Loading, loaded, and saving states.
- `DocumentListReducerTests` — the overflow entry presents the destination, and the delegate exits
  selection mode.
