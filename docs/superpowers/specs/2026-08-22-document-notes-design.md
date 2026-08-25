# Document notes

## Context

`DocumentFormView` is the edit sheet for a document. Since
[2026-08-21](2026-08-21-document-edit-content-design.md) it has two sections — Details and Content —
switched from a `Picker`-in-`Menu` behind an ellipsis in `SheetHeader`'s `right:` slot, with
Reset and Save in the bottom bar.

Paperless keeps free-text notes against a document. Nothing in this app reads or writes them today;
the only trace is `SortField.notes` (`num_notes`), which lets the list be sorted by note count
without ever showing one.

### What the server actually offers

Probed against the `paperless-ngx:3.0.5` instance this repo runs in `docker/`:

```
GET    /api/documents/{id}/notes/          → [Note]
POST   /api/documents/{id}/notes/          {"note": "…"}  → [Note]
DELETE /api/documents/{id}/notes/?id={n}   → [Note]
```

Three things follow from the probe, and they shape the whole design:

1. **There is no PATCH.** A note cannot be edited once written. "Write" means *add*, never *update*.
2. **Every verb returns the complete, updated list.** A create or a delete is also a refresh — the
   response replaces local state outright, so there is never a second round-trip and never a
   locally-invented row.
3. **The server does not validate.** `POST {"note": ""}` returns `200` and stores an empty note.
   Guarding against blank notes is entirely the client's job.

A note is shaped like this, oldest first:

```json
{
  "id": 1,
  "note": "Needs a signature",
  "created": "2026-08-22T08:48:24.692612+02:00",
  "user": { "id": 2, "username": "admin", "first_name": "", "last_name": "" }
}
```

The nested `user` is **not** the app's `User` — it carries four fields where `User` has thirteen.
It needs its own type. `created` matches the format `added` and `modified` already use, so
`JSONDecoder.apiDecoder` handles it unchanged.

### The document endpoint already carries notes

`GET /api/documents/{id}/` returns a `notes` key. `DocumentFormReducer` already calls it eagerly on
`onAppear` to get untruncated content, so notes could ride along for free.

They deliberately do not. The requirement is that notes load **only when the user opens the Notes
section** — most edits never go near it, and the notes payload is unbounded. Keeping notes on their
own endpoint also means a create or delete response refreshes exactly the notes and touches nothing
else in the shared `Document`.

## Goal

A third section in the edit sheet that lists a document's notes, adds one, and deletes one — loaded
lazily on first visit, committed immediately, with no way to write a blank note.

## Design

### API layer

A new `Note` in `ApiInterface/Notes/`:

```swift
public struct Note: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<Note, Int>

    public let created: Date
    public let id: Id
    public let note: String
    public let user: Author

    public struct Author: Codable, Equatable, Hashable, Identifiable, Sendable {
        public let id: User.Id
        public let username: String
    }
}
```

`Author` is nested so the name does not collide with `User`, which leaves `User.Id` resolving to the
real thing. It models `id` and `username` only; `first_name` and `last_name` come back empty on a
fresh install and nothing in the design displays them, so decoding drops them.

Three use cases in `ApiInterface/Notes/`, each following the shape of every other use case in the
module and each returning `[Note]`:

- `GetNotesUseCase` — `(Document.Id, Server) -> [Note]`
- `CreateNoteUseCase` — `(Document.Id, CreateNoteInput, Server) -> [Note]`
- `DeleteNoteUseCase` — `(Document.Id, Note.Id, Server) -> [Note]`

`CreateNoteInput` is a one-field `Encodable` wrapper around `note`, matching how every other body in
the module is expressed.

The live implementations delegate to a new `NotesRepository` in `ApiImplementation/Notes/`, rather
than growing `DocumentsRepository` past its current eleven methods. The endpoints hang off
`/api/documents/{id}/`, but they are a distinct resource with a distinct model, and the module is
already organised one repository per folder per entity.

### Feature layer

Notes get their own reducer in `Modules/DocumentsFeature/DocumentNotes/`, scoped into
`DocumentFormReducer` with `Scope`, rather than another set of fields on a reducer that is already
carrying two sections. Loading, creating, deleting, a draft, a confirmation dialog and three
in-flight flags would roughly double it.

```swift
@ObservableState
public struct State: Equatable {
    @Presents var destination: Destination.State?
    var draft = ""
    let documentId: Document.Id
    var deletingNoteId: Note.Id?
    var isCreating = false
    var isLoading = false
    var loadError: String?
    var notes: IdentifiedArrayOf<Note>?
    let server: Server

    var canCreate: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }
}
```

`notes` is optional for the same reason `content` is: **`nil` means "not loaded", and an empty array
means "loaded, and there are none"**. Collapsing the two would either show the empty state before
the request lands or spin forever once it returns nothing.

`deletingNoteId` is a single id rather than a set. The row that is being deleted dims; a second
swipe during the round-trip is not worth supporting when the response replaces the whole list
anyway.

#### Lazy loading falls out of the view hierarchy

`DocumentFormView` switches on `store.section`, so `DocumentNotesView` is only in the hierarchy
while Notes is showing. Its `.onAppear` is therefore the first-visit hook — no extra plumbing, no
flag on the parent:

```swift
case .onAppear:
    guard state.notes == nil, state.loadError == nil, !state.isLoading else { return .none }
```

The guard is copied from `DocumentFormReducer.onAppear` and earns its three clauses the same way:
switching away and back must not refetch, and a failed load must not retry silently — that is what
the retry button is for.

#### Create and delete replace the list wholesale

Because the server answers every verb with the full list, all three results land in one place:

```swift
case let .notesResult(action, result):
```

where `action` distinguishes which flag to clear and whether a failure sets `loadError`. A load
failure sets `loadError` and shows the section's retry state; a create or delete failure only
toasts, because the list on screen is still valid.

On a successful create the draft is cleared. On a failure it is **not** — the user's text survives a
network error rather than vanishing with it.

#### Deleting

Swipe reveals a destructive Delete, which runs `runConfirmDelete(noteId:)` — an effect that awaits
`DocumentNoteDeleteConfirmationPresenter` and, only on a `true`, sends `.deleteConfirmed(noteId)`.
This is the `PopupPresenter` + `ConfirmationPopupView` route `DocumentRow` takes.

This was first built on TCA's `ConfirmationDialogState` and `.confirmationDialog`, matching
`CorrespondentRow`, `TagRow`, `DocumentTypeRow`, `StoragePathRow` and `ServerRow`. That was wrong,
and visibly so: presented from inside the edit sheet, the system dialog rendered as a clipped
popover anchored to the bottom edge with the cancel button pushed off screen entirely. The custom
popup is presented above everything by `PopupPresenter` and is unaffected.

The rule is now recorded in `AGENTS.md`, and migrating the five remaining rows is parked in
`docs/ideas.md`.

There is no `Destination` on this reducer at all — the confirmation lives in the effect, so the
note id is carried by the action rather than by presented state.

### View

`DocumentFormSection` gains `case notes`, ordered after `content`.

The section splits across two of `Sheet`'s slots:

```swift
Sheet(isScrollingEnabled: store.section == .details) {
    SheetHeader(…)
} content: {
    switch store.section {
    case .details: detailsSection()
    case .content: contentSection()
    case .notes:   DocumentNotesView(store: notesStore)
    }
} bottom: {
    switch store.section {
    case .details, .content: buttons()
    case .notes:             DocumentNoteComposerView(store: notesStore)
    }
}
```

`isScrollingEnabled` narrows from `!= .content` to `== .details`, because the notes `List` scrolls
itself and must not nest inside the sheet's `ScrollView`.

**The composer takes the bottom slot that Reset and Save vacate.** Nothing in the Notes section is
staged, so a Save button there would have nothing to save and a Reset nothing to reset. Putting the
composer in that slot pins it above the keyboard, keeps the sheet's chrome uniform, and avoids the
alternative — conditionally passing `EmptyView` — which `Sheet` cannot express from a single call
site: a `ViewBuilder` `if` yields `_ConditionalContent`, not `EmptyView`, so the divider and padding
would render around nothing.

`DocumentNotesView` mirrors the three states `contentSection()` already establishes:

- `loadError` → `EmptyListView` with a retry button
- `notes == nil` → a large `ProgressView`
- `notes?.isEmpty == true` → `EmptyListView` with no button; the composer below is the call to action
- otherwise → a `List` of `DocumentNoteRowView`

Rows are cards: note text, then a caption line of username and timestamp, on
`Color.m3SurfaceContainer` with `.listRowSeparator(.hidden)` and `Constants.cornerRadius`, dimmed
while that row is the one being deleted. Timestamps use a new fixed-format
`DateFormatter.noteCreated` (`yyyy-MM-dd HH:mm`) alongside the existing `createdDate`, rather than a
locale-aware style — the test trait pins `timeZone` but not `locale`, so a locale-aware format would
make snapshots machine-dependent.

`DocumentNoteComposerView` is a `TextField(axis: .vertical)` with `lineLimit(1...5)` and a trailing
circular add button, disabled unless `canCreate` and showing a spinner while `isCreating`.

### Strings

`notes`, `addNote`, `deleteNote`, `deleteNoteConfirmation`, `noNotesFound`.

## Out of scope

- Editing an existing note. The server has no endpoint for it.
- Showing a note count on the document row, in the list, or on the ellipsis menu. All of them would
  need notes loaded before the user asks for them, which is the one thing this design rules out.
- Reading notes out of the `GET /api/documents/{id}/` response, for the same reason.
- Note permissions. `user` is displayed, never enforced against.

## Testing

- **`NotesRepositoryTests`** — integration tests against the docker instance: create a note, read it
  back, delete it, assert the returned list each time. Covers the round-trip the design leans on.
- **`DocumentNotesReducerTests`**
  - `onAppear` loads and populates; a second `onAppear` does not refetch.
  - `onAppear` after a failure does not refetch; `retryLoadButtonTapped` does.
  - A failing load sets `loadError` and toasts.
  - `canCreate` is false for empty and whitespace-only drafts. **This is the guard standing in for
    the server's missing validation.**
  - A successful create replaces the list and clears the draft.
  - **A failing create keeps the draft.**
  - Swipe-delete presents the confirmation and deletes the right id on confirm; cancelling does
    not delete; a swipe on a row the latest response already removed never opens the popup.
  - A failing delete toasts, clears `deletingNoteId` and leaves the list intact.
- **`DocumentNotesViewTests`** — snapshots for loading, loaded, empty and error states.
- **`DocumentFormViewTests`** — a snapshot of the sheet on the notes section, confirming the
  composer replaces Reset/Save.

## Files

New:

- `Modules/ApiInterface/Notes/Note.swift`
- `Modules/ApiInterface/Notes/CreateNoteInput.swift`
- `Modules/ApiInterface/Notes/CreateNoteUseCase.swift`
- `Modules/ApiInterface/Notes/DeleteNoteUseCase.swift`
- `Modules/ApiInterface/Notes/GetNotesUseCase.swift`
- `Modules/ApiImplementation/Notes/NotesRepository.swift`
- `Modules/ApiImplementation/Notes/CreateNoteUseCase.swift`
- `Modules/ApiImplementation/Notes/DeleteNoteUseCase.swift`
- `Modules/ApiImplementation/Notes/GetNotesUseCase.swift`
- `Modules/DocumentsFeature/DocumentNotes/DocumentNotesReducer.swift`
- `Modules/DocumentsFeature/DocumentNotes/DocumentNoteDeleteConfirmationPresenter.swift`
- `Modules/DocumentsFeature/DocumentNotes/DocumentNotesReducer+Effect.swift`
- `Modules/DocumentsFeature/DocumentNotes/DocumentNotesReducer+TestValue.swift`
- `Modules/DocumentsFeature/DocumentNotes/DocumentNotesView.swift`
- `Modules/DocumentsFeature/DocumentNotes/DocumentNoteRowView.swift`
- `Modules/DocumentsFeature/DocumentNotes/DocumentNoteComposerView.swift`
- `Modules/ApiImplementationTests/Notes/NotesRepositoryTests.swift`
- `Modules/DocumentsFeatureTests/DocumentNotes/DocumentNotesReducerTests.swift`
- `Modules/DocumentsFeatureTests/DocumentNotes/DocumentNotesViewTests.swift`

Changed:

- `AGENTS.md` — the confirmation rule
- `docs/ideas.md` — migrating the five remaining rows
- `Modules/DocumentsFeature/Extensions/DateFormatter+Extensions.swift` — `noteCreated`
- `Modules/DocumentsFeature/DocumentForm/DocumentFormSection.swift` — `case notes`
- `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift` — scoped child
- `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer+TestValue.swift`
- `Modules/DocumentsFeature/DocumentForm/DocumentFormView.swift` — section and bottom slot
- `Shared/Framework/Resources/Localizable.xcstrings`
- `Modules/DocumentsFeatureTests/DocumentForm/DocumentFormViewTests.swift`
- `Snapshots/DocumentsFeatureTests/` — new captures
