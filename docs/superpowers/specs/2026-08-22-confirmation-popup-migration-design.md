# Migrate the remaining system confirmation dialogs to `ConfirmationPopupView`

## Context

Confirmations in this app are split between two mechanisms.

`DocumentRow`, `DocumentNotes` and `DocumentBulkEdit` await a `@DependencyClient` presenter that
shows `ConfirmationPopupView` through `PopupPresenter`. Six list rows still set a
`ConfirmationDialogState` destination and render it with `.confirmationDialog`:

| Row | Module | Delegate sent on confirm |
|---|---|---|
| `CorrespondentRow` | `CorrespondentsFeature` | `.deleteCorrespondent` |
| `DocumentTypeRow` | `DocumentTypesFeature` | `.deleteDocumentType` |
| `SavedViewRow` | `SavedViewsFeature` | `.deleteSavedView` |
| `ServerRow` | `ServersFeature` | `.deleteServer` (with `animation: .default`) |
| `StoragePathRow` | `StoragePathsFeature` | `.deleteStoragePath` |
| `TagRow` | `TagsFeature` | `.deleteTag` |

`docs/ideas.md` recorded five; `SavedViewRow` is the sixth and was missed. All six are structurally
identical — same `Destination` enum with a single `confirmation` case, same
`.deleteConfirmation(name)` message, same `+ConfirmationDialogState.swift` file. Only the
destructive button title differs.

### Why the popup wins

`AGENTS.md` already carries the rule, and it is not only about consistency. The notes section
started on `.confirmationDialog` and it was visibly broken: presented from inside the edit sheet,
the system dialog rendered as a clipped popover anchored to the bottom edge with the cancel button
pushed off screen entirely. `PopupPresenter` presents above everything and is unaffected. Any of
the six would do the same the day it is presented from within a sheet.

## Goal

Delete every remaining `ConfirmationDialogState` and `.confirmationDialog` from `Modules/`, with
the six rows going through one shared presenter rather than six near-identical copies.

## Design

### One presenter in `Components`

`Modules/Components/Popup/DeleteConfirmationPresenter.swift`, registered as `\.deleteConfirmation`:

```swift
@DependencyClient
public struct DeleteConfirmationPresenter: Sendable {
    public var present: @Sendable (
        _ title: LocalizedStringResource,
        _ name: String
    ) async -> Bool = { _, _ in false }
}
```

`liveValue` builds the popup through `\.popupPresenter`, exactly as
`DocumentNoteDeleteConfirmationPresenter` does:

```swift
ConfirmationPopupView(
    title: title,
    message: .deleteConfirmation(name),
    isDestructive: true,
    cancel: { resolve(false) },
    confirm: { resolve(true) }
)
```

`previewValue` returns `false`; `testValue` is `Self()`.

The presenter owns the message format rather than taking it as a parameter. All six rows pass the
same `.deleteConfirmation(name)` today, and baking it in means it cannot drift between them. The
entity-specific title — `.deleteTag`, `.deleteServer` — stays with the caller. `Components`
compiles the shared string catalog like every other module, so `.deleteConfirmation` resolves
there.

The two document presenters (`DocumentDeleteConfirmationPresenter`,
`DocumentNoteDeleteConfirmationPresenter`) are deliberately left alone. The first carries a second
`presentMany` case that does not fit the shape, and folding them in would widen the change without
removing a system dialog.

### Wording

The system dialog's destructive button reads "Delete tag"; that string becomes the popup **title**,
and the confirm button takes `ConfirmationPopupView`'s default "Confirm":

```
┌─────────────────────────────┐
│  Delete tag                 │
├─────────────────────────────┤
│  Do you really want to      │
│  delete "Inbox"?            │
├─────────────────────────────┤
│  [ Cancel ]   [ Confirm ]   │
└─────────────────────────────┘
```

This is byte-for-byte the shape of the existing document and note delete popups, so the app ends up
with one confirmation, not two dialects of one. No new strings are needed — `deleteTag`,
`deleteCorrespondent`, `deleteDocumentType`, `deleteSavedView`, `deleteServer`,
`deleteStoragePath`, `deleteConfirmation`, `confirm` and `cancel` all already exist.

### Per-row change

Identical six times. `TagRow` as the worked example:

- **Delete** `TagRowReducer+ConfirmationDialogState.swift`.
- **Reducer** — remove the `Destination` enum, `@Presents var destination`, the `destination`
  action case, `.ifLet(\.$destination, action: \.destination)`, the
  `extension TagRowReducer.Destination.State: Equatable {}` line, and the
  `.destination(.presented(.confirmation(.deleteButtonTapped)))` case. `deleteButtonTapped` becomes
  `return .runConfirmDelete(name: state.tag.name)`.
- **New `TagRowReducer+Effect.swift`** — `ServerRow` already has one and gains a method instead:

```swift
static func runConfirmDelete(name: String) -> Self {
    @Dependency(\.deleteConfirmation.present)
    var presentConfirmation

    return .run { send in
        guard await presentConfirmation(.deleteTag, name) else {
            return
        }
        await send(.delegate(.deleteTag))
    }
    .cancellable(id: CancelID.confirmDelete)
}
```

- **View** — drop the `.confirmationDialog(…)` modifier. `@Bindable var store` becomes plain
  `var store`, since the destination was its only binding use.

There is no intermediate `deleteConfirmed` action: the effect sends the existing `.delegate` case
directly, as `DocumentRowReducer.runConfirmDelete` does. `ServerRow` keeps `animation: .default` on
that send, preserving the behaviour its current `.run` wrapper provides.

`.forEach` namespaces cancellation IDs per element, so a single `CancelID.confirmDelete` per
feature is safe across the rows of a list.

### What does not change

Parent list reducers already match row actions as `case …(.element(id:, action: .delegate(…)))`
with a `case .binding, .destination, .tags: return .none` catch-all, so removing the row's
`.destination` case compiles unchanged. No parent reducer, view or test outside the row directories
references `Destination.Confirmation`.

## Testing

**Unit** — each `…RowReducerTests` loses `test_destination_confirmation_deleteButtonTapped` and its
destination-mutating `test_view_deleteButtonTapped`, and gains the pair
`DocumentRowReducerTests` already uses:

- `test_view_deleteButtonTapped_confirmed` stubs
  `$0.deleteConfirmation.present = { title, name in … ; true }`, captures both arguments in a
  `LockIsolated`, asserts the delegate is received and that the title and name were correct.
- `test_view_deleteButtonTapped_cancelled` returns `false` and asserts nothing follows.

**XCUITest** — six `…AppTests` files tap `app.sheets.buttons["Delete tag"].firstMatch` today and
must target the popup's Confirm button instead. The
`app.staticTexts["Do you really want to delete \"Inbox\"?"]` assertion above each tap stays valid:
the popup renders that string as a `Text`.

**Snapshots** — none added. `ConfirmationPopupView` is unchanged and already covered by
`ComponentsTests/Popup/ConfirmationPopupViewTests`.

## Order of work

1. Add `DeleteConfirmationPresenter` to `Components`.
2. Migrate `TagRow` end-to-end, then run `TagsFeatureTests` **and** `TagsAppTests` on the simulator.
3. Repeat for `CorrespondentRow`, `DocumentTypeRow`, `StoragePathRow`, `SavedViewRow`, `ServerRow`.
4. Update `AGENTS.md` — drop the closing paragraph listing the rows that "still carry the old
   `ConfirmationDialogState` destination" — and remove the entry from `docs/ideas.md`.
5. Verify no `ConfirmationDialogState`, `.confirmationDialog` or `.alert` remains in `Modules/`.

Step 2 is a checkpoint, not just the first item. No existing XCUITest drives a
`ConfirmationPopupView`, so whether the popup is reachable from XCUITest is unproven until that run
passes.

## Risks

- **XCUITest reachability.** `PopupPresenter` shows the popup via SwiftMessages in a
  `.window(windowLevel: .statusBar)` presentation context, not in the app's own window. If
  `app.buttons["Confirm"]` does not find it, the fallback is an accessibility identifier on
  `ConfirmationPopupView`'s buttons — which would also be the first XCUITest coverage the popup has
  ever had. Step 2 surfaces this before the pattern is copied five more times.
- **`ci` docker drift.** `docs/ideas.md` records that the `ci` instance no longer matches the seed.
  These app tests create and delete their own records through the repositories rather than relying
  on seeded metadata, so it should not bite, but an unrelated failure there is not evidence against
  this change.
