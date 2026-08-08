# Bulk edit — thorough integration tests

## Context

`docs/plans/2026-08-08-bulk-edit-api.md` and `-plan.md` added the bulk-edit API layer (`BulkEditDocumentsInput`, `DocumentsRepository.bulkEditDocuments`, `BulkEditDocumentsUseCase`), with one integration test (`test_bulkEditDocuments` in `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`) that only exercises `.setCorrespondent(nil)` against the shared "Lego" fixture documents and asserts the call doesn't throw — it doesn't prove any operation actually does anything. This phase replaces that single smoke test with one thorough integration test per bulk-edit method (`delete`, `modify_tags`, `set_correspondent`, `set_document_type`, `set_storage_path`), each verifying the real effect by re-fetching the document afterward.

Two decisions were made explicitly with the user before this design, both worth recording since they're non-obvious:

1. **Depth:** verify real effect (create a fixture, apply the bulk edit, re-fetch and assert the field changed), not just non-throw.
2. **Cross-suite fixture race:** the four reference-data integration suites (`TagsRepositoryTests`, `CorrespondentsRepositoryTests`, `DocumentTypesRepositoryTests`, `StoragePathsRepositoryTests`) each wipe **all** records of their kind at the start of every one of their own tests (`init() async throws { try await repository.deleteAll() }`). Swift Testing runs suites in parallel by default, so a tag/correspondent/document-type/storage-path this plan's tests create could theoretically be wiped mid-test by one of those suites running concurrently.
   - `.serialized` does **not** fix this: per this project's own `.agents/skills/swift-testing-pro/references/async-tests.md`, `.serialized` only serializes a suite's *parameterized* test cases against each other — it has no effect on plain `@Test func` tests (which is what every test here is), and provides no exclusion between different suite types at all. This was verified against that reference before ruling it out.
   - True global exclusion (`-parallel-testing-enabled NO`) or dropping fixture creation entirely were the alternatives; the user chose to **accept the race and verify empirically**: build the tests the same way the existing reference-data suites already build their own (create/use/delete inline, within one test), then actually run the full integration suite multiple times in a row to check for flakiness before calling it done, escalating rather than shipping it if it proves flaky.

## Approach: each test owns a disposable document

Rather than mutating the shared "Lego" fixture documents that other tests depend on existing, each new test creates its own uniquely-titled document (`"<label> \(UUID())"`, so parallel test functions never collide on title), exercises one bulk-edit method on it, verifies the effect, and cleans up — using bulk-edit `.delete` itself as teardown. No test in this plan touches the "Lego" documents.

### New helper: `createTestDocument(title:)`

`Modules/ApiImplementation`'s `createDocument` hits paperless-ngx's async multipart consume endpoint — it returns `Void`, and the document is created by a background consumer task, not synchronously. Nothing in this codebase currently waits for that consumption to finish; every existing test that calls `createDocument` just fires it and returns (`test_createDocument`) or never looks up the result. Testing `delete` (and giving the other four tests a real document to operate on) requires a real, discoverable id, so this plan adds a private polling helper to `DocumentsRepositoryTests`:

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
```

30 attempts × 1s = a 30s ceiling, generous for a tiny temp PDF against the local dev fixture instance. `DocumentConsumptionTimedOut` is a trivial local `Error` struct — if this ever fires, that's a real signal (consumption broke or got much slower), not something to silently retry past.

### The 5 tests (replacing `test_bulkEditDocuments`)

All five carry the same integration trait as the existing tests: `.dependencies { $0.authenticationProvider = .integrationTest; $0.context = .live }, .tags(.integrationTests)`.

1. **`test_bulkEditDocuments_delete`** — create a document, bulk-edit `.delete` it, assert `getAllDocumentIds` for its title now returns empty.
2. **`test_bulkEditDocuments_modifyTags`** — create a tag (`tagsRepository.createTag`) and a document, bulk-edit `.modifyTags(addTags: [tag], removeTags: [])`, re-fetch via `getDocuments` and assert `.tags == [tag.id]`; bulk-edit `.modifyTags(addTags: [], removeTags: [tag])`, re-fetch and assert `.tags == []`. Clean up: bulk-edit `.delete` the document, `tagsRepository.deleteTag` the tag.
3. **`test_bulkEditDocuments_setCorrespondent`** — create a correspondent (`correspondentsRepository.createCorrespondent`) and a document, bulk-edit `.setCorrespondent(correspondent.id)`, re-fetch and assert `.correspondent == correspondent.id`; bulk-edit `.setCorrespondent(nil)`, re-fetch and assert `.correspondent == nil`. Clean up document + correspondent.
4. **`test_bulkEditDocuments_setDocumentType`** — same shape via `documentTypesRepository.createDocumentType` / `Document.documentType`.
5. **`test_bulkEditDocuments_setStoragePath`** — same shape via `storagePathsRepository.createStoragePath` / `Document.storagePath`.

Each test creates and tears down its own fixtures inline — the same pattern `TagsRepositoryTests.crud()` etc. already use for their own resources — consistent with "accept the race, verify empirically."

`DocumentsRepositoryTests` gains four more `@Dependency` properties (`tagsRepository`, `correspondentsRepository`, `documentTypesRepository`, `storagePathsRepository`) alongside its existing `documentsRepository`, scoped `private`, matching the existing property's style.

### Verification step

Once implemented, run the full `ApiImplementationTests` integration pass **three times in a row** (not once) specifically to surface intermittent flakiness from the accepted cross-suite race. Any flaky run stops the work for a report back rather than shipping it.

## Out of scope

- No changes to `BulkEditDocumentsInput`/`BulkEditDocumentsUseCase` or any non-integration test — this is test-only work.
- No `.serialized` traits added anywhere (confirmed ineffective for this codebase's non-parameterized tests).
- No shared/reusable "wait for consumption" utility promoted to `TestSupport` — only `DocumentsRepositoryTests` needs it right now; promote it later if a second consumer appears (YAGNI).
