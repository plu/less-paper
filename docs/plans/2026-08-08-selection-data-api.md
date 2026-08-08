# Selection data — API layer

## Context

paperless-ngx exposes `POST /api/documents/selection_data/` — given a set of document ids, it returns, per correspondent/document-type/storage-path/tag, how many of those documents have it. Bulk-edit UI (a later, separate phase — this is API layer only, matching the pattern already established for `docs/plans/2026-08-08-bulk-edit-api.md`) uses this to render partial-selection state (e.g. "3 of 5 selected documents have tag X").

The reference implementation is `../paperless-ios`'s `PaperlessKit/Sources/PaperlessAPI/Models/Document+SelectionData.swift` and `.../Services/Documents/DocumentsService+SelectionData.swift`: `POST /api/documents/selection_data/` with body `{"documents": [Int]}`, returning `{selected_correspondents, selected_document_types, selected_storage_paths, selected_tags}`, each an array of `{id, document_count}`. The old app used one untyped `{id: Int, documentCount: Int}` struct for all four categories, with no dedicated test file for the service/model.

This app's convention departs from that in one deliberate way: `Tagged<Entity, Int>` id types throughout (never raw `Int`), and — per `ListOutput<Element, Id>` in `Modules/ApiInterface/Shared/ListOutput.swift`, the existing precedent for a shared generic type — a generic item type instead of 4 duplicated structs or one untyped one.

## New model: `SelectionDataItem<Id>`

New file `Modules/ApiInterface/Shared/SelectionDataItem.swift`, mirroring `ListOutput`'s generic-in-`Shared/` convention:

```swift
public struct SelectionDataItem<Id: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let documentCount: Int
    public let id: Id

    public init(documentCount: Int, id: Id) {
        self.documentCount = documentCount
        self.id = id
    }
}
```

`testValue()` on this generic type needs a concrete `Id` per use — provided per-instantiation in `GetSelectionDataOutput`'s own `testValue()` rather than on `SelectionDataItem` itself (a generic type can't supply a default literal for an unconstrained `Id`).

## `GetSelectionDataInput` / `GetSelectionDataOutput`

New files in `Modules/ApiInterface/Documents/`, following the `GetAllDocumentIdsInput`/`GetAllDocumentIdsOutput` naming and shape exactly:

```swift
public struct GetSelectionDataInput: Encodable, Equatable, Sendable {
    public let documents: [Document.Id]

    public init(documents: [Document.Id]) {
        self.documents = documents
    }
}
```

```swift
public struct GetSelectionDataOutput: Decodable, Equatable, Sendable {
    public let selectedCorrespondents: [SelectionDataItem<Correspondent.Id>]
    public let selectedDocumentTypes: [SelectionDataItem<DocumentType.Id>]
    public let selectedStoragePaths: [SelectionDataItem<StoragePath.Id>]
    public let selectedTags: [SelectionDataItem<Tag.Id>]

    public init(
        selectedCorrespondents: [SelectionDataItem<Correspondent.Id>],
        selectedDocumentTypes: [SelectionDataItem<DocumentType.Id>],
        selectedStoragePaths: [SelectionDataItem<StoragePath.Id>],
        selectedTags: [SelectionDataItem<Tag.Id>]
    ) {
        self.selectedCorrespondents = selectedCorrespondents
        self.selectedDocumentTypes = selectedDocumentTypes
        self.selectedStoragePaths = selectedStoragePaths
        self.selectedTags = selectedTags
    }
}
```

No manual `CodingKeys` anywhere — plain camelCase fields. `JSONEncoder.apiEncoder`'s `.convertToSnakeCase` and `JSONDecoder.apiDecoder`'s `.convertFromSnakeCase` (confirmed in `Modules/ApiInterface/Extensions/JSONDecoder+Extensions.swift`) handle `selectedCorrespondents` ↔ `selected_correspondents`, `documentCount` ↔ `document_count`, etc. automatically, the same way `Document`/`Tag`/every other model in this codebase already round-trips without manual keys.

`testValue()` on both types, unconditional `public extension`, matching every other `Input`/`Output` in this codebase.

## `DocumentsRepository.getSelectionData` + `GetSelectionDataUseCase`

Exactly the `getAllDocumentIds` / `GetAllDocumentIdsUseCase` shape (`Modules/ApiImplementation/Documents/DocumentsRepository.swift`, `Modules/ApiInterface/Documents/GetSelectionDataUseCase.swift`, `Modules/ApiImplementation/Documents/GetSelectionDataUseCase.swift`):

```swift
var getSelectionData: @Sendable (
    _ input: GetSelectionDataInput,
    _ server: Server
) async throws -> GetSelectionDataOutput
```
```swift
static func getSelectionData(
    input: GetSelectionDataInput,
    server: Server
) async throws -> GetSelectionDataOutput {
    try await APIClient
        .client(server: server)
        .send(.init(
            path: "/api/documents/selection_data/",
            method: .post,
            body: input
        ))
        .value
}
```

`DocumentsRepository`'s members are alphabetical (`bulkEditDocuments`, `createDocument`, `downloadDocument`, `getAllDocumentIds`, `getDocuments`, `getNextArchiveSerialNumber`, `updateDocument`) — `getSelectionData` slots in after `getNextArchiveSerialNumber`, before `updateDocument`.

The use case is a pure pass-through, matching `GetAllDocumentIdsUseCase`/`CreateDocumentUseCase` (no cache — this data is read-only and never cached, same as `GetDocumentsUseCase`).

## Tests

- **`Modules/ApiInterfaceTests/Documents/GetSelectionDataOutputTests.swift`** — one `@Test func decode()` asserting a realistic JSON payload (one item per category) decodes correctly via `JSONDecoder.apiDecoder`, `expectNoDifference` against `.testValue()`, matching `GetDocumentTypesOutputTests` style exactly.
- **`Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`** — one `.tags(.integrationTests)` test, `test_getSelectionData`, fetching the "Lego" fixture ids via `getAllDocumentIds` (as existing tests already do) and calling `repository.getSelectionData`, asserting it doesn't throw. This is read-only — unlike the bulk-edit integration tests, there's no mutation to worry about, so it can safely reuse the shared "Lego" fixtures without the disposable-document machinery `test_bulkEditDocuments_*` needed.
- No dedicated use-case test — pass-through, same precedent as `GetAllDocumentIdsUseCase`/`CreateDocumentUseCase`.

## Out of scope

- No UI. `BulkEditSelectionData` (the old app's dictionary-lookup wrapper for rendering bulk-edit checkboxes) is feature/UI-layer code — a later phase, if/when the bulk-edit UI itself gets built.
