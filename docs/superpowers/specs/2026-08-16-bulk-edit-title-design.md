# Bulk edit title

## Context

The four bulk edit actions in the bottom toolbar go through `bulk_edit`, which assigns one value to
every selected document in a single request. Titles cannot work that way: each document
gets a *different* new title, and paperless-ngx has no endpoint for that. The old app
(`../paperless-ios`, `BulkEditTitleView`) solved it with a template — a string containing
`{placeholder}` tokens expanded per document — followed by one `PATCH` per document. That approach
is kept.

What is not kept is its scope. The old app renamed only the documents currently loaded in the list
and showed a warning banner when the selection was larger, because it had no way to fetch the rest.
This codebase has `GetDocumentsByIdsUseCase`, already used by `runRefreshDocuments`, so the whole
selection is fetched and the warning has no reason to exist.

## Design

### Placement

"Edit title" goes in the bottom toolbar's overflow `Menu`, above a `Divider` and the destructive
"Delete documents".

A sixth icon was the intent, and it does not fit. Measured on a running iPhone 17 Pro (402pt wide)
with `snapshot_ui`, six buttons span **-4.7pt to 406.6pt — 411pt in total**: the first icon is
clipped off the left edge and the last runs past the right. Each `Label` at `.title3` renders about
42pt wide, not the ~25pt a glyph suggests, and with `.x5` = 32pt spacing five is the maximum. With
the button moved into the menu the row measures 34pt to 368pt, comfortably centred.

So the menu now holds one reversible action and one destructive one. The `Divider` keeps them
apart, and delete keeps its `.destructive` role, so the reason delete lives there — not being one
mistap from four reversible icons — still holds.

### Template engine

`DocumentBulkEditTitleTemplate` wraps the template string and exposes

```swift
func title(for document: Document, server: Server) -> String
```

Names are resolved through the existing `Correspondent.Id.get(server)`, `DocumentType.Id.get`,
`StoragePath.Id.get`, `Tag.Id.get` and `User.Id.get` helpers, which read `apiCache`. That keeps the
engine free of `@Shared` plumbing and leaves it controllable from tests, since `apiCache` is a
dependency.

All 22 placeholders from the old app carry over unchanged, and no new ones are invented: `{asn}`,
`{correspondent}`, `{document_type}`, `{tag_list}`, `{title}`, `{created}`, `{created_day}`,
`{created_month}`, `{created_month_name}`, `{created_month_name_short}`, `{created_year}`,
`{created_year_short}`, the six `{added_*}` equivalents, `{owner_username}`, `{original_name}` and
`{doc_pk}`.

Four deliberate departures from the old implementation:

**Single pass.** The engine scans for `{token}` and substitutes each occurrence once. The old code
chained one `replacingOccurrences` call per placeholder, so `{title}` was expanded first and any
placeholder token inside the document's own title was then expanded by the passes that followed.
Tokens are
scanned left to right; an unrecognised `{token}` is left in place rather than deleted, so a typo is
visible in the preview instead of silently vanishing.

**`{asn}` with no ASN** yields an empty string. `Document.archiveSerialNumber` is `Int?` here; the
old model had it non-optional and would have printed a placeholder value.

**`{original_name}`** yields the filename minus its extension, which is what the description string
has always promised and what paperless-ngx itself does. The old code inserted `invoice.pdf`.

**Dates** come from `Calendar` and `DateFormatter` in the local time zone. SwiftDate is not a
dependency of this repo; `{created_month_name}` and `{created_month_name_short}` use
`DateFormatter.monthSymbols` and `shortMonthSymbols`, `{created}` and `{added}` use
`ISO8601Format()` as before. `{created_*}` reads `document.created`, which is the field
`DocumentRowView` and `DocumentFormInput` already treat as the document's date.

### Sheet

One sheet, not the old app's two. The template field sits at the top, the placeholder reference
lives behind a `{…}` menu in the sheet header, and the rest of the sheet is the preview list —
old title struck through, new title below it — which recomputes as the user types.

```
┌──────────────────────────────────────┐
│  ✕            Edit title         {…} │
├──────────────────────────────────────┤
│  Title                               │
│  ┌────────────────────────────────┐  │
│  │ {created_year}-{correspondent} │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ I̶n̶v̶o̶i̶c̶e̶ ̶4̶2̶                     │  │
│  │ 2026-Stadtwerke                │  │
│  ├────────────────────────────────┤  │
│  │ S̶c̶a̶n̶ ̶2̶0̶2̶6̶-̶0̶3̶-̶1̶1̶                │  │
│  │ 2026-Finanzamt                 │  │
│  └────────────────────────────────┘  │
│  ┌─────────┐  ┌─────────────────┐    │
│  │  Reset  │  │      Apply      │    │
│  └─────────┘  └─────────────────┘    │
└──────────────────────────────────────┘
```

The preview *is* the second step, so it does not need to be a second screen. Folding it in also
matches the four sibling sheets, which are all one sheet plus a confirmation popup, and avoids a
sheet stacked on a sheet — awkward to express as a nested `Destination` and awkward to dismiss.

The placeholder menu replaces the old app's scrolling list of 22 tokens with descriptions.
Selecting one appends its token to the template, exactly as tapping a row did. Reset clears the
template, matching `DocumentBulkEditGenericValueView`.

### Flow

```
view(.editTitleButtonTapped)                    — DocumentListReducer
  └─ destination = .bulkEditTitle(documents: selection, server:)

view(.onAppear)
  └─ runGetDocumentsByIds(ids:)     — chunked by 100, as runRefreshDocuments does
       └─ documentsLoaded(chunk) ×N — the list fills progressively
       └─ documentsLoadFailed       — toast, sheet stays open, Apply stays disabled

binding(\.template)                 — the preview is a computed property, no action

view(.applyButtonTapped)
  └─ guard the template is non-empty and at least one title actually changes
  └─ runConfirmApply(documentCount:)
       └─ false: nothing happens
       └─ true:  applyConfirmed
            └─ runUpdateTitles      — at most 4 requests in flight
                 ├─ progress(completed:) ×N
                 └─ saved(failed:)
                      ├─ delegate(.documentsUpdated(succeeded))  — always
                      ├─ failed empty → dismiss
                      └─ otherwise    → documents := failures, progress = 0, toast
```

`delegate(.documentsUpdated(ids))` carries the ids that actually succeeded, and gets its own case
in `DocumentListReducer` rather than joining the multi-pattern one the four other bulk edits share.
That case re-fetches the list and refreshes `documentCache` exactly as the shared one does, but
does **not** set `destination = nil`: after a partial failure the sheet has to stay open holding
the failures, while the documents that did get renamed still reach the list.

Dismissal on full success is the sheet's own business, through `@Dependency(\.dismiss)` — the same
route `closeButtonTapped` already takes.

**Bounded concurrency** is the substantive change to the save path. The old code did
`chunked(into: count / 4)` and ran each chunk through an unbounded task group, which puts
`count / 4` requests in flight at once — reasonable for the page of 25 it could actually reach, a
stampede now that "select all matching" can hand it thousands. Four at a time, refilled as each
completes.

**Documents whose new title equals their current title are skipped.** A template that only
matches part of the selection should not issue thousands of no-op `PATCH`es.

`UpdateDocumentInput` is reused as-is, built from the document's existing fields with the new
title. It carries every field, but the request is a `PATCH` and the other values are the ones
already on the server, so it is a rename in effect. Adding a title-only input would mean a second
shape for the same endpoint.

Apply is disabled until the fetch has completed and the template expands to at least one changed
title, so a partially loaded selection can never be half-renamed.

### Failure

A failed *fetch* toasts and leaves the sheet open with Apply disabled; the user closes it and
retries. Nothing has been written at that point, so there is nothing to unwind.

A failed *save* keeps the old app's behaviour: the sheet stays open, its list shrinks to the documents that failed,
progress resets to zero and a plural-aware toast names the count. Tapping Apply again retries
exactly those. Everything that succeeded has already been sent to the list through the delegate.

### Progress

A determinate `ProgressView(value:total:)` above the button row while saving, with the preview list
disabled. The old app floated a capsule popup, which has no equivalent here, and the indeterminate
spinner that `.primary(isLoading:)` gives the sibling sheets says nothing useful across a few
thousand sequential requests.

### Confirmation

`DocumentBulkEditConfirmationPresenter` gains a third entry point alongside `present` and
`presentTags`:

```swift
var presentTitle: @Sendable (_ documentCount: Int) async -> Bool
```

Titled `confirmChanges` rather than `confirmAssignment` — nothing is being assigned. This mirrors
how `DocumentDeleteConfirmationPresenter` grew a second entry point for bulk delete rather than
generalising the first.

The message names the count, not the documents, for the same reason bulk delete does: the
selection can run to thousands.

### Strings

New keys in `Shared/Framework/Resources/Localizable.xcstrings`: `editTitle`, `placeholders`,
`confirmChanges`, `bulkEditTitleConfirmation` (plural), `bulkEditTitleError` (plural), and 22
`bulkEditTitlePlaceholder.*` descriptions. English and German come from the old app's catalog,
which already has translated copy for all of them except `bulkEditTitleConfirmation` — the old
wording there said the operation would "modify" the documents, which is vague for a rename.

`bulkEditAllDocumentsWarning` is not ported — fetching the whole selection retired it.

## Testing

- `DocumentBulkEditTitleTemplateTests` — every placeholder; absent correspondent, document type,
  owner and ASN; an unrecognised token left in place; a document whose own title contains a token.
- `DocumentBulkEditTitleReducerTests` — chunked load, confirm and cancel, unchanged titles skipped,
  partial failure leaving only the failures behind, progress.
- `DocumentBulkEditTitleViewTests` — snapshots, following the existing bulk edit view tests.
- `DocumentListReducerTests` — the toolbar action opens the destination, and the delegate refreshes
  the list.
- End to end against the seeded container with a temporary XCUITest driving `DocumentsApp`: the
  toolbar geometry above, the placeholder menu inserting `{asn}`, the confirmation reading "This
  will rename 2 documents.", and both documents coming back renamed from the server. The fixture
  titles were restored afterwards and the test deleted.

## Out of scope

- **The last-used template is not remembered.** Retyping `{created_year}-{correspondent}` every
  time is the obvious next annoyance; parked in `docs/ideas.md`.
- **No undo.** A rename can be reversed by renaming again, but only if the user still knows the old
  titles.
- **No cap on selection size.** A 3000-document rename is 3000 requests and will take minutes; the
  progress bar is what makes that bearable rather than a limit.
