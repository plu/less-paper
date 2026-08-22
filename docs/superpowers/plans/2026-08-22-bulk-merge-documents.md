# Merge Selected Documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user merge the documents they have selected in the document list into one new PDF, choosing the page order and whether the originals are deleted.

**Architecture:** A new `.merge` case on the existing `BulkEditDocumentsInput.Method` posts to `/api/documents/bulk_edit/` — not the newer `/api/documents/merge/`, which does not exist on API v9 servers. A new sheet (`DocumentBulkEditMergeReducer` + `View`) fetches the selected documents in the list's sort order, lets the user drag them into the page order they want, and applies the merge behind a `ConfirmationPopupView`.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, `swift-dependencies`, Swift Testing, `swift-snapshot-testing`, Tuist, paperless-ngx 3.0.5.

**Spec:** `docs/superpowers/specs/2026-08-22-bulk-merge-documents-design.md`

## Global Constraints

- **Comments:** Never write `///` or `/** */`. Only `//`, and only when a future reader would otherwise stop and wonder why the code is the way it is. See `AGENTS.md`.
- **Confirmations:** Never `.confirmationDialog`, `.alert`, or `ConfirmationDialogState`. Every confirmation goes through `PopupPresenter` + `ConfirmationPopupView`. See `AGENTS.md`.
- **`@ViewAction` views** send with `send(…)`, never `store.send(…)` — including inside `.task`. See `AGENTS.md`.
- **Minimum API version is 9** (`Modules/ApiInterface/Shared/ApiVersion.swift:7`). Do not call `/api/documents/merge/`, `/api/documents/delete/`, or any other v10-only endpoint.
- **`archive_fallback` is always `true`.** It is never surfaced to the user.
- **`metadata_document_id` and `source_mode` are never sent.**
- **Properties within a type are ordered alphabetically** in this codebase (see `DocumentBulkEditTagsReducer.State`). Keep new ones alphabetical.
- **Builds are not warning-free by default** — skim build output for files you touched.

## File Structure

**Create:**
- `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer.swift` — state, actions, reducer body
- `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer+Effect.swift` — the four effects and their `CancelID`s
- `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer+TestValue.swift` — `State.testValue(…)`
- `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeView.swift` — the sheet
- `Modules/DocumentsFeatureTests/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducerTests.swift`
- `Modules/DocumentsFeatureTests/DocumentBulkEdit/Merge/DocumentBulkEditMergeViewTests.swift`

**Modify:**
- `Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift` — `.merge` case, `Merge` payload, key, encoding, test value
- `Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift` — optional sort
- `Modules/ApiImplementation/Documents/DocumentsRepository.swift:272-283` — `ordering` query item
- `Modules/DocumentsFeature/DocumentBulkEdit/DocumentBulkEditConfirmationPresenter.swift` — `presentMerge`
- `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` — `Destination.bulkEditMerge`, `View.mergeSelectedButtonTapped`, delegate handling
- `Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift` — overflow menu entry and sheet
- `Shared/Framework/Resources/Localizable.xcstrings` — five new strings
- `Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift`
- `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`
- `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

---

### Task 1: `.merge` method on `BulkEditDocumentsInput`

**Files:**
- Modify: `Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift`
- Test: `Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `BulkEditDocumentsInput.Method.merge(BulkEditDocumentsInput.Method.Merge)`, and `Merge(archiveFallback: Bool, deleteOriginals: Bool)` with a `.testValue(archiveFallback:deleteOriginals:)` factory. Task 6 constructs these.

**Background:** `JSONEncoder.apiEncoder` sets `.convertToSnakeCase`, so `archiveFallback` encodes as `archive_fallback` with no `CodingKeys`. It also sets `.sortedKeys` under `#if DEBUG`, which is why the expected JSON below is alphabetically ordered. The `documents` array is *not* sorted — it is an array, and its order is the merged PDF's page order.

- [ ] **Step 1: Write the failing test**

Add to `Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift`, after `encode_delete`:

```swift
    @Test
    func encode_merge() async throws {
        let input = BulkEditDocumentsInput(
            documents: [3, 1, 2],
            method: .merge(.testValue(deleteOriginals: true))
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            3,
            1,
            2
          ],
          "method" : "merge",
          "parameters" : {
            "archive_fallback" : true,
            "delete_originals" : true
          }
        }
        """)
    }

    @Test
    func encode_merge_withDefaults() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2],
            method: .merge(.testValue())
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2
          ],
          "method" : "merge",
          "parameters" : {
            "archive_fallback" : true,
            "delete_originals" : false
          }
        }
        """)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets ApiInterfaceTests`
Expected: FAIL — `type 'BulkEditDocumentsInput.Method' has no member 'merge'`.

- [ ] **Step 3: Add the case to the `Method` enum**

In `Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift`, add `merge` to the enum, alphabetically after `delete`:

```swift
    public enum Method: Equatable, Sendable {
        case delete
        case merge(Merge)
        case modifyTags(ModifyTags)
        case setCorrespondent(SetCorrespondent)
        case setDocumentType(SetDocumentType)
        case setStoragePath(SetStoragePath)
    }
```

- [ ] **Step 4: Add the `Merge` payload**

In the same file, inside `public extension BulkEditDocumentsInput.Method`, add `Merge` before `ModifyTags`:

```swift
    struct Merge: Encodable, Equatable, Sendable {
        public let archiveFallback: Bool
        public let deleteOriginals: Bool

        public init(
            archiveFallback: Bool,
            deleteOriginals: Bool
        ) {
            self.archiveFallback = archiveFallback
            self.deleteOriginals = deleteOriginals
        }
    }
```

- [ ] **Step 5: Add the method key and the encoding branch**

In `private extension BulkEditDocumentsInput.Method`, add to the `key` switch after `case .delete`:

```swift
        case .merge:
            "merge"
```

In `func encode(to:)`, add to the switch after `case .delete: break`:

```swift
        case let .merge(parameters):
            try container.encode(parameters, forKey: .parameters)
```

- [ ] **Step 6: Add the test value**

At the end of the file, after the `ModifyTags` test value:

```swift
public extension BulkEditDocumentsInput.Method.Merge {

    static func testValue(
        archiveFallback: Bool = true,
        deleteOriginals: Bool = false
    ) -> Self {
        .init(
            archiveFallback: archiveFallback,
            deleteOriginals: deleteOriginals
        )
    }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets ApiInterfaceTests`
Expected: PASS, including the pre-existing `encode_*` tests.

- [ ] **Step 8: Commit**

```bash
git add Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift \
        Modules/ApiInterfaceTests/Documents/BulkEditDocumentsInputTests.swift
git commit -m "feat: add merge method to bulk edit input"
```

---

### Task 2: Optional ordering on `GetDocumentsByIdsInput`

**Files:**
- Modify: `Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift`
- Modify: `Modules/ApiImplementation/Documents/DocumentsRepository.swift:272-283`
- Test: `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `GetDocumentsByIdsInput(ids:sortDirection:sortField:)` where both sort arguments default to `nil`. Task 6 passes a real sort.

**Background:** `GetDocumentsByIdsInput` today sends no `ordering`, so `id__in` comes back in the server's default order. The merge sheet needs the list's order. Verified against the docker instance that `id__in` and `ordering` combine correctly and that `-title` is the exact reverse of `title`.

Both sort properties are **optional and default to `nil`**, and the query item is omitted when `sortField` is `nil`. This keeps the two existing callers — `DocumentListReducer+Effect.runRefreshDocuments` and `DocumentBulkEditTitleReducer+Effect.runGetDocumentsByIds`, which both call `.init(ids: chunk)` and key results by id — byte-for-byte unchanged on the wire.

- [ ] **Step 1: Write the failing test**

Add to `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`, after `test_getDocumentsByIds`:

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getDocumentsByIds_ordering() async throws {
        let allIds = try await repository.getAllDocumentIds(
            input: .testValue(),
            server: .testValue()
        )
        let ids = Array(allIds.results.map(\.id).prefix(5))

        let ascending = try await repository.getDocumentsByIds(
            input: .init(ids: ids, sortDirection: .ascending, sortField: .title),
            server: .testValue()
        )
        let descending = try await repository.getDocumentsByIds(
            input: .init(ids: ids, sortDirection: .descending, sortField: .title),
            server: .testValue()
        )

        #expect(ascending.map(\.id) == descending.map(\.id).reversed())
        #expect(ascending.map(\.title) == ascending.map(\.title).sorted())
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Make sure the docker instance is running first (`mise run docker:up` if it is not — check `mise tasks` for the exact name).

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets ApiImplementationTests`
Expected: FAIL — `extra arguments at positions #2, #3 in call`.

- [ ] **Step 3: Add the sort properties to the input**

Replace the body of `Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift`:

```swift
import Foundation

public struct GetDocumentsByIdsInput: Codable, Equatable, Sendable {

    public let ids: [Document.Id]

    public let sortDirection: SortDirection?

    public let sortField: SortField?

    public init(
        ids: [Document.Id],
        sortDirection: SortDirection? = nil,
        sortField: SortField? = nil
    ) {
        self.ids = ids
        self.sortDirection = sortDirection
        self.sortField = sortField
    }
}

public extension GetDocumentsByIdsInput {

    static func testValue(
        ids: [Document.Id] = [],
        sortDirection: SortDirection? = nil,
        sortField: SortField? = nil
    ) -> Self {
        .init(
            ids: ids,
            sortDirection: sortDirection,
            sortField: sortField
        )
    }
}
```

- [ ] **Step 4: Thread `ordering` into the request**

Replace `init(input: GetDocumentsByIdsInput)` in `Modules/ApiImplementation/Documents/DocumentsRepository.swift`:

```swift
    init(input: GetDocumentsByIdsInput) {
        var query: [(String, String?)] = [
            ("id__in", input.ids.map { "\($0.rawValue)" }.joined(separator: ",")),
            ("page", "1"),
            ("page_size", "\(input.ids.count)"),
            ("truncate_content", "true"),
        ]

        if let sortField = input.sortField {
            query.append((
                "ordering",
                [(input.sortDirection ?? .ascending).rawValue, sortField.rawValue].joined()
            ))
        }

        self.init(
            path: "/api/documents/",
            method: .get,
            query: query
        )
    }
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets ApiImplementationTests`
Expected: PASS, including the pre-existing `test_getDocumentsByIds` and `test_getDocumentsByIds_emptyIds_returnsEmpty`.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface/Documents/GetDocumentsByIdsInput.swift \
        Modules/ApiImplementation/Documents/DocumentsRepository.swift \
        Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift
git commit -m "feat: let getDocumentsByIds request a sort order"
```

---

### Task 3: Integration test for the merge wire format

**Files:**
- Test: `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`

**Interfaces:**
- Consumes: `BulkEditDocumentsInput.Method.merge` from Task 1.
- Produces: nothing.

**Background:** This is the only test that proves the JSON we send is accepted. `_validate_parameters_merge` rejects a non-boolean `delete_originals` with a 400, which this test would surface immediately as a thrown error.

Two things to know before writing it, **both established the hard way by running an earlier version of this test**:

1. **The existing `createTempTestFile` fixture cannot be merged.** It writes plain text into a file named `test.pdf`. Paperless stores it as `originals/000….txt` and generates *no* archive version, so `archive_fallback` has nothing to fall back to and `pikepdf` fails with `unable to find trailer dictionary`. The server logs `No documents were merged` and still returns `"OK"` — the silent-partial-merge limitation, observed live. The test therefore needs a genuine PDF.

   Every PDF under `docker/data` is already seeded, and paperless rejects a byte-identical upload as a duplicate. Appending a comment after `%%EOF` changes the checksum while leaving a file `pikepdf` opens cleanly (verified: 1 page, differing MD5).

2. **The merged document's title is not predictable.** Without `metadata_document_id` it derives from a filename paperless builds itself, and paperless's own title parsing can rewrite it. Find the merged document by *elimination* — snapshot the id set before merging and poll for an id that was not there — which also asserts the merge actually produced something rather than silently merging nothing.

Merge is asynchronous. A malformed request throws immediately; a merge that is accepted but produces nothing fails on the polling timeout instead. In practice the test takes about 8 seconds.

- [ ] **Step 1: Write the helpers**

Add to `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`, above `createTestDocument`:

```swift
    private func documentIds() async throws -> Set<Document.Id> {
        let output = try await repository.getAllDocumentIds(
            input: .testValue(),
            server: .testValue()
        )

        return Set(output.results.map(\.id))
    }

    // A comment is appended so the checksum is unique: paperless rejects a byte-identical upload as
    // a duplicate, and every PDF under `docker/data` is already seeded. Bytes after `%%EOF` are
    // ignored, so the file stays a PDF pikepdf can open — which `merge` requires and the plain-text
    // `createTempTestFile` fixture does not satisfy.
    private func createTempPdfFile() throws -> URL {
        var data = try Data(
            contentsOf: URL.projectRoot
                .appendingPathComponent("docker")
                .appendingPathComponent("data")
                .appendingPathComponent("Puky.pdf")
        )
        data.append(Data("\n% \(UUID())\n".utf8))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID()).pdf")
        try data.write(to: url)

        return url
    }

    private func createTestPdfDocument(title: String) async throws -> Document.Id {
        try await repository.createDocument(
            input: .testValue(
                createdDate: Date(),
                title: title,
                url: try createTempPdfFile()
            ),
            server: .testValue()
        )

        return try await waitForDocument(title: title)
    }

    // Found by elimination rather than by name: without `metadata_document_id` the merged
    // document's title comes from a filename paperless builds itself.
    private func waitForNewDocument(excluding existing: Set<Document.Id>) async throws -> Document.Id {
        for _ in 0 ..< 60 {
            if let id = try await documentIds().subtracting(existing).first {
                return id
            }
            try await Task.sleep(for: .seconds(1))
        }

        throw DocumentConsumptionTimedOut()
    }
```

- [ ] **Step 2: Write the test**

Add to `Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift`, after `test_bulkEditDocuments_delete`:

Add after `test_bulkEditDocuments_delete`:

```swift
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_bulkEditDocuments_merge() async throws {
        let first = try await createTestPdfDocument(title: "Bulk Edit Merge Test A \(UUID())")
        let second = try await createTestPdfDocument(title: "Bulk Edit Merge Test B \(UUID())")
        let existing = try await documentIds()

        try await repository.bulkEditDocuments(
            input: .init(
                documents: [first, second],
                method: .merge(.init(archiveFallback: true, deleteOriginals: true))
            ),
            server: .testValue()
        )

        let mergedId = try await waitForNewDocument(excluding: existing)

        try await repository.bulkEditDocuments(
            input: .init(documents: [mergedId], method: .delete),
            server: .testValue()
        )
    }
```

- [ ] **Step 3: Run the test**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets ApiImplementationTests`
Expected: PASS in roughly 8 seconds.

If it fails with a thrown `ApiError`, the request body is wrong — re-read `_validate_parameters_merge` in the container:
`docker exec paperless-ci-paperless-1 sed -n '2040,2050p' /usr/src/paperless/src/documents/serialisers.py`

If it fails on the polling timeout, the merge was accepted but produced nothing. Check why:
`docker logs paperless-ci-paperless-1 --since 5m 2>&1 | grep -i merg`

- [ ] **Step 4: Confirm the instance is clean**

Run:
```bash
T=$(curl -s -X POST http://localhost:9000/api/token/ -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"T0PS3CR3T!!123"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")
curl -s -H "Authorization: Token $T" "http://localhost:9000/api/documents/?page_size=1" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['count'])"
```
Expected: `14`, the seed count. The ci instance is on port **9000** (dev is on 8000). If the count is higher, a failed run left documents behind — delete them via `bulk_edit` before continuing.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiImplementationTests/Documents/DocumentsRepositoryTests.swift
git commit -m "test: cover the bulk merge wire format against paperless"
```

---

### Task 4: Localized strings

**Files:**
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: nothing.
- Produces: `LocalizedStringResource` symbols `.confirmMerge`, `.deleteOriginals`, `.merge`, `.mergeDocuments`, and the two plural-aware `.bulkEditMergeConfirmation(_:)` / `.bulkEditMergeDeleteOriginalsConfirmation(_:)`. Tasks 5, 7 and 8 use these.

**Background:** Strings live in one catalog and Xcode generates the symbols, so they must exist before any task that references them compiles. `sourceLanguage` is `en`; every entry needs both `en` and `de`, `"extractionState": "manual"`, and plural forms use `%lld` with `one`/`other` variations. Entries are stored alphabetically by key.

- [ ] **Step 1: Add the six entries**

Insert each into the `"strings"` object of `Shared/Framework/Resources/Localizable.xcstrings`, keeping the file's alphabetical key order:

```json
    "bulkEditMergeConfirmation" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Dieser Vorgang führt %lld Dokument zu einem neuen Dokument zusammen. Die Originale bleiben erhalten."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Dieser Vorgang führt %lld Dokumente zu einem neuen Dokument zusammen. Die Originale bleiben erhalten."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This will merge %lld document into a new document. The originals are kept."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This will merge %lld documents into a new document. The originals are kept."
                }
              }
            }
          }
        }
      }
    },
    "bulkEditMergeDeleteOriginalsConfirmation" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Dieser Vorgang führt %lld Dokument zu einem neuen Dokument zusammen und löscht das Original."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Dieser Vorgang führt %lld Dokumente zu einem neuen Dokument zusammen und löscht die Originale."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This will merge %lld document into a new document and delete the original."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This will merge %lld documents into a new document and delete the originals."
                }
              }
            }
          }
        }
      }
    },
    "confirmMerge" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Zusammenführen bestätigen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Confirm merge"
          }
        }
      }
    },
    "deleteOriginals" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Originale löschen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Delete originals"
          }
        }
      }
    },
    "merge" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Zusammenführen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Merge"
          }
        }
      }
    },
    "mergeDocuments" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Dokumente zusammenführen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Merge documents"
          }
        }
      }
    },
```

- [ ] **Step 2: Verify the catalog is still valid JSON and the keys are present**

Run:
```bash
python3 -c "
import json
d = json.load(open('Shared/Framework/Resources/Localizable.xcstrings'))
for k in ['bulkEditMergeConfirmation','bulkEditMergeDeleteOriginalsConfirmation','confirmMerge','deleteOriginals','merge','mergeDocuments']:
    assert k in d['strings'], k
print('ok', len(d['strings']), 'strings')
"
```
Expected: `ok <n> strings` with no assertion error.

- [ ] **Step 3: Build so Xcode generates the symbols**

Run: `tuist build LessPaper-Workspace`
Expected: builds cleanly. The generated symbols are what Tasks 5, 7 and 8 reference.

- [ ] **Step 4: Commit**

```bash
git add Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: add strings for merging documents"
```

---

### Task 5: `presentMerge` on the confirmation presenter

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/DocumentBulkEditConfirmationPresenter.swift`

**Interfaces:**
- Consumes: `.confirmMerge`, `.bulkEditMergeConfirmation(_:)`, `.bulkEditMergeDeleteOriginalsConfirmation(_:)` from Task 4.
- Produces: `documentBulkEditConfirmation.presentMerge: @Sendable (_ deleteOriginals: Bool, _ documentCount: Int) async -> Bool`. Task 6 depends on it.

**Background:** `@DependencyClient` generates a throwing/unimplemented `testValue`, which is what reducer tests override. The existing `presentTitle` is the closest model — copy its shape. The message branches on `deleteOriginals` because deleting the originals is the part a user needs warning about.

- [ ] **Step 1: Add the client property**

In `struct DocumentBulkEditConfirmationPresenter`, add after `present`, keeping alphabetical order:

```swift
    var presentMerge: @Sendable (
        _ deleteOriginals: Bool,
        _ documentCount: Int
    ) async -> Bool = { _, _ in false }
```

- [ ] **Step 2: Add it to `previewValue` and `liveValue`**

In the `TestDependencyKey` extension, `previewValue` becomes:

```swift
    static let previewValue = Self(
        present: { _ in false },
        presentMerge: { _, _ in false },
        presentTags: { _, _, _ in false },
        presentTitle: { _ in false }
    )
```

In the `DependencyKey` extension, `liveValue` becomes:

```swift
    static let liveValue = Self(
        present: present(message:),
        presentMerge: presentMerge(deleteOriginals:documentCount:),
        presentTags: presentTags(addTags:documentCount:removeTags:),
        presentTitle: presentTitle(documentCount:)
    )
```

Leave `testValue = Self()` alone — the unimplemented default is what tests want.

- [ ] **Step 3: Add the implementation**

In `private extension DocumentBulkEditConfirmationPresenter`, after `present(message:)`:

```swift
    static func presentMerge(deleteOriginals: Bool, documentCount: Int) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .confirmMerge,
                message: deleteOriginals
                    ? .bulkEditMergeDeleteOriginalsConfirmation(documentCount)
                    : .bulkEditMergeConfirmation(documentCount),
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
```

- [ ] **Step 4: Build**

Run: `tuist build LessPaper-Workspace`
Expected: builds cleanly, no new warnings in `DocumentBulkEditConfirmationPresenter.swift`.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature/DocumentBulkEdit/DocumentBulkEditConfirmationPresenter.swift
git commit -m "feat: add merge confirmation presenter"
```

---

### Task 6: The merge reducer

**Files:**
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer+Effect.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducerTests.swift`

**Interfaces:**
- Consumes: `BulkEditDocumentsInput.Method.merge` (Task 1), `GetDocumentsByIdsInput(ids:sortDirection:sortField:)` (Task 2), `presentMerge` (Task 5).
- Produces:
  - `DocumentBulkEditMergeReducer` with `State(deleteOriginals:documents:isLoading:isSaving:selectedDocuments:server:sort:)`
  - `Action.View`: `closeButtonTapped`, `mergeButtonTapped`, `moved(IndexSet, Int)`, `onAppear`
  - `Action.Delegate.documentsMerged`
  - `State.canMerge: Bool`
  - `State.testValue(…)`

Task 7 builds the view against these; Task 8 constructs the state and matches the delegate.

**Background:** `.toast(error)` calls `toastPresenter.present`, which is unimplemented under `.dependencies()` — every error-path test must stub it or the `receive(\.error)` records an issue. `DocumentBulkEditTagsReducerTests.test_view_onAppear_error` is the pattern.

`state.sort` is `DocumentFilterInput.SortFilter` — the same value the list holds at `state.filter.input.sort`, with `direction` and `field` properties (`Modules/DocumentsFeature/DocumentFilter/DocumentFilterInput.swift:35`).

The fetch is a **single request**, unlike `DocumentBulkEditTitleReducer+Effect.runGetDocumentsByIds` which chunks into 100s. The server applies `ordering` per request, so concatenating independently-ordered chunks would produce page order that is not the list's. `getDocumentsByIds` already sends `page_size` equal to the id count, so one request returns everything.

- [ ] **Step 1: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducerTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentBulkEditMergeReducerTests {

    @Test
    func test_canMerge() async throws {
        #expect(DocumentBulkEditMergeReducer.State.testValue(documents: []).canMerge == false)
        #expect(DocumentBulkEditMergeReducer.State.testValue(
            documents: [.testValue(id: 1)]
        ).canMerge == false)
        #expect(DocumentBulkEditMergeReducer.State.testValue(
            documents: [.testValue(id: 1), .testValue(id: 2)]
        ).canMerge == true)
    }

    @Test
    func test_onAppear_loadsDocumentsInListOrder() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [],
            selectedDocuments: [2, 1],
            sort: .init(direction: .ascending, field: .title)
        )) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { input, _ in
                #expect(input.ids == [1, 2])
                #expect(input.sortDirection == .ascending)
                #expect(input.sortField == .title)
                return [.testValue(id: 2, title: "A"), .testValue(id: 1, title: "B")]
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.documentsLoaded) {
            $0.documents = [.testValue(id: 2, title: "A"), .testValue(id: 1, title: "B")]
            $0.isLoading = false
        }
    }

    @Test
    func test_onAppear_doesNotReloadWhenAlreadyLoaded() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1), .testValue(id: 2)]
        )) {
            DocumentBulkEditMergeReducer()
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_moved_reordersDocuments() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1), .testValue(id: 2), .testValue(id: 3)]
        )) {
            DocumentBulkEditMergeReducer()
        }

        await store.send(.view(.moved(IndexSet(integer: 2), 0))) {
            $0.documents = [.testValue(id: 3), .testValue(id: 1), .testValue(id: 2)]
        }
    }

    @Test
    func test_merge_sendsReorderedIds() async throws {
        let store = TestStore(initialState: .testValue(
            deleteOriginals: true,
            documents: [.testValue(id: 3), .testValue(id: 1), .testValue(id: 2)]
        )) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentMerge = { deleteOriginals, documentCount in
                #expect(deleteOriginals == true)
                #expect(documentCount == 3)
                return true
            }
            $0.bulkEditDocuments.execute = { input, _ in
                #expect(input.documents == [3, 1, 2])
                #expect(input.method == .merge(.init(archiveFallback: true, deleteOriginals: true)))
            }
        }

        await store.send(.view(.mergeButtonTapped))
        await store.receive(\.mergeConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsMerged)
    }

    @Test
    func test_merge_whenConfirmationCancelled() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1), .testValue(id: 2)]
        )) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentMerge = { _, _ in false }
        }

        await store.send(.view(.mergeButtonTapped))
    }

    @Test
    func test_merge_whenBelowTwoDocuments() async throws {
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1)]
        )) {
            DocumentBulkEditMergeReducer()
        }

        await store.send(.view(.mergeButtonTapped))
    }

    @Test
    func test_merge_whenRequestFails() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(
            documents: [.testValue(id: 1), .testValue(id: 2)]
        )) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentMerge = { _, _ in true }
            $0.bulkEditDocuments.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.mergeButtonTapped))
        await store.receive(\.mergeConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.error) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_onAppear_whenRequestFails() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(documents: [])) {
            DocumentBulkEditMergeReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.error) {
            $0.isLoading = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets DocumentsFeatureTests`
Expected: FAIL — `cannot find 'DocumentBulkEditMergeReducer' in scope`.

- [ ] **Step 3: Write the reducer**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentBulkEditMergeReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case documentsLoaded([Document])
        case error(Error)
        case mergeConfirmed
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentsMerged
        }

        public enum View {
            case closeButtonTapped
            case mergeButtonTapped
            case moved(IndexSet, Int)
            case onAppear
        }
    }

    @ObservableState
    public struct State: Equatable {

        // Read off the fetched documents rather than the selection: a document that was deleted on
        // the server between selecting and opening the sheet is not in `documents`, and merging
        // what is left of a two-document selection would silently copy a single document.
        var canMerge: Bool {
            documents.count >= minimumDocumentCount
        }

        var deleteOriginals = false

        var documents: [Document] = []

        var isLoading = false

        var isSaving = false

        let selectedDocuments: Set<Document.Id>

        let server: Server

        let sort: DocumentFilterInput.SortFilter
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .documentsLoaded(documents):
                state.documents = documents
                state.isLoading = false
                return .none
            case let .error(error):
                state.isLoading = false
                state.isSaving = false
                return .toast(error)
            case .mergeConfirmed:
                guard state.canMerge else {
                    return .none
                }
                state.isSaving = true
                return .runMerge(
                    deleteOriginals: state.deleteOriginals,
                    documents: state.documents.map(\.id),
                    server: state.server
                )
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .runDismiss()
                case .mergeButtonTapped:
                    guard state.canMerge else {
                        return .none
                    }
                    return .runConfirmMerge(
                        deleteOriginals: state.deleteOriginals,
                        documentCount: state.documents.count
                    )
                case let .moved(source, destination):
                    state.documents.move(fromOffsets: source, toOffset: destination)
                    return .none
                case .onAppear:
                    guard state.documents.isEmpty else {
                        return .none
                    }
                    state.isLoading = true
                    return .runGetDocumentsByIds(
                        ids: state.selectedDocuments,
                        server: state.server,
                        sort: state.sort
                    )
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}

private let minimumDocumentCount = 2
```

- [ ] **Step 4: Write the effects**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentBulkEditMergeReducer.Action {

    static func runConfirmMerge(
        deleteOriginals: Bool,
        documentCount: Int
    ) -> Self {
        @Dependency(\.documentBulkEditConfirmation.presentMerge)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(deleteOriginals, documentCount) else {
                return
            }
            await send(.mergeConfirmed)
        }
        .cancellable(id: CancelID.confirmMerge)
    }

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    // One request, not the chunked loop `DocumentBulkEditTitleReducer` uses: the server applies
    // `ordering` per request, so concatenating chunks would interleave their orders and hand the
    // user a page order that is not the one the list showed.
    static func runGetDocumentsByIds(
        ids: Set<Document.Id>,
        server: Server,
        sort: DocumentFilterInput.SortFilter
    ) -> Self {
        @Dependency(\.getDocumentsByIds.execute)
        var getDocumentsByIds

        let input = GetDocumentsByIdsInput(
            ids: ids.sorted(),
            sortDirection: sort.direction,
            sortField: sort.field
        )

        return .run { send in
            await send(.documentsLoaded(try await getDocumentsByIds(input, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.getDocumentsByIds)
    }

    static func runMerge(
        deleteOriginals: Bool,
        documents: [Document.Id],
        server: Server
    ) -> Self {
        @Dependency(\.bulkEditDocuments.execute)
        var bulkEditDocuments

        let input = BulkEditDocumentsInput(
            documents: documents,
            method: .merge(.init(
                archiveFallback: true,
                deleteOriginals: deleteOriginals
            ))
        )

        return .run { send in
            try await bulkEditDocuments(input, server)
            await send(.delegate(.documentsMerged))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.merge)
    }
}

private enum CancelID {
    case confirmMerge
    case getDocumentsByIds
    case merge
}
```

- [ ] **Step 5: Write the test value**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducer+TestValue.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension DocumentBulkEditMergeReducer.State {

    static func testValue(
        deleteOriginals: Bool = false,
        documents: [Document] = [
            .testValue(id: 1, title: "Invoice"),
            .testValue(id: 2, title: "Receipt")
        ],
        isLoading: Bool = false,
        isSaving: Bool = false,
        selectedDocuments: Set<Document.Id> = [1, 2],
        server: Server = .testValue(),
        sort: DocumentFilterInput.SortFilter = .init()
    ) -> Self {
        .init(
            deleteOriginals: deleteOriginals,
            documents: documents,
            isLoading: isLoading,
            isSaving: isSaving,
            selectedDocuments: selectedDocuments,
            server: server,
            sort: sort
        )
    }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets DocumentsFeatureTests`
Expected: PASS for all nine `DocumentBulkEditMergeReducerTests` tests.

- [ ] **Step 7: Commit**

```bash
git add Modules/DocumentsFeature/DocumentBulkEdit/Merge/ \
        Modules/DocumentsFeatureTests/DocumentBulkEdit/Merge/DocumentBulkEditMergeReducerTests.swift
git commit -m "feat: add the document merge reducer"
```

---

### Task 7: The merge sheet

**Files:**
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/Merge/DocumentBulkEditMergeViewTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 4 and 6.
- Produces: `DocumentBulkEditMergeView(store:)`. Task 8 presents it.

**Background:** `.onMove` only takes effect when the list is in edit mode, which the sheet forces with `.environment(\.editMode, .constant(.active))` — there is no Edit button to press. `DocumentBulkEditTagsView` is the layout to copy: `Sheet` with `SheetHeader` on top, list in the middle, buttons at the bottom.

This view **is** annotated `@ViewAction`, so it sends with `send(…)`, never `store.send(…)`, including in `.task`.

Every `Toggle` in this app is tinted `Color.m3Primary` (`ShareFormView.swift:226`, `TagFormView.swift`, `CorrespondentFormView.swift:93`). Without it the switch renders system green, which is off-brand.

Rows set `listRowBackground(Color.m3Surface)` explicitly. Without it they paint the system default, which is indistinguishable from `m3Surface` in light mode but wrong in dark — which is what the dark-mode snapshot below exists to catch.

- [ ] **Step 1: Write the view**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeView.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentBulkEditMergeReducer.self)
struct DocumentBulkEditMergeView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .mergeDocuments,
                left: leftHeader
            )
        } content: {
            list()
        } bottom: {
            buttons()
        }
        .task { await send(.onAppear).finish() }
    }

    @Bindable
    var store: StoreOf<DocumentBulkEditMergeReducer>

    @ViewBuilder
    private func buttons() -> some View {
        VStack(spacing: .x4) {
            Toggle(isOn: $store.deleteOriginals) {
                Text(.deleteOriginals)
            }
            .disabled(store.isSaving)
            .tint(Color.m3Primary)

            Button {
                send(.mergeButtonTapped)
            } label: {
                Text(.merge)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isSaving))
            .disabled(!store.canMerge)
        }
    }

    @ViewBuilder
    private func leftHeader() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }

    @ViewBuilder
    private func list() -> some View {
        List {
            ForEach(store.documents) { document in
                Text(document.title)
                    .foregroundStyle(Color.m3OnSurface)
                    .listRowBackground(Color.m3Surface)
                    .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
                    .listRowSeparator(.hidden)
            }
            .onMove { source, destination in
                send(.moved(source, destination))
            }
        }
        .background(Color.m3Surface)
        .environment(\.defaultMinListRowHeight, 0)
        .environment(\.editMode, .constant(.active))
        .listStyle(.plain)
        .overlay(loadingView())
        .presentationDetents([.sheet])
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func loadingView() -> some View {
        if store.isLoading {
            ProgressView()
                .controlSize(.large)
        }
    }
}
```

- [ ] **Step 2: Write the snapshot tests**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/Merge/DocumentBulkEditMergeViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentBulkEditMergeViewTests {

    @Test
    func testSnapshot_loaded() async throws {
        assertSnapshot(
            of: view(state: .testValue(documents: documents)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loaded"
        )
    }

    @Test
    func testSnapshot_deleteOriginals() async throws {
        assertSnapshot(
            of: view(state: .testValue(deleteOriginals: true, documents: documents)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "deleteOriginals"
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        assertSnapshot(
            of: view(state: .testValue(documents: [], isLoading: true)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loading"
        )
    }

    @Test
    func testSnapshot_saving() async throws {
        assertSnapshot(
            of: view(state: .testValue(documents: documents, isSaving: true)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "saving"
        )
    }

    // Dark mode: the rows set `listRowBackground` explicitly, and in light mode `m3Surface` and the
    // system default are both white, so only dark shows whether that is actually applied.
    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: view(state: .testValue(documents: documents)),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "darkMode"
        )
    }

    private var documents: [Document] {
        [
            .testValue(id: 1, title: "Invoice January"),
            .testValue(id: 2, title: "Invoice February"),
            .testValue(id: 3, title: "Invoice March")
        ]
    }

    private func view(state: DocumentBulkEditMergeReducer.State) -> some View {
        DocumentBulkEditMergeView(
            store: Store(initialState: state) {
                EmptyReducer<
                    DocumentBulkEditMergeReducer.State,
                    DocumentBulkEditMergeReducer.Action
                >()
            }
        )
    }
}
```

- [ ] **Step 3: Record the snapshots**

Run: `SNAPSHOT_TESTING_RECORD=missing tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets DocumentsFeatureTests`
Expected: the five tests fail on the first run with "Automatically recorded a new snapshot", writing PNGs into `Snapshots/DocumentsFeatureTests/DocumentBulkEditMergeViewTests/`.

- [ ] **Step 4: Inspect the recorded snapshots**

Open the five new PNGs and confirm: the three document titles are listed in order, each row shows a drag handle, the "Delete originals" toggle is off in `loaded` and on in `deleteOriginals`, the merge button is enabled, and `darkMode` shows rows on the dark surface rather than a black system default.

If any of these is wrong, fix the view and re-record before continuing — a wrong snapshot committed now becomes the baseline.

- [ ] **Step 5: Run the tests again to verify they pass**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets DocumentsFeatureTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/DocumentsFeature/DocumentBulkEdit/Merge/DocumentBulkEditMergeView.swift \
        Modules/DocumentsFeatureTests/DocumentBulkEdit/Merge/DocumentBulkEditMergeViewTests.swift \
        Snapshots/DocumentsFeatureTests/DocumentBulkEditMergeViewTests
git commit -m "feat: add the document merge sheet"
```

---

### Task 8: Wire merge into the document list

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentBulkEditMergeReducer` and `DocumentBulkEditMergeView` (Tasks 6, 7), `.mergeDocuments` (Task 4).
- Produces: the finished feature.

**Background:** Three decisions from the spec land here.

1. Merge goes in the **overflow menu**, not the icon row — the comment in `DocumentListBottomToolbar` records that a sixth icon spans 411pt on a 402pt iPhone 17 Pro and clips.
2. It sits **above the divider**, with Edit title rather than with Delete. It creates a document; it does not destroy one.
3. On `documentsMerged` the list **dismisses and exits selection mode but does not refetch**. The merged document does not exist yet — it is queued through `consume_file` — so a refetch would show nothing new, and if `deleteOriginals` was set the originals are still there until consumption finishes. This is deliberately unlike the five sibling bulk-edit delegates just above it, which do refetch.

- [ ] **Step 1: Write the failing tests**

Add to `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`:

The third test is the load-bearing one. The `TestStore` is exhaustive, so if the reducer returned a refetch effect the test fails on an unreceived action — that is what pins "no refetch after merge".

```swift
    @Test
    func test_view_mergeSelectedButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.mergeSelectedButtonTapped)) {
            $0.destination = .bulkEditMerge(DocumentBulkEditMergeReducer.State(
                selectedDocuments: [1, 2],
                server: $0.server,
                sort: $0.filter.input.sort
            ))
        }
    }

    @Test
    func test_view_mergeSelectedButtonTapped_withOneDocument() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.mergeSelectedButtonTapped))
    }

    @Test
    func test_destination_bulkEditMerge_documentsMerged_exitsSelectionWithoutRefetching() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            destination: .bulkEditMerge(DocumentBulkEditMergeReducer.State(
                selectedDocuments: [1, 2],
                server: .testValue(),
                sort: .init()
            )),
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.destination(.presented(.bulkEditMerge(.delegate(.documentsMerged))))) {
            $0.destination = nil
            $0.documentSelection.isActive = false
            $0.documentSelection.selectedDocuments = []
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets DocumentsFeatureTests`
Expected: FAIL — `type 'DocumentListReducer.Action.View' has no member 'mergeSelectedButtonTapped'`.

- [ ] **Step 3: Add the destination and the view action**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`, add to `enum Destination`, alphabetically:

```swift
        case bulkEditMerge(DocumentBulkEditMergeReducer)
```

placed between `bulkEditDocumentType` and `bulkEditStoragePath`.

Add to `enum View`, alphabetically after `importButtonTapped`:

```swift
            case mergeSelectedButtonTapped
```

- [ ] **Step 4: Handle the view action**

In the `case let .view(viewAction)` switch, add after `case .importButtonTapped`:

```swift
                case .mergeSelectedButtonTapped:
                    guard state.documentSelection.selectedDocuments.count >= 2 else {
                        return .none
                    }
                    state.destination = .bulkEditMerge(DocumentBulkEditMergeReducer.State(
                        selectedDocuments: state.documentSelection.selectedDocuments,
                        server: state.server,
                        sort: state.filter.input.sort
                    ))
                    return .none
```

- [ ] **Step 5: Handle the delegate**

Add a case before the existing `case let .destination(.presented(.bulkEditCorrespondent(…)))` group:

```swift
            // No refetch, unlike the five bulk-edit delegates below: `bulk_edit.merge` queues the
            // merged PDF through `consume_file`, so it does not exist yet, and `delete_originals`
            // only fires once that consumption succeeds. Fetching here would show neither change.
            case .destination(.presented(.bulkEditMerge(.delegate(.documentsMerged)))):
                state.destination = nil
                state.documentSelection.isActive = false
                state.documentSelection.selectedDocuments = []
                return .none
```

- [ ] **Step 6: Add the menu entry and the sheet**

In `Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift`, add a sheet modifier after the `bulkEditDocumentType` one, keeping alphabetical order:

```swift
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditMerge,
                    action: \.destination.bulkEditMerge
                )
            ) { store in
                DocumentBulkEditMergeView(store: store)
                    .presentationDetents([.sheet])
            }
```

In `selectActionsMenu`, add merge above the divider:

```swift
            Menu {
                Button {
                    send(.editTitleButtonTapped)
                } label: {
                    Label(.editTitle, systemImage: "textformat")
                }

                Button {
                    send(.mergeSelectedButtonTapped)
                } label: {
                    Label(.mergeDocuments, systemImage: "arrow.trianglehead.merge")
                }
                .disabled(store.documentSelection.selectedDocuments.count < 2)

                Divider()

                Button(role: .destructive) {
                    send(.deleteSelectedButtonTapped)
                } label: {
                    Label(.deleteDocuments, systemImage: "trash")
                }
            } label: {
                Label(.moreActions, systemImage: "ellipsis.circle")
            }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `tuist test -d "iPhone 17 Pro" --skip-ui-tests --test-targets DocumentsFeatureTests`
Expected: PASS, including the pre-existing `DocumentListReducerTests` and `DocumentListViewTests` snapshots — the toolbar's visible icon row is unchanged, so no snapshot should move.

- [ ] **Step 8: Run the whole suite**

Run: `rm -rf test.xcresult && mise run ci:test`

The `rm` matters: `xcodebuild` refuses to start with `error: Existing file at -resultBundlePath`, and the summary printed afterwards then comes from the *stale* bundle and looks like a pass.

Tuist's **selective testing** also caches per-target results, so after running targets individually this prints "There are no tests to run, finishing early" and the result bundle holds only a subset. For a trustworthy full run:

```bash
rm -rf test.xcresult
tuist test -d "iPhone 17 Pro" --clean --skip-ui-tests --no-selective-testing \
  -T test.xcresult -- -testLanguage en -testRegion DE
xcrun xcresulttool get test-results summary --path test.xcresult
```
Expected: 18 bundles, 863 tests, 0 failures. This includes the integration tests from Tasks 2 and 3 against the docker container.

- [ ] **Step 9: Lint**

Run: `mise run ci:lint`
Expected: clean. Fix anything it reports, especially `///` comments — the project forbids them.

- [ ] **Step 10: Verify in the running app**

`tuist generate --no-open` first — a preceding `tuist test` leaves the project in a testing-only state where the "Less Paper" scheme has no run destination and `build_run_sim` fails with "Supported platforms for the buildables in the current scheme is empty".

Then launch on the simulator, select two documents, open the overflow menu, choose "Merge documents", drag a row to reorder, and merge. Confirm the sheet dismisses, selection mode exits, and after a pull-to-refresh the merged document appears.

This step needs XcodeBuildMCP's UI automation tools, which are **not** enabled in the default configuration (see https://github.com/getsentry/XcodeBuildMCP/blob/main/docs/CONFIGURATION.md). Without them, the closest automated substitute is the `DocumentsAppTests` XCUITest smoke test, which drives the real app against docker:

```bash
CI_UI_TESTS=true tuist test -d "iPhone 17 Pro" --no-selective-testing \
  --test-targets DocumentsAppTests -- -testLanguage en -testRegion DE
```

It confirms the app still launches and lists documents, but it does **not** exercise merge — the merge flow still needs a human, or a new UI test.

- [ ] **Step 11: Commit**

```bash
git add Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift \
        Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift \
        Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift
git commit -m "feat: merge selected documents from the document list"
```

---

## Notes for the reviewer

Two behaviours are deliberate and will look like bugs if you do not know the server:

- **A merge can silently drop a document.** If a selected document is not a PDF and has no archive version, `bulk_edit.merge` logs the failure and excludes it, still returning `"OK"`. The app cannot detect this — `Document` has no `mime_type` and the response body is just `{"result":"OK"}`. `archive_fallback: true` narrows the window as far as a client can.
- **Nothing visibly happens straight after a merge.** The merged document is queued for consumption, so it appears only on the next fetch. This is the same gap `docs/ideas.md` records under "Refresh lists after an import", and closing it is out of scope.
