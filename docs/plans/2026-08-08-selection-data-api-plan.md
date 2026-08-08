# Selection Data — API Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add API-layer support (model, repository, use case, tests) for paperless-ngx's `POST /api/documents/selection_data/` endpoint — no UI in this phase.

**Architecture:** Same `ApiInterface`/`ApiImplementation` split as the bulk-edit work it follows. A new generic `SelectionDataItem<Id>` (mirroring the existing `ListOutput<Element, Id>` generic) plus `GetSelectionDataInput`/`GetSelectionDataOutput` in `ApiInterface`; one new member on `DocumentsRepository`; a thin pass-through `GetSelectionDataUseCase`.

**Tech Stack:** Swift, Swift Testing, `swift-dependencies`, `Get`, Tuist-generated Xcode project.

**Full design context:** See `docs/plans/2026-08-08-selection-data-api.md` for the investigation and rationale — this plan implements that design directly.

## Global Constraints

- Endpoint: `POST /api/documents/selection_data/`, body `{"documents": [Document.Id]}`, response `{selected_correspondents, selected_document_types, selected_storage_paths, selected_tags}` (each an array of `{id, document_count}`).
- Use `Tagged<Entity, Int>` id types — never raw `Int`. Each category's `SelectionDataItem<Id>` instantiation uses its own entity's `Id` (`Correspondent.Id`, `DocumentType.Id`, `StoragePath.Id`, `Tag.Id`).
- No manual `CodingKeys` anywhere in this feature — plain camelCase fields; `JSONEncoder.apiEncoder`'s `.convertToSnakeCase` and `JSONDecoder.apiDecoder`'s `.convertFromSnakeCase` handle the snake_case wire format automatically.
- `DocumentsRepository`'s members are alphabetical — `getSelectionData` goes after `getNextArchiveSerialNumber`, before `updateDocument`.
- This is read-only — unlike the bulk-edit integration tests, it's safe to reuse the shared "Lego" fixture documents directly; no disposable-document machinery needed.
- No dedicated use-case test — pass-through, same precedent as `GetAllDocumentIdsUseCase`/`CreateDocumentUseCase`.
- Test command: `tuist test <scheme> --no-selective-testing` (e.g. `tuist test ApiInterface --no-selective-testing`, `tuist test ApiImplementation --no-selective-testing`). **The `--no-selective-testing` flag is required** — plain `tuist test` (even with `--clean`) can silently report "no tests to run, finishing early" due to Tuist's test-impact cache, which would give false confidence that a new test ran when it didn't. This was discovered the hard way during the bulk-edit work; don't drop it here. Run `mise run docker:start` first if the local fixture isn't already up.

---

## Task 1: `SelectionDataItem<Id>` + `GetSelectionDataInput`/`GetSelectionDataOutput` + decode test

**Files:**
- Create: `Modules/ApiInterface/Shared/SelectionDataItem.swift`
- Create: `Modules/ApiInterface/Documents/GetSelectionDataInput.swift`
- Create: `Modules/ApiInterface/Documents/GetSelectionDataOutput.swift`
- Create: `Modules/ApiInterfaceTests/Documents/GetSelectionDataOutputTests.swift`

**Interfaces:**
- Consumes: `Document.Id`, `Correspondent.Id`, `DocumentType.Id`, `StoragePath.Id`, `Tag.Id` (all already exist), `JSONDecoder.apiDecoder` (`Modules/ApiInterface/Extensions/JSONDecoder+Extensions.swift`, already exists).
- Produces: `SelectionDataItem<Id>` (public generic struct, `Codable & Equatable & Sendable`, `init(documentCount: Int, id: Id)`), `GetSelectionDataInput` (public struct, `Encodable & Equatable & Sendable`, `init(documents: [Document.Id])`), `GetSelectionDataOutput` (public struct, `Decodable & Equatable & Sendable`, with the 4 `selected*` fields). Tasks 2 and 3 construct `GetSelectionDataInput` and consume `GetSelectionDataOutput`.

- [x] **Step 1: Write `SelectionDataItem`**

Create `Modules/ApiInterface/Shared/SelectionDataItem.swift`:

```swift
import Foundation

public struct SelectionDataItem<Id: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {

    public let documentCount: Int

    public let id: Id

    public init(
        documentCount: Int,
        id: Id
    ) {
        self.documentCount = documentCount
        self.id = id
    }
}
```

- [x] **Step 2: Write `GetSelectionDataInput`**

Create `Modules/ApiInterface/Documents/GetSelectionDataInput.swift`:

```swift
import Foundation

public struct GetSelectionDataInput: Encodable, Equatable, Sendable {

    public let documents: [Document.Id]

    public init(documents: [Document.Id]) {
        self.documents = documents
    }
}

public extension GetSelectionDataInput {

    static func testValue(
        documents: [Document.Id] = [1, 2, 3]
    ) -> Self {
        .init(documents: documents)
    }
}
```

- [x] **Step 3: Write `GetSelectionDataOutput`**

Create `Modules/ApiInterface/Documents/GetSelectionDataOutput.swift`:

```swift
import Foundation

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

public extension GetSelectionDataOutput {

    static func testValue(
        selectedCorrespondents: [SelectionDataItem<Correspondent.Id>] = [.init(documentCount: 2, id: 1)],
        selectedDocumentTypes: [SelectionDataItem<DocumentType.Id>] = [.init(documentCount: 1, id: 2)],
        selectedStoragePaths: [SelectionDataItem<StoragePath.Id>] = [.init(documentCount: 3, id: 3)],
        selectedTags: [SelectionDataItem<Tag.Id>] = [.init(documentCount: 4, id: 4)]
    ) -> Self {
        .init(
            selectedCorrespondents: selectedCorrespondents,
            selectedDocumentTypes: selectedDocumentTypes,
            selectedStoragePaths: selectedStoragePaths,
            selectedTags: selectedTags
        )
    }
}
```

- [x] **Step 4: Write the decode test**

Create `Modules/ApiInterfaceTests/Documents/GetSelectionDataOutputTests.swift`:

```swift
@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct GetSelectionDataOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "selected_correspondents": [
            {
              "document_count": 2,
              "id": 1
            }
          ],
          "selected_document_types": [
            {
              "document_count": 1,
              "id": 2
            }
          ],
          "selected_storage_paths": [
            {
              "document_count": 3,
              "id": 3
            }
          ],
          "selected_tags": [
            {
              "document_count": 4,
              "id": 4
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetSelectionDataOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
```

- [x] **Step 5: Run the test to verify it passes**

Run: `tuist test ApiInterface --no-selective-testing`
Expected: PASS, including `GetSelectionDataOutputTests.decode()`.

- [x] **Step 6: Commit**

```bash
git add Modules/ApiInterface/Shared/SelectionDataItem.swift Modules/ApiInterface/Documents/GetSelectionDataInput.swift Modules/ApiInterface/Documents/GetSelectionDataOutput.swift Modules/ApiInterfaceTests/Documents/GetSelectionDataOutputTests.swift
git commit -m "feat: add GetSelectionDataInput/Output models"
```

---

## Task 2: `DocumentsRepository.getSelectionData`

**Files:**
- Modify: `Modules/ApiImplementation/Documents/DocumentsRepository.swift`
- Modify: `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`

**Interfaces:**
- Consumes: `GetSelectionDataInput`/`GetSelectionDataOutput` (Task 1), `APIClient.client(server:)` and `Request` (already used elsewhere in this file, same pattern as `getSelectionData`'s sibling `getAllDocumentIds`).
- Produces: `DocumentsRepository.getSelectionData: @Sendable (_ input: GetSelectionDataInput, _ server: Server) async throws -> GetSelectionDataOutput`. Task 3's `GetSelectionDataUseCase` live implementation calls this via `@Dependency(\.documentsRepository)`.

- [x] **Step 1: Add the integration test**

In `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`, add after `test_getAllDocumentIds()` and before `test_bulkEditDocuments_delete()`:

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getSelectionData() async throws {
        let documentIds = try await repository.getAllDocumentIds(
            input: .testValue(
                filterRules: [.init(ruleType: .title, value: "Lego")]
            ),
            server: .testValue()
        )

        _ = try await repository.getSelectionData(
            input: .init(documents: documentIds.results.map(\.id)),
            server: .testValue()
        )
    }
```

This is read-only, so it safely reuses the shared "Lego" fixture ids the same way `test_getAllDocumentIds`/`test_getDocuments` already do — no cleanup needed. `_ = ` discards the result explicitly (the call isn't `@discardableResult`); the assertion here is only that the call succeeds, matching this file's existing rigor level for this kind of read-only smoke coverage.

- [x] **Step 2: Run the test to verify it fails to compile**

Run: `tuist test ApiImplementation --no-selective-testing`
Expected: FAIL — build error, `value of type 'DocumentsRepository' has no member 'getSelectionData'`.

- [x] **Step 3: Add `getSelectionData` to `DocumentsRepository`**

In `Modules/ApiImplementation/Documents/DocumentsRepository.swift`, add to the `@DependencyClient struct DocumentsRepository` declaration, right after `var getNextArchiveSerialNumber` (whose closure type ends `) async throws -> Int`), before `var updateDocument`:

```swift
    var getSelectionData: @Sendable (
        _ input: GetSelectionDataInput,
        _ server: Server
    ) async throws -> GetSelectionDataOutput

```

Add to both `previewValue` and `testValue` (in the `TestDependencyKey` extension), right after `getNextArchiveSerialNumber: { _ in 1 },`, before `updateDocument: { _, _, _ in .testValue() }`:

```swift
        getSelectionData: { _, _ in .testValue() },
```

Add to `liveValue` (in the `DependencyKey` extension), right after `getNextArchiveSerialNumber: getNextArchiveSerialNumber(server:),`, before `updateDocument: updateDocument(id:input:server:)`:

```swift
        getSelectionData: getSelectionData(input:server:),
```

Add the implementation to the `private extension DocumentsRepository`, right after `getNextArchiveSerialNumber(server:)`'s closing brace, before `static func updateDocument(...)`:

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

- [x] **Step 4: Run the test to verify it passes**

```bash
mise run docker:start
```

Run: `tuist test ApiImplementation --no-selective-testing`
Expected: PASS, including `test_getSelectionData`.

- [x] **Step 5: Commit**

```bash
git add Modules/ApiImplementation/Documents/DocumentsRepository.swift Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift
git commit -m "feat: add DocumentsRepository.getSelectionData"
```

---

## Task 3: `GetSelectionDataUseCase`

**Files:**
- Create: `Modules/ApiInterface/Documents/GetSelectionDataUseCase.swift`
- Create: `Modules/ApiImplementation/Documents/GetSelectionDataUseCase.swift`

**Interfaces:**
- Consumes: `GetSelectionDataInput`/`GetSelectionDataOutput` (Task 1), `DocumentsRepository.getSelectionData` (Task 2, via `@Dependency(\.documentsRepository)`).
- Produces: `GetSelectionDataUseCase` (public `@DependencyClient` struct, `Sendable`) with `public var execute: @Sendable (_ input: GetSelectionDataInput, _ server: Server) async throws -> GetSelectionDataOutput`, and `DependencyValues.getSelectionData: GetSelectionDataUseCase`. This is the entry point a future UI phase will call.

No dedicated test file — pass-through, same precedent as `GetAllDocumentIdsUseCase`/`CreateDocumentUseCase`. Verification is a successful build.

- [x] **Step 1: Write the use case interface**

Create `Modules/ApiInterface/Documents/GetSelectionDataUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetSelectionDataUseCase: Sendable {

    public var execute: @Sendable (
        _ input: GetSelectionDataInput,
        _ server: Server
    ) async throws -> GetSelectionDataOutput
}

extension GetSelectionDataUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var getSelectionData: GetSelectionDataUseCase {
        get { self[GetSelectionDataUseCase.self] }
        set { self[GetSelectionDataUseCase.self] = newValue }
    }
}
```

- [x] **Step 2: Write the live implementation**

Create `Modules/ApiImplementation/Documents/GetSelectionDataUseCase.swift` (the `SwiftSharing` import matches its sibling `GetAllDocumentIdsUseCase.swift` in this same folder, even though nothing here uses `@Shared` directly):

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension GetSelectionDataUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension GetSelectionDataUseCase {

    static func execute(
        input: GetSelectionDataInput,
        server: Server
    ) async throws -> GetSelectionDataOutput {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.getSelectionData(
            input: input,
            server: server
        )
    }
}
```

- [x] **Step 3: Verify it builds**

Run: `tuist test ApiImplementation --no-selective-testing`
Expected: PASS (build succeeds, all existing and Task 2 tests still pass — this task adds no new tests of its own).

- [x] **Step 4: Commit**

```bash
git add Modules/ApiInterface/Documents/GetSelectionDataUseCase.swift Modules/ApiImplementation/Documents/GetSelectionDataUseCase.swift
git commit -m "feat: add GetSelectionDataUseCase"
```

---

## Definition of Done

- `tuist test ApiInterface --no-selective-testing` passes, including `GetSelectionDataOutputTests.decode()`.
- `tuist test ApiImplementation --no-selective-testing` passes (with `mise run docker:start` run first), including `test_getSelectionData`.
- `GetSelectionDataUseCase.liveValue` is wired and ready for a future UI phase to call via `@Dependency(\.getSelectionData.execute)`.
- No UI changes in this plan.
