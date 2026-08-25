# Bulk edit — API layer

## Context

Paperless-ngx exposes `POST /api/documents/bulk_edit/` for applying one operation to many documents at once (delete, retag, recorrespondent, etc. — the endpoint takes a list of document ids, a `method` discriminator string, and an optional `parameters` object shaped by that method). This app has no bulk-edit support yet; the goal of this phase is the API layer only — model, repository, use case, and tests — with no UI. Multi-select and the bulk-edit UI are a separate, later phase.

The sibling app `../paperless-ios` (`PaperlessKit/Sources/PaperlessAPI/Models/Document+BulkEditOperation.swift` and `PaperlessKit/Sources/PaperlessAPI/Services/Documents/DocumentsService+BulkEdit.swift`) already implements this against the same endpoint and is the reference for which methods and payload shapes to support. That implementation covers five methods: `delete`, `modify_tags`, `set_correspondent`, `set_document_type`, `set_storage_path`. This phase matches that scope exactly — this app has no permissions- or custom-fields-editing UI yet, so newer bulk_edit methods (`set_permissions`, `modify_custom_fields`, …) are out of scope for now.

Investigation of the current codebase (`Modules/ApiInterface`/`Modules/ApiImplementation`) confirmed the conventions to follow:

- One flat file per `Input`/`Output`/`UseCase`/`Repository` type (no `Type+Extra.swift` nesting the way the old app does it) — see `UpdateDocumentInput.swift`, `CreateDocumentInput.swift`, `UpdateDocumentUseCase.swift`.
- `JSONEncoder.apiEncoder` (`Modules/ApiInterface/Extensions/JSONEncoder+Extensions.swift`) sets `.keyEncodingStrategy = .convertToSnakeCase`, so plain camelCase `Encodable` struct fields need no manual `CodingKeys` — snake_case conversion is automatic and encoder-wide, including for nested structs encoded through the same encoder.
- `@NullEncodable` (`Modules/ApiInterface/Shared/NullEncodable.swift`) is this app's equivalent of the old app's `@Nullable` — encodes `nil` as JSON `null` instead of omitting the key, used for "explicitly clear this field" semantics (see `UpdateDocumentInput.correspondent`/`.documentType`/`.storagePath`).
- Id types are `Tagged<Entity, Int>` (`Document.Id`, `Tag.Id`, `Correspondent.Id`, `DocumentType.Id`, `StoragePath.Id`), not raw `Int`.
- The app already prefers plain `Array` over `Set` for id collections sent to the API (`Document.tags: [Tag.Id]`, `UpdateDocumentInput.tags`) — this phase follows that, both for consistency and because `Set` encoding order is nondeterministic, which would break exact-JSON-string snapshot tests.
- `DocumentsRepository` (`Modules/ApiImplementation/Documents/DocumentsRepository.swift`) is a `@DependencyClient` struct with one closure per operation, a `liveValue` implementation using `APIClient.client(server:).send(...)`, and matching `previewValue`/`testValue` stubs.
- Each repository operation has a matching `UseCase` pair: interface in `ApiInterface` (`@DependencyClient` struct + `DependencyValues` accessor), live implementation in `ApiImplementation`. Most of these (`CreateDocumentUseCase`, `DownloadDocumentUseCase`) are pure pass-throughs to the repository. `UpdateDocumentUseCase` is the one exception that also fires a best-effort `getStatistics` refresh inline — investigation confirmed this is *not* the general convention (statistics/cache refresh is normally centralized in `UpdateCacheUseCase`, invoked from the UI layer), so it's not something to copy here.
- There is no `@Shared` cache of `Document`s (unlike `Tag`/`DocumentType`/`Correspondent`/`StoragePath`, which are small reference lists kept in `@Shared` caches that use cases mutate directly on write). Nothing here needs cache invalidation.
- Response bodies that aren't useful are just discarded (`createDocument`, `downloadDocument` aside) by typing the closure as `async throws -> Void` — no `typealias FooOutput = Void` needed (that pattern exists elsewhere in the codebase but isn't used within `Documents`).
- Test conventions: `ApiInterfaceTests` has one file per `Input`/`Output` type asserting exact encoded JSON via `JSONEncoder.apiEncoder` + `expectNoDifference` (see `SaveDocumentTypeInputTests`). `ApiImplementationTests/Documents/DocumentsRepositoryTests.swift` has real, `.tags(.integrationTests)`-gated tests against the docker Paperless-ngx fixture instance (title-filterable "Lego Duplo"/"Lego Friends" documents already exist and are used by other tests without being mutated). Use cases that are pure pass-throughs (no cache mutation) have no dedicated unit test file — only the pass-through's underlying repository call is tested, at the repository/integration level.

## New model: `BulkEditDocumentsInput`

New file `Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift`:

```swift
public struct BulkEditDocumentsInput: Encodable, Equatable, Sendable {
    public enum Method: Equatable, Sendable {
        case delete
        case modifyTags(ModifyTags)
        case setCorrespondent(SetCorrespondent)
        case setDocumentType(SetDocumentType)
        case setStoragePath(SetStoragePath)
    }

    public let documents: [Document.Id]
    public let method: Method

    public init(documents: [Document.Id], method: Method) {
        self.documents = documents
        self.method = method
    }
}

public extension BulkEditDocumentsInput.Method {
    struct ModifyTags: Encodable, Equatable, Sendable {
        public let addTags: [Tag.Id]
        public let removeTags: [Tag.Id]

        public init(addTags: [Tag.Id], removeTags: [Tag.Id]) {
            self.addTags = addTags
            self.removeTags = removeTags
        }
    }

    struct SetCorrespondent: Encodable, Equatable, Sendable {
        @NullEncodable
        public var correspondent: Correspondent.Id?

        public init(correspondent: Correspondent.Id?) {
            self.correspondent = correspondent
        }
    }

    struct SetDocumentType: Encodable, Equatable, Sendable {
        @NullEncodable
        public var documentType: DocumentType.Id?

        public init(documentType: DocumentType.Id?) {
            self.documentType = documentType
        }
    }

    struct SetStoragePath: Encodable, Equatable, Sendable {
        @NullEncodable
        public var storagePath: StoragePath.Id?

        public init(storagePath: StoragePath.Id?) {
            self.storagePath = storagePath
        }
    }
}
```

`ModifyTags`/`SetCorrespondent`/`SetDocumentType`/`SetStoragePath` need no manual `CodingKeys` — `.convertToSnakeCase` handles `addTags` → `add_tags`, `documentType` → `document_type`, `storagePath` → `storage_path` automatically.

The top-level type needs a hand-written `encode(to:)` to produce the `method`-discriminator-plus-`parameters` shape the endpoint expects (this part necessarily mirrors the old app, since it's inherent to the wire format, not a naming convention):

```swift
private extension BulkEditDocumentsInput.Method {
    var key: String {
        switch self {
        case .delete: "delete"
        case .modifyTags: "modify_tags"
        case .setCorrespondent: "set_correspondent"
        case .setDocumentType: "set_document_type"
        case .setStoragePath: "set_storage_path"
        }
    }
}

extension BulkEditDocumentsInput {
    private enum CodingKeys: String, CodingKey {
        case documents, method, parameters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(documents, forKey: .documents)
        try container.encode(method.key, forKey: .method)
        switch method {
        case .delete:
            break
        case let .modifyTags(parameters):
            try container.encode(parameters, forKey: .parameters)
        case let .setCorrespondent(parameters):
            try container.encode(parameters, forKey: .parameters)
        case let .setDocumentType(parameters):
            try container.encode(parameters, forKey: .parameters)
        case let .setStoragePath(parameters):
            try container.encode(parameters, forKey: .parameters)
        }
    }
}
```

Example encoded payload for `.modifyTags`:

```json
{
  "documents": [1, 2, 3],
  "method": "modify_tags",
  "parameters": { "add_tags": [42, 43], "remove_tags": [99, 98] }
}
```

`.delete` encodes with no `parameters` key at all.

`testValue()` helpers on `BulkEditDocumentsInput` and each `Method` parameter struct, as unconditional `public extension` (this codebase, unlike the old app, doesn't gate test helpers behind `#if DEBUG`).

## `DocumentsRepository` changes

`Modules/ApiImplementation/Documents/DocumentsRepository.swift` — add one member, following the `createDocument` pattern:

```swift
var bulkEditDocuments: @Sendable (
    _ input: BulkEditDocumentsInput,
    _ server: Server
) async throws -> Void
```

`previewValue`/`testValue` stub: `bulkEditDocuments: { _, _ in }`.

`liveValue` wiring: `bulkEditDocuments: bulkEditDocuments(input:server:)`.

Live implementation:

```swift
static func bulkEditDocuments(
    input: BulkEditDocumentsInput,
    server: Server
) async throws {
    try await APIClient
        .client(server: server)
        .send(.init(
            path: "/api/documents/bulk_edit/",
            method: .post,
            body: input
        ))
        .value
}
```

Response body is discarded, matching the old app.

## New use case: `BulkEditDocumentsUseCase`

`Modules/ApiInterface/Documents/BulkEditDocumentsUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct BulkEditDocumentsUseCase: Sendable {

    public var execute: @Sendable (
        _ input: BulkEditDocumentsInput,
        _ server: Server
    ) async throws -> Void
}

extension BulkEditDocumentsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _ in }
    )
}

public extension DependencyValues {

    var bulkEditDocuments: BulkEditDocumentsUseCase {
        get { self[BulkEditDocumentsUseCase.self] }
        set { self[BulkEditDocumentsUseCase.self] = newValue }
    }
}
```

`Modules/ApiImplementation/Documents/BulkEditDocumentsUseCase.swift` — pure pass-through, matching `CreateDocumentUseCase`/`DownloadDocumentUseCase` (no inline statistics refresh — that's not the general convention, see Context):

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension BulkEditDocumentsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension BulkEditDocumentsUseCase {

    static func execute(
        input: BulkEditDocumentsInput,
        server: Server
    ) async throws {
        @Dependency(\.documentsRepository)
        var documentsRepository

        try await documentsRepository.bulkEditDocuments(
            input: input,
            server: server
        )
    }
}
```

## Tests

- **`Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift`** — one `@Test` per `Method` case (5 tests: delete, modifyTags, setCorrespondent, setDocumentType, setStoragePath — including a `nil` variant for the three `@NullEncodable` cases to confirm `null` is emitted, not an omitted key), encoding via `JSONEncoder.apiEncoder` and diffing the exact JSON string with `expectNoDifference`, matching `SaveDocumentTypeInputTests` style.
- **`Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`** — add one `.tags(.integrationTests)` test, `test_bulkEditDocuments`, that fetches the existing "Lego" fixture document ids via `getAllDocumentIds` (as `test_getAllDocumentIds` already does) and calls `repository.bulkEditDocuments` with `.setCorrespondent(correspondent: nil)`, asserting it doesn't throw. This is a safe, idempotent operation against shared fixture data (same rigor level as the existing `test_createDocument`/`test_getNextArchiveSerialNumber` tests, which also just assert success rather than a specific resulting state).
- **No dedicated `BulkEditDocumentsUseCaseTests.swift`** — consistent with `CreateDocumentUseCase`/`DownloadDocumentUseCase`/`UpdateDocumentUseCase`, none of which have a dedicated use-case-level unit test; pass-through use cases are covered by the repository test.

## Out of scope (future phases)

- Multi-select UI in the document list.
- Bulk-edit action sheet/form UI.
- Any newer bulk_edit methods (`set_permissions`, `modify_custom_fields`, `rotate`, `merge`, `split`, …) — can be added the same way later if/when this app grows editing UI for those concepts.
