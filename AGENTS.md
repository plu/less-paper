# Conventions

Instructions for any AI agent working in this repository.

## Comment Style

**Never write `///` doc comments. Never write `/** ... */` doc comments. Only ever `//`.**

This applies everywhere — types, properties, methods, initialisers, test helpers. No exceptions,
including when adding to a file that still contains old-style doc comments.

Comment only when something is **exceptional** — when a future reader would otherwise stop and
wonder why the code is the way it is. A comment earns its place by explaining a non-obvious
constraint, a subtle trap, or a decision that looks wrong until you know the reason.

```swift
// Reading state at delivery rather than capturing it: a keystroke would otherwise report a
// search type the user has since changed.
case .searchDebounced:
    return .runFilterUpdated(state)
```

Do **not** restate what the code already says:

```swift
// Wrong — adds nothing.
/// The current sort direction
private let direction: SortDirection
```

## `@ViewAction` views send with `send`, never `store.send`

In a view annotated `@ViewAction(for:)`, the macro generates a `send` that wraps the action in
`.view(…)`. Calling `store.send` there compiles but emits:

> Do not use 'store.send' directly when using '@ViewAction'

It applies to `task` and other modifiers too, not just button actions — the trailing `.finish()`
works the same either way:

```swift
// Wrong — warns.
.task { await store.send(.view(.onAppear)).finish() }

// Right.
.task { await send(.onAppear).finish() }
```

Views without the macro — `DocumentBulkEditGenericValueView` is one, because it is generic — keep
using `store.send(.view(…))`. Check for the annotation before copying a line between views.

Builds are not warning-free by default, so a new warning is easy to miss. When touching a view,
skim the build output for its file.

## Confirmations use `ConfirmationPopupView`, never the system dialog

**Never use `.confirmationDialog`, `.alert`, or `ConfirmationDialogState`.** Every confirmation in
this app goes through `PopupPresenter` and `ConfirmationPopupView`.

The system dialog is not just off-brand — inside a presented sheet it renders as a clipped popover
anchored to the wrong edge, and the cancel button can be pushed off screen entirely. The custom
popup is presented by `PopupPresenter` above everything and is unaffected.

The shape is a `@DependencyClient` presenter that returns whether the user confirmed, with the
reducer awaiting it inside an effect. `DocumentDeleteConfirmationPresenter` and
`DocumentNoteDeleteConfirmationPresenter` are the two to copy:

```swift
// Wrong — off-brand, and clipped inside a sheet.
state.destination = .confirmation(.confirmDelete(name: state.tag.name))

// Right.
return .runConfirmDelete(noteId: noteId)
```

```swift
static func runConfirmDelete(noteId: Note.Id) -> Self {
    @Dependency(\.documentNoteDeleteConfirmation.present)
    var presentConfirmation

    return .run { send in
        guard await presentConfirmation() else {
            return
        }
        await send(.deleteConfirmed(noteId))
    }
    .cancellable(id: CancelID.confirmDelete)
}
```

For the common case — deleting a named record — there is one shared presenter already:
`Components/Popup/DeleteConfirmationPresenter.swift`. It takes the entity title and the record's
name and renders `Delete tag` over `Do you really want to delete "Inbox"?`:

```swift
@Dependency(\.deleteConfirmation.present)
var presentConfirmation

guard await presentConfirmation(.deleteTag, name) else {
    return
}
```

Reach for that first. Write a presenter of your own only when the popup needs custom content, as
`DocumentBulkEditConfirmationPresenter` does.

## UI tests never mutate global server state

UI tests live in `AppUITests` and drive the real app against the paperless-ngx container in
`docker/`. Each test creates its own Paperless user, so every tag, correspondent, document type,
storage path and saved view it creates is owned by that user and invisible to every other test. The
list a test opens starts empty.

**Never write a helper that deletes all of something.** `deleteAllTags()` and its kind are why the
old per-feature harness suites could not run in parallel, and they are gone.

Two exceptions, both probed against paperless-ngx 3.0.5:

- **Custom fields have no owner** and are global — every user sees every custom field. Namespace
  them by name (`uit-<id>-<label>`) and never assert on the total count of the custom field list.
- **Documents consumed from `docker/consume/` have no owner** and form a shared read-only corpus.
  Read from it freely; a test that needs to *modify* a document must upload its own first.

Tests always launch with a `UITestConfiguration`, even the onboarding journey that starts without a
server. Launching with no configuration at all would let the app read whatever `servers.json` the
simulator happens to hold, which is how a developer machine and a clean CI runner end up
disagreeing.
