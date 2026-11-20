# Document share links

## Intent

Paperless-ngx can hand out a public link to a single document — `<server>/share/<slug>` — that
anyone can open without an account, optionally until an expiry date. The web UI offers it under
*Send → Share Links* on the document detail page. The app cannot create one today: the only links
it can share are the app link and the web link (`DocumentShareMenu.swift`), and both need the
recipient to have an account on the server.

This adds share links to the app, in the same place the existing sharing already lives, so a
document can be handed to someone outside the archive straight from the phone.

## Goals

- Create a share link for a document, choosing an expiry and, where it applies, whether the
  archived or the original file is shared.
- Hand the new link straight to the system share sheet, so it reaches Messages, Mail and the like
  in one step.
- See the document's existing share links, copy one, and delete one.
- Reachable from both places the Share menu already appears: the document row's context menu and
  the document detail toolbar.

## Non-goals

- A global list of every share link across documents. The web UI has none either outside the
  per-document dropdown.
- Editing an existing link's expiry. The web UI does not offer it; delete and recreate instead.
- Share link bundles (several documents behind one link), which newer paperless-ngx versions add.
- Sharing several selected documents at once from bulk edit.

## Anti-goals

- A sheet that looks or behaves differently from the app's other bottom sheets.
- A system `.alert` or `.confirmationDialog` for the delete confirmation — see AGENTS.md.
- Offering the action to a user the server will refuse: it must be gated on permissions.

## Approaches

1. **Follow the Notes pattern — chosen.** New `ShareLinks/` use cases in `ApiInterface` and
   `ApiImplementation`, modelled on `Notes/`, which is the same shape of thing: per-document
   records that are listed, created and deleted. A new `DocumentShareLinks` reducer and view in
   `DocumentsFeature`, presented as a destination from both `DocumentRowReducer` and
   `DocumentDetailReducer`. One implementation, two entry points.
2. **A new section in `DocumentSheetView`** (the full-height tabbed sheet behind *Open ▸* that
   holds Notes and History). Cheapest, but it is not a small bottom sheet and it is not reached
   from Share, which is where the user asked for it.
3. **A separate `ShareLinksFeature` module.** Only adds wiring and one more string catalogue;
   `DocumentsFeature` already owns sharing, including `DocumentShareMenu`.

## Design

### Entry point

`DocumentShareMenu` gains one item below *App link* and *Web link*: **Share link…** with the
`link.badge.plus` symbol. Because the menu is shared, this reaches the row context menu and the
detail toolbar at once.

The menu itself does not know about reducers — today it only takes `documentId`, `server` and a
view builder. It gains an optional action closure for the new item; when the closure is `nil` the
item is not shown. Both callers pass a closure that sends a new view action
(`shareLinksButtonTapped`), and pass `nil` when the user lacks `addShareLink` (see Permissions).

The detail screen shows the item whether or not the file has finished downloading — like the app
and web links, a share link needs nothing downloaded. It is hidden on an offline snapshot, the same
way editing is (`isEditable = canEdit && !isOfflineSnapshot`), and the Offline tab's rows follow
the same rule since they reuse `DocumentRowReducer`.

### The sheet

Built from the existing `Sheet` / `SheetHeader` components with the `.sheet` detent, the same as
`DocumentBulkEditTitleView`:

```
┌──────────────────────────────────────┐
│  ✕          Share links              │
├──────────────────────────────────────┤
│  🔗 …/share/aB3x9Q                   │
│     Expires in 6 days            ⧉ 🗑 │
│  🔗 …/share/K7pLmZ                   │
│     Never expires                ⧉ 🗑 │
│                                      │
│  Expires        [ 7 days        ▾ ]  │
│  Share archived version     [ on  ]  │
├──────────────────────────────────────┤
│  [          Create link           ]  │
└──────────────────────────────────────┘
```

- **Header:** `SheetCloseButton` on the left, title *Share links*.
- **List:** the document's existing links, in the order the server returns them (newest first —
  the endpoint orders by `-created`). Each row shows the URL (truncated in the middle) and its
  expiry: *Expires in …* as a relative date, or *Never expires*. The server leaves expired links out
  of this endpoint, so there is no *Expired* state to show. Each row has a copy button (writes the URL to `UIPasteboard`, confirmed with the app's
  existing success toast) and a delete button.
- **Empty list:** a short line, *No share links yet*, in place of the list.
- **Form:** *Expires* as a menu picker with exactly the web UI's choices — 1 day, 7 days, 30 days,
  Never — defaulting to 7 days, as the web UI does. *Share archived version* as a toggle, on by
  default, shown only when the document has an archived version (`document.archivedFileName !=
  nil`); when hidden, `original` is sent. The gate is presentational only: the server's share view
  already falls back to the original when there is no archive.
- **Bottom:** a full-width primary *Create link* button, with the loading state while the request
  runs.
- **Loading:** a centred `ProgressView` while the list is first fetched, as
  `DocumentBulkEditTitleView` does.

### Creating

*Create link* posts the link. On success the new link is inserted at the top of the list and the
system share sheet (`Components/Share/ShareSheet`) is presented on top of the share-links sheet with
the new URL. Dismissing the share sheet returns to the share-links sheet, which stays open so the
user can see the link they just made. The form keeps its selections.

### Deleting

The delete button asks first through the shared `DeleteConfirmationPresenter`, with a new entity
title (*Delete share link*) and the link's slug as the name. On confirm the link is deleted and
removed from the list.

### Errors

Any failed request — list, create, delete — shows the app's `.error` toast with the message and
leaves the sheet as it was, matching `DocumentFormReducer`. A failed initial list shows the empty
state with a retry button, like `DocumentDetailView.errorView`.

### Permissions

The server does not gate the per-document list on `view_sharelink`: `GET
/api/documents/{id}/share_links/` checks `change_document` on that document (owner-aware) and
answers 403 otherwise. So:

- The menu item needs `addShareLink` **and** the existing `isEditable` (`canEdit` — i.e.
  `changeDocument` — and not an offline snapshot). That is the closest the app can get to the
  server's check without a per-object request.
- The delete button needs `deleteShareLink`.

Unknown permissions count as allowed, as everywhere else in `ServerPermissions`. Two refusals the
app cannot predict surface as an error toast rather than being gated: a document the user can
change globally but not by object ownership (403 on the list), and deleting a link another user
created (links are owned by their creator, and the list endpoint does not return an owner). The
web UI has the same two gaps.

### API

New in `ApiInterface/ShareLinks/`, mirroring `Notes/`:

- `ShareLink` — `id` (`Tagged<ShareLink, Int>`), `created: Date`, `expiration: Date?`, `slug:
  String`.
- `ShareLink.FileVersion` — `archive` / `original`.
- `CreateShareLinkInput` — `document`, `expiration: Date?`, `fileVersion`.
- `GetShareLinksUseCase` — `GET /api/documents/{id}/share_links/`.
- `CreateShareLinkUseCase` — `POST /api/share_links/` with `document`, `expiration` (ISO 8601, or
  `null` for never), `file_version`.
- `DeleteShareLinkUseCase` — `DELETE /api/share_links/{id}/`.

Implemented in `ApiImplementation/ShareLinks/` behind a `ShareLinksRepository`, the same layering
as `NotesRepository`. Unlike the notes endpoints, these do not answer with the full list, so the
reducer updates its list locally after a create or delete rather than refetching.

The per-document list endpoint does not return `file_version`, so the list does not show which
version a link shares. That matches the web UI's dropdown.

The expiry is computed on the device as now + the chosen interval and sent as a full timestamp, as
the web UI does.

### The link URL

`<server url>/share/<slug>`, built so a server hosted under a subpath keeps its prefix the same way
the web link does — `https://example.com/paperless` yields
`https://example.com/paperless/share/<slug>`. This is a plain URL helper (for example
`ShareLink.url(server:)`), **not** a new `DeepLink.Route`: `DeepLink` also parses incoming URLs, and
a share link is not something the app should try to open.

### Strings

All new strings go into `Modules/DocumentsFeature/Resources/Localizable.xcstrings` in `en` and
`de`, including the *Delete share link* title: `DeleteConfirmationPresenter` takes the title from
its caller, and callers keep their own (`deleteTag` lives in `TagsFeature`).

## Testing

- `ApiInterfaceTests`: decoding `ShareLink` (with and without an expiry), encoding
  `CreateShareLinkInput` (expiry `null` for never, `file_version` spelling).
- `ApiImplementationTests/ShareLinks`: create, list and delete against the dev instance, owned by a
  per-test user and cleaned up in teardown, as the other repository tests do.
- `DocumentsFeatureTests`: the `DocumentShareLinks` reducer — load, create presents the share item,
  delete awaits confirmation, delete gating, error paths.
- Row and detail: the menu item hidden without `addShareLink`, without `changeDocument`, and on an
  offline snapshot.
- Row and detail reducers: `shareLinksButtonTapped` presents the destination.
- `AppUITests`: one journey — upload a document as the test user, open Share link…, create a link,
  dismiss the share sheet, see it in the list, delete it.

## Left to the builder

- Exact symbol names, file layout inside `DocumentShare/`, and reducer action naming.
- Whether the picker is a `Menu` or a segmented control, as long as it fits the `.sheet` detent at
  large Dynamic Type.
- The precise relative-date formatting for *Expires in …*.
