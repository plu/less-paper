# Global Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a search field to the Documents list that queries paperless-ngx's global search endpoint and shows documents, saved views, tags, correspondents, document types, storage paths and custom fields in sections, where tapping a document opens it and tapping anything else filters the list by it.

**Architecture:** A `DocumentSearchReducer` scoped into the existing `DocumentListReducer` the way `DocumentSelectionReducer` already is, talking back through a `Delegate`. A new `GlobalSearchUseCase` in `ApiInterface`/`ApiImplementation` calls `GET /api/search/`. The view attaches `.searchable` and `.searchSuggestions` to the list that is already on screen, so there is no new navigation, no new list and no new module.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-dependencies, swift-sharing, Get (HTTP), Tuist, swift-snapshot-testing, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-21-global-search-design.md`

## Global Constraints

- **Never write `///` or `/** */` doc comments. Only `//`.** Comment only what is exceptional — a non-obvious constraint, a subtle trap, or a decision that looks wrong until you know the reason. Never restate what the code already says.
- **In a view annotated `@ViewAction(for:)`, call `send(...)`, never `store.send(...)`** — including inside `.task` and other modifiers. It compiles either way and emits a warning, and warnings are errors on CI.
- **Never use `.confirmationDialog`, `.alert` or `ConfirmationDialogState`.** Not needed here; listed because it is a project-wide rule.
- **Every module owns its strings.** New user-facing strings go in `Modules/DocumentsFeature/Resources/Localizable.xcstrings`, in both `en` and `de`, with `"extractionState": "manual"`, keys sorted alphabetically. A module may only use strings from its own catalogue. `type 'LocalizedStringResource' has no member 'x'` and `'import' is inaccessible due to 'internal' protection level` both mean the same thing: add the key to *this* module's catalogue, copying any existing entry verbatim including its translation.
- **Unit tests are Swift Testing** — `@Suite`, `@Test`, `#expect`, `expectNoDifference` from `CustomDump`. **UI tests in `Modules/AppUITests` are XCTest**, subclassing `UITestCase` and using `XCTAssertTrue`. Do not convert either to the other.
- **The minimum query length is 3.** Below that no request is made — the endpoint answers `400 Query must be at least 3 characters`.
- **The debounce is 400 milliseconds**, via `@Dependency(\.continuousClock)`, cancellable with `cancelInFlight: true`.
- **`mise run ci:lint` must pass before pushing.** Five steps under `set -eou pipefail`, so the first failure hides every one after it. `mise run format` fixes the first three mechanically.
- **Warnings are errors on CI only.** Reproduce with `TUIST_WARNINGS_AS_ERRORS=true mise exec -- tuist generate --no-open`; it is read at *generate* time.
- **Point tests at the dev instance**, because Docker is not available in the agent VM:
  ```bash
  export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
  mise exec -- tuist generate --no-open
  ```
  Also read at *generate* time. Export it for the generate and the test, or every test fails on a connection refused against port 9000.
- **The local test command** used throughout:
  ```bash
  mise exec -- tuist test <Scheme> \
    -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" \
    --no-selective-testing \
    -- -testLanguage en -testRegion DE -only-testing:<Target>/<Suite>
  ```
  `TEST_SIMULATOR` (`iPhone 17 Pro`) and `TEST_SIMULATOR_OS` (`27.0`) come from `mise.toml`, so run through `mise`.
- **Commits and the PR title take a Conventional Commits prefix.** PRs are squash merged, so the title becomes the commit on `main` permanently.

## File Structure

| File | Responsibility |
|---|---|
| `Modules/ApiInterface/GlobalSearch/GlobalSearchInput.swift` | the query value object |
| `Modules/ApiInterface/GlobalSearch/GlobalSearchOutput.swift` | the seven decoded arrays |
| `Modules/ApiInterface/GlobalSearch/GlobalSearchUseCase.swift` | the `@DependencyClient` seam |
| `Modules/ApiImplementation/GlobalSearch/GlobalSearchRepository.swift` | `GET /api/search/` |
| `Modules/ApiImplementation/GlobalSearch/GlobalSearchUseCase.swift` | live value; resolves entities against the shared caches |
| `Modules/DocumentsFeature/DocumentSearch/DocumentFilterInput+SearchResult.swift` | what a tapped entity becomes as a filter |
| `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer.swift` | state, actions, delegate |
| `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer+Effect.swift` | debounce, the use-case call, `CancelID` |
| `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer+TestValue.swift` | the `State.testValue()` factory |
| `Modules/DocumentsFeature/DocumentSearch/DocumentSearchResultsView.swift` | the sections |
| `Modules/DocumentsFeature/DocumentSearch/DocumentSearchRowView.swift` | one result row |
| `Modules/Logging/LogRedaction.swift` | *modified* — exact-match key list |

---

### Task 1: The API contract decodes

**Files:**
- Create: `Modules/ApiInterface/GlobalSearch/GlobalSearchInput.swift`
- Create: `Modules/ApiInterface/GlobalSearch/GlobalSearchOutput.swift`
- Test: `Modules/ApiInterfaceTests/GlobalSearch/GlobalSearchOutputTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `GlobalSearchInput(query: String)`; `GlobalSearchOutput` with `correspondents: [Correspondent]`, `customFields: [CustomField]`, `documents: [Document]`, `documentTypes: [DocumentType]`, `savedViews: [SavedView]`, `storagePaths: [StoragePath]`, `tags: [Tag]`, a memberwise `init` in that order, `var isEmpty: Bool`, and `static func testValue(...)` with every parameter defaulting to `[]`.

Background: `JSONDecoder.apiDecoder` applies `.convertFromSnakeCase`, so `saved_views` arrives as `savedViews` with no `CodingKeys` gymnastics. The endpoint also returns `total`, `users`, `groups`, `mail_accounts`, `mail_rules` and `workflows`; none are decoded. `total` counts types this screen does not show, so displaying it would contradict the screen.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiInterfaceTests/GlobalSearch/GlobalSearchOutputTests.swift`:

```swift
@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite(
    .testDependencies()
)
struct GlobalSearchOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "total": 2,
          "documents": [
            {
              "id": 8,
              "correspondent": 7,
              "document_type": 4,
              "storage_path": 3,
              "title": "Puky",
              "content": "KINDERFAHRRAD",
              "tags": [5],
              "created": "2022-04-23",
              "created_date": "2022-04-23",
              "modified": "2026-09-20T11:46:21.299051+02:00",
              "added": "2026-09-20T11:40:21.433921+02:00",
              "archive_serial_number": 5,
              "original_file_name": "Puky.pdf",
              "owner": null,
              "user_can_change": true,
              "notes": [],
              "custom_fields": []
            }
          ],
          "saved_views": [],
          "correspondents": [],
          "document_types": [],
          "storage_paths": [],
          "custom_fields": [],
          "tags": [
            {
              "id": 7,
              "slug": "manual",
              "name": "Manual",
              "color": "#1f78b4",
              "text_color": "#ffffff",
              "match": "",
              "matching_algorithm": 1,
              "is_insensitive": true,
              "is_inbox_tag": false,
              "owner": null,
              "user_can_change": true,
              "parent": null,
              "children": []
            }
          ],
          "users": [],
          "groups": [],
          "mail_rules": [],
          "mail_accounts": [],
          "workflows": []
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(
            GlobalSearchOutput.self,
            from: #require(json.data(using: .utf8))
        )

        #expect(output.documents.map(\.title) == ["Puky"])
        #expect(output.tags.map(\.name) == ["Manual"])
        #expect(output.isEmpty == false)
    }

    // The five types this app has no screen for are not decoded at all, so a payload full of them
    // must reach consumers as nothing.
    @Test
    func decode_ignoresUnsupportedTypes() async throws {
        let json = """
        {
          "total": 5,
          "documents": [],
          "saved_views": [],
          "correspondents": [],
          "document_types": [],
          "storage_paths": [],
          "custom_fields": [],
          "tags": [],
          "users": [{"id": 3, "username": "admin"}],
          "groups": [{"id": 1, "name": "editors"}],
          "mail_rules": [{"id": 1, "name": "rule"}],
          "mail_accounts": [{"id": 1, "name": "account"}],
          "workflows": [{"id": 1, "name": "flow"}]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(
            GlobalSearchOutput.self,
            from: #require(json.data(using: .utf8))
        )

        expectNoDifference(output, .testValue())
        #expect(output.isEmpty)
    }

    // `custom_fields` postdates the search endpoint, so a server that omits the key must decode
    // rather than fail the whole response and break search entirely.
    @Test
    func decode_toleratesMissingCustomFields() async throws {
        let json = """
        {
          "total": 0,
          "documents": [],
          "saved_views": [],
          "correspondents": [],
          "document_types": [],
          "storage_paths": [],
          "tags": []
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(
            GlobalSearchOutput.self,
            from: #require(json.data(using: .utf8))
        )

        expectNoDifference(output, .testValue())
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- tuist test ApiInterface \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE -only-testing:ApiInterfaceTests/GlobalSearchOutputTests
```

Expected: FAIL to compile — `cannot find 'GlobalSearchOutput' in scope`.

- [ ] **Step 3: Write the input**

Create `Modules/ApiInterface/GlobalSearch/GlobalSearchInput.swift`:

```swift
import Foundation

public struct GlobalSearchInput: Codable, Equatable, Sendable {

    public let query: String

    public init(query: String) {
        self.query = query
    }
}

public extension GlobalSearchInput {

    static func testValue(query: String = "manual") -> Self {
        .init(query: query)
    }
}
```

- [ ] **Step 4: Write the output**

Create `Modules/ApiInterface/GlobalSearch/GlobalSearchOutput.swift`:

```swift
import Foundation

public struct GlobalSearchOutput: Equatable, Sendable {

    public let correspondents: [Correspondent]

    public let customFields: [CustomField]

    public let documents: [Document]

    public let documentTypes: [DocumentType]

    public let savedViews: [SavedView]

    public let storagePaths: [StoragePath]

    public let tags: [Tag]

    public init(
        correspondents: [Correspondent],
        customFields: [CustomField],
        documents: [Document],
        documentTypes: [DocumentType],
        savedViews: [SavedView],
        storagePaths: [StoragePath],
        tags: [Tag]
    ) {
        self.correspondents = correspondents
        self.customFields = customFields
        self.documents = documents
        self.documentTypes = documentTypes
        self.savedViews = savedViews
        self.storagePaths = storagePaths
        self.tags = tags
    }

    public var isEmpty: Bool {
        correspondents.isEmpty
            && customFields.isEmpty
            && documents.isEmpty
            && documentTypes.isEmpty
            && savedViews.isEmpty
            && storagePaths.isEmpty
            && tags.isEmpty
    }
}

extension GlobalSearchOutput: Decodable {

    private enum CodingKeys: String, CodingKey {
        case correspondents, customFields, documents, documentTypes, savedViews, storagePaths, tags
    }

    // Every array is optional on read. `custom_fields` postdates the endpoint, and a key this app
    // has not met must not fail the whole response — the alternative is search breaking entirely
    // against a server one version older. `total`, `users`, `groups`, `mail_accounts`,
    // `mail_rules` and `workflows` are deliberately absent: nothing here can act on them.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        correspondents = try container.decodeIfPresent([Correspondent].self, forKey: .correspondents) ?? []
        customFields = try container.decodeIfPresent([CustomField].self, forKey: .customFields) ?? []
        documents = try container.decodeIfPresent([Document].self, forKey: .documents) ?? []
        documentTypes = try container.decodeIfPresent([DocumentType].self, forKey: .documentTypes) ?? []
        savedViews = try container.decodeIfPresent([SavedView].self, forKey: .savedViews) ?? []
        storagePaths = try container.decodeIfPresent([StoragePath].self, forKey: .storagePaths) ?? []
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
    }
}

public extension GlobalSearchOutput {

    static func testValue(
        correspondents: [Correspondent] = [],
        customFields: [CustomField] = [],
        documents: [Document] = [],
        documentTypes: [DocumentType] = [],
        savedViews: [SavedView] = [],
        storagePaths: [StoragePath] = [],
        tags: [Tag] = []
    ) -> Self {
        .init(
            correspondents: correspondents,
            customFields: customFields,
            documents: documents,
            documentTypes: documentTypes,
            savedViews: savedViews,
            storagePaths: storagePaths,
            tags: tags
        )
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Same command as Step 2. Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface/GlobalSearch Modules/ApiInterfaceTests/GlobalSearch
git commit -m "feat: decode the paperless global search response"
```

---

### Task 2: The use case fetches and resolves

**Files:**
- Create: `Modules/ApiInterface/GlobalSearch/GlobalSearchUseCase.swift`
- Create: `Modules/ApiImplementation/GlobalSearch/GlobalSearchRepository.swift`
- Create: `Modules/ApiImplementation/GlobalSearch/GlobalSearchUseCase.swift`
- Test: `Modules/ApiImplementationTests/GlobalSearch/GlobalSearchUseCaseTests.swift`

**Interfaces:**
- Consumes: `GlobalSearchInput`, `GlobalSearchOutput` (Task 1).
- Produces: `@Dependency(\.globalSearch)` with `execute: @Sendable (_ query: String, _ server: Server) async throws -> GlobalSearchOutput`; and, internal to `ApiImplementation`, `@Dependency(\.globalSearchRepository)` with `search: @Sendable (_ input: GlobalSearchInput, _ server: Server) async throws -> GlobalSearchOutput`.

Background: the search payload carries no `document_count`, so a `Tag` decoded from it arrives with `documentCount: 0`. That value flows into `filter.input.tag.selection` and is then rendered by the filter sheet, so the live use case swaps in the cached entity where there is one. Documents and saved views are used as decoded.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiImplementationTests/GlobalSearch/GlobalSearchUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct GlobalSearchUseCaseTests {

    @Test
    func execute_passesTheQueryThrough() async throws {
        try await withDependencies {
            $0.globalSearchRepository.search = { input, _ in
                #expect(input.query == "manual")
                return .testValue(tags: [.testValue(id: 7, name: "Manual")])
            }
        } operation: {
            let output = try await GlobalSearchUseCase.liveValue.execute(
                query: "manual",
                server: .testValue()
            )

            #expect(output.tags.map(\.name) == ["Manual"])
        }
    }

    // The search payload has no document_count, so a tag taken straight from it would carry 0 into
    // the filter sheet. The cached tag is the one with the real count.
    @Test
    func execute_resolvesEntitiesAgainstTheCache() async throws {
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<Tag>

        $tags.withLock {
            $0 = [.testValue(documentCount: 12, id: 7, name: "Manual")]
        }

        try await withDependencies {
            $0.globalSearchRepository.search = { _, _ in
                .testValue(tags: [.testValue(documentCount: 0, id: 7, name: "Manual")])
            }
        } operation: {
            let output = try await GlobalSearchUseCase.liveValue.execute(
                query: "manual",
                server: .testValue()
            )

            #expect(output.tags.map(\.documentCount) == [12])
        }
    }

    // A tag created since the cache was last refreshed still has to appear in the results.
    @Test
    func execute_keepsEntitiesTheCacheHasNotSeen() async throws {
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<Tag>

        $tags.withLock { $0 = [] }

        try await withDependencies {
            $0.globalSearchRepository.search = { _, _ in
                .testValue(tags: [.testValue(id: 99, name: "Brand New")])
            }
        } operation: {
            let output = try await GlobalSearchUseCase.liveValue.execute(
                query: "brand",
                server: .testValue()
            )

            #expect(output.tags.map(\.name) == ["Brand New"])
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mise exec -- tuist test ApiImplementation \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE -only-testing:ApiImplementationTests/GlobalSearchUseCaseTests
```

Expected: FAIL to compile — `cannot find 'GlobalSearchUseCase' in scope`.

- [ ] **Step 3: Write the use-case seam**

Create `Modules/ApiInterface/GlobalSearch/GlobalSearchUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GlobalSearchUseCase: Sendable {

    public var execute: @Sendable (
        _ query: String,
        _ server: Server
    ) async throws -> GlobalSearchOutput
}

extension GlobalSearchUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var globalSearch: GlobalSearchUseCase {
        get { self[GlobalSearchUseCase.self] }
        set { self[GlobalSearchUseCase.self] = newValue }
    }
}
```

- [ ] **Step 4: Write the repository**

Create `Modules/ApiImplementation/GlobalSearch/GlobalSearchRepository.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct GlobalSearchRepository: Sendable {

    var search: @Sendable (
        _ input: GlobalSearchInput,
        _ server: Server
    ) async throws -> GlobalSearchOutput
}

extension GlobalSearchRepository: TestDependencyKey {

    static let previewValue = Self(
        search: { _, _ in .testValue() }
    )

    static let testValue = Self(
        search: { _, _ in .testValue() }
    )
}

extension DependencyValues {

    var globalSearchRepository: GlobalSearchRepository {
        get { self[GlobalSearchRepository.self] }
        set { self[GlobalSearchRepository.self] = newValue }
    }
}

extension GlobalSearchRepository: DependencyKey {
    static let liveValue = Self(
        search: search(input:server:)
    )
}

private extension GlobalSearchRepository {

    static func search(
        input: GlobalSearchInput,
        server: Server
    ) async throws -> GlobalSearchOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }
}

private extension Request where Response == GlobalSearchOutput {

    init(input: GlobalSearchInput) {
        self.init(
            path: "/api/search/",
            method: .get,
            query: [("query", input.query)]
        )
    }
}
```

- [ ] **Step 5: Write the live use case**

Create `Modules/ApiImplementation/GlobalSearch/GlobalSearchUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GlobalSearchUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(query:server:)
    )
}

private extension GlobalSearchUseCase {

    static func execute(
        query: String,
        server: Server
    ) async throws -> GlobalSearchOutput {
        @Dependency(\.globalSearchRepository)
        var repository

        let output = try await repository.search(
            input: .init(query: query),
            server: server
        )

        @Shared(.correspondents(server))
        var correspondents: IdentifiedArrayOf<Correspondent>

        @Shared(.customFields(server))
        var customFields: IdentifiedArrayOf<CustomField>

        @Shared(.documentTypes(server))
        var documentTypes: IdentifiedArrayOf<DocumentType>

        @Shared(.storagePaths(server))
        var storagePaths: IdentifiedArrayOf<StoragePath>

        @Shared(.tags(server))
        var tags: IdentifiedArrayOf<Tag>

        return .init(
            correspondents: resolve(output.correspondents, in: correspondents),
            customFields: resolve(output.customFields, in: customFields),
            documents: output.documents,
            documentTypes: resolve(output.documentTypes, in: documentTypes),
            savedViews: output.savedViews,
            storagePaths: resolve(output.storagePaths, in: storagePaths),
            tags: resolve(output.tags, in: tags)
        )
    }

    // /api/search/ omits document_count, so an entity taken straight from it would carry 0 into the
    // filter sheet. The cached copy is the complete one; the decoded copy is the fallback for
    // anything created since the cache was last refreshed.
    static func resolve<Value: Identifiable>(
        _ values: [Value],
        in cache: IdentifiedArrayOf<Value>
    ) -> [Value] {
        values.map { cache[id: $0.id] ?? $0 }
    }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Same command as Step 2. Expected: PASS, 3 tests.

- [ ] **Step 7: Commit**

```bash
git add Modules/ApiInterface/GlobalSearch Modules/ApiImplementation/GlobalSearch Modules/ApiImplementationTests/GlobalSearch
git commit -m "feat: add a global search use case over /api/search/"
```

---

### Task 3: The search term never reaches the diagnostics file

**Files:**
- Modify: `Modules/Logging/LogRedaction.swift`
- Test: `Modules/LoggingTests/LogRedactionTests.swift`

**Interfaces:**
- Consumes: nothing. Produces nothing other tasks reference — independently shippable.

Background: `LogRedaction.sensitiveKeys` matches query item names by *containment*, so adding `"query"` there would also redact `custom_field_query`, whose value is genuinely diagnostic for the filter feature. `ApiClientDelegate.swift:141` logs one line per failed request including the redacted path, so without this a failed search writes the user's search term — as often a person's name as a word — into the file they hand to support.

- [ ] **Step 1: Write the failing test**

Append inside the existing suite in `Modules/LoggingTests/LogRedactionTests.swift`:

```swift
    // A failed /api/search/ would otherwise write the user's search term into the file they share
    // with support, and a term is as often a person's name as it is a word.
    @Test
    func redactUrl_redactsSearchTerms() throws {
        let url = try #require(URL(string: "https://example.com/api/search/?query=Mustermann"))

        #expect(LogRedaction.redact(url) == "/api/search/?query=<redacted>")
    }

    @Test
    func redactUrl_redactsAutocompleteTerms() throws {
        let url = try #require(URL(string: "https://example.com/api/search/autocomplete/?term=Muster"))

        #expect(LogRedaction.redact(url) == "/api/search/autocomplete/?term=<redacted>")
    }

    // The containment list would have taken `custom_field_query` with it, and which filter was
    // applied when a request failed is the whole point of that log line.
    @Test
    func redactUrl_keepsCustomFieldQuery() throws {
        let url = try #require(
            URL(string: "https://example.com/api/documents/?custom_field_query=exists")
        )

        #expect(LogRedaction.redact(url).contains("custom_field_query=exists"))
        #expect(LogRedaction.redact(url).contains(LogRedaction.placeholder) == false)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mise exec -- tuist test Logging \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE -only-testing:LoggingTests/LogRedactionTests
```

Expected: FAIL — `redactUrl_redactsSearchTerms` gets `/api/search/?query=Mustermann`.

- [ ] **Step 3: Add the exact-match list**

In `Modules/Logging/LogRedaction.swift`, add below `sensitiveKeys`:

```swift
    /// Query items whose value is never written, matched by exact name rather than by containment.
    /// `query` cannot join `sensitiveKeys`: that list matches by containment, so it would take
    /// `custom_field_query` with it — and which filter was applied is exactly what a failed
    /// request needs to say.
    static let exactSensitiveKeys = [
        "query",
        "term",
    ]
```

and replace `isSensitive(_:)` with:

```swift
    static func isSensitive(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        if exactSensitiveKeys.contains(lowercased) {
            return true
        }
        return sensitiveKeys.contains { lowercased.contains($0) }
    }
```

Note the file's existing comments use `///` on these declarations. That is pre-existing style in `Logging`; match the surrounding file rather than converting it, and use `//` for anything new you add elsewhere.

- [ ] **Step 4: Run the test to verify it passes**

Same command as Step 2. Expected: PASS, including every pre-existing test in the suite.

- [ ] **Step 5: Commit**

```bash
git add Modules/Logging/LogRedaction.swift Modules/LoggingTests/LogRedactionTests.swift
git commit -m "fix: keep search terms out of the diagnostics log"
```

---

### Task 4: A tapped entity becomes a filter

**Files:**
- Create: `Modules/DocumentsFeature/DocumentSearch/DocumentFilterInput+SearchResult.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentSearch/DocumentFilterInputSearchResultTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: five factories on `DocumentFilterInput`, each returning an input with everything else at its default:
  - `static func searchResult(correspondent: Correspondent) -> Self`
  - `static func searchResult(customField: CustomField) -> Self`
  - `static func searchResult(documentType: DocumentType) -> Self`
  - `static func searchResult(storagePath: StoragePath) -> Self`
  - `static func searchResult(tag: Tag) -> Self`

Background: `DocumentFilterInput` lives in `Modules/DocumentsFeature/DocumentFilter/DocumentFilterInput.swift`; its `ListFilter` and `TagFilter` members are internal, which is fine from the same module. A tap **replaces** the filter, so each factory starts from `Self()`. `CustomFieldQuery` atoms are built as `.atom(.init(field:op:value:))` — the shape `applyLegacyCustomFieldIds` already uses in that same file.

- [ ] **Step 1: Write the failing test**

Create `Modules/DocumentsFeatureTests/DocumentSearch/DocumentFilterInputSearchResultTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct DocumentFilterInputSearchResultTests {

    @Test
    func searchResult_tag() {
        let tag = Tag.testValue(id: 7, name: "Manual")

        let input = DocumentFilterInput.searchResult(tag: tag)

        #expect(input.tag.rule == .any)
        #expect(input.tag.selection.any == [tag])
        #expect(input.filterRules == [.init(ruleType: .hasTagsAny, value: "7")])
    }

    @Test
    func searchResult_correspondent() {
        let correspondent = Correspondent.testValue(id: 4)

        let input = DocumentFilterInput.searchResult(correspondent: correspondent)

        #expect(input.correspondent.rule == .include)
        #expect(input.correspondent.selection == [correspondent])
        #expect(input.filterRules == [.init(ruleType: .hasCorrespondentAny, value: "4")])
    }

    @Test
    func searchResult_documentType() {
        let documentType = DocumentType.testValue(id: 5)

        let input = DocumentFilterInput.searchResult(documentType: documentType)

        #expect(input.documentType.rule == .include)
        #expect(input.documentType.selection == [documentType])
        #expect(input.filterRules == [.init(ruleType: .hasDocumentTypeAny, value: "5")])
    }

    @Test
    func searchResult_storagePath() {
        let storagePath = StoragePath.testValue(id: 3)

        let input = DocumentFilterInput.searchResult(storagePath: storagePath)

        #expect(input.storagePath.rule == .include)
        #expect(input.storagePath.selection == [storagePath])
        #expect(input.filterRules == [.init(ruleType: .hasStoragePathAny, value: "3")])
    }

    @Test
    func searchResult_customField() {
        let customField = CustomField.testValue(id: 2, name: "Reference")

        let input = DocumentFilterInput.searchResult(customField: customField)

        #expect(input.customFieldQuery == .atom(.init(field: 2, op: .exists, value: .bool(true))))
    }

    // A tap replaces the filter rather than adding to it, so nothing else may survive in what it
    // produces.
    @Test
    func searchResult_leavesEverythingElseAtItsDefault() {
        let input = DocumentFilterInput.searchResult(tag: .testValue(id: 7))

        #expect(input.searchValue.isEmpty)
        #expect(input.searchType == DocumentFilterInput().searchType)
        #expect(input.correspondent.selection.isEmpty)
        #expect(input.documentType.selection.isEmpty)
        #expect(input.storagePath.selection.isEmpty)
        #expect(input.customFieldQuery == nil)
        #expect(input.unsupportedFilterRules.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mise exec -- tuist test DocumentsFeature \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE \
     -only-testing:DocumentsFeatureTests/DocumentFilterInputSearchResultTests
```

Expected: FAIL to compile — `type 'DocumentFilterInput' has no member 'searchResult'`.

- [ ] **Step 3: Write the factories**

Create `Modules/DocumentsFeature/DocumentSearch/DocumentFilterInput+SearchResult.swift`:

```swift
import ApiInterface
import CorrespondentsFeature
import DocumentTypesFeature
import Foundation
import StoragePathsFeature
import TagsFeature

// Each of these replaces the filter rather than adding to it, which is what the web client does and
// what keeps the result of a tap describable in one line: documents that have this thing.
extension DocumentFilterInput {

    static func searchResult(correspondent: Correspondent) -> Self {
        var input = Self()
        input.correspondent.rule = .include
        input.correspondent.selection = [correspondent]
        return input
    }

    static func searchResult(customField: CustomField) -> Self {
        var input = Self()
        input.customFieldQuery = .atom(.init(field: customField.id, op: .exists, value: .bool(true)))
        return input
    }

    static func searchResult(documentType: DocumentType) -> Self {
        var input = Self()
        input.documentType.rule = .include
        input.documentType.selection = [documentType]
        return input
    }

    static func searchResult(storagePath: StoragePath) -> Self {
        var input = Self()
        input.storagePath.rule = .include
        input.storagePath.selection = [storagePath]
        return input
    }

    static func searchResult(tag: Tag) -> Self {
        var input = Self()
        input.tag.rule = .any
        input.tag.selection.any = [tag]
        return input
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Same command as Step 2. Expected: PASS, 6 tests.

If `searchResult_customField` fails on the `field:` argument type, read `CustomFieldQueryAtom`'s initialiser and pass `customField.id` in whatever form it takes. Do not change the atom to suit the call site.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature/DocumentSearch Modules/DocumentsFeatureTests/DocumentSearch
git commit -m "feat: turn a search result into a document filter"
```

---

### Task 5: The search reducer

**Files:**
- Create: `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer+Effect.swift`
- Create: `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentSearch/DocumentSearchReducerTests.swift`

**Interfaces:**
- Consumes: `@Dependency(\.globalSearch)` (Task 2); `DocumentFilterInput.searchResult(...)` (Task 4).
- Produces:
  - `DocumentSearchReducer.State` with `var error: String?`, `var isLoading: Bool`, `var results: GlobalSearchOutput?`, `var searchText: String`, `let server: Server`, `var trimmedQuery: String`, `var hasQuery: Bool`, and a public memberwise `init`.
  - `Action.Delegate`: `documentTapped(Document.Id)`, `filterRequested(DocumentFilterInput)`, `queryCommitted(String)`, `savedViewTapped(SavedView)`.
  - `Action.View`: `correspondentTapped(Correspondent)`, `customFieldTapped(CustomField)`, `documentTapped(Document)`, `documentTypeTapped(DocumentType)`, `savedViewTapped(SavedView)`, `searchTextChanged(String)`, `storagePathTapped(StoragePath)`, `submitted`, `tagTapped(Tag)`.
  - `DocumentSearchReducer.State.testValue(...)` and `static let minimumQueryLength = 3`.

**Two decisions here that look wrong until you know why — do not "simplify" them:**

1. **`searchTextChanged(String)` is an explicit view action, not a `BindableAction` binding.** `DocumentFilterReducer.swift:246` records why: `$store.input.searchValue` is a chained lookup, so the store only ever sees `.binding(.set(\.input, …))` with the whole value — a `\.input.searchValue` case never matches. The same applies through a scope: `$store.search.searchText` writes through the *parent's* `BindingReducer` straight into child state and the debounce never fires. The view builds an explicit `Binding` instead, in Task 7.
2. **The flag is `isLoading`, not `isSearching`**, so it cannot be confused with SwiftUI's `\.isSearching` environment value, which the fallback in Task 7 may end up reading.

The reducer takes no `Logging` dependency and `DocumentsFeature` needs none: `ApiClientDelegate.swift:141` already records every failed request, calling itself "the one place that has to remember to log".

- [ ] **Step 1: Write the failing test**

Create `Modules/DocumentsFeatureTests/DocumentSearch/DocumentSearchReducerTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DocumentSearchReducerTests {

    @Test
    func view_searchTextChanged_debouncesThenSearches() async throws {
        let clock = TestClock()
        let output = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in output }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = output
        }
    }

    // Under three characters the endpoint answers 400, so the request is never made at all.
    @Test
    func view_searchTextChanged_shortQueryMakesNoRequest() async throws {
        let clock = TestClock()

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: .testValue(tags: [.testValue(id: 7, name: "Manual")])
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in
                Issue.record("no request may be made below the minimum query length")
                return .testValue()
            }
        }

        await store.send(.view(.searchTextChanged("ma"))) {
            $0.searchText = "ma"
            $0.isLoading = false
            $0.results = nil
        }

        await clock.advance(by: .milliseconds(400))
    }

    @Test
    func view_searchTextChanged_coalescesKeystrokes() async throws {
        let clock = TestClock()
        let output = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])
        let queries = LockIsolated([String]())

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { query, _ in
                queries.withValue { $0.append(query) }
                return output
            }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }
        await clock.advance(by: .milliseconds(200))
        await store.send(.view(.searchTextChanged("manu"))) {
            $0.searchText = "manu"
        }
        await clock.advance(by: .milliseconds(400))

        await store.receive(\.searchDebounced)
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = output
        }

        #expect(queries.value == ["manu"])
    }

    // The query is read when searchDebounced lands rather than captured when it is scheduled, so a
    // keystroke inside the window searches for what is on screen, not what was.
    @Test
    func searchDebounced_usesTheTrimmedQuery() async throws {
        let clock = TestClock()
        let queries = LockIsolated([String]())

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { query, _ in
                queries.withValue { $0.append(query) }
                return .testValue()
            }
        }

        await store.send(.view(.searchTextChanged("  manual  "))) {
            $0.searchText = "  manual  "
            $0.isLoading = true
        }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.results) {
            $0.isLoading = false
            $0.results = .testValue()
        }

        #expect(queries.value == ["manual"])
    }

    // A failed lookup must not blank the results out from under someone still reading them.
    @Test
    func error_keepsPreviousResults() async throws {
        let clock = TestClock()
        let previous = GlobalSearchOutput.testValue(tags: [.testValue(id: 7, name: "Manual")])

        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            results: previous
        )) {
            DocumentSearchReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.globalSearch.execute = { _, _ in throw SearchTestError.failed }
        }

        await store.send(.view(.searchTextChanged("man"))) {
            $0.searchText = "man"
            $0.isLoading = true
        }

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.error) {
            $0.isLoading = false
            $0.error = SearchTestError.failed.localizedDescription
        }

        #expect(store.state.results == previous)
    }

    @Test
    func view_documentTapped_delegates() async throws {
        let document = Document.testValue(id: 8)
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.documentTapped(document)))
        await store.receive(\.delegate.documentTapped, document.id)
    }

    @Test
    func view_tagTapped_delegatesAFilter() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.tagTapped(tag)))
        await store.receive(\.delegate.filterRequested, .searchResult(tag: tag))
    }

    @Test
    func view_correspondentTapped_delegatesAFilter() async throws {
        let correspondent = Correspondent.testValue(id: 4)
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.correspondentTapped(correspondent)))
        await store.receive(\.delegate.filterRequested, .searchResult(correspondent: correspondent))
    }

    @Test
    func view_savedViewTapped_delegates() async throws {
        let savedView = SavedView.testValue()
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue()) {
            DocumentSearchReducer()
        }

        await store.send(.view(.savedViewTapped(savedView)))
        await store.receive(\.delegate.savedViewTapped, savedView)
    }

    @Test
    func view_submitted_delegatesTheQuery() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "manual"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.submitted))
        await store.receive(\.delegate.queryCommitted, "manual")
    }

    // Submitting two characters would put a filter on screen the results overlay never showed.
    @Test
    func view_submitted_ignoresAShortQuery() async throws {
        let store = TestStore(initialState: DocumentSearchReducer.State.testValue(
            searchText: "ma"
        )) {
            DocumentSearchReducer()
        }

        await store.send(.view(.submitted))
    }
}

private enum SearchTestError: Error {
    case failed
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mise exec -- tuist test DocumentsFeature \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE -only-testing:DocumentsFeatureTests/DocumentSearchReducerTests
```

Expected: FAIL to compile — `cannot find 'DocumentSearchReducer' in scope`.

- [ ] **Step 3: Write the reducer**

Create `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import CorrespondentsFeature
import DocumentTypesFeature
import Foundation
import SavedViewsFeature
import StoragePathsFeature
import TagsFeature

@Reducer
public struct DocumentSearchReducer: Sendable {

    // The endpoint answers `400 Query must be at least 3 characters`, so this is the server's rule
    // rather than a chosen one, and the request is simply not made below it.
    static let minimumQueryLength = 3

    public enum Action: ViewAction {
        case delegate(Delegate)
        case error(Error)
        case results(GlobalSearchOutput)
        case searchDebounced
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentTapped(Document.Id)
            case filterRequested(DocumentFilterInput)
            case queryCommitted(String)
            case savedViewTapped(SavedView)
        }

        public enum View {
            case correspondentTapped(Correspondent)
            case customFieldTapped(CustomField)
            case documentTapped(Document)
            case documentTypeTapped(DocumentType)
            case savedViewTapped(SavedView)
            case searchTextChanged(String)
            case storagePathTapped(StoragePath)
            case submitted
            case tagTapped(Tag)
        }
    }

    @ObservableState
    public struct State: Equatable {

        var error: String?

        var isLoading = false

        var results: GlobalSearchOutput?

        var searchText = ""

        let server: Server

        var trimmedQuery: String {
            searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var hasQuery: Bool {
            trimmedQuery.count >= DocumentSearchReducer.minimumQueryLength
        }

        public init(
            error: String? = nil,
            isLoading: Bool = false,
            results: GlobalSearchOutput? = nil,
            searchText: String = "",
            server: Server
        ) {
            self.error = error
            self.isLoading = isLoading
            self.results = results
            self.searchText = searchText
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
            case let .error(error):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none
            case let .results(output):
                state.error = nil
                state.isLoading = false
                state.results = output
                return .none
            // Reading state at delivery rather than capturing it: a keystroke inside the debounce
            // window would otherwise search for text the user has already moved on from.
            case .searchDebounced:
                return .runGlobalSearch(query: state.trimmedQuery, server: state.server)
            case let .view(.correspondentTapped(correspondent)):
                return .send(.delegate(.filterRequested(.searchResult(correspondent: correspondent))))
            case let .view(.customFieldTapped(customField)):
                return .send(.delegate(.filterRequested(.searchResult(customField: customField))))
            case let .view(.documentTapped(document)):
                return .send(.delegate(.documentTapped(document.id)))
            case let .view(.documentTypeTapped(documentType)):
                return .send(.delegate(.filterRequested(.searchResult(documentType: documentType))))
            case let .view(.savedViewTapped(savedView)):
                return .send(.delegate(.savedViewTapped(savedView)))
            case let .view(.searchTextChanged(searchText)):
                state.searchText = searchText
                guard state.hasQuery else {
                    state.error = nil
                    state.isLoading = false
                    state.results = nil
                    return .runCancelSearch()
                }
                state.isLoading = true
                return .runSearchDebounce()
            case let .view(.storagePathTapped(storagePath)):
                return .send(.delegate(.filterRequested(.searchResult(storagePath: storagePath))))
            case .view(.submitted):
                guard state.hasQuery else {
                    return .none
                }
                return .send(.delegate(.queryCommitted(state.trimmedQuery)))
            case let .view(.tagTapped(tag)):
                return .send(.delegate(.filterRequested(.searchResult(tag: tag))))
            }
        }
    }

    public init() {}
}
```

- [ ] **Step 4: Write the effects**

Create `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentSearchReducer.Action {

    static func runCancelSearch() -> Self {
        .cancel(id: CancelID.search)
    }

    static func runGlobalSearch(query: String, server: Server) -> Self {
        .run { send in
            @Dependency(\.globalSearch.execute)
            var globalSearch

            try await send(.results(globalSearch(query, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    // Carries no query on purpose: the reducer reads state when `searchDebounced` lands.
    static func runSearchDebounce() -> Self {
        @Dependency(\.continuousClock)
        var clock

        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            await send(.searchDebounced)
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}

// One id for the debounce and the request together, unlike the two ids DocumentFilterReducer keeps.
// A keystroke has to cancel a request already in flight as well as a pending sleep, and a second id
// would leave the older request to land after the newer one.
private enum CancelID {
    case search
}
```

- [ ] **Step 5: Write the test value**

Create `Modules/DocumentsFeature/DocumentSearch/DocumentSearchReducer+TestValue.swift`:

```swift
import ApiInterface
import Foundation

extension DocumentSearchReducer.State {

    static func testValue(
        error: String? = nil,
        isLoading: Bool = false,
        results: GlobalSearchOutput? = nil,
        searchText: String = "",
        server: Server = .testValue()
    ) -> Self {
        .init(
            error: error,
            isLoading: isLoading,
            results: results,
            searchText: searchText,
            server: server
        )
    }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Same command as Step 2. Expected: PASS, 11 tests.

- [ ] **Step 7: Commit**

```bash
git add Modules/DocumentsFeature/DocumentSearch Modules/DocumentsFeatureTests/DocumentSearch
git commit -m "feat: add the document search reducer"
```

---

### Task 6: Wire the reducer into the document list

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: everything from Task 5.
- Produces: `DocumentListReducer.State.search: DocumentSearchReducer.State` and `DocumentListReducer.Action.search(DocumentSearchReducer.Action)`.

Background: read `DocumentListReducer.swift` first. Its `State.init` already builds `documentSelection` from `server`; follow that shape. Reuse the existing `.openDocument(id)` and `.view(.savedViewButtonTapped(_))` handlers rather than writing new effects. `filter.savedView` must be cleared when a filter is applied, or `navigationTitle` keeps naming a saved view whose rules are no longer in force.

- [ ] **Step 1: Write the failing test**

Append to `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`:

```swift
    @Test
    func search_delegate_filterRequested_replacesTheFilter() async throws {
        let tag = Tag.testValue(id: 7, name: "Manual")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(savedView: .testValue())
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.filterRequested(.searchResult(tag: tag))))) {
            $0.filter.input = .searchResult(tag: tag)
            $0.filter.savedView = nil
        }
    }

    @Test
    func search_delegate_queryCommitted_runsATitleAndContentSearch() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in .testValue() }
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.queryCommitted("manual")))) {
            $0.filter.input.searchType = .titleContent
            $0.filter.input.searchValue = "manual"
        }
    }

    @Test
    func search_delegate_documentTapped_opensTheDocument() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        }
        store.exhaustivity = .off

        await store.send(.search(.delegate(.documentTapped(Document.Id(rawValue: 1)))))
        await store.receive(\.openDocument)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mise exec -- tuist test DocumentsFeature \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE -only-testing:DocumentsFeatureTests/DocumentListReducerTests
```

Expected: FAIL to compile — `type 'DocumentListReducer.Action' has no member 'search'`.

- [ ] **Step 3: Add the state, the action and the scope**

In `DocumentListReducer.swift`:

1. Add to `Action`, keeping the cases alphabetical: `case search(DocumentSearchReducer.Action)`.
2. Add to `State`: `var search: DocumentSearchReducer.State`.
3. In `State.init`, add `search: DocumentSearchReducer.State? = nil` and
   `self.search = search ?? DocumentSearchReducer.State(server: server)`, mirroring `documentSelection`.
4. In `body`, beside the existing scopes:

```swift
        Scope(state: \.search, action: \.search) {
            DocumentSearchReducer()
        }
```

5. Add these to the `Reduce` block:

```swift
            case let .search(.delegate(.documentTapped(id))):
                return .send(.openDocument(id))
            // The saved view goes with it: leaving it set would keep the navigation title naming a
            // view whose rules are no longer the ones being applied.
            case let .search(.delegate(.filterRequested(input))):
                state.filter.input = input
                state.filter.savedView = nil
                return .runGetDocuments(
                    filterRules: state.filter.input.filterRules,
                    server: state.server,
                    sortDirection: state.filter.input.sort.direction,
                    sortField: state.filter.input.sort.field
                )
            case let .search(.delegate(.queryCommitted(query))):
                state.filter.input.searchType = .titleContent
                state.filter.input.searchValue = query
                return .runGetDocuments(
                    filterRules: state.filter.input.filterRules,
                    server: state.server,
                    sortDirection: state.filter.input.sort.direction,
                    sortField: state.filter.input.sort.field
                )
            case let .search(.delegate(.savedViewTapped(savedView))):
                return .send(.view(.savedViewButtonTapped(savedView)))
            case .search:
                return .none
```

`case .search:` must come **after** the four delegate cases. Swift matches in order, so a bare
`case .search` above them swallows every one.

- [ ] **Step 4: Update the test value**

In `DocumentListReducer+TestValue.swift`, add `search: DocumentSearchReducer.State? = nil` to the
parameter list in alphabetical position and pass it to `init`.

- [ ] **Step 5: Run the test to verify it passes**

Same command as Step 2. Expected: PASS — the three new tests plus every pre-existing test in the suite.

- [ ] **Step 6: Commit**

```bash
git add Modules/DocumentsFeature/DocumentList Modules/DocumentsFeatureTests/DocumentList
git commit -m "feat: apply a search result to the document filter"
```

---

### Task 7: The search field and the results

**Files:**
- Create: `Modules/DocumentsFeature/DocumentSearch/DocumentSearchRowView.swift`
- Create: `Modules/DocumentsFeature/DocumentSearch/DocumentSearchResultsView.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListView.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentSearch/DocumentSearchResultsViewTests.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentSearch/DocumentSearchTextBindingTests.swift`

**Interfaces:**
- Consumes: `DocumentSearchReducer` (Task 5), the `search` scope (Task 6).
- Produces: `DocumentSearchResultsView(store: StoreOf<DocumentSearchReducer>)`, and `DocumentListView.searchTextBinding: Binding<String>` (non-private, so the binding test can reach it — `DocumentFilterView.searchValueBinding` is non-private for exactly this reason).

**Do not touch the toolbar.** Its magnifying glass keeps opening the filter sheet. Re-iconing it was considered and declined in the spec.

Icons, taken from the screens that already own each type (`SettingListView.swift:53-106`): correspondents `person`, custom fields `list.bullet.rectangle`, document types `document.badge.gearshape`, saved views `line.3.horizontal.decrease`, storage paths `folder`, tags `tag`, documents `document`.

The spacing scale (`.x0` … `.x5`, where `.x3` is 8pt and `.x4` is 16pt) is declared in
`Modules/Components/Extensions/Double+Extensions.swift`, so it arrives with `import Components`,
not `import DesignTokens`. **It stops at `.x5`** — there is no `.x6`. `Color.m3*` is the
`DesignTokens` half. `Document.created` is a `Date`, so `.formatted(date:time:)` applies to it
directly.

Strings to add to `Modules/DocumentsFeature/Resources/Localizable.xcstrings`, `en` and `de`, `"extractionState": "manual"`, keys sorted alphabetically. Check first whether the module already has any of these keys and reuse rather than duplicate.

| Key | en | de |
|---|---|---|
| `search` | Search | Suchen |
| `searchNoResults` | No results | Keine Ergebnisse |
| `searchSectionCorrespondents` | Correspondents | Korrespondenten |
| `searchSectionCustomFields` | Custom fields | Benutzerdefinierte Felder |
| `searchSectionDocuments` | Documents | Dokumente |
| `searchSectionDocumentTypes` | Document types | Dokumenttypen |
| `searchSectionSavedViews` | Saved views | Gespeicherte Ansichten |
| `searchSectionStoragePaths` | Storage paths | Speicherpfade |
| `searchSectionTags` | Tags | Tags |

- [ ] **Step 1: Write the failing binding test**

Create `Modules/DocumentsFeatureTests/DocumentSearch/DocumentSearchTextBindingTests.swift`, modelled
on the existing `DocumentFilterSearchValueBindingTests`:

```swift
@testable import DocumentsFeature

import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DocumentSearchTextBindingTests {

    @Test
    func searchTextBinding_sendsWhenTheValueChanges() async throws {
        let (view, sent) = view(searchText: "ma")

        view.searchTextBinding.wrappedValue = "man"

        #expect(sent.value == ["man"])
    }

    // SwiftUI writes the binding with the value it already holds, both when the field appears and
    // when it tears down. Each redundant write would otherwise cost a 400ms debounce and a request
    // for a search that had not changed.
    @Test
    func searchTextBinding_ignoresRedundantWrites() async throws {
        let (view, sent) = view(searchText: "man")

        view.searchTextBinding.wrappedValue = "man"

        #expect(sent.value.isEmpty)
    }

    @Test
    func searchTextBinding_ignoresTheEmptyWriteOnAppear() async throws {
        let (view, sent) = view(searchText: "")

        view.searchTextBinding.wrappedValue = ""

        #expect(sent.value.isEmpty)
    }

    private func view(searchText: String) -> (DocumentListView, LockIsolated<[String]>) {
        let sent = LockIsolated<[String]>([])
        let store = Store(
            initialState: DocumentListReducer.State.testValue(
                search: .testValue(searchText: searchText)
            )
        ) {
            Reduce<DocumentListReducer.State, DocumentListReducer.Action> { _, action in
                if case let .search(.view(.searchTextChanged(value))) = action {
                    sent.withValue { $0.append(value) }
                }
                return .none
            }
        }
        return (DocumentListView(store: store), sent)
    }
}
```

- [ ] **Step 2: Write the failing snapshot test**

Create `Modules/DocumentsFeatureTests/DocumentSearch/DocumentSearchResultsViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentSearchResultsViewTests {

    @Test
    func testSnapshot_populated() async throws {
        assertSnapshot(
            of: DocumentSearchResultsView(
                store: Store(
                    initialState: DocumentSearchReducer.State.testValue(
                        results: .testValue(
                            correspondents: [.testValue(id: 4)],
                            customFields: [.testValue(id: 2, name: "Reference")],
                            documents: [
                                .testValue(id: 1, title: "Puky"),
                                .testValue(id: 2, title: "W-8BEN"),
                            ],
                            documentTypes: [.testValue(id: 5)],
                            savedViews: [.testValue()],
                            storagePaths: [.testValue(id: 3)],
                            tags: [.testValue(id: 7, name: "Manual")]
                        ),
                        searchText: "man"
                    ),
                    reducer: {
                        DocumentSearchReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_noResults() async throws {
        assertSnapshot(
            of: DocumentSearchResultsView(
                store: Store(
                    initialState: DocumentSearchReducer.State.testValue(
                        results: .testValue(),
                        searchText: "zzz"
                    ),
                    reducer: {
                        DocumentSearchReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        assertSnapshot(
            of: DocumentSearchResultsView(
                store: Store(
                    initialState: DocumentSearchReducer.State.testValue(
                        isLoading: true,
                        searchText: "man"
                    ),
                    reducer: {
                        DocumentSearchReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
```

- [ ] **Step 3: Run both tests to verify they fail**

```bash
mise exec -- tuist test DocumentsFeature \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE \
     -only-testing:DocumentsFeatureTests/DocumentSearchResultsViewTests \
     -only-testing:DocumentsFeatureTests/DocumentSearchTextBindingTests
```

Expected: FAIL to compile — `cannot find 'DocumentSearchResultsView' in scope`.

- [ ] **Step 4: Write the row view**

Create `Modules/DocumentsFeature/DocumentSearch/DocumentSearchRowView.swift`:

```swift
import ApiInterface
import Components
import DesignTokens
import SwiftUI
import TagsFeature

struct DocumentSearchRowView: View {

    var body: some View {
        HStack(spacing: .x3) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.m3Primary)
                .frame(width: .x4)
            if let tag {
                Text(tag.name).tag(tag: tag, font: .body)
            } else {
                Text(title)
                    .foregroundStyle(Color.m3OnSurface)
                    .lineLimit(1)
            }
            Spacer()
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Color.m3Outline)
            }
        }
        .contentShape(.rect)
    }

    init(
        caption: String? = nil,
        systemImage: String,
        tag: Tag? = nil,
        title: String
    ) {
        self.caption = caption
        self.systemImage = systemImage
        self.tag = tag
        self.title = title
    }

    private let caption: String?
    private let systemImage: String
    // Carried rather than rendered as plain text so a tag keeps the colour it has everywhere else
    // in the app; `.tag(tag:font:)` is TagsFeature's own capsule.
    private let tag: Tag?
    private let title: String
}
```

- [ ] **Step 5: Write the results view**

Create `Modules/DocumentsFeature/DocumentSearch/DocumentSearchResultsView.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchResultsView: View {

    var body: some View {
        if let results = store.results {
            if results.isEmpty, store.hasQuery, !store.isLoading {
                Text(.searchNoResults)
                    .foregroundStyle(Color.m3Outline)
            } else {
                // No client-side truncation: the server already caps each list through
                // PAPERLESS_GLOBAL_SEARCH_MAX_RESULTS, and a second cap here would hide results
                // the server chose to send.
                Section(String(localized: .searchSectionDocuments)) {
                    ForEach(results.documents) { document in
                        Button {
                            send(.documentTapped(document))
                        } label: {
                            DocumentSearchRowView(
                                caption: document.created.formatted(date: .numeric, time: .omitted),
                                systemImage: "document",
                                title: document.title
                            )
                        }
                    }
                }
                Section(String(localized: .searchSectionSavedViews)) {
                    ForEach(results.savedViews) { savedView in
                        Button {
                            send(.savedViewTapped(savedView))
                        } label: {
                            DocumentSearchRowView(
                                systemImage: "line.3.horizontal.decrease",
                                title: savedView.name
                            )
                        }
                    }
                }
                Section(String(localized: .searchSectionTags)) {
                    ForEach(results.tags) { tag in
                        Button {
                            send(.tagTapped(tag))
                        } label: {
                            DocumentSearchRowView(systemImage: "tag", tag: tag, title: tag.name)
                        }
                    }
                }
                Section(String(localized: .searchSectionCorrespondents)) {
                    ForEach(results.correspondents) { correspondent in
                        Button {
                            send(.correspondentTapped(correspondent))
                        } label: {
                            DocumentSearchRowView(systemImage: "person", title: correspondent.name)
                        }
                    }
                }
                Section(String(localized: .searchSectionDocumentTypes)) {
                    ForEach(results.documentTypes) { documentType in
                        Button {
                            send(.documentTypeTapped(documentType))
                        } label: {
                            DocumentSearchRowView(
                                systemImage: "document.badge.gearshape",
                                title: documentType.name
                            )
                        }
                    }
                }
                Section(String(localized: .searchSectionStoragePaths)) {
                    ForEach(results.storagePaths) { storagePath in
                        Button {
                            send(.storagePathTapped(storagePath))
                        } label: {
                            DocumentSearchRowView(systemImage: "folder", title: storagePath.name)
                        }
                    }
                }
                Section(String(localized: .searchSectionCustomFields)) {
                    ForEach(results.customFields) { customField in
                        Button {
                            send(.customFieldTapped(customField))
                        } label: {
                            DocumentSearchRowView(
                                systemImage: "list.bullet.rectangle",
                                title: customField.name
                            )
                        }
                    }
                }
            }
        }
    }

    init(store: StoreOf<DocumentSearchReducer>) {
        self.store = store
    }

    let store: StoreOf<DocumentSearchReducer>
}
```

A `Section` whose `ForEach` is empty renders nothing, which is what "omitted when empty" means here — do not add `if !results.tags.isEmpty` guards around each one unless a snapshot shows a stray header.

- [ ] **Step 6: Attach it to the document list**

In `DocumentListView.swift`, add the binding beside the existing private members:

```swift
    // An explicit binding rather than `$store.search.searchText`: that is a chained lookup, so the
    // store would only ever see `.binding(.set(\.search, …))` on the parent, writing straight into
    // child state and never running the debounce. Redundant writes are dropped for the reason
    // DocumentFilterView gives — SwiftUI makes one on appear and one on teardown, and each would
    // cost a 400ms debounce and a request for a search that had not changed.
    var searchTextBinding: Binding<String> {
        Binding(
            get: { store.search.searchText },
            set: {
                guard $0 != store.search.searchText else {
                    return
                }
                store.send(.search(.view(.searchTextChanged($0))))
            }
        )
    }
```

and on the `List` inside `AdaptiveNavigationView`'s `list` closure, beside `.refreshable` and `.task`:

```swift
            .searchable(text: searchTextBinding, prompt: Text(.search))
            .searchSuggestions {
                DocumentSearchResultsView(
                    store: store.scope(state: \.search, action: \.search)
                )
            }
            .onSubmit(of: .search) { store.send(.search(.view(.submitted))) }
```

Two things not to change:

- **No `placement:` argument** — but not for the reason first given here. This step originally said the default would keep the field hidden until the list is pulled down, citing `FavoriteListView`. That precedent does not transfer: `FavoriteListView` declares no toolbar, and `DocumentListView`'s bottom bar changes where iOS 27 puts the field. The field is **visible at rest, at the bottom**; three placement configurations were measured and none hides it. See the spec's "The field is visible at rest" decision for the table. The argument is still omitted because `.automatic` is the configuration that was chosen and verified.
- **`store.send` here, not `send`.** `DocumentListView` is `@ViewAction(for: DocumentListReducer.self)`, so its `send` wraps actions in `.view(…)` — and `.search(…)` is not a view action of the parent. This is the documented exception, not a slip.

`InboxView` is deliberately left alone: a global filter applied there would fight the inbox filter that defines the screen.

- [ ] **Step 7: Record the snapshot references**

```bash
mise run snapshots:record DocumentsFeature \
  --only DocumentsFeatureTests/DocumentSearchResultsViewTests
```

The run ends in `TEST FAILED` and that is the success case — record mode writes the reference and
then raises "Record mode is on" for every assertion. **Open the three recorded PNGs and look at
them before trusting them:** a reference records whatever the code produced, bug included, and that
is how fourteen German references were once recorded showing English captions.

- [ ] **Step 8: Run both tests to verify they pass**

Same command as Step 3. Expected: PASS, 6 tests.

- [ ] **Step 9: Verify the existing Documents references still pass**

```bash
mise exec -- tuist test DocumentsFeature \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE
```

Expected: PASS. A hidden search field should not have changed any existing reference. If one did,
look at the diff before re-recording — it means the field is rendering at rest, which is a bug in
Step 6, not a stale reference.

- [ ] **Step 10: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Snapshots/DocumentsFeatureTests
git commit -m "feat: search documents, tags and correspondents from the document list"
```

**If `.searchSuggestions` fights the design system** — it is system-styled and may refuse
`m3SurfaceContainerLowest` or the row treatment — the fallback in the spec is a child view reading
`@Environment(\.isSearching)` driving an `.overlay` on the list. Switch only on evidence from a
recorded snapshot, not on suspicion, and keep every reducer and test above unchanged: only the
attachment in Step 6 and the container in Step 5 would move.

---

### Task 8: A UI journey through the real thing

**Files:**
- Modify: `Modules/UITestSupport/Screens/DocumentListScreen.swift`
- Create: `Modules/AppUITests/DocumentSearchJourneyTests.swift`

**Interfaces:**
- Consumes: the finished feature.
- Produces: `DocumentListScreen.search(for:)` and `DocumentListScreen.tapSearchResult(_:)`.

Background, all load-bearing:
- **UI tests never mutate global server state.** This journey reads the shared corpus and writes
  nothing, like `DocumentBrowsingJourneyTests` — documents consumed from `docker/consume/` have no
  owner, and the seed's tags, document types and storage paths are unowned too, so every test sees
  the same ones.
- **Never write a helper that deletes all of something.**
- **Never delete the seeded server in a journey.** It is the server the app is running on.
- These tests are **XCTest**, subclassing `UITestCase`, with `XCTAssertTrue` — not Swift Testing.
- Wait on the rows rather than sleeping for the debounce. The comment at
  `DocumentListScreen.swift:40` explains why the harness this replaced stopped sleeping 700ms.

- [ ] **Step 1: Add the screen accessors**

Append to `Modules/UITestSupport/Screens/DocumentListScreen.swift`, inside the struct:

```swift
    // Pulls the list down to reveal the search field, which is hidden at rest by design. The field
    // is in the navigation bar's search drawer, so it is a searchField rather than a textField.
    @discardableResult
    public func search(for text: String) -> Bool {
        let list = app.collectionViews.firstMatch
        guard list.waitForExistence(timeout: timeout) else {
            return false
        }
        list.swipeDown()

        let field = app.searchFields.firstMatch
        guard field.waitUntilHittable(timeout: timeout) else {
            return false
        }
        field.tap()
        app.typeText(text)
        return true
    }

    @discardableResult
    public func tapSearchResult(_ label: String) -> Bool {
        let result = app.buttons.containing(.staticText, identifier: label).firstMatch
        guard result.waitUntilHittable(timeout: timeout) else {
            return false
        }
        result.tap()
        return true
    }
```

- [ ] **Step 2: Write the journey**

Create `Modules/AppUITests/DocumentSearchJourneyTests.swift`:

```swift
import UITestSupport
import XCTest

@MainActor
final class DocumentSearchJourneyTests: UITestCase {

    // Reads the seeded corpus and modifies nothing. The seed's entities are unowned, so the Manual
    // tag is visible to the user this journey runs as — which is what makes the result assertable
    // without creating anything.
    func testSearchingRevealsATagAndFiltersByIt() async throws {
        launch()

        let documents = DocumentListScreen(app: app, timeout: timeout)
        XCTAssertTrue(documents.open(), "Could not open the Documents tab")

        XCTAssertTrue(documents.search(for: "man"), "Could not reveal the search field")

        XCTAssertTrue(
            app.staticTexts["Tags"].waitForExistence(timeout: timeout),
            "Searching for man did not show a Tags section"
        )
        XCTAssertTrue(
            app.staticTexts["Manual"].waitForExistence(timeout: timeout),
            "Searching for man did not offer the Manual tag"
        )

        XCTAssertTrue(documents.tapSearchResult("Manual"), "Could not tap the Manual tag result")

        XCTAssertTrue(
            app.staticTexts["Puky"].waitForExistence(timeout: timeout),
            "Filtering by the Manual tag did not leave Puky in the list"
        )
    }
}
```

If the seeded corpus on the instance under test does not carry a `Manual` tag on the `Puky`
document, check with
`curl -s "$TUIST_PAPERLESS_TEST_URL/api/search/?query=man" -H "Authorization: Token <token>"`
and substitute a tag and document that the seed does pair. Do not create one — that would make this
journey a writer.

- [ ] **Step 3: Run it**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE -only-testing:AppUITests/DocumentSearchJourneyTests
```

Expected: PASS. A connection-refused failure means `TUIST_PAPERLESS_TEST_URL` was not exported for
the *generate*, not just the test.

- [ ] **Step 4: Commit**

```bash
git add Modules/AppUITests Modules/UITestSupport
git commit -m "test: a journey searching for a tag from the document list"
```

---

### Task 9: Green build, green lint

**Files:**
- Possibly modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`

**Interfaces:**
- Consumes: everything. Produces a branch that can be pushed.

Background: no dependency change is *expected*. `DocumentsFeature` already depends on
`ApiInterface`, `Components`, `CorrespondentsFeature`, `CustomFieldsFeature`, `DesignTokens`,
`DocumentTypesFeature`, `SavedViewsFeature`, `StoragePathsFeature` and `TagsFeature`, and the search
reducer takes no `Logging` dependency. But `tuist inspect dependencies --only implicit` is the only
check that catches a target using a module it reaches transitively — it compiles, links and passes
every test — so run it rather than assume.

- [ ] **Step 1: Format**

```bash
mise run format
```

SwiftLint's `--fix` makes real edits, not only whitespace — it rewrites
`aspectRatio(contentMode: .fit)` to `scaledToFit()`, for instance. Re-run the tests for anything it
touched rather than assuming a formatter cannot change behaviour.

- [ ] **Step 2: Lint**

```bash
mise run ci:lint
```

Five steps under `set -eou pipefail`, so the first failure hides every one after it. Expect to fix
and re-run rather than treating one pass as done. If `tuist inspect dependencies --only implicit`
names a target and a missing module, add that line to `Module+Dependencies.swift`.

- [ ] **Step 3: Reproduce the CI warnings-as-errors build**

```bash
TUIST_WARNINGS_AS_ERRORS=true mise exec -- tuist generate --no-open
mise exec -- tuist build "Less Paper"
```

Read at generate time, so a build after a generate without it is warning-tolerant. Regenerate
without the variable afterwards to get back to a tolerant local build.

- [ ] **Step 4: Full unit suite**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- tuist test ApiInterface ApiImplementation DocumentsFeature Logging \
  -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
  -- -testLanguage en -testRegion DE
```

Expected: PASS.

- [ ] **Step 5: Commit any fixes and open the pull request**

The PR title becomes the squashed commit on `main`, permanently. Write it as the line you want in
`git log`:

```
feat: search documents, tags and correspondents from the document list
```

Pushing needs a credential helper, because git does not read `GH_TOKEN`:

```bash
GIT_TERMINAL_PROMPT=0 mise exec -- fnox exec -- git \
  -c 'credential.helper=!f(){ echo username=x-access-token; echo "password=$GH_TOKEN"; };f' \
  push -u origin autocompletion
```
