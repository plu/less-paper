# Preview and share from the document row

## Context

Long-pressing a document row opens a context menu with two items — Edit document, Delete document
(`DocumentRowView.swift:42`). The two read-only actions a user is most likely to want, previewing
the PDF and sharing it, exist only on the detail screen's ellipsis menu
(`DocumentDetailView.swift:33`), three taps away: open the document, wait for the download, open the
menu.

The detail screen can offer them because it has already downloaded the file. `runDownloadDocument`
(`DocumentDetailReducer+Effect.swift:7`) fetches the document, writes it to
`temporaryDirectory/<fileName>` and keeps both the data and the URL in state; the menu is then
gated on `store.downloadResult?.value?.url`. A list row has none of that — it shows a thumbnail and
metadata only, so both new actions have to fetch the file themselves before they can present
anything.

The menus also name their items with the noun attached: "Edit document", "Delete document",
"Preview document", "Share document". A four-item menu of those reads as boilerplate, and the noun
is redundant when the menu is anchored to the document it acts on.

## Design

### The row context menu

Four items, in this order:

| Item | Symbol | Behaviour |
|---|---|---|
| Preview | `eye` | Downloads if needed, then opens QuickLook |
| Share | `square.and.arrow.up` | Downloads if needed, then opens the system share sheet |
| Edit | `square.and.pencil` | Unchanged — presents `DocumentFormView` |
| Delete | `trash` | Unchanged — destructive role, confirmation popup |

Read-only actions first, destructive last. Preview and Share sit above Edit because they are the
cheap, non-committal ones.

### Fetching from a row

Tapping Preview or Share sets the row downloading. The row dims to 0.5 — the opacity the row
already uses for `isUpdating` — with a `ProgressView` centred over it. The context menu is gone by
then, so without this the tap would look like it did nothing on a slow server.

The dim condition becomes `isUpdating || isDownloading`. The spinner overlay is applied *after*
`.opacity(…)` so the spinner is not dimmed along with the row beneath it. Centred over the row
rather than pinned to the thumbnail: `AdaptiveStack` moves the thumbnail from leading to top at
accessibility sizes, and the centre is the one position that reads correctly in both layouts.

On success the row presents QuickLook or the share sheet, whichever was asked for. On failure it
stops dimming and an `.error` toast carries the message, matching how `DocumentFormReducer` and
`DocumentFilterReducer` already report failures. There is no inline retry: the menu item is the
retry.

**The URL is kept.** A successful download stores its URL in row state, so Preview followed by
Share on the same document downloads once. The row's state does not outlive the list's copy of the
document, so a reload drops the URL and the next action re-fetches — which is also what keeps the
cached file from going stale.

**The effect is cancellable per document.** `DocumentDetailReducer` cancels on a bare
`CancelID.downloadDocument`, which is fine for a screen that only ever has one download in flight.
Rows are not: a shared id would mean starting a download on one row silently kills another's. The
row's cancel id is keyed by `document.id`. Tapping a second time on a row that is already
downloading therefore restarts that row's download and nothing else.

### The shared download

`runDownloadDocument` currently owns the whole sequence: call the use case, write the bytes to a
temporary file named after the document, hand back data and URL. The row needs all of that except
the data — holding PDF `Data` per row is exactly what a list should not do.

The download-and-write becomes one internal helper in `DocumentsFeature`, returning the data and
the URL. `DocumentDetailReducer` keeps wrapping the result in `DownloadResult` because
`PDFKitView` needs the bytes; the row keeps only the URL and lets the data go.

### Row reducer

- **View actions:** `previewButtonTapped`, `shareButtonTapped`.
- **Internal actions:** `downloadSucceeded(url:intent:)`, `downloadFailed(String)`. The intent —
  `preview` or `share` — travels in the action rather than living in state, so there is no stale
  pending-intent to invalidate when a download is replaced or fails.
- **State:** `downloadedURL: URL?`, `isDownloading: Bool`, `quickLookPreview: URL?`,
  `shareItem: ShareItem?`.

Both taps run the same branch: if `downloadedURL` is set, present immediately; otherwise set
`isDownloading` and run the effect carrying the intent.

### Presenting

`.quickLookPreview($store.quickLookPreview)` on the row, exactly as `DocumentDetailView.swift:25`
does it, and `.sheet(item: $store.shareItem)` for sharing. Presenting from a row is already
established here — the row presents `DocumentFormView` the same way.

The detail screen keeps `ShareLink`: it has the URL at the moment the menu is built, and `ShareLink`
is the better API wherever that holds. A context menu item cannot use it, because the item is
dismissed before the URL exists. So `Components` gains a small `ShareSheet`, a
`UIViewControllerRepresentable` around `UIActivityViewController`, driven by:

```swift
struct ShareItem: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
}
```

Identified by the URL rather than a generated `UUID`, so the value stays deterministic under
`TestStore` assertions.

### The detail menu

Labels shorten; structure is untouched — ellipsis menu holding Preview and Share, Edit as its own
toolbar button.

One fix while there: the ellipsis `Menu` is currently always tappable, and its contents are gated on
`if let url = store.downloadResult?.value?.url`, so during the download it opens an empty menu. It
gets disabled until the URL exists.

### Strings

Reuse the existing `edit` ("Edit" / "Bearbeiten"), which is in the catalog with no callers. Add:

| Key | en | de |
|---|---|---|
| `delete` | Delete | Löschen |
| `preview` | Preview | Vorschau |
| `share` | Share | Teilen |

`editDocument` and `deleteDocument` stay — they title the form sheet (`DocumentFormView.swift:15`)
and the delete confirmation (`DocumentDeleteConfirmationPresenter.swift:38`), where the noun still
earns its place. `previewDocument` and `shareDocument` lose their only callers and come out of the
catalog.

The long-form strings in other features (`editTag`, `deleteCorrespondent`, …) are accessibility
labels on icon buttons, not visible menu text, and are left alone.

## Testing

Written test-first.

- `DocumentRowReducerTests`
  - Preview on a row with no cached URL: downloading set, download runs, `quickLookPreview` set,
    downloading cleared, `downloadedURL` retained.
  - Share on a row with no cached URL: same, ending in `shareItem`.
  - Preview then Share: the second tap presents without running the download again. Asserted by
    leaving the download dependency unimplemented for the second leg.
  - Failure: downloading cleared, no presentation, one `.error` toast with the message — asserted
    through a `toastPresenter.present` override, as `DocumentFormReducerTests` does.
- `DocumentRowViewTests` — `testSnapshot_isDownloading`, alongside the existing
  `testSnapshot_isUpdating`, pinning the dim plus the spinner over the thumbnail.
- `DocumentDetailViewTests` — the existing snapshots come back with the shortened labels; a case
  covering the disabled ellipsis menu while the download is in flight.

## Out of scope

- **A real download cache.** Nothing is shared between the row and the detail screen, so opening a
  document after previewing it from the list downloads a second time. Fixing that means a cache with
  an eviction and invalidation story, which is its own piece of work.
- **Preview or share for a selection.** The bulk-edit selection bar is a separate surface with its
  own semantics (what does sharing twelve documents even produce?).
- **Progress percentage.** `DownloadDocumentUseCase` returns `Data` in one shot with no progress
  reporting; an indeterminate spinner is all the current API can honestly show.
