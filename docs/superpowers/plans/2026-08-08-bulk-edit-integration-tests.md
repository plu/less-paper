# Bulk Edit — Thorough Integration Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single non-throw-only `test_bulkEditDocuments` integration test with one thorough integration test per bulk-edit method (`delete`, `modify_tags`, `set_correspondent`, `set_document_type`, `set_storage_path`), each verifying the real effect against a live paperless-ngx fixture instance.

**Architecture:** All changes live in one file, `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`. A new private polling helper (`createTestDocument(title:)`) creates a uniquely-titled, disposable document per test (working around `createDocument`'s async server-side consumption, which nothing in this codebase currently waits for). Each of the 5 new tests creates its own fixtures (document, and where needed a tag/correspondent/document-type/storage-path), applies one bulk-edit method, re-fetches to verify the real effect, then cleans up — using bulk-edit `.delete` itself as document teardown. No test touches the shared "Lego" fixture documents other tests depend on.

**Tech Stack:** Swift, Swift Testing, `swift-dependencies`, `Get`, a live local paperless-ngx docker fixture instance (`mise run docker:start`).

**Full design context:** See `docs/superpowers/specs/2026-08-08-bulk-edit-integration-tests-design.md` for the investigation and the two explicit decisions this plan implements (verify real effect; accept the cross-suite fixture race and verify empirically rather than relying on `.serialized`, which is confirmed ineffective here).

## Global Constraints

- Every new test creates and tears down its own fixtures inline (document, and any tag/correspondent/document-type/storage-path it needs) — never touch or rely on the shared "Lego"/"Sonos"/etc. fixture documents other tests use.
- Give every created fixture a title/name containing `UUID()` so parallel test functions never collide.
- All 5 tests carry the same integration trait already used by neighboring tests: `.dependencies { $0.authenticationProvider = .integrationTest; $0.context = .live }, .tags(.integrationTests)`.
- Do not add `.serialized` anywhere — confirmed ineffective for this codebase's non-parameterized tests (see design doc).
- Test command is `tuist test ApiImplementation` (the module's own scheme name — there is no separate `ApiImplementationTests` scheme; it runs the paired `ApiImplementationTests` target). Run `mise run docker:start` first if the local fixture isn't already up (safe to run even if it is).
- The final task in this plan runs the full integration suite **3 times in a row** to check for flakiness before the work is considered done — this is a required step, not optional polish.

---

## Task 1: `createTestDocument` helper + `test_bulkEditDocuments_delete`

**Files:**
- Modify: `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`

**Interfaces:**
- Consumes: `repository.createDocument(input:server:)`, `repository.getAllDocumentIds(input:server:)`, `repository.bulkEditDocuments(input:server:)` (all already exist on `DocumentsRepository`), `createTempTestFile()` (existing private helper in this same file), `BulkEditDocumentsInput`/`.Method.delete` (already exist in `ApiInterface`).
- Produces: `private func createTestDocument(title: String) async throws -> Document.Id` and `private struct DocumentConsumptionTimedOut: Error {}`, both used by every later task in this plan. `createTestDocument` creates a document with the given title, polls until paperless-ngx has finished consuming it, and returns its id.

- [ ] **Step 1: Remove the old smoke test**

In `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`, delete the existing `test_bulkEditDocuments()` test entirely (it currently sits right after `test_getAllDocumentIds()` and right before the `createTempTestFile` helper):

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

It's being replaced by 5 more thorough tests (this task adds the first: `test_bulkEditDocuments_delete`).

- [ ] **Step 2: Add the `createTestDocument` helper and its error type**

Add these two right after the existing `createTempTestFile` helper (which stays as-is):

```swift
    private func createTestDocument(title: String) async throws -> Document.Id {
        let tempURL = try createTempTestFile()
        try await repository.createDocument(
            input: .testValue(createdDate: Date(), title: title, url: tempURL),
            server: .testValue()
        )

        for _ in 0..<30 {
            let output = try await repository.getAllDocumentIds(
                input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
                server: .testValue()
            )
            if let id = output.results.first?.id {
                return id
            }
            try await Task.sleep(for: .seconds(1))
        }

        throw DocumentConsumptionTimedOut()
    }

    private struct DocumentConsumptionTimedOut: Error {}
```

`createDocument`'s underlying endpoint hands the file to paperless-ngx's background consumer and returns immediately — the document doesn't exist yet when the call returns. This polls `getAllDocumentIds` (filtered by the unique title) once a second, up to 30 seconds, until it appears.

- [ ] **Step 3: Add `test_bulkEditDocuments_delete`**

Add in the same place the old test was:

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_delete() async throws {
        let title = "Bulk Edit Delete Test \(UUID())"
        let id = try await createTestDocument(title: title)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )

        let output = try await repository.getAllDocumentIds(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(output.results.isEmpty)
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Start the local paperless-ngx dev fixture instance if not already running:

```bash
mise run docker:start
```

Run: `tuist test ApiImplementation`
Expected: PASS, including `test_bulkEditDocuments_delete`. (This runs the whole target — there is no narrower single-test CLI invocation in this project's tooling — so all pre-existing tests must also still pass.)

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift
git commit -m "test: replace bulk edit smoke test with a real delete integration test"
```

---

## Task 2: `test_bulkEditDocuments_modifyTags`

**Files:**
- Modify: `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`

**Interfaces:**
- Consumes: `createTestDocument(title:)` and `repository.bulkEditDocuments`/`.delete` (Task 1), `tagsRepository.createTag(input:server:)` / `.deleteTag(id:server:)` (`Modules/ApiImplementation/Tags/TagsRepository.swift`, already exists — `createTag` returns `SaveTagOutput` = `Tag`, which has `.id: Tag.Id`), `SaveTagInput.init(color:isInboxTag:name:)` (`color`/`isInboxTag`/`name` required, rest default — `Modules/ApiInterface/Tags/SaveTagInput.swift`), `repository.getDocuments(input:server:)` (already exists, returns `GetDocumentsOutput` whose `.results` are full `Document` values with a `.tags: [Tag.Id]` field), `BulkEditDocumentsInput.Method.modifyTags(ModifyTags(addTags:removeTags:))` (already exists).
- Produces: nothing new for later tasks — this task's only consumer is the final verification task (Task 4), which just runs the whole suite.

- [ ] **Step 1: Add the `tagsRepository` dependency**

Add right after the existing `@Dependency(\.documentsRepository) private var repository` at the bottom of the `DocumentsRepositoryTests` struct:

```swift

    @Dependency(\.tagsRepository)
    private var tagsRepository
```

- [ ] **Step 2: Add `test_bulkEditDocuments_modifyTags`**

Add alongside `test_bulkEditDocuments_delete` (from Task 1):

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_modifyTags() async throws {
        let title = "Bulk Edit Modify Tags Test \(UUID())"
        let id = try await createTestDocument(title: title)
        let tag = try await tagsRepository.createTag(
            input: .init(
                color: "#ff0000",
                isInboxTag: false,
                name: "Bulk Edit Test Tag \(UUID())"
            ),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .modifyTags(.init(addTags: [tag.id], removeTags: []))
            ),
            server: .testValue()
        )

        var documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.tags == [tag.id])

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .modifyTags(.init(addTags: [], removeTags: [tag.id]))
            ),
            server: .testValue()
        )

        documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.tags == [])

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await tagsRepository.deleteTag(id: tag.id, server: .testValue())
    }
```

- [ ] **Step 3: Run the tests to verify they pass**

```bash
mise run docker:start
```

Run: `tuist test ApiImplementation`
Expected: PASS, including `test_bulkEditDocuments_modifyTags` and everything from Task 1.

- [ ] **Step 4: Commit**

```bash
git add Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift
git commit -m "test: add bulk edit modify_tags integration test"
```

---

## Task 3: `set_correspondent` / `set_document_type` / `set_storage_path` tests

**Files:**
- Modify: `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`

**Interfaces:**
- Consumes: `createTestDocument(title:)` and `repository.bulkEditDocuments`/`.delete` (Task 1); `correspondentsRepository.createCorrespondent(input:server:)`/`.deleteCorrespondent(id:server:)` (`Modules/ApiImplementation/Correspondents/CorrespondentsRepository.swift` — `createCorrespondent` returns `SaveCorrespondentOutput` = `Correspondent`, `.id: Correspondent.Id`); `documentTypesRepository.createDocumentType(input:server:)`/`.deleteDocumentType(id:server:)` (`Modules/ApiImplementation/DocumentTypes/DocumentTypesRepository.swift` — returns `SaveDocumentTypeOutput` = `DocumentType`, `.id: DocumentType.Id`); `storagePathsRepository.createStoragePath(input:server:)`/`.deleteStoragePath(id:server:)` (`Modules/ApiImplementation/StoragePaths/StoragePathsRepository.swift` — returns `SaveStoragePathOutput` = `StoragePath`, `.id: StoragePath.Id`); `SaveCorrespondentInput.init(name:)`, `SaveDocumentTypeInput.init(name:)`, `SaveStoragePathInput.init(name:path:)` (all in `ApiInterface`, only `name`/`path` are required, rest default); `Document.correspondent`/`.documentType`/`.storagePath` fields; `BulkEditDocumentsInput.Method.setCorrespondent`/`.setDocumentType`/`.setStoragePath` (already exist).
- Produces: nothing new for later tasks.

- [ ] **Step 1: Add the three remaining repository dependencies**

Add right after the `tagsRepository` dependency added in Task 2:

```swift

    @Dependency(\.correspondentsRepository)
    private var correspondentsRepository

    @Dependency(\.documentTypesRepository)
    private var documentTypesRepository

    @Dependency(\.storagePathsRepository)
    private var storagePathsRepository
```

- [ ] **Step 2: Add `test_bulkEditDocuments_setCorrespondent`**

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_setCorrespondent() async throws {
        let title = "Bulk Edit Set Correspondent Test \(UUID())"
        let id = try await createTestDocument(title: title)
        let correspondent = try await correspondentsRepository.createCorrespondent(
            input: .init(name: "Bulk Edit Test Correspondent \(UUID())"),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setCorrespondent(.init(correspondent: correspondent.id))
            ),
            server: .testValue()
        )

        var documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.correspondent == correspondent.id)

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setCorrespondent(.init(correspondent: nil))
            ),
            server: .testValue()
        )

        documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.correspondent == nil)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await correspondentsRepository.deleteCorrespondent(id: correspondent.id, server: .testValue())
    }
```

- [ ] **Step 3: Add `test_bulkEditDocuments_setDocumentType`**

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_setDocumentType() async throws {
        let title = "Bulk Edit Set Document Type Test \(UUID())"
        let id = try await createTestDocument(title: title)
        let documentType = try await documentTypesRepository.createDocumentType(
            input: .init(name: "Bulk Edit Test Document Type \(UUID())"),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setDocumentType(.init(documentType: documentType.id))
            ),
            server: .testValue()
        )

        var documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.documentType == documentType.id)

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setDocumentType(.init(documentType: nil))
            ),
            server: .testValue()
        )

        documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.documentType == nil)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await documentTypesRepository.deleteDocumentType(id: documentType.id, server: .testValue())
    }
```

- [ ] **Step 4: Add `test_bulkEditDocuments_setStoragePath`**

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_setStoragePath() async throws {
        let title = "Bulk Edit Set Storage Path Test \(UUID())"
        let id = try await createTestDocument(title: title)
        let storagePath = try await storagePathsRepository.createStoragePath(
            input: .init(name: "Bulk Edit Test Storage Path \(UUID())", path: "bulk-edit-test/{{ title }}"),
            server: .testValue()
        )

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setStoragePath(.init(storagePath: storagePath.id))
            ),
            server: .testValue()
        )

        var documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.storagePath == storagePath.id)

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [id],
                method: .setStoragePath(.init(storagePath: nil))
            ),
            server: .testValue()
        )

        documents = try await repository.getDocuments(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(documents.results.first?.storagePath == nil)

        try await repository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await storagePathsRepository.deleteStoragePath(id: storagePath.id, server: .testValue())
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
mise run docker:start
```

Run: `tuist test ApiImplementation`
Expected: PASS, including all 3 new tests and everything from Tasks 1-2.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift
git commit -m "test: add bulk edit set_correspondent/set_document_type/set_storage_path integration tests"
```

---

## Task 4: Flakiness verification pass

**Files:** none (verification only — no code changes expected)

**Interfaces:** none.

This task exists because the design accepted a known, unmitigated race (Tags/Correspondents/DocumentTypes/StoragePaths integration suites wipe all records of their kind at the start of every one of their own tests; Swift Testing runs suites in parallel by default) rather than eliminating it structurally. This step is how that acceptance gets checked rather than just asserted.

- [ ] **Step 1: Ensure the fixture instance is running**

```bash
mise run docker:start
```

- [ ] **Step 2: Run the full integration suite 3 times in a row**

Run this exact command three separate times, recording the result of each:

```bash
tuist test ApiImplementation
```

- [ ] **Step 3: Report**

If all 3 runs pass cleanly: this task is DONE. Report the 3 pass results.

If any run fails or shows different results between runs (the signature of the accepted race actually manifesting): do **not** attempt a fix in this task. Report BLOCKED with which test(s) failed, the failure output, and whether the same test failed consistently or intermittently — the controller needs to decide whether to add fixture-collision hardening (e.g. more specific cleanup ordering) or escalate the race back to the human partner, per the design doc's stated fallback ("If it's flaky, escalate rather than shipping it").

- [ ] **Step 4: Commit (only if Step 3 required no code changes)**

If all 3 runs were clean, there is nothing to commit — this task produced no diff. Skip committing.

---

## Definition of Done

- `tuist test ApiImplementation` passes 3 times in a row with no flakiness.
- `test_bulkEditDocuments` (the old smoke test) is gone, replaced by `test_bulkEditDocuments_delete`, `_modifyTags`, `_setCorrespondent`, `_setDocumentType`, `_setStoragePath`.
- None of the 5 new tests touch the shared "Lego" fixture documents.
- No `.serialized` traits were added anywhere.
