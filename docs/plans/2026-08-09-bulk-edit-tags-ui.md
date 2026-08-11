# Bulk edit UI — tags

## Context

`docs/plans/2026-08-08-bulk-edit-ui.md` shipped bulk edit for correspondent, document type and storage path, and explicitly deferred tags:

> **Tags.** The `editTags` toolbar button stays a no-op. Tags need a different interaction — multi-select with independent add/remove sets (`Method.ModifyTags`), not one-of-N assignment — so they do not fit `DocumentBulkEditGenericValue` and get their own phase.

This is that phase. Everything below the feature layer already exists:

- `BulkEditDocumentsInput.Method.modifyTags(ModifyTags)` with `addTags: [Tag.Id]` / `removeTags: [Tag.Id]`, encoding to `{"method": "modify_tags", "parameters": {"add_tags": […], "remove_tags": […]}}` (`docs/plans/2026-08-08-bulk-edit-api.md`)
- `GetSelectionDataOutput.selectedTags: [SelectionDataItem<Tag.Id>]` (`docs/plans/2026-08-08-selection-data-api.md`)
- `SharedReaderKey.tags(_ server:)` — the same per-server cache key `DocumentFilterReducer` already reads tags from
- `DocumentListBottomToolbar.swift` renders `Label(.editTags, systemImage: "tag")` with an empty action, waiting to be wired

The reference implementation is `../paperless-ios`'s `PaperlessKit/Sources/PaperlessKit/BulkEdit/Tags/` — `BulkEditTagsModel` + `BulkEditTagsView`.

## Placement and naming

A sibling of `GenericValue/`, not a generalisation of it. Tags carry a *set* of pending changes rather than a single `Operation?`; folding both into one reducer would make the generic one worse for the three types that fit it today.

```
Modules/DocumentsFeature/DocumentBulkEdit/
  DocumentBulkEditConfirmationPresenter.swift    (extended)
  GenericValue/                                  (untouched)
  Tags/
    DocumentBulkEditTagsConfirmationView.swift
    DocumentBulkEditTagsReducer.swift
    DocumentBulkEditTagsReducer+Effect.swift
    DocumentBulkEditTagsReducer+TestValue.swift
    DocumentBulkEditTagsView.swift
```

## `DocumentBulkEditTagsReducer`

Not generic — it only ever operates on `Tag`.

### State

```swift
@Reducer
public struct DocumentBulkEditTagsReducer: Sendable {

    public enum Operation: Equatable, Sendable {
        case add
        case remove
    }

    @ObservableState
    public struct State: Equatable {

        var addTags: [Tag.Id] {
            operations.filter { $0.value == .add }.keys.sorted()
        }

        var documentCounts: [Tag.Id: Int] = [:]

        let documents: Set<Document.Id>

        var filteredValues: IdentifiedArrayOf<Tag> {
            if searchText.isEmpty {
                values
            } else {
                values.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
            }
        }

        var isEdited: Bool {
            !operations.isEmpty
        }

        var isLoading = false

        var isSaving = false

        var operations: [Tag.Id: Operation] = [:]

        var removeTags: [Tag.Id] {
            operations.filter { $0.value == .remove }.keys.sorted()
        }

        var searchText = ""

        let server: Server

        let values: IdentifiedArrayOf<Tag>
    }
}
```

Everything except `operations` / `documentCounts` mirrors `DocumentBulkEditGenericValueReducer.State` field for field.

The reference holds two parallel `Set<Int>`s and relies on `toggle` to hand-maintain the invariant that no tag appears in both. One dictionary keyed by `Tag.Id` makes that invariant structural instead: a tag has at most one pending operation, by construction. `addTags` / `removeTags` derive from it for the request, `.sorted()` so `TestStore` assertions are deterministic.

`Tag: CustomStringConvertible` returns `name`, so `filteredValues` is character-for-character the generic reducer's and `DocumentFilterTagListReducer`'s.

### Row icon

```swift
func isAssignedToAll(_ value: Tag) -> Bool {
    !documents.isEmpty && documentCounts[value.id, default: 0] == documents.count
}

func isAssignedToAny(_ value: Tag) -> Bool {
    documentCounts[value.id, default: 0] > 0
}

func systemImage(for value: Tag) -> String {
    switch operations[value.id] {
    case .add:
        return "checkmark.circle.fill"
    case .remove:
        return "circle"
    case nil:
        if isAssignedToAll(value) { return "checkmark.circle.fill" }
        if isAssignedToAny(value) { return "minus.circle" }
        return "circle"
    }
}
```

Filled icons match `DocumentBulkEditGenericValueView`, not the reference's unfilled `checkmark.circle`.

The `!documents.isEmpty` guard is deliberate: without it every zero-count tag would satisfy `0 == 0` and render as "all selected documents have this". The toolbar disables the button on an empty selection so this is unreachable in practice, but the guard keeps `State` honest in isolation and in tests. `DocumentBulkEditGenericValueReducer.systemImage(for:)` has the same latent hole; fixing it there is out of scope for this change.

### Tap logic

Ported from `BulkEditTagsModel.toggle(tag:)`, rewritten against `operations`:

```swift
case let .valueTapped(value):
    let all = state.isAssignedToAll(value)
    let any = state.isAssignedToAny(value)
    switch state.operations[value.id] {
    case .remove where all:
        state.operations[value.id] = nil
    case nil where all:
        state.operations[value.id] = .remove
    case nil:
        state.operations[value.id] = .add
    case .add where any:
        state.operations[value.id] = .remove
    default:
        state.operations[value.id] = nil
    }
    return .none
```

Which yields three distinct cycles depending on how the tag currently sits across the selection:

| Starting point | Tap cycle |
| --- | --- |
| no selected document has it | `circle` → `.add` → `circle` |
| some selected documents have it | `minus.circle` → `.add` → `.remove` → `minus.circle` |
| every selected document has it | `checkmark.circle.fill` → `.remove` → `checkmark.circle.fill` |

A partially-applied tag is the only one with three meaningful states, and it is the only one that gets a three-step cycle: add to all, remove from all, or leave alone. For an all-or-nothing tag the middle state is unreachable and the cycle is two steps.

### Actions

```swift
public enum Action: BindableAction, ViewAction {
    case applyConfirmed
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case error(Error)
    case selectionDataLoaded(GetSelectionDataOutput)
    case view(View)

    @CasePathable
    public enum Delegate {
        case documentsUpdated
    }

    public enum View {
        case applyButtonTapped
        case closeButtonTapped
        case onAppear
        case resetButtonTapped
        case valueTapped(Tag)
    }
}
```

Identical in shape to the generic reducer's, and handled the same way:

- `.view(.onAppear)` → `isLoading = true`, `.runGetSelectionData`
- `.selectionDataLoaded(output)` → `documentCounts = Dictionary(uniqueKeysWithValues: output.selectedTags.map { ($0.id, $0.documentCount) })`, `isLoading = false`
- `.view(.resetButtonTapped)` → `operations = [:]`
- `.view(.applyButtonTapped)` → `.runConfirmApply` when `isEdited`, otherwise `.none` (no state change; the popup may be cancelled)
- `.applyConfirmed` → `isSaving = true`, `.runBulkEdit`
- `.error(error)` → `isLoading = false`, `isSaving = false`, `.toast(error)`

## Confirmation popup

The generic flow's `DocumentBulkEditConfirmationPresenter` takes a `LocalizedStringResource` and hands it to `ConfirmationPopupView(title:message:cancel:confirm:)`. Tags need a body, not a sentence — "Add 2 tags: [invoice] [2026] / Remove 1 tag: [draft]" — so the presenter gains a second closure rather than trying to pass a `View` through a `Sendable` dependency:

```swift
@DependencyClient
struct DocumentBulkEditConfirmationPresenter: Sendable {

    /// Presents the confirmation popup and suspends until the user confirms or cancels
    var present: @Sendable (_ message: LocalizedStringResource) async -> Bool = { _ in false }

    /// Presents the tag confirmation popup and suspends until the user confirms or cancels
    var presentTags: @Sendable (
        _ documentCount: Int,
        _ addTags: [Tag],
        _ removeTags: [Tag]
    ) async -> Bool = { _, _, _ in false }
}
```

Plain data in, `Bool` out — so it stays `Sendable`, and `TestStore` can assert on the arguments. The live value builds the popup with `ConfirmationPopupView`'s existing content-taking initializer:

```swift
static func presentTags(
    documentCount: Int,
    addTags: [Tag],
    removeTags: [Tag]
) async -> Bool {
    @Dependency(\.popupPresenter)
    var popupPresenter

    return await popupPresenter.present { resolve in
        ConfirmationPopupView(
            title: .confirmAssignment,
            cancel: { resolve(false) },
            confirm: { resolve(true) }
        ) {
            DocumentBulkEditTagsConfirmationView(
                addTags: addTags,
                documentCount: documentCount,
                removeTags: removeTags
            )
        }
    } ?? false
}
```

The reducer resolves ids to `Tag` values from `state.values` before calling it, sorted by name:

```swift
let addTags = state.addTags.compactMap { state.values[id: $0] }.sorted { $0.name < $1.name }
```

### `DocumentBulkEditTagsConfirmationView`

```swift
VStack(alignment: .leading, spacing: .x6) {
    Text(.tagBulkEditConfirmation(documentCount))

    if !addTags.isEmpty {
        section(title: .tagBulkEditConfirmationAdd(addTags.count), tags: addTags)
    }

    if !removeTags.isEmpty {
        section(title: .tagBulkEditConfirmationRemove(removeTags.count), tags: removeTags)
    }
}
```

Each section is a title plus a horizontally-scrolling `HStack` of capsules, rendered exactly as `DocumentFilterTagListView` renders tag rows:

```swift
Text(tag.name)
    .capsule(
        backgroundColor: Color(hex: tag.color),
        font: .body,
        foregroundColor: Color(hex: tag.textColor)
    )
```

`.scrollIndicators(.hidden)` on the `ScrollView`, as the reference does. It takes plain `[Tag]` arrays and an `Int` — no store, no bindings — so it snapshot-tests directly.

## Effects

`DocumentBulkEditTagsReducer+Effect.swift`, with `Action` bound concretely (no generic gymnastics needed here, unlike the generic reducer's effects):

```swift
extension Effect where Action == DocumentBulkEditTagsReducer.Action {

    static func runBulkEdit(
        addTags: [Tag.Id],
        documents: Set<Document.Id>,
        removeTags: [Tag.Id],
        server: Server
    ) -> Self { … }

    static func runConfirmApply(
        addTags: [Tag],
        documentCount: Int,
        removeTags: [Tag]
    ) -> Self { … }

    static func runGetSelectionData(
        documents: Set<Document.Id>,
        server: Server
    ) -> Self { … }
}
```

Bodies follow `DocumentBulkEditGenericValueReducer+Effect.swift` one for one: `@Dependency` lookups at the top, `.run { } catch: { }` sending `.error`, each `.cancellable(id:)` on a private `CancelID` case. `runBulkEdit` builds

```swift
BulkEditDocumentsInput(
    documents: Array(documents),
    method: .modifyTags(.init(addTags: addTags, removeTags: removeTags))
)
```

then sends `.delegate(.documentsUpdated)`.

## `DocumentBulkEditTagsView`

`Sheet` + `SheetHeader` + list + Reset/Apply, structurally the same as `DocumentBulkEditGenericValueView` with two changes:

- the row's label is a capsule (`Text(value.name).capsule(backgroundColor:font:foregroundColor:)`) instead of plain `Text(value.description)`
- the header title is `.editTags`

Otherwise unchanged: `Searchable { List(store.filteredValues) { … } }` with `.searchable(text: $store.searchText)`, icon / label / `Spacer` / `Text(String(store.documentCounts[value.id] ?? 0))` per row, `ProgressView` overlay while `isLoading`, `ContentUnavailableView` with `EmptyListView(systemImage: "tray")` when `filteredValues` is empty, `AdaptiveStack` with Reset `.secondary()` and Apply `.primary(isLoading: $store.isSaving)` both `.disabled(!store.isEdited)`, `.presentationDetents([.sheet])`, and `.task { await store.send(.view(.onAppear)).finish() }`.

The reference has neither a search field nor a per-tag count in the sheet; both come from the sibling bulk edit sheet, which is the closer precedent.

## Post-save behaviour

`.delegate(.documentsUpdated)` → `DocumentListReducer` clears the destination and refetches with the current filter, the same handler the other three bulk edits already share.

The reference instead posts a `.documentDidUpdate` notification per document with a `DocumentUpdater` closure that replays the add/remove locally. That has no analogue here and is not needed — this app refetches, which is both simpler and correct when the server applies matching rules on top of the edit.

## Wiring into `DocumentListReducer`

`State` gains a fourth `@Shared` collection alongside the three it already declares:

```swift
self._tags = Shared(wrappedValue: [], .tags(server))
```

`Destination` gains a case:

```swift
case bulkEditTags(DocumentBulkEditTagsReducer)
```

`Action.View` gains `editTagsButtonTapped`:

```swift
case .editTagsButtonTapped:
    state.destination = .bulkEditTags(DocumentBulkEditTagsReducer.State(
        documents: state.documentSelection.selectedDocuments,
        server: state.server,
        values: state.tags
    ))
    return .none
```

and the existing three-way delegate pattern match becomes four-way:

```swift
case .destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated)))),
     .destination(.presented(.bulkEditDocumentType(.delegate(.documentsUpdated)))),
     .destination(.presented(.bulkEditStoragePath(.delegate(.documentsUpdated)))),
     .destination(.presented(.bulkEditTags(.delegate(.documentsUpdated)))):
```

`DocumentListBottomToolbar` fills in the empty tag `Button`'s action with `send(.editTagsButtonTapped)` and attaches a fourth `.sheet(item: $store.scope(state: \.destination?.bulkEditTags, action: \.destination.bulkEditTags))`. The existing `.disabled(store.documentSelection.selectedDocuments.isEmpty)` on the enclosing `HStack` already covers the new button.

## Localization

`Shared/Framework/Resources/Localizable.xcstrings`, `extractionState: "manual"`, en + de. Reused as-is: `apply`, `reset`, `cancel`, `close`, `confirm`, `confirmAssignment`, `editTags`.

Three new plural-varied strings, ported from the old catalog's `Global.bulkEditConfirmation`, `Type.Tag.bulkEditConfirmationAdd` and `Type.Tag.bulkEditConfirmationRemove`, renamed to this codebase's flat camelCase and with `%d` respelled as `%ld` to match the existing bulk edit strings:

| key | en `one` | en `other` |
| --- | --- | --- |
| `tagBulkEditConfirmation` | This operation will modify the selected document. | This operation will modify the selected %ld documents. |
| `tagBulkEditConfirmationAdd` | Following tag will be added: | Following %ld tags will be added: |
| `tagBulkEditConfirmationRemove` | Following tag will be removed: | Following %ld tags will be removed: |

| key | de `one` | de `other` |
| --- | --- | --- |
| `tagBulkEditConfirmation` | Diese Aktion wird das ausgewählte Dokument verändern. | Diese Aktion wird die ausgewählten %ld Dokumente verändern. |
| `tagBulkEditConfirmationAdd` | Folgender Tag wird hinzugefügt: | Folgende %ld Tags werden hinzugefügt: |
| `tagBulkEditConfirmationRemove` | Folgender Tag wird entfernt: | Folgende %ld Tags werden entfernt: |

## Tests

Written test-first, mirroring what `DocumentBulkEdit/GenericValue/` already has.

- **`DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift`**
  - `onAppear` → `getSelectionData` called with the selected ids → `documentCounts` populated, `isLoading` cleared
  - each of the three tap cycles above, driven end to end so the wrap-around is asserted, not just the first step
  - a tag tapped twice in a partial selection leaves exactly one entry in `operations` — the invariant the dictionary exists to protect
  - `resetButtonTapped` clears `operations`
  - `applyButtonTapped` while unedited does nothing
  - `applyButtonTapped` → `presentTags` receives the resolved `Tag` values sorted by name, plus `documents.count`
  - confirmed → `bulkEditDocuments` receives `.modifyTags` with sorted `addTags` / `removeTags` → `.delegate(.documentsUpdated)`
  - cancelled → no request
  - error paths for both `getSelectionData` and `bulkEditDocuments` clearing their flag and toasting
- **`DocumentBulkEditTagsViewTests.swift`** — snapshot, `.tags(.snapshotTests)`: unedited with mixed counts, pending add + remove, loading, empty search result
- **`DocumentBulkEditTagsConfirmationViewTests.swift`** — snapshot: add only, remove only, both
- **`DocumentListReducerTests`** — `editTagsButtonTapped` builds the destination from `state.tags` and the current selection; the delegate dismisses and refetches

`DocumentBulkEditTagsReducer+TestValue.swift` provides `State.testValue(…)` with the same defaulted-parameter shape as `DocumentBulkEditGenericValueReducer+TestValue.swift`.

## Out of scope

- **Title bulk edit.** The reference's `BulkEdit/Title/` (placeholder-based renaming with a preview sheet) still has no API-layer support here.
- **Delete.** `Method.delete` exists in the API layer but has no entry point in the toolbar.
- **The `documents.isEmpty` hole in `DocumentBulkEditGenericValueReducer.systemImage(for:)`.** Noted above; a separate change.
