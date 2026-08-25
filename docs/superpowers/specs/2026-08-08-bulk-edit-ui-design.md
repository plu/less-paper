# Bulk edit UI — correspondent, document type, storage path

## Context

The API layer is done: `BulkEditDocumentsInput.Method.setCorrespondent/.setDocumentType/.setStoragePath` (`docs/superpowers/specs/2026-08-08-bulk-edit-api-design.md`) and `GetSelectionDataOutput` with `SelectionDataItem<Tagged Id>` (`docs/superpowers/specs/2026-08-08-selection-data-api-design.md`). `DocumentListBottomToolbar` already renders four buttons — edit correspondent, document type, storage path, tags — with empty actions. This phase gives the first three of them a UI. Tags are out of scope (see below).

The reference implementation is `../paperless-ios`'s `PaperlessKit/Sources/PaperlessKit/BulkEdit/Generic/`: a sheet listing every correspondent (or document type / storage path), each row showing a tri-state icon derived from `selection_data` counts plus the count itself, with Reset/Apply at the bottom and a confirmation popup before the request fires.

This app already generalises that exact sheet shape over exactly these three types — `DocumentFilterGenericValueListReducer<Value>`, presented as three `Destination` cases from `DocumentFilterReducer`. Bulk edit follows that precedent, with one addition: it needs per-type behaviour (which `selection_data` array to read, which bulk-edit method to build, which strings to show), so it adds a small local protocol on top of the plain constraints the filter reducer gets away with.

## Placement and naming

New directory `Modules/DocumentsFeature/DocumentBulkEdit/`, mirroring `DocumentsFeature/DocumentFilter/` and its `Document<Area>GenericValue…` prefixing:

```
DocumentBulkEdit/
  DocumentBulkEditConfirmationView.swift
  GenericValue/
    DocumentBulkEditGenericValue.swift
    DocumentBulkEditGenericValue+Correspondent.swift
    DocumentBulkEditGenericValue+DocumentType.swift
    DocumentBulkEditGenericValue+StoragePath.swift
    DocumentBulkEditGenericValueReducer.swift
    DocumentBulkEditGenericValueReducer+Effect.swift
    DocumentBulkEditGenericValueReducer+TestValue.swift
    DocumentBulkEditGenericValueView.swift
```

## `DocumentBulkEditGenericValue`

Five members — the complete set of per-type variance:

```swift
protocol DocumentBulkEditGenericValue:
    CustomStringConvertible, Hashable, Identifiable, Sendable where ID: Sendable {

    static var editTitle: LocalizedStringResource { get }

    static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource
    static func confirmationRemove(documentCount: Int) -> LocalizedStringResource
    static func documentCounts(selectionData: GetSelectionDataOutput) -> [ID: Int]
    static func method(id: ID?) -> BulkEditDocumentsInput.Method
}
```

`ID` stays `Tagged<Correspondent, Int>` / `Tagged<DocumentType, Int>` / `Tagged<StoragePath, Int>` throughout — no raw `Int` anywhere, per the convention `SelectionDataItem` established. The `where ID: Sendable` refinement is what lets the reducer's `State` and effects stay `Sendable`.

Conformances are ~15 lines each. `Correspondent`:

```swift
extension Correspondent: DocumentBulkEditGenericValue {

    static var editTitle: LocalizedStringResource { .editCorrespondent }

    static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource {
        .correspondentBulkEditConfirmationAssign(name, documentCount)
    }

    static func confirmationRemove(documentCount: Int) -> LocalizedStringResource {
        .correspondentBulkEditConfirmationRemove(documentCount)
    }

    static func documentCounts(selectionData: GetSelectionDataOutput) -> [Id: Int] {
        Dictionary(
            uniqueKeysWithValues: selectionData.selectedCorrespondents.map { ($0.id, $0.documentCount) }
        )
    }

    static func method(id: Id?) -> BulkEditDocumentsInput.Method {
        .setCorrespondent(.init(correspondent: id))
    }
}
```

`DocumentType` and `StoragePath` are identical modulo `selectedDocumentTypes`/`selectedStoragePaths`, `.setDocumentType`/`.setStoragePath`, and their own strings.

One deviation from the filter precedent: `DocumentFilterGenericValueListView` takes `title` as an init parameter, whereas here `editTitle` lives on the protocol next to the two confirmation strings, so all of a type's localization sits in one file.

## `DocumentBulkEditGenericValueReducer<Value>`

### State

```swift
@ObservableState
public struct State: Equatable {

    var documentCounts: [Value.ID: Int] = [:]

    let documents: Set<Document.Id>

    var filteredValues: IdentifiedArrayOf<Value> {
        if searchText.isEmpty {
            values
        } else {
            values.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var isEdited: Bool { operation != nil }

    var isLoading = false

    var isSaving = false

    var operation: Operation?

    var searchText = ""

    let server: Server

    let values: IdentifiedArrayOf<Value>
}

```

`Operation` is nested in the reducer, not in `State` — it references `Value.ID`, so it needs the reducer's generic parameter in scope:

```swift
@Reducer
public struct DocumentBulkEditGenericValueReducer<Value: DocumentBulkEditGenericValue>: Sendable {

    public enum Operation: Equatable {
        case assign(Value.ID)
        case remove
    }
    …
}
```

`documents` is the selection handed down from `DocumentListReducer`; `values` comes from the parent's `@Shared` collection, exactly as `DocumentFilterReducer` passes `state.correspondents` into the filter list. `operation == nil` means unedited.

### Row icon

```swift
func systemImage(for value: Value) -> String {
    switch operation {
    case let .assign(id):
        return id == value.id ? "checkmark.circle.fill" : "circle"
    case .remove:
        return "circle"
    case nil:
        let count = documentCounts[value.id] ?? 0
        if count == documents.count { return "checkmark.circle.fill" }
        if count > 0 { return "minus.circle" }
        return "circle"
    }
}
```

Unedited, the icon reflects the current server state across the selection: all selected documents have this value, some do, or none do. Once an operation is chosen it reflects the pending change instead. The trailing count text (`documentCounts[value.id] ?? 0`) renders only while `documentCounts` is populated.

The old app used the unfilled `checkmark.circle`; this uses `.fill` to match `DocumentFilterGenericValueListView`.

### Tap logic

Ported from `BulkEditGenericModel.toggle(value:)`:

```swift
case let .valueTapped(value):
    let count = state.documentCounts[value.id] ?? 0
    if state.operation == nil, count == state.documents.count {
        state.operation = .remove
    } else if case let .assign(id) = state.operation, id == value.id {
        state.operation = .remove
    } else {
        state.operation = .assign(value.id)
    }
    return .none
```

Tapping a value every selected document already has means "unassign it". Tapping the already-chosen value flips to remove. Everything else assigns.

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
        case valueTapped(Value)
    }
}
```

`applyConfirmed` is not a `View` case — it originates in the popup presented by an effect, not in the sheet's own view tree. `Action` is not `Equatable` (it carries `Error`), matching `DocumentFilterReducer`.

- `.view(.onAppear)` → `isLoading = true`, `.runGetSelectionData`
- `.selectionDataLoaded(output)` → `documentCounts = Value.documentCounts(selectionData: output)`, `isLoading = false`
- `.view(.resetButtonTapped)` → `operation = nil`
- `.view(.applyButtonTapped)` → `.runConfirmApply` (no state change; the popup may be cancelled)
- `.applyConfirmed` → `isSaving = true`, `.runBulkEdit`
- `.error(error)` → `isLoading = false`, `isSaving = false`, `.toast(error)`. Both flags are cleared unconditionally rather than per-source: only one can be in flight at a time, and it keeps the handler a single case regardless of which effect failed.

## Effects

`DocumentBulkEditGenericValueReducer+Effect.swift`. Because `Value` is unbound at extension scope, these are generic statics constrained per method rather than the usual `extension Effect where Action == …Action`:

```swift
extension Effect {

    static func runGetSelectionData<Value: DocumentBulkEditGenericValue>(
        documents: Set<Document.Id>,
        server: Server
    ) -> Self where Action == DocumentBulkEditGenericValueReducer<Value>.Action {
        @Dependency(\.getSelectionData.execute)
        var getSelectionData

        let input = GetSelectionDataInput(documents: Array(documents))

        return .run { send in
            await send(.selectionDataLoaded(try await getSelectionData(input, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.getSelectionData)
    }
}
```

`runConfirmApply` presents the confirmation through `@Dependency(\.popupPresenter)`, the pattern `CertificateApprovalReducer` established. The confirm closure captures `send` directly — no channel is needed, since unlike the certificate flow this originates inside the store:

```swift
return .run { send in
    @Dependency(\.popupPresenter)
    var popupPresenter

    await popupPresenter.present {
        DocumentBulkEditConfirmationView(
            message: message,
            cancel: { Task { await popupPresenter.dismiss() } },
            confirm: {
                Task {
                    await popupPresenter.dismiss()
                    await send(.applyConfirmed)
                }
            }
        )
    }
}
```

`message` is built in the reducer from the operation: `.assign(id)` looks the name up in `state.values[id: id]` and calls `Value.confirmationAssign(name:documentCount:)`; `.remove` calls `Value.confirmationRemove(documentCount:)`. Both take `state.documents.count`.

`runBulkEdit` calls `bulkEditDocuments(.init(documents: Array(documents), method: Value.method(id: id)), server)` — where `id` is the assigned id or `nil` for remove — then sends `.delegate(.documentsUpdated)`. On failure it clears `isSaving` and sends `.error`.

## `DocumentBulkEditGenericValueView<Value>`

`Sheet` with `SheetHeader`, list, and Reset/Apply, following `DocumentFilterGenericValueListView` for the header/list/`Searchable` structure and `DocumentFilterView` for the button row:

- header: `SheetHeader(title: Value.editTitle, left: closeButton)` — an `xmark` sending `.view(.closeButtonTapped)`, which dismisses via `@Dependency(\.dismiss)`
- content: `Searchable { List(store.filteredValues) { … } }` with `.searchable(text: $store.searchText)`, each row a `Button` sending `.view(.valueTapped(value))` and laying out icon / `value.description` / `Spacer` / count
- `ProgressView` overlay while `isLoading`; `ContentUnavailableView` with `EmptyListView(systemImage: "tray")` when `filteredValues` is empty, as the filter list does
- bottom: `AdaptiveStack` with Reset `.secondary()` and Apply `.primary(isLoading: $store.isSaving)`, both `.disabled(!store.isEdited)`
- presented with `.presentationDetents([.sheet])`

The search field is the one addition beyond the old app, which had none. The sheet lists every correspondent, the `Searchable` component and `filteredValues` pattern already exist, and the filter list already does this.

## `DocumentBulkEditConfirmationView`

Modelled on `CertificateApprovalView` — the one existing consumer of `PopupPresenter`:

```swift
Sheet {
    Text(.confirmAssignment)
} content: {
    Text(message)
        .font(.body)
        .foregroundStyle(Color.m3OnSurface)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
} bottom: {
    AdaptiveStack {
        Button { cancel() } label: { Text(.cancel).frame(maxWidth: .infinity) }
            .buttonStyle(.secondary())
        Button { confirm() } label: { Text(.confirm).frame(maxWidth: .infinity) }
            .buttonStyle(.primary())
    }
}
.background(Color.m3Surface)
.clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
.padding(.x4)
.frame(maxWidth: 600)
```

It takes `message: LocalizedStringResource` plus `cancel`/`confirm` closures, and gets a `testValue()` static like `CertificateApprovalView` has.

## Localization

`Shared/Framework/Resources/Localizable.xcstrings`, `extractionState: "manual"`, en + de. Reused as-is: `apply`, `reset`, `cancel`, `close`, `editCorrespondent`, `editDocumentType`, `editStoragePath`.

Two new plain strings:

| key | en | de |
| --- | --- | --- |
| `confirm` | Confirm | Bestätigen |
| `confirmAssignment` | Confirm assignment | Zuweisung bestätigen |

Six new plural-varied strings, ported verbatim from the old catalog's `Type.<T>.bulkEditConfirmationReplace/Remove` (renamed to this codebase's flat camelCase):

| key | en `one` | en `other` |
| --- | --- | --- |
| `correspondentBulkEditConfirmationAssign` | This operation will assign the correspondent "%1$@" to the selected document. | This operation will assign the correspondent "%1$@" to %2$ld selected documents. |
| `correspondentBulkEditConfirmationRemove` | This operation will remove the correspondent from the selected document. | This operation will remove the correspondent from %ld selected documents. |
| `documentTypeBulkEditConfirmationAssign` | This operation will assign the document type "%1$@" to the selected document. | This operation will assign the document type "%1$@" to %2$ld selected documents. |
| `documentTypeBulkEditConfirmationRemove` | This operation will remove the document type from the selected document. | This operation will remove the document type from %ld selected documents. |
| `storagePathBulkEditConfirmationAssign` | This operation will assign the storage path "%1$@" to the selected document. | This operation will assign the storage path "%1$@" to %2$ld selected documents. |
| `storagePathBulkEditConfirmationRemove` | This operation will remove the storage path from the selected document. | This operation will remove the storage path from %ld selected documents. |

German, likewise verbatim:

| key | de `one` | de `other` |
| --- | --- | --- |
| `correspondentBulkEditConfirmationAssign` | Diese Aktion wird dem ausgewählten Dokument den Korrespondenten „%1$@“ zuweisen. | Diese Aktion wird %2$ld ausgewählten Dokumenten den Korrespondenten „%1$@“ zuweisen. |
| `correspondentBulkEditConfirmationRemove` | Diese Aktion wird bei dem ausgewählten Dokument den Korrespondent entfernen. | Diese Aktion wird bei %ld ausgewählten Dokumenten den Korrespondent entfernen. |
| `documentTypeBulkEditConfirmationAssign` | Diese Aktion wird dem ausgewählten Dokument den Dokumenttyp „%1$@“ zuweisen. | Diese Aktion wird %2$ld ausgewählten Dokumenten den Dokumenttyp „%1$@“ zuweisen. |
| `documentTypeBulkEditConfirmationRemove` | Diese Aktion wird bei dem ausgewählten Dokument den Dokumenttyp entfernen. | Diese Aktion wird bei %ld ausgewählten Dokumenten den Dokumenttyp entfernen. |
| `storagePathBulkEditConfirmationAssign` | Diese Aktion wird dem ausgewählten Dokument den Speicherpfad „%1$@“ zuweisen. | Diese Aktion wird %2$ld ausgewählten Dokumenten den Speicherpfad „%1$@“ zuweisen. |
| `storagePathBulkEditConfirmationRemove` | Diese Aktion wird bei dem ausgewählten Dokument den Speicherpfad entfernen. | Diese Aktion wird bei %ld ausgewählten Dokumenten den Speicherpfad entfernen. |

## Wiring into `DocumentListReducer`

The destination lives on `DocumentListReducer`, not `DocumentSelectionReducer`, because the list owns both the reload effect and the toolbar's view actions. It reads the selection from `state.documentSelection.selectedDocuments`.

```swift
@Reducer
public enum Destination {
    case bulkEditCorrespondent(DocumentBulkEditGenericValueReducer<Correspondent>)
    case bulkEditDocumentType(DocumentBulkEditGenericValueReducer<DocumentType>)
    case bulkEditStoragePath(DocumentBulkEditGenericValueReducer<StoragePath>)
    case documentFilter(DocumentFilterReducer)
}
```

`State` gains three `@Shared` collections, declared exactly as `DocumentFilterReducer.State` already declares them:

```swift
self._correspondents = Shared(wrappedValue: [], .correspondents(server))
self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
```

`Action.View` gains `editCorrespondentButtonTapped`, `editDocumentTypeButtonTapped`, `editStoragePathButtonTapped`, each building the destination:

```swift
case .editCorrespondentButtonTapped:
    state.destination = .bulkEditCorrespondent(DocumentBulkEditGenericValueReducer.State(
        documents: state.documentSelection.selectedDocuments,
        server: state.server,
        values: state.correspondents
    ))
    return .none
```

All three delegates collapse to the same handler — dismiss, then refetch with the current filter, leaving selection mode and the selection intact so a second bulk edit can be chained:

```swift
case .destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated)))),
     .destination(.presented(.bulkEditDocumentType(.delegate(.documentsUpdated)))),
     .destination(.presented(.bulkEditStoragePath(.delegate(.documentsUpdated)))):
    state.destination = nil
    return .runGetDocuments(
        filterRules: state.filter.input.filterRules,
        server: state.server,
        sortDirection: state.filter.input.sort.direction,
        sortField: state.filter.input.sort.field
    )
```

`DocumentListBottomToolbar` wires its three buttons to those view actions, attaches the three `.sheet(item: $store.scope(state: \.destination?.bulkEditX, action: \.destination.bulkEditX))` modifiers, and disables all four buttons when `store.documentSelection.selectedDocuments.isEmpty`.

## Tests

Mirroring what `DocumentFilter/GenericValue` already has:

- **`DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducerTests.swift`** — instantiated on `Correspondent` only, as the filter reducer tests are: `onAppear` → selection data loaded into `documentCounts`; each of the four tap transitions (none → assign, all-have → remove, assign → different assign, assign same → remove); reset; `applyButtonTapped` presenting the popup (asserted via `$0.popupPresenter.present = { _ in … }`, as `CertificateApprovalReducerTests` does); `applyConfirmed` calling `bulkEditDocuments` with the expected `BulkEditDocumentsInput` and emitting `.delegate(.documentsUpdated)`; error paths clearing their loading flag and toasting.
- **`DocumentBulkEditGenericValueTests.swift`** — conformance coverage for all three types: `documentCounts(selectionData:)` picks the right array and `method(id:)` builds the right case, including the `nil` (remove) variant. Cheap, and it is the one place a copy-paste slip between the three extensions would hide.
- **`DocumentBulkEditGenericValueViewTests.swift`** — snapshot, `.tags(.snapshotTests)`, on `Correspondent`, one per state worth seeing: unedited with mixed counts, and an assign operation pending.
- **`DocumentBulkEditConfirmationViewTests.swift`** — snapshot, assign and remove messages.
- **`DocumentListReducerTests`** — the three new view actions building the right destination, and the delegate handler dismissing and refetching.

## Out of scope

- **Tags.** The `editTags` toolbar button stays a no-op. Tags need a different interaction — multi-select with independent add/remove sets (`Method.ModifyTags`), not one-of-N assignment — so they do not fit `DocumentBulkEditGenericValue` and get their own phase, as they had their own `BulkEditTagsView` in the old app.
- **Title bulk edit.** The old app's `BulkEdit/Title/` (placeholder-based renaming with a preview sheet) has no API-layer support here yet.
- **Delete.** `Method.delete` exists in the API layer but has no entry point in the toolbar.
