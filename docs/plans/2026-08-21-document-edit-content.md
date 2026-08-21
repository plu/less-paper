# Edit document content

## Context

`DocumentFormView` is the edit sheet for a document. It shows title, ASN, created date,
correspondent, document type, storage path and tags — a flat list of fields with Reset and Save in
the bottom bar. There is no way to edit the document's OCR text.

The old app had this feature. It is not in `main` there either; it lives on the abandoned
`custom_fields` branch, commit `c8b8996a` ("Edit document content"), and worked like this:

- `DocumentEditSection` — `case content, details, permissions`, chosen from an ellipsis menu in the
  sheet header.
- `DocumentEditContentView` — a `UIViewRepresentable` around `UITextView` with
  `isScrollEnabled = false`, so it grew inside the sheet's scroll view.
- `DocumentDetailModel` gained `@Published var content`, seeded from `document.content ?? ""`, with
  `isEdited` comparing `content != document.content`.
- `Document.Patch` gained `content: UpdateOperation<String>?`, sent only when changed:
  `content != document.content ? .replace(content) : nil`.

### The list does not carry full content

Paperless truncates `content` when a list request passes `truncate_content`. The old app sent it on
every list call (`FilterProtocol.swift:21`, `DocumentsService+List.swift:29`,
`DocumentsService+GetNextAsn.swift:17`) and recovered the full text from a single-document GET:

```swift
func load() async {
    document = try await appModel.service.documents.get(id: document.id)
    ...
}
```

`get(id:)` hits `/api/documents/{id}/` with no `truncate_content`. `document` had
`didSet { resetValues() }`, so the arriving full document re-seeded every form field.

This codebase is in the same position — all three list requests send `truncate_content: "true"`
(`DocumentsRepository.swift:246`, `:259`, `:274`) — but with one difference that matters.

### Two entry points, not one

The old app reached the edit sheet only from the detail screen, which had already re-fetched the
full document. Here `DocumentFormReducer` is presented from two places:

- `DocumentDetailReducer.swift:74`
- `DocumentRowReducer.swift:140` — straight from the list row

The row hands the form a `Shared<Document>` whose `content` is truncated. Adding a content field
without a fetch would let a user open the sheet from the list and save a truncated stump over the
document's full text. **The fetch is not an optimisation; it is what makes the feature safe.**

## Goal

Add a Content section to the edit sheet, backed by a fetch of the complete document, with a
guarantee that partial content can never be written back.

## Design

### Fetching the full document

A new `GetDocumentUseCase` in `ApiInterface/Documents/`, following the shape of every other use
case, with the live implementation delegating to a new repository method:

```swift
static func getDocument(
    id: Document.Id,
    server: Server
) async throws -> Document {
    try await APIClient
        .client(server: server)
        .send(.init(path: "/api/documents/\(id)/", method: .get))
        .value
}
```

No `truncate_content`, so content comes back whole.

The old `get(id:)` also sent `full_perms=true`. That is left out here: `Document` has no
`permissions` field to decode into, so the parameter would do nothing. It becomes a one-line
addition when a Permissions section arrives.

**The fetch is eager, on the form's `onAppear`**, rather than lazy when the Content section is
opened. A Permissions section is the likely next addition, and document permissions are *only*
available from this same endpoint — `Document` carries `owner` but no `permissions`, and
`PermissionsFeature/PermissionsForm` is already wired into the correspondent, document type, tag
and storage path forms but not documents. Two sections depending on one request makes per-section
lazy loading the wrong shape.

### `UpdateDocumentInput` gains content

```swift
public let content: String?
```

A plain optional, deliberately **not** `@NullEncodable`. The other optional fields use that wrapper
because sending an explicit `null` is how they clear a correspondent or a storage path. Content is
the opposite case: a `null` would blank the document. A plain optional gets the synthesised
`encodeIfPresent`, so nil omits the key entirely and the server leaves content alone.

That is the structural guarantee. If the form does not hold the full content, the key cannot reach
the server, regardless of what the UI does.

### Content lives beside the input, not inside it

```swift
var content: String?

var isModified: Bool {
    input != DocumentFormInput(document: document, server: server) || isContentModified
}

var isContentModified: Bool {
    guard let content else { return false }
    return content != document.content
}
```

`isModified` compares `input` against a `DocumentFormInput` derived fresh from the document. Putting
content inside `DocumentFormInput` would force a choice between two broken outcomes: seed it from
the truncated document and a save sends the stump, or leave it nil and the sheet reads as modified
the moment it opens.

Keeping it alongside lets `nil` carry one precise meaning — *the content is not known, so it is
never sent* — and `isContentModified` reproduces the old `content != document.content` rule.

### Flow

`.onAppear` runs the fetch.

On success the full document replaces the shared one and content is seeded from it:

```swift
state.$document.withLock { $0 = document }
state.content = document.content
```

**Only `content` is re-seeded — not `input`.** The user can be typing in Details while the request
is in flight. The old app's `document.didSet { resetValues() }` clobbered every field, which was
only safe because its sheet was not open during the load. This one is.

Replacing the shared document does not shift the `isModified` baseline for the other fields: the
truncated and full payloads differ only in `content`. It does mean the list row and detail screen
end up holding the complete record, which is a small bonus rather than a problem.

On failure the error goes to `state.loadError` and to the usual toast.

`resetButtonTapped` additionally restores `state.content` from the document, guarded on the content
having loaded — an unloaded reset must leave `nil` in place rather than adopt the truncated string.

`saveButtonTapped` passes `state.isContentModified ? state.content : nil`.

### Sections and the view

A new `DocumentFormSection` enum — `case content, details` — shaped like the existing
`ServerFormSection`.

The switcher is a `Picker` inside a `Menu` in `SheetHeader`'s `right:` slot, following
`DocumentFilterView`'s `optionsMenu()`. The old app drew custom radio circles; `Picker`-in-`Menu`
renders standard system checkmarks instead, which is native and matches the rest of this codebase.

The content section takes over the whole sheet:

```swift
Sheet(isScrollingEnabled: store.section != .content) { … }
```

`Sheet` already supports this. Dropping the outer `ScrollView` lets a `TextEditor` fill the space
and scroll itself, which is what OCR text running to thousands of characters needs. It also avoids
nesting a scroll view inside a scroll view. This is where the design departs from the old
`UITextView` with `isScrollEnabled = false`: that grew inside the outer scroll view, which is
workable for short text and increasingly bad for long text.

While `content` is nil the section shows a `ProgressView`. On `loadError` it shows `EmptyListView`
with a retry button, matching `DocumentDetailView.errorView`.

Reset and Save stay in the bottom bar for both sections.

Two new strings: `content`, `details`.

## Out of scope

- A Permissions section. The fetch is shaped to support it; the section itself is separate work.
- Notes and metadata, the other two sections commented out in the old enum.
- `full_perms=true` on the new endpoint, until there is a `permissions` field to decode.
- Changing what the list requests. `truncate_content` on list calls is correct and stays.

## Testing

- **`DocumentFormReducerTests`**
  - `onAppear` fetches, replaces the shared document and seeds content.
  - A failing fetch sets `loadError` and toasts.
  - Editing content flips `isModified`; editing it back clears it.
  - Save after a content edit sends the new content.
  - **Save before the fetch lands sends no content key at all.** This is the data-loss guard and the
    most important test in the set.
  - Reset before the fetch lands leaves content nil.
- **`DocumentsRepositoryTests`** — the new endpoint, asserting the query carries no
  `truncate_content`.
- **`DocumentFormViewTests`** — new snapshots for the content section in its loading, loaded and
  error states. The existing Details snapshots re-record because the header gains the ellipsis.

## Files

New:

- `Modules/ApiInterface/Documents/GetDocumentUseCase.swift`
- `Modules/ApiImplementation/Documents/GetDocumentUseCase.swift`
- `Modules/DocumentsFeature/DocumentForm/DocumentFormSection.swift`

Changed:

- `Modules/ApiInterface/Documents/UpdateDocumentInput.swift` — `content`
- `Modules/ApiImplementation/Documents/DocumentsRepository.swift` — `getDocument`
- `Modules/DocumentsFeature/DocumentForm/DocumentFormInput.swift` — `apiValue(content:)`
- `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift` — content, section, load state
- `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer+Effect.swift` — `runGetDocument`
- `Modules/DocumentsFeature/DocumentForm/DocumentFormView.swift` — section menu, content section
- `Shared/Framework/Resources/Localizable.xcstrings` — `content`, `details`
- `Modules/DocumentsFeatureTests/DocumentForm/` — reducer and view tests
- `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`
- `Snapshots/DocumentsFeatureTests/DocumentFormViewTests/` — re-recorded
