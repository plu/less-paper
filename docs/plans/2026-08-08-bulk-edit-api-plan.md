# Bulk Edit — API Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add API-layer support (model, repository, use case, tests) for paperless-ngx's bulk document editing endpoint (`POST /api/documents/bulk_edit/`) — no UI in this phase.

**Architecture:** Follows this codebase's existing `ApiInterface`/`ApiImplementation` split exactly: a new `Encodable` input model in `ApiInterface`, one new member on the existing `DocumentsRepository` (`ApiImplementation`) that POSTs it, and a thin pass-through `BulkEditDocumentsUseCase` (interface in `ApiInterface`, live implementation in `ApiImplementation`) that the future UI phase will call.

**Tech Stack:** Swift, Swift Testing, `swift-dependencies` (`@DependencyClient`/`DependencyKey`), `Get` (HTTP client used via `APIClient.client(server:).send(...)`), Tuist-generated Xcode project.

**Full design context:** See `docs/plans/2026-08-08-bulk-edit-api.md` for the investigation and rationale behind every decision below — this plan implements that design directly.

## Global Constraints

- Scope is exactly 5 bulk-edit methods: `delete`, `modify_tags`, `set_correspondent`, `set_document_type`, `set_storage_path`. Do not add others (e.g. `set_permissions`, `modify_custom_fields`) in this phase.
- Endpoint: `POST /api/documents/bulk_edit/`. Response body is discarded (`Void`).
- Use `Tagged<Entity, Int>` id types (`Document.Id`, `Tag.Id`, `Correspondent.Id`, `DocumentType.Id`, `StoragePath.Id`) — never raw `Int`.
- Use plain `Array`, never `Set`, for id collections sent to the API (matches `Document.tags: [Tag.Id]`; also keeps JSON encoding deterministic for snapshot tests).
- `JSONEncoder.apiEncoder` already applies `.convertToSnakeCase` — do not write manual `CodingKeys` on any type except the one place the wire format genuinely requires a custom shape (the top-level `BulkEditDocumentsInput.encode(to:)`, for the `method`-string + `parameters`-object discriminated shape).
- Use `@NullEncodable` (not a custom `Nullable` wrapper) wherever a field must serialize as JSON `null` when cleared.
- Test helpers (`testValue()`) are unconditional `public extension`s — do not gate them behind `#if DEBUG`.
- No `@Shared` cache exists for `Document`s — nothing in this feature touches a cache.
- Pass-through use cases (no cache mutation) get no dedicated unit test file in this codebase (see `CreateDocumentUseCase`, `DownloadDocumentUseCase` — neither has one). Don't add one for `BulkEditDocumentsUseCase` either; a successful build is that task's verification.
- Run tests with `tuist test <SchemeName>` from the repo root (e.g. `tuist test ApiInterfaceTests`). Integration tests (`.tags(.integrationTests)`) additionally require a local paperless-ngx instance — start one with `mise run docker:start` first (dev instance listens on `http://localhost:8010`).

---

## Task 1: `BulkEditDocumentsInput` model + encoding tests

**Files:**
- Create: `Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift`
- Create: `Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift`

**Interfaces:**
- Consumes: `Document.Id`, `Tag.Id`, `Correspondent.Id`, `DocumentType.Id`, `StoragePath.Id` (all `Modules/ApiInterface`, already exist), `@NullEncodable` (`Modules/ApiInterface/Shared/NullEncodable.swift`, already exists), `JSONEncoder.apiEncoder` (`Modules/ApiInterface/Extensions/JSONEncoder+Extensions.swift`, already exists).
- Produces: `BulkEditDocumentsInput` (public struct, `Encodable & Equatable & Sendable`), with public nested `Method` enum (5 cases below) and public nested parameter structs `Method.ModifyTags`, `Method.SetCorrespondent`, `Method.SetDocumentType`, `Method.SetStoragePath`. All of these, plus `BulkEditDocumentsInput` itself, get a `static func testValue(...)`. Task 2 and Task 3 construct `BulkEditDocumentsInput` values and pass them to `DocumentsRepository.bulkEditDocuments`/`BulkEditDocumentsUseCase.execute`.

- [ ] **Step 1: Write the model**

Create `Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift`:

```swift
import Foundation

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

    public init(
        documents: [Document.Id],
        method: Method
    ) {
        self.documents = documents
        self.method = method
    }
}

public extension BulkEditDocumentsInput.Method {

    struct ModifyTags: Encodable, Equatable, Sendable {
        public let addTags: [Tag.Id]
        public let removeTags: [Tag.Id]

        public init(
            addTags: [Tag.Id],
            removeTags: [Tag.Id]
        ) {
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

private extension BulkEditDocumentsInput.Method {
    var key: String {
        switch self {
        case .delete:
            "delete"
        case .modifyTags:
            "modify_tags"
        case .setCorrespondent:
            "set_correspondent"
        case .setDocumentType:
            "set_document_type"
        case .setStoragePath:
            "set_storage_path"
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

public extension BulkEditDocumentsInput {

    static func testValue(
        documents: [Document.Id] = [1, 2, 3],
        method: Method = .modifyTags(.testValue())
    ) -> Self {
        .init(
            documents: documents,
            method: method
        )
    }
}

public extension BulkEditDocumentsInput.Method.ModifyTags {

    static func testValue(
        addTags: [Tag.Id] = [42, 43],
        removeTags: [Tag.Id] = [99, 98]
    ) -> Self {
        .init(
            addTags: addTags,
            removeTags: removeTags
        )
    }
}

public extension BulkEditDocumentsInput.Method.SetCorrespondent {

    static func testValue(
        correspondent: Correspondent.Id? = 42
    ) -> Self {
        .init(correspondent: correspondent)
    }
}

public extension BulkEditDocumentsInput.Method.SetDocumentType {

    static func testValue(
        documentType: DocumentType.Id? = 43
    ) -> Self {
        .init(documentType: documentType)
    }
}

public extension BulkEditDocumentsInput.Method.SetStoragePath {

    static func testValue(
        storagePath: StoragePath.Id? = 44
    ) -> Self {
        .init(storagePath: storagePath)
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift`:

```swift
@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct BulkEditDocumentsInputTests {

    @Test
    func encode_delete() async throws {
        let input = BulkEditDocumentsInput(documents: [1, 2, 3], method: .delete)

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "delete"
        }
        """)
    }

    @Test
    func encode_modifyTags() async throws {
        let input = BulkEditDocumentsInput.testValue()

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "modify_tags",
          "parameters" : {
            "add_tags" : [
              42,
              43
            ],
            "remove_tags" : [
              99,
              98
            ]
          }
        }
        """)
    }

    @Test
    func encode_setCorrespondent() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setCorrespondent(.testValue())
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_correspondent",
          "parameters" : {
            "correspondent" : 42
          }
        }
        """)
    }

    @Test
    func encode_setCorrespondent_withNilCorrespondent() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setCorrespondent(.testValue(correspondent: nil))
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_correspondent",
          "parameters" : {
            "correspondent" : null
          }
        }
        """)
    }

    @Test
    func encode_setDocumentType() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setDocumentType(.testValue())
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_document_type",
          "parameters" : {
            "document_type" : 43
          }
        }
        """)
    }

    @Test
    func encode_setDocumentType_withNilDocumentType() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setDocumentType(.testValue(documentType: nil))
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_document_type",
          "parameters" : {
            "document_type" : null
          }
        }
        """)
    }

    @Test
    func encode_setStoragePath() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setStoragePath(.testValue())
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_storage_path",
          "parameters" : {
            "storage_path" : 44
          }
        }
        """)
    }

    @Test
    func encode_setStoragePath_withNilStoragePath() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setStoragePath(.testValue(storagePath: nil))
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_storage_path",
          "parameters" : {
            "storage_path" : null
          }
        }
        """)
    }
}
```

Note: write Step 1 (the model) and Step 2 (the tests) together here because the model's shape *is* the thing under test — there's no meaningful separate "red" state without it. Once both files exist, run the tests once to confirm they pass (there is no prior failing state to observe, unlike a bug-fix task).

- [ ] **Step 3: Run the tests and verify they pass**

Run: `tuist test ApiInterfaceTests`
Expected: all tests pass, including the 8 new `BulkEditDocumentsInputTests` tests.

- [ ] **Step 4: Commit**

```bash
git add Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift
git commit -m "feat: add BulkEditDocumentsInput model"
```

---

## Task 2: `DocumentsRepository.bulkEditDocuments`

**Files:**
- Modify: `Modules/ApiImplementation/Documents/DocumentsRepository.swift`
- Modify: `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`

**Interfaces:**
- Consumes: `BulkEditDocumentsInput` (Task 1), `APIClient.client(server:)` and `Request` (`Modules/ApiImplementation/Extensions/APIClient+Extensions.swift`, already exist — same pattern as `updateDocument` in this file).
- Produces: `DocumentsRepository.bulkEditDocuments: @Sendable (_ input: BulkEditDocumentsInput, _ server: Server) async throws -> Void`. Task 3's `BulkEditDocumentsUseCase` live implementation calls this via `@Dependency(\.documentsRepository) var documentsRepository; try await documentsRepository.bulkEditDocuments(input:server:)`.

- [ ] **Step 1: Add the failing integration test**

In `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`, add a new test after `test_getAllDocumentIds()` (which ends around line 275, right before the `private func createTempTestFile` helper):

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments() async throws {
        let documentIds = try await repository.getAllDocumentIds(
            input: .testValue(
                filterRules: [.init(ruleType: .title, value: "Lego")]
            ),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: documentIds.results.map(\.id),
                method: .setCorrespondent(.init(correspondent: nil))
            ),
            server: .testValue()
        )
    }
```

This fetches the ids of the existing "Lego Duplo"/"Lego Friends" fixture documents (same lookup `test_getAllDocumentIds` already does) and clears their correspondent — a safe, idempotent operation since those fixtures don't have one set — asserting only that the call doesn't throw, matching the rigor of the neighboring `test_createDocument`/`test_getNextArchiveSerialNumber` tests.

- [ ] **Step 2: Run the test to verify it fails to compile**

Run: `tuist test ApiImplementationTests`
Expected: FAIL — build error, `value of type 'DocumentsRepository' has no member 'bulkEditDocuments'`.

- [ ] **Step 3: Add `bulkEditDocuments` to `DocumentsRepository`**

The existing members of `DocumentsRepository` are declared in alphabetical order (`createDocument`, `downloadDocument`, `getAllDocumentIds`, `getDocuments`, `getNextArchiveSerialNumber`, `updateDocument`) — keep that ordering, so `bulkEditDocuments` (b) goes *before* `createDocument`, in all four places below.

In `Modules/ApiImplementation/Documents/DocumentsRepository.swift`, add to the `@DependencyClient struct DocumentsRepository` declaration, right *before* `var createDocument`:

```swift
    var bulkEditDocuments: @Sendable (
        _ input: BulkEditDocumentsInput,
        _ server: Server
    ) async throws -> Void

```

Add to both `previewValue` and `testValue` (in the `TestDependencyKey` extension), right *before* `createDocument: { _, _ in },`:

```swift
        bulkEditDocuments: { _, _ in },
```

Add to `liveValue` (in the `DependencyKey` extension), right *before* `createDocument: createDocument(input:server:),`:

```swift
        bulkEditDocuments: bulkEditDocuments(input:server:),
```

Add the implementation to the `private extension DocumentsRepository`, right *before* `static func createDocument(...)`:

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

- [ ] **Step 4: Run the test to verify it passes**

First, start the local paperless-ngx dev fixture instance (skip if already running):

```bash
mise run docker:start
```

Then:

Run: `tuist test ApiImplementationTests`
Expected: PASS, including the new `test_bulkEditDocuments` test.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiImplementation/Documents/DocumentsRepository.swift Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift
git commit -m "feat: add DocumentsRepository.bulkEditDocuments"
```

---

## Task 3: `BulkEditDocumentsUseCase`

**Files:**
- Create: `Modules/ApiInterface/Documents/BulkEditDocumentsUseCase.swift`
- Create: `Modules/ApiImplementation/Documents/BulkEditDocumentsUseCase.swift`

**Interfaces:**
- Consumes: `BulkEditDocumentsInput` (Task 1), `DocumentsRepository.bulkEditDocuments` (Task 2, accessed via `@Dependency(\.documentsRepository)`).
- Produces: `BulkEditDocumentsUseCase` (public `@DependencyClient` struct, `Sendable`) with `public var execute: @Sendable (_ input: BulkEditDocumentsInput, _ server: Server) async throws -> Void`, and `DependencyValues.bulkEditDocuments: BulkEditDocumentsUseCase`. This is the entry point the future UI phase will call.

No dedicated test file for this task, per the "pass-through use cases have no dedicated test" convention documented in Global Constraints (see `CreateDocumentUseCase`/`DownloadDocumentUseCase` for precedent) — the underlying repository call is already covered by Task 2's integration test. This task's verification step is a successful build.

- [ ] **Step 1: Write the use case interface**

Create `Modules/ApiInterface/Documents/BulkEditDocumentsUseCase.swift`:

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

- [ ] **Step 2: Write the live implementation**

Create `Modules/ApiImplementation/Documents/BulkEditDocumentsUseCase.swift` (the `SwiftSharing` import matches its siblings `CreateDocumentUseCase.swift`/`DownloadDocumentUseCase.swift` in this same folder, even though nothing here uses `@Shared` directly):

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

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

- [ ] **Step 3: Verify it builds**

Run: `tuist test ApiImplementationTests`
Expected: PASS (build succeeds, all existing and Task 2 tests still pass — this task adds no new tests of its own).

- [ ] **Step 4: Commit**

```bash
git add Modules/ApiInterface/Documents/BulkEditDocumentsUseCase.swift Modules/ApiImplementation/Documents/BulkEditDocumentsUseCase.swift
git commit -m "feat: add BulkEditDocumentsUseCase"
```

---

## Definition of Done

- `tuist test ApiInterfaceTests` passes, including all 8 new `BulkEditDocumentsInputTests` tests.
- `tuist test ApiImplementationTests` passes (with `mise run docker:start` run first), including the new `test_bulkEditDocuments` integration test.
- `BulkEditDocumentsUseCase.liveValue` is wired and ready for the (separate, future) UI phase to call via `@Dependency(\.bulkEditDocuments.execute)`.
- No UI changes in this plan — multi-select and the bulk-edit action UI are out of scope, per the design doc.
