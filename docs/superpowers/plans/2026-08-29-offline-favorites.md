# Offline Favorites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep chosen documents on the device in full — metadata, notes, custom fields and the PDF — readable with no server in reach, from a Favorites tab with search and pull-to-refresh.

**Architecture:** `FavoriteDocument` records live in a per-server file-backed shared key beside the existing ones; PDFs are files in the app group. A new `FavoritesFeature` module owns the tab and reuses the existing detail screen with three dependencies pointed at the store. Refresh is two phases: one `id__in` request that always writes back the document, then the expensive three only where `modified` moved.

**Tech Stack:** Swift 6, TCA (`ComposableArchitecture`), `swift-sharing` (`@Shared`/`FileStorageKey`), swift-testing (`@Test`/`@Suite`), swift-snapshot-testing, Tuist, PDFKit.

**Spec:** `docs/superpowers/specs/2026-08-29-offline-favorites-design.md`

## Global Constraints

- **Branch:** `feat/favorites`. It must be rebased onto `main` after PR #30 (`chore/settings-tidy`) merges — Task 11 edits the Settings section that PR reorders, and the tip jar must already be `cup.and.saucer` before the heart is taken.
- **Comments:** never `///` or `/** */`, only `//`. Comment only what a reader would otherwise stop and wonder about. (`AGENTS.md`)
- **`@ViewAction` views send with `send(...)`, never `store.send(...)`.**
- **Confirmations** go through `PopupPresenter` / `ConfirmationPopupView`. Never `.alert` or `.confirmationDialog`. Reuse `Components/Popup/DeleteConfirmationPresenter.swift` for "delete a named thing".
- **Strings** live in the *using* module's `Resources/Localizable.xcstrings`, in both `en` and `de`, `"extractionState": "manual"`, keys sorted alphabetically. A key used by two modules is **copied** into both, byte-identical.
- **PR titles are Conventional Commits** — the squash merge makes the title the commit message on `main`.
- **Snapshot references** are re-recorded only by flipping `isEnabled` in `Tuist/ProjectDescriptionHelpers/Extensions/Dictionary+Extensions.swift` to `true`, `tuist generate`, running tests, flipping back, regenerating. Always look at what was recorded.
- **Tests run** as `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`.
- **Generate** after any Tuist manifest change: `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- tuist generate --no-open`.

**Tasks 1–4 are shippable on their own** — they add a tested storage layer with no UI. If you want to land in two PRs, that is the seam.

---

## File Structure

| File | Responsibility |
|---|---|
| `Modules/ApiInterface/Favorites/FavoriteDocument.swift` | the stored record |
| `Modules/ApiInterface/Favorites/FavoritesStore.swift` | `@DependencyClient` over the PDF files on disk |
| `Modules/ApiInterface/Favorites/SaveFavoriteUseCase.swift` | interface |
| `Modules/ApiInterface/Favorites/RemoveFavoriteUseCase.swift` | interface |
| `Modules/ApiInterface/Favorites/RefreshFavoritesUseCase.swift` | interface + `FavoriteRefreshResult` |
| `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift` | add `favorites(_:)` |
| `Modules/ApiImplementation/Favorites/FavoritesStore+Live.swift` | file IO |
| `Modules/ApiImplementation/Favorites/SaveFavoriteUseCase.swift` | fetch + persist |
| `Modules/ApiImplementation/Favorites/RemoveFavoriteUseCase.swift` | delete record + file |
| `Modules/ApiImplementation/Favorites/RefreshFavoritesUseCase.swift` | the two-phase refresh |
| `Modules/DocumentsFeature/DocumentRow/DocumentRowContent.swift` | presentation extracted from `DocumentRowView` |
| `Modules/FavoritesFeature/FavoriteRow/FavoriteRowReducer.swift` + `…View.swift` | one favorite in the list |
| `Modules/FavoritesFeature/FavoriteList/FavoriteListReducer.swift` + `…View.swift` | the tab |
| `Modules/SettingsFeature/FavoriteSettings/FavoriteSettingsReducer.swift` + `…View.swift` | size, redownload, remove all |

---

### Task 1: The record and its shared key

**Files:**
- Create: `Modules/ApiInterface/Favorites/FavoriteDocument.swift`
- Modify: `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`
- Test: `Modules/ApiInterfaceTests/Favorites/FavoriteDocumentTests.swift`

**Interfaces:**
- Consumes: `Document`, `Note`, `DocumentMetadata`, `Server` (all existing in `ApiInterface`).
- Produces: `FavoriteDocument` with `init(document:notes:metadata:pdfByteCount:storedAt:isUnavailable:)`, `var id: Document.Id`, `static func testValue(...) -> FavoriteDocument`; and `SharedReaderKey.favorites(_ server: Server)` defaulting to `[]`.

- [ ] **Step 1: Write the failing test**

`Modules/ApiInterfaceTests/Favorites/FavoriteDocumentTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing

@Suite
struct FavoriteDocumentTests {

    @Test
    func test_idIsTheDocumentId() {
        let favorite = FavoriteDocument.testValue(document: .testValue(id: 7))

        #expect(favorite.id == 7)
    }

    // Not the API coders: JSONEncoder.apiEncoder formats every Date as "yyyy-MM-dd", which would
    // truncate `storedAt` and — far worse — `document.modified`, the field the refresh gate
    // compares. Favorites is the first thing to persist a Document to disk, so it is the first to
    // need a lossless pair.
    @Test
    func test_roundTripsLosslesslyIncludingTimeOfDay() throws {
        let modified = Date(timeIntervalSince1970: 1_756_290_271)
        let favorite = FavoriteDocument.testValue(
            document: .testValue(modified: modified),
            storedAt: modified
        )

        let data = try JSONEncoder.favoritesEncoder.encode(favorite)
        let decoded = try JSONDecoder.favoritesDecoder.decode(FavoriteDocument.self, from: data)

        #expect(decoded == favorite)
        #expect(decoded.document.modified == modified)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ApiInterface -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — `cannot find 'FavoriteDocument' in scope`.

- [ ] **Step 3: Write the record**

`Modules/ApiInterface/Favorites/FavoriteDocument.swift`:

```swift
import Foundation

public struct FavoriteDocument: Codable, Equatable, Hashable, Identifiable, Sendable {

    public var id: Document.Id { document.id }

    public let document: Document

    public let metadata: DocumentMetadata?

    public let notes: [Note]

    public let pdfByteCount: Int

    public let storedAt: Date

    // The `document.modified` at which notes, metadata and the PDF were last successfully fetched.
    // The refresh gate compares against this rather than `document.modified`, because phase one
    // writes the fresh document unconditionally: comparing against that would mean a failed phase
    // two hides itself, and the favorite stays stale until someone hits "Redownload all".
    public let syncedModified: Date

    // Set by a refresh whose id__in response did not include this document. Mutable because it is
    // the one field that changes without the document behind it changing.
    public var isUnavailable: Bool

    public init(
        document: Document,
        metadata: DocumentMetadata?,
        notes: [Note],
        pdfByteCount: Int,
        storedAt: Date,
        syncedModified: Date,
        isUnavailable: Bool = false
    ) {
        self.document = document
        self.metadata = metadata
        self.notes = notes
        self.pdfByteCount = pdfByteCount
        self.storedAt = storedAt
        self.syncedModified = syncedModified
        self.isUnavailable = isUnavailable
    }
}

public extension FavoriteDocument {

    static func testValue(
        document: Document = .testValue(),
        metadata: DocumentMetadata? = .testValue(),
        notes: [Note] = [],
        pdfByteCount: Int = 1024,
        storedAt: Date = Date(timeIntervalSince1970: 1_756_290_271),
        syncedModified: Date? = nil,
        isUnavailable: Bool = false
    ) -> Self {
        .init(
            document: document,
            metadata: metadata,
            notes: notes,
            pdfByteCount: pdfByteCount,
            storedAt: storedAt,
            syncedModified: syncedModified ?? document.modified,
            isUnavailable: isUnavailable
        )
    }
}
```

- [ ] **Step 4: Add lossless coders and the shared key**

Create `Modules/ApiInterface/Extensions/JSONCoder+Favorites.swift`:

```swift
import Foundation

// The API pair cannot be reused here. JSONEncoder.apiEncoder formats every Date as "yyyy-MM-dd",
// which is right for the API — paperless wants a day for `created` — and wrong for a file we read
// back. It would round `storedAt` to midnight, and round `document.modified` with it: the field the
// refresh gate compares, which would then differ from the server's on every launch and re-download
// every PDF. Nothing has hit this before because `documents(_:)` is `.inMemory`, so no Document has
// ever been written to disk.
public extension JSONEncoder {

    static let favoritesEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()
}

public extension JSONDecoder {

    static let favoritesDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
```

The two are symmetric and use default key coding, so the property names are the contract on both
sides. This file is private to the device; there is no interop to honour.

Append to `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, in the same shape as `correspondents(_:)`:

```swift
public extension SharedReaderKey
where Self == FileStorageKey<IdentifiedArrayOf<FavoriteDocument>>.Default {

    static func favorites(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-favorites.json"),
                decoder: .favoritesDecoder,
                encoder: .favoritesEncoder
            ),
            default: []
        ]
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ApiInterface -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface/Favorites Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift Modules/ApiInterfaceTests/Favorites
git commit -m "feat: a FavoriteDocument record and its per-server shared key"
```

---

### Task 2: The store over the PDF files

**Files:**
- Create: `Modules/ApiInterface/Favorites/FavoritesStore.swift`
- Create: `Modules/ApiImplementation/Favorites/FavoritesStore+Live.swift`
- Test: `Modules/ApiImplementationTests/Favorites/FavoritesStoreTests.swift`

**Interfaces:**
- Consumes: `FavoriteDocument`, `Server`, `Document.Id`.
- Produces: `FavoritesStore` with `pdfURL: @Sendable (Document.Id, Server) -> URL`, `writePDF: @Sendable (Data, Document.Id, Server) async throws -> Int`, `deletePDF: @Sendable (Document.Id, Server) async throws -> Void`, `deleteAll: @Sendable (Server) async throws -> Void`, `totalByteCount: @Sendable (Server) async -> Int`; and `DependencyValues.favoritesStore`.

- [ ] **Step 1: Write the failing test**

`Modules/ApiImplementationTests/Favorites/FavoritesStoreTests.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import Testing

@Suite
struct FavoritesStoreTests {

    // A server per test, so the directories cannot collide. swift-testing runs a suite's tests in
    // parallel, and the byte-count test asserts an exact total over its whole directory — sharing
    // one server would make it flake whenever a sibling's file happened to exist.
    private static func server(_ name: String) -> Server {
        .testValue(id: "favorites-store-tests-\(name)")
    }

    @Test
    func test_writeThenReadThenDelete() async throws {
        let store = FavoritesStore.liveValue
        let server = Self.server("write-read-delete")
        let data = Data("%PDF-1.4 hello".utf8)

        let written = try await store.writePDF(data, 42, server)
        #expect(written == data.count)

        let url = store.pdfURL(42, server)
        #expect(try Data(contentsOf: url) == data)

        try await store.deletePDF(42, server)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    // A second write must replace the file rather than append to or fail over it: refresh
    // re-downloads into the same path.
    @Test
    func test_writeReplacesAnExistingFile() async throws {
        let store = FavoritesStore.liveValue
        let server = Self.server("write-replaces")

        _ = try await store.writePDF(Data(repeating: 0, count: 100), 43, server)
        let second = try await store.writePDF(Data(repeating: 1, count: 10), 43, server)

        #expect(second == 10)
        #expect(try Data(contentsOf: store.pdfURL(43, server)).count == 10)

        try await store.deletePDF(43, server)
    }

    @Test
    func test_totalByteCountSumsTheFilesAndDeleteAllClearsThem() async throws {
        let store = FavoritesStore.liveValue
        let server = Self.server("total-bytes")

        _ = try await store.writePDF(Data(repeating: 0, count: 300), 44, server)
        _ = try await store.writePDF(Data(repeating: 0, count: 700), 45, server)

        #expect(await store.totalByteCount(server) == 1000)

        try await store.deleteAll(server)

        #expect(await store.totalByteCount(server) == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ApiImplementation -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — `cannot find 'FavoritesStore' in scope`.

- [ ] **Step 3: Write the interface**

`Modules/ApiInterface/Favorites/FavoritesStore.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct FavoritesStore: Sendable {

    public var deleteAll: @Sendable (_ server: Server) async throws -> Void

    public var deletePDF: @Sendable (_ id: Document.Id, _ server: Server) async throws -> Void

    public var pdfURL: @Sendable (_ id: Document.Id, _ server: Server) -> URL = { _, _ in
        URL(filePath: NSTemporaryDirectory())
    }

    public var totalByteCount: @Sendable (_ server: Server) async -> Int = { _ in 0 }

    public var writePDF: @Sendable (_ data: Data, _ id: Document.Id, _ server: Server) async throws -> Int
}

extension FavoritesStore: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {

    var favoritesStore: FavoritesStore {
        get { self[FavoritesStore.self] }
        set { self[FavoritesStore.self] = newValue }
    }
}
```

- [ ] **Step 4: Write the live store**

`Modules/ApiImplementation/Favorites/FavoritesStore+Live.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation

extension FavoritesStore: @retroactive DependencyKey {

    public static let liveValue = Self(
        deleteAll: { server in
            try removeIfPresent(directory(server))
        },
        deletePDF: { id, server in
            try removeIfPresent(url(id, server))
        },
        pdfURL: { id, server in
            url(id, server)
        },
        totalByteCount: { server in
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: directory(server),
                includingPropertiesForKeys: [.fileSizeKey]
            )) ?? []

            // Only the PDFs. Summing whatever happens to be in the directory would let any stray
            // file inflate the number Settings shows as "storage used".
            return urls
                .filter { $0.pathExtension == "pdf" }
                .reduce(0) { total, url in
                    total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
        },
        writePDF: { data, id, server in
            try FileManager.default.createDirectory(at: directory(server), withIntermediateDirectories: true)

            // `.atomic` already writes to a temporary file and renames it into place, so a download
            // killed mid-flight cannot leave a truncated file that later reads as a corrupt PDF.
            // Doing that dance by hand would only add a partial file to leak when the rename throws.
            try data.write(to: url(id, server), options: .atomic)

            return data.count
        }
    )

    private static func directory(_ server: Server) -> URL {
        URL.applicationGroupDirectory
            .appending(component: "Favorites")
            .appending(component: "\(server.id)")
    }

    // Already gone is the outcome the caller wanted, so it is not an error. Anything else —
    // permissions, a busy volume — is, and must not be swallowed: a `try?` here would report a
    // favorite as removed while its bytes stayed on disk.
    private static func removeIfPresent(_ url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }

    private static func url(_ id: Document.Id, _ server: Server) -> URL {
        directory(server).appending(component: "\(id.rawValue).pdf")
    }
}
```

Note: `URL.applicationGroupDirectory` is `internal` to `ApiInterface` today (`SharedReaderKey+Extensions.swift:207`). Make that extension `public` so `ApiImplementation` can use it.

- [ ] **Step 5: Run tests to verify they pass**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ApiImplementation -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface/Favorites/FavoritesStore.swift Modules/ApiImplementation/Favorites Modules/ApiImplementationTests/Favorites Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift
git commit -m "feat: a FavoritesStore over the PDFs on disk"
```

---

### Task 3: Saving and removing one favorite

**Files:**
- Create: `Modules/ApiInterface/Favorites/SaveFavoriteUseCase.swift`, `Modules/ApiInterface/Favorites/RemoveFavoriteUseCase.swift`
- Create: `Modules/ApiImplementation/Favorites/SaveFavoriteUseCase.swift`, `Modules/ApiImplementation/Favorites/RemoveFavoriteUseCase.swift`
- Test: `Modules/ApiImplementationTests/Favorites/SaveFavoriteUseCaseTests.swift`

**Interfaces:**
- Consumes: `FavoritesStore`, `getNotes`, `getDocumentMetadata`, `downloadDocument`, `@Shared(.favorites(server))`.
- Produces: `SaveFavoriteUseCase.execute: (Document, Server) async throws -> Void`, `RemoveFavoriteUseCase.execute: (Document.Id, Server) async throws -> Void`, `DependencyValues.saveFavorite`, `DependencyValues.removeFavorite`.

- [ ] **Step 1: Write the failing test**

`Modules/ApiImplementationTests/Favorites/SaveFavoriteUseCaseTests.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SaveFavoriteUseCaseTests {

    @Test
    func test_savesTheDocumentItsNotesMetadataAndPdf() async throws {
        let server = Server.testValue()
        let document = Document.testValue(id: 7, title: "Invoice")
        let note = Note.testValue()
        let written = LockIsolated<Data?>(nil)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

        try await withDependencies {
            $0.getNotes.execute = { _, _ in [note] }
            $0.getDocumentMetadata.execute = { _, _ in .testValue() }
            $0.downloadDocument.execute = { _, _ in Data(repeating: 9, count: 64) }
            $0.favoritesStore.writePDF = { data, _, _ in written.setValue(data); return data.count }
            $0.date.now = Date(timeIntervalSince1970: 100)
        } operation: {
            try await SaveFavoriteUseCase.liveValue.execute(document, server)
        }

        #expect(written.value?.count == 64)
        #expect($favorites.wrappedValue[id: 7]?.document.title == "Invoice")
        #expect($favorites.wrappedValue[id: 7]?.notes == [note])
        #expect($favorites.wrappedValue[id: 7]?.pdfByteCount == 64)
        #expect($favorites.wrappedValue[id: 7]?.isUnavailable == false)
    }

    // A failed download must leave nothing behind: a record without its PDF is a favorite that
    // cannot be read offline, which is the one thing it exists to do.
    @Test
    func test_writesNoRecordWhenTheDownloadFails() async {
        let server = Server.testValue()

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

        await #expect(throws: (any Error).self) {
            try await withDependencies {
                $0.getNotes.execute = { _, _ in [] }
                $0.getDocumentMetadata.execute = { _, _ in .testValue() }
                $0.downloadDocument.execute = { _, _ in throw ApiError.testValue() }
            } operation: {
                try await SaveFavoriteUseCase.liveValue.execute(.testValue(id: 7), server)
            }
        }

        #expect($favorites.wrappedValue.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ApiImplementation -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — `cannot find 'SaveFavoriteUseCase' in scope`.

- [ ] **Step 3: Write the interfaces**

`Modules/ApiInterface/Favorites/SaveFavoriteUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

// Refresh and favoriting share this use case, and they want opposite things from a document that
// was unfavorited while the fetch was in flight: the add path must write it, a refresh must not
// resurrect it.
public enum SaveFavoriteMode: Equatable, Sendable {
    case add
    case refreshExisting
}

@DependencyClient
public struct SaveFavoriteUseCase: Sendable {

    public var execute: @Sendable (
        _ document: Document,
        _ server: Server,
        _ mode: SaveFavoriteMode
    ) async throws -> Void
}

extension SaveFavoriteUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _, _ in })

    public static let testValue = Self(execute: { _, _, _ in })
}

public extension DependencyValues {

    var saveFavorite: SaveFavoriteUseCase {
        get { self[SaveFavoriteUseCase.self] }
        set { self[SaveFavoriteUseCase.self] = newValue }
    }
}
```

`Modules/ApiInterface/Favorites/RemoveFavoriteUseCase.swift` is the same shape with
`execute: @Sendable (_ id: Document.Id, _ server: Server) async throws -> Void` and
`DependencyValues.removeFavorite`.

- [ ] **Step 4: Write the implementations**

`Modules/ApiImplementation/Favorites/SaveFavoriteUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveFavoriteUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(document:server:))
}

private extension SaveFavoriteUseCase {

    static func execute(document: Document, server: Server) async throws {
        @Dependency(\.date.now) var now
        @Dependency(\.downloadDocument.execute) var downloadDocument
        @Dependency(\.favoritesStore) var store
        @Dependency(\.getDocumentMetadata.execute) var getMetadata
        @Dependency(\.getNotes.execute) var getNotes

        // Everything is fetched before anything is stored, so a failure anywhere leaves no
        // half-written favorite.
        let notes = try await getNotes(document.id, server)
        let metadata = try await getMetadata(document.id, server)
        let data = try await downloadDocument(document.id, server)
        let byteCount = try await store.writePDF(data, document.id, server)

        @Shared(.favorites(server)) var favorites

        // The check and the write share one lock, so nothing can remove the favorite between them.
        // A refresh that loses that race deletes the PDF it just wrote rather than leaving an
        // orphan file behind.
        let wrote = $favorites.withLock { favorites -> Bool in
            guard mode == .add || favorites[id: document.id] != nil else {
                return false
            }
            favorites[id: document.id] = FavoriteDocument(
                document: document,
                metadata: metadata,
                notes: notes,
                pdfByteCount: byteCount,
                storedAt: now,
                // The expensive three were just fetched at this document's `modified`, so this is
                // the version the offline copy actually holds.
                syncedModified: document.modified
            )
            return true
        }

        if !wrote {
            try await store.deletePDF(document.id, server)
        }
    }
}
```

`RefreshFavoritesUseCase` passes `.refreshExisting`; favoriting from the row or the toolbar passes
`.add`.

`Modules/ApiImplementation/Favorites/RemoveFavoriteUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing

extension RemoveFavoriteUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(id:server:))
}

private extension RemoveFavoriteUseCase {

    static func execute(id: Document.Id, server: Server) async throws {
        @Dependency(\.favoritesStore) var store

        @Shared(.favorites(server)) var favorites

        // The record goes first. A `.refreshExisting` save racing this then fails its in-lock
        // check, refuses to write, and deletes the PDF it had already written - so no file is
        // left with nothing pointing at it.
        _ = $favorites.withLock { $0.remove(id: id) }

        try await store.deletePDF(id, server)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ApiImplementation -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface/Favorites Modules/ApiImplementation/Favorites Modules/ApiImplementationTests/Favorites
git commit -m "feat: save and remove one favorite"
```

---

### Task 4: The two-phase refresh

This is the task most likely to be quietly wrong. Read the "Refresh" section of the spec before starting.

**Files:**
- Create: `Modules/ApiInterface/Favorites/RefreshFavoritesUseCase.swift`
- Create: `Modules/ApiImplementation/Favorites/RefreshFavoritesUseCase.swift`
- Test: `Modules/ApiImplementationTests/Favorites/RefreshFavoritesUseCaseTests.swift`

**Interfaces:**
- Consumes: `getDocumentsByIds` (existing, issues `id__in`), `SaveFavoriteUseCase`, `@Shared(.favorites(server))`.
- Produces: `RefreshFavoritesUseCase.execute: (_ force: Bool, _ server: Server) async throws -> FavoriteRefreshResult`, `FavoriteRefreshResult(updated: Int, failed: Int, unavailable: Int)`, `DependencyValues.refreshFavorites`.

- [ ] **Step 1: Write the failing tests**

`Modules/ApiImplementationTests/Favorites/RefreshFavoritesUseCaseTests.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct RefreshFavoritesUseCaseTests {

    private static let stored = Date(timeIntervalSince1970: 1_000)

    @Test
    func test_unchangedModifiedFetchesNothingExpensive() async throws {
        let server = Server.testValue()
        let document = Document.testValue(id: 7, modified: Self.stored)
        let downloads = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: document)
        ]

        let result = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [document] }
            $0.downloadDocument.execute = { _, _ in downloads.withValue { $0 += 1 }; return Data() }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect(downloads.value == 0)
        #expect(result.updated == 0)
    }

    @Test
    func test_movedModifiedRefetchesEverything() async throws {
        let server = Server.testValue()
        let fresh = Document.testValue(id: 7, modified: Self.stored.addingTimeInterval(60))
        let saved = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7, modified: Self.stored))
        ]

        let result = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [fresh] }
            $0.saveFavorite.execute = { _, _, _ in saved.withValue { $0 += 1 } }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect(saved.value == 1)
        #expect(result.updated == 1)
    }

    // bulk_edit changes tags and correspondent through QuerySet.update(), which bypasses Django's
    // auto_now, so `modified` does not move. The document from phase one is written back anyway,
    // and this is the test that catches anyone "simplifying" that away.
    @Test
    func test_fieldsChangedWithoutModifiedMovingAreStillStored() async throws {
        let server = Server.testValue()
        let fresh = Document.testValue(id: 7, modified: Self.stored, title: "Renamed")
        let downloads = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7, modified: Self.stored, title: "Old"))
        ]

        _ = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [fresh] }
            $0.downloadDocument.execute = { _, _ in downloads.withValue { $0 += 1 }; return Data() }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect($favorites.wrappedValue[id: 7]?.document.title == "Renamed")
        #expect(downloads.value == 0)
    }

    @Test
    func test_anIdMissingFromTheResponseIsMarkedUnavailable() async throws {
        let server = Server.testValue()

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        let result = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [] }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(false, server)
        }

        #expect($favorites.wrappedValue[id: 7]?.isUnavailable == true)
        #expect(result.unavailable == 1)
    }

    // The one that matters most: a failed request knows nothing about what the server holds.
    // Marking on failure would badge every favorite the first time the app opens on a plane.
    @Test
    func test_aFailedPhaseOneMarksNothing() async {
        let server = Server.testValue()

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 7))
        ]

        await #expect(throws: (any Error).self) {
            try await withDependencies {
                $0.getDocumentsByIds.execute = { _, _ in throw ApiError.testValue() }
            } operation: {
                try await RefreshFavoritesUseCase.liveValue.execute(false, server)
            }
        }

        #expect($favorites.wrappedValue[id: 7]?.isUnavailable == false)
    }

    @Test
    func test_forceRefetchesEvenWhenModifiedIsUnchanged() async throws {
        let server = Server.testValue()
        let document = Document.testValue(id: 7, modified: Self.stored)
        let saved = LockIsolated(0)

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: document)
        ]

        _ = try await withDependencies {
            $0.getDocumentsByIds.execute = { _, _ in [document] }
            $0.saveFavorite.execute = { _, _, _ in saved.withValue { $0 += 1 } }
        } operation: {
            try await RefreshFavoritesUseCase.liveValue.execute(true, server)
        }

        #expect(saved.value == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ApiImplementation -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — `cannot find 'RefreshFavoritesUseCase' in scope`.

- [ ] **Step 3: Write the interface**

`Modules/ApiInterface/Favorites/RefreshFavoritesUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

public struct FavoriteRefreshResult: Equatable, Sendable {

    public let failed: Int
    public let unavailable: Int
    public let updated: Int

    public init(failed: Int = 0, unavailable: Int = 0, updated: Int = 0) {
        self.failed = failed
        self.unavailable = unavailable
        self.updated = updated
    }
}

@DependencyClient
public struct RefreshFavoritesUseCase: Sendable {

    // `force` is what separates pull-to-refresh from Settings' "Redownload all": the same walk,
    // with phase two run for every favorite instead of only the changed ones.
    public var execute: @Sendable (
        _ force: Bool,
        _ server: Server
    ) async throws -> FavoriteRefreshResult
}

extension RefreshFavoritesUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in .init() })

    public static let testValue = Self(execute: { _, _ in .init() })
}

public extension DependencyValues {

    var refreshFavorites: RefreshFavoritesUseCase {
        get { self[RefreshFavoritesUseCase.self] }
        set { self[RefreshFavoritesUseCase.self] = newValue }
    }
}
```

- [ ] **Step 4: Write the implementation**

`Modules/ApiImplementation/Favorites/RefreshFavoritesUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing

extension RefreshFavoritesUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(force:server:))
}

private extension RefreshFavoritesUseCase {

    // Long enough to be worth one request, short enough that the URL cannot be rejected.
    static let chunkSize = 100

    // Enough to be quick, not enough to hammer a home server.
    static let concurrency = 3

    static func execute(force: Bool, server: Server) async throws -> FavoriteRefreshResult {
        @Dependency(\.getDocumentsByIds.execute) var getDocumentsByIds
        @Dependency(\.saveFavorite.execute) var saveFavorite

        @Shared(.favorites(server)) var favorites

        let stored = $favorites.wrappedValue
        guard !stored.isEmpty else {
            return FavoriteRefreshResult()
        }

        // Phase one. A throw here propagates before anything is written, which is what keeps a
        // failed request from marking every favorite unavailable.
        var fresh: [Document.Id: Document] = [:]
        for chunk in stored.ids.chunked(into: chunkSize) {
            let documents = try await getDocumentsByIds(
                GetDocumentsByIdsInput(ids: Array(chunk)),
                server
            )
            for document in documents {
                fresh[document.id] = document
            }
        }

        var changed: [Document] = []
        var unavailable = 0

        $favorites.withLock { favorites in
            for favorite in stored {
                guard let document = fresh[favorite.id] else {
                    favorites[id: favorite.id]?.isUnavailable = true
                    unavailable += 1
                    continue
                }

                // Written back unconditionally: bulk edit changes fields without moving `modified`.
                favorites[id: favorite.id] = FavoriteDocument(
                    document: document,
                    metadata: favorite.metadata,
                    notes: favorite.notes,
                    pdfByteCount: favorite.pdfByteCount,
                    storedAt: favorite.storedAt,
                    // Carried, not advanced: only a successful phase-two save may move it.
                    syncedModified: favorite.syncedModified,
                    isUnavailable: false
                )

                if force || document.modified != favorite.syncedModified {
                    changed.append(document)
                }
            }
        }

        // Phase two.
        // A sliding window: `concurrency` tasks in flight, and each one that finishes starts the
        // next. `withTaskGroup(of:)` would otherwise run all of them at once.
        let failed = await withTaskGroup(of: Bool.self) { group in
            var iterator = changed.makeIterator()
            var failures = 0

            func addNext() {
                guard let document = iterator.next() else { return }
                group.addTask {
                    do {
                        try await saveFavorite(document, server, .refreshExisting)
                        return true
                    } catch {
                        return false
                    }
                }
            }

            for _ in 0 ..< concurrency { addNext() }

            while let succeeded = await group.next() {
                if !succeeded { failures += 1 }
                addNext()
            }

            return failures
        }

        return FavoriteRefreshResult(
            failed: failed,
            unavailable: unavailable,
            updated: changed.count - failed
        )
    }
}

private extension Collection {

    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { offset in
            let start = index(startIndex, offsetBy: offset)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return Array(self[start ..< end])
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ApiImplementation -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS — all six.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface/Favorites Modules/ApiImplementation/Favorites Modules/ApiImplementationTests/Favorites
git commit -m "feat: refresh favorites, re-downloading only what changed"
```

---

### Task 5: Register the FavoritesFeature module

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`, `Module+Dependencies.swift`, `Module+Schemes.swift`
- Create: `Modules/FavoritesFeature/Resources/Localizable.xcstrings`, `Modules/FavoritesFeature/Favorites.swift` (placeholder so the target has a source file)
- Create: `Modules/FavoritesFeatureTests/FavoritesFeatureTests.swift`

**Interfaces:**
- Produces: a `FavoritesFeature` framework target and a `FavoritesFeatureTests` unit-test target, both building and schemed.

- [ ] **Step 1: Add the enum cases**

In `Module.swift`, alphabetically beside `.forwardAuthFeature`:

```swift
case favoritesFeature = "FavoritesFeature"
case favoritesFeatureTests = "FavoritesFeatureTests"
```

Then mirror `.tipsFeature` / `.tipsFeatureTests` everywhere they appear. **Grep rather than trusting line numbers** — `grep -rn 'tipsFeature' Tuist/` lists every switch arm that needs the new cases, and the set has drifted before. In `Module.swift` that is the `product` and `codeCoverageTarget` switches; there is no `infoPlist` switch there.

- [ ] **Step 2: Add the dependencies**

In `Module+Dependencies.swift`:

```swift
case .favoritesFeature:
    [
        .external(.composableArchitecture),
        .external(.dependencies),
        .external(.dependenciesMacros),
        .external(.sharing),
        .external(.tagged),
        .target(.apiInterface),
        .target(.components),
        .target(.documentsFeature),
    ]
case .favoritesFeatureTests:
    [
        .external(.composableArchitecture),
        .external(.dependenciesTestSupport),
        .external(.snapshotTesting),
        .target(.apiInterface),
        .target(.favoritesFeature),
        .target(.testSupport),
    ]
```

- [ ] **Step 3: Add the scheme**

In `Module+Schemes.swift`, add `.favoritesFeature` to the list at line ~109 and `.favoritesFeatureTests` to the list at line ~177, beside the `.tipsFeature` entries.

- [ ] **Step 4: Create the module's files**

`Modules/FavoritesFeature/Favorites.swift`:

```swift
import Foundation

// Placeholder so the target has a source file before Task 7 lands. Delete it there.
enum Favorites {}
```

`Modules/FavoritesFeature/Resources/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {},
  "version" : "1.1"
}
```

`Modules/FavoritesFeatureTests/FavoritesFeatureTests.swift`:

```swift
@testable import FavoritesFeature

import Testing

@Suite
struct FavoritesFeatureTests {

    @Test
    func test_theModuleBuilds() {
        #expect(true)
    }
}
```

- [ ] **Step 5: Generate and build**

Run:
```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme FavoritesFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Tuist Modules/FavoritesFeature Modules/FavoritesFeatureTests
git commit -m "chore: add the FavoritesFeature module"
```

---

### Task 6: Extract DocumentRowContent

Pure refactoring in service of Task 7. **The existing row snapshots must not change** — if one needs re-recording, something moved that should not have.

**Files:**
- Create: `Modules/DocumentsFeature/DocumentRow/DocumentRowContent.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift`

**Interfaces:**
- Produces: `public struct DocumentRowContent: View` with `init(document: Document, server: Server, titleLineLimit: Int)` — the text column: correspondent, created date, title, and the ASN / document-type / storage-path grid.
- Produces: `public struct DocumentRowTags: View` with `init(tags: [Tag], height: CGFloat)` — the tag chips. These are **not** part of the text column: `DocumentRowView` overlays them on the thumbnail at `.topTrailing`, and they size themselves against the image height. They are extracted separately so the favourites row can overlay the same chips on its own thumbnail rather than restyling them.

- [ ] **Step 1: Run the existing snapshots to capture the baseline**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme DocumentsFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS. This is the baseline the refactor must preserve.

- [ ] **Step 2: Move the presentation into its own view**

Create `DocumentRowContent.swift` holding the bodies currently in `DocumentRowView.detailsView()` and `tagsView()`, reading from a plain `Document` and `Server` instead of `store`. Keep the `titleLineLimit` computation on the caller and pass it in, since `DocumentRowReducer.State` already derives it.

```swift
import ApiInterface
import Components
import SwiftUI

public struct DocumentRowContent: View {

    public var body: some View {
        // The body of DocumentRowView.detailsView(), with `store.document` replaced by `document`
        // and `store.server` by `server`.
    }

    public init(document: Document, server: Server, titleLineLimit: Int) {
        self.document = document
        self.server = server
        self.titleLineLimit = titleLineLimit
    }

    private let document: Document
    private let server: Server
    private let titleLineLimit: Int
}
```

- [ ] **Step 3: Move the tag chips out too**

`tagsView()` is an overlay on the thumbnail, not part of the text column, so it becomes its own view rather than a member of `DocumentRowContent`:

```swift
public struct DocumentRowTags: View {

    public var body: some View {
        // The body of DocumentRowView.tagsView(), with `store.tags` replaced by `tags` and
        // `imageSize.height` by `height`.
    }

    public init(tags: [Tag], height: CGFloat) {
        self.tags = tags
        self.height = height
    }

    private let tags: [Tag]
    private let height: CGFloat
}
```

- [ ] **Step 4: Call both from DocumentRowView**

Replace `detailsView()`'s body with:

```swift
DocumentRowContent(
    document: store.document,
    server: store.server,
    titleLineLimit: store.titleLineLimit
)
```

and `tagsView()`'s with:

```swift
DocumentRowTags(tags: store.tags, height: imageSize.height)
```

- [ ] **Step 5: Run the snapshots and confirm they are unchanged**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme DocumentsFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS with **no** reference changes. Confirm with `git status Snapshots/` — it must be empty. A diff there means the extraction changed layout; fix the view rather than re-recording.

- [ ] **Step 6: Commit**

```bash
git add Modules/DocumentsFeature/DocumentRow
git commit -m "refactor: extract DocumentRowContent from DocumentRowView"
```

---

### Task 7: The favorites row

**Files:**
- Create: `Modules/FavoritesFeature/FavoriteRow/FavoriteRowReducer.swift`, `FavoriteRowView.swift`, `FavoriteThumbnail.swift`
- Delete: `Modules/FavoritesFeature/Favorites.swift`
- Modify: `Modules/FavoritesFeature/Resources/Localizable.xcstrings`
- Test: `Modules/FavoritesFeatureTests/FavoriteRow/FavoriteRowReducerTests.swift`

**Interfaces:**
- Consumes: `FavoriteDocument`, `RemoveFavoriteUseCase`, `DocumentRowContent`.
- Produces: `FavoriteRowReducer` with `State(favorite:server:)`, `Action.delegate(.open(FavoriteDocument))`, `Action.view(.rowTapped)`, `Action.view(.unfavoriteButtonTapped)`.

- [ ] **Step 1: Add the strings**

`Modules/FavoritesFeature/Resources/Localizable.xcstrings` — add, alphabetically:

| key | en | de |
|---|---|---|
| `favoriteUnavailable` | `Unavailable` | `Nicht verfügbar` |
| `unfavorite` | `Remove from Favorites` | `Aus Favoriten entfernen` |

Each entry takes `"extractionState": "manual"` and both localizations `"state": "translated"`.

- [ ] **Step 2: Write the failing test**

`Modules/FavoritesFeatureTests/FavoriteRow/FavoriteRowReducerTests.swift`:

```swift
@testable import FavoritesFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct FavoriteRowReducerTests {

    @Test
    func test_unfavoriteRemovesTheFavorite() async {
        let removed = LockIsolated<Document.Id?>(nil)
        let favorite = FavoriteDocument.testValue(document: .testValue(id: 7))

        let store = TestStore(
            initialState: FavoriteRowReducer.State(favorite: favorite, server: .testValue())
        ) {
            FavoriteRowReducer()
        } withDependencies: {
            $0.removeFavorite.execute = { id, _ in removed.setValue(id) }
        }

        await store.send(.view(.unfavoriteButtonTapped))

        #expect(removed.value == 7)
    }

    @Test
    func test_tappingTheRowAsksToOpenIt() async {
        let favorite = FavoriteDocument.testValue(document: .testValue(id: 7))

        let store = TestStore(
            initialState: FavoriteRowReducer.State(favorite: favorite, server: .testValue())
        ) {
            FavoriteRowReducer()
        }

        await store.send(.view(.rowTapped))
        await store.receive(\.delegate.open)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme FavoritesFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — `cannot find 'FavoriteRowReducer' in scope`.

- [ ] **Step 4: Write the reducer**

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

@Reducer
public struct FavoriteRowReducer: Sendable {

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Document.Id { favorite.id }

        var favorite: FavoriteDocument
        let server: Server

        public init(favorite: FavoriteDocument, server: Server) {
            self.favorite = favorite
            self.server = server
        }
    }

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        // @CasePathable, or `store.receive(\.delegate.open)` will not compile — the same shape
        // DocumentFilterReducer uses.
        @CasePathable
        public enum Delegate {
            case open(FavoriteDocument)
        }

        public enum View {
            case rowTapped
            case unfavoriteButtonTapped
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
            case .view(.rowTapped):
                return .send(.delegate(.open(state.favorite)))
            case .view(.unfavoriteButtonTapped):
                let id = state.id
                let server = state.server
                return .run { _ in
                    @Dependency(\.removeFavorite.execute) var removeFavorite
                    try await removeFavorite(id, server)
                }
            }
        }
    }

    public init() {}
}
```

- [ ] **Step 5: Write the thumbnail and the view**

`FavoriteThumbnail.swift` renders page one of the stored PDF:

```swift
import PDFKit
import SwiftUI

struct FavoriteThumbnail: View {

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                // Not rendered yet, or the file is gone or is not a PDF. The row lays out either way.
                Image(systemName: "doc").resizable().aspectRatio(contentMode: .fit)
            }
        }
        .task(id: url) {
            image = await Self.render(url: url, size: size)
        }
    }

    let url: URL
    let size: CGSize

    @State private var image: UIImage?

    // Opening a PDF and rasterising a page is far too much to do while SwiftUI evaluates a body: as
    // a computed property it ran for every visible row on every frame of a scroll. Once per
    // appearance, off the main actor, into @State.
    private static func render(url: URL, size: CGSize) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let page = PDFDocument(url: url)?.page(at: 0) else { return nil }
            return page.thumbnail(of: size, for: .mediaBox)
        }.value
    }
}
```

`FavoriteRowView.swift` renders `DocumentRowContent` beside that thumbnail, overlays
`DocumentRowTags(tags:height:)` on the thumbnail at `.topTrailing` exactly as `DocumentRowView` does
— same chips, not a restyled copy — adds an "Unavailable" badge when `store.favorite.isUnavailable`,
`.onTapGesture { send(.rowTapped) }`, and:

```swift
.swipeActions {
    Button(role: .destructive) {
        send(.unfavoriteButtonTapped)
    } label: {
        Label(.unfavorite, systemImage: "heart.slash")
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme FavoritesFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git rm Modules/FavoritesFeature/Favorites.swift
git add Modules/FavoritesFeature Modules/FavoritesFeatureTests
git commit -m "feat: a favorites row with a thumbnail from the stored PDF"
```

---

### Task 8: The favorites list

**Files:**
- Create: `Modules/FavoritesFeature/FavoriteList/FavoriteListReducer.swift`, `FavoriteListView.swift`, `FavoriteListReducer+TestValue.swift`
- Modify: `Modules/FavoritesFeature/Resources/Localizable.xcstrings`
- Test: `Modules/FavoritesFeatureTests/FavoriteList/FavoriteListReducerTests.swift`, `FavoriteListViewTests.swift`

**Interfaces:**
- Consumes: `FavoriteRowReducer`, `RefreshFavoritesUseCase`, `DocumentDetailReducer` (from `DocumentsFeature`).
- Produces: `FavoriteListReducer` with `State(server:)`, `Action.view(.onRefresh)`, `Action.binding(\.searchText)`, and `Path.documentDetail(DocumentDetailReducer)`.

- [ ] **Step 1: Add the strings**

| key | en | de |
|---|---|---|
| `favorites` | `Favorites` | `Favoriten` |
| `noFavorites` | `No favorites yet` | `Noch keine Favoriten` |
| `noFavoritesMessage` | `Documents you favorite are kept on this device, ready to read without a connection.` | `Favorisierte Dokumente bleiben auf diesem Gerät und sind ohne Verbindung lesbar.` |

- [ ] **Step 2: Write the failing test**

`Modules/FavoritesFeatureTests/FavoriteList/FavoriteListReducerTests.swift`:

```swift
@testable import FavoritesFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing

@MainActor
@Suite
struct FavoriteListReducerTests {

    @Test
    func test_searchFiltersOnTitle() async {
        let server = Server.testValue()

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 1, title: "Invoice")),
            .testValue(document: .testValue(id: 2, title: "Warranty")),
        ]

        let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
            FavoriteListReducer()
        }

        await store.send(\.binding.searchText, "inv") {
            $0.searchText = "inv"
        }

        #expect(store.state.visibleFavorites.map(\.id) == [1])
    }

    @Test
    func test_refreshReportsItsResult() async {
        let server = Server.testValue()

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
            .testValue(document: .testValue(id: 1))
        ]

        let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
            FavoriteListReducer()
        } withDependencies: {
            $0.refreshFavorites.execute = { _, _ in FavoriteRefreshResult(updated: 1) }
        }

        await store.send(.view(.onRefresh)) { $0.isRefreshing = true }
        await store.receive(\.refreshResult) { $0.isRefreshing = false }
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme FavoritesFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — `cannot find 'FavoriteListReducer' in scope`.

- [ ] **Step 4: Write the reducer**

`State` holds `@Shared(.favorites(server)) var favorites`, `searchText`, `isRefreshing`, a `StackState<Path.State>`, and — so a favorite does not show a pre-edit copy in the same session — the live cache the other lists project their rows out of:

```swift
@Shared(.documents(server))
var documentCache: IdentifiedArrayOf<Document>

// The live copy when the cache has one, the stored snapshot otherwise. A cold launch and an
// offline session get the snapshot, which is exactly when it is the only truth available.
func displayed(_ favorite: FavoriteDocument) -> Document {
    documentCache[id: favorite.id] ?? favorite.document
}
```

Rows are built with `displayed(favorite)`, and the detail push passes `Shared($documentCache[id:])`
when the cache has an entry and `Shared(value: favorite.document)` when it does not.

Add this test alongside the search one:

```swift
@Test
func test_aRowShowsTheLiveDocumentWhenTheCacheHasOne() async {
    let server = Server.testValue()

    @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
        .testValue(document: .testValue(id: 1, title: "Stored"))
    ]
    @Shared(.documents(server)) var cache: IdentifiedArrayOf<Document> = [
        .testValue(id: 1, title: "Edited")
    ]

    let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
        FavoriteListReducer()
    }

    #expect(store.state.rows[id: 1]?.document.title == "Edited")
}
```

and the filter:

```swift
var visibleFavorites: IdentifiedArrayOf<FavoriteDocument> {
    guard !searchText.isEmpty else { return favorites }

    let needle = searchText.lowercased()
    return favorites.filter { favorite in
        let haystack = [
            favorite.document.title,
            favorite.document.content ?? "",
            favorite.document.correspondent?.get(server)?.name ?? "",
            favorite.document.documentType?.get(server)?.name ?? "",
            favorite.document.storagePath?.get(server)?.name ?? "",
        ] + favorite.document.tags.compactMap { $0.get(server)?.name }

        return haystack.contains { $0.lowercased().contains(needle) }
    }
}
```

`.view(.onRefresh)` sets `isRefreshing` and runs `refreshFavorites(false, server)`, sending `.refreshResult`. A thrown error still clears `isRefreshing`.

- [ ] **Step 5: Write the view**

```swift
Searchable {
    List {
        ForEach(store.scope(state: \.rows, action: \.rows)) { store in
            FavoriteRowView(store: store)
        }
    }
    .searchable(text: $store.searchText)
    .refreshable { await send(.onRefresh).finish() }
    .navigationTitle(.favorites)
}
```

with `EmptyListView(systemImage: "heart", title: .noFavorites)` when `store.favorites.isEmpty`.

- [ ] **Step 6: Add the snapshot tests**

`FavoriteListViewTests.swift`, following `DiagnosticsListViewTests`: `testSnapshot_populated`, `testSnapshot_empty`, `testSnapshot_unavailable`. Suite attributes `.snapshots(record: .environment)` and `.tags(.snapshotTests)`.

- [ ] **Step 7: Run tests, record the new references, and look at them**

Run the suite; the three snapshots will fail with nothing to compare against and write references on the first run. **Open each recorded PNG and check it** before trusting it — a first reference records whatever the code produced, bug included.

- [ ] **Step 8: Pin the dependency overrides**

The `Path` runs the detail screen with three dependencies pointed at the store:

```swift
case .documentDetail:
    DocumentDetailReducer()
        .dependency(\.getNotes, .favoritesStore)
        .dependency(\.getDocumentMetadata, .favoritesStore)
        .dependency(\.downloadDocument, .favoritesStore)
```

Each `.favoritesStore` instance reads the record instead of the network — `getNotes` returns
`favorites[id: documentId]?.notes ?? []`, `getDocumentMetadata` returns its `metadata`, and
`downloadDocument` returns `Data(contentsOf: favoritesStore.pdfURL(id, server))`.

This test is the one that catches a future fourth network call in the detail screen, which would
otherwise only show up offline:

```swift
@Test
func test_theDetailScreenReadsFromTheStoreRatherThanTheNetwork() async {
    let server = Server.testValue()
    let note = Note.testValue()
    let networkCalls = LockIsolated(0)

    @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
        .testValue(document: .testValue(id: 7), notes: [note])
    ]

    let store = TestStore(initialState: FavoriteListReducer.State(server: server)) {
        FavoriteListReducer()
    } withDependencies: {
        $0.getNotes.execute = { _, _ in networkCalls.withValue { $0 += 1 }; return [] }
    }

    await store.send(.rows(.element(id: 7, action: .delegate(.open(favorites[0])))))
    // …drive the pushed detail's onAppear…

    #expect(networkCalls.value == 0)
}
```

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme FavoritesFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Modules/FavoritesFeature Modules/FavoritesFeatureTests Snapshots/FavoritesFeatureTests
git commit -m "feat: the favorites list, with search and pull-to-refresh"
```

---

### Task 9: Favoriting from the document row and detail

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`, `DocumentRowView.swift`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift`, `DocumentDetailView.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`

**Interfaces:**
- Consumes: `SaveFavoriteUseCase`, `RemoveFavoriteUseCase`, `@SharedReader(.favorites(server))`.
- Produces: `DocumentRowReducer.Action.View.favoriteButtonTapped`, `DocumentRowReducer.State.isFavorited`, `DocumentDetailReducer.State.isOfflineSnapshot`.

- [ ] **Step 1: Add the strings**

To `Modules/DocumentsFeature/Resources/Localizable.xcstrings`:

| key | en | de |
|---|---|---|
| `favorite` | `Add to Favorites` | `Zu Favoriten hinzufügen` |
| `unfavorite` | `Remove from Favorites` | `Aus Favoriten entfernen` |

`unfavorite` is byte-identical to the copy added to `FavoritesFeature` in Task 7 — copy it, do not re-translate.

- [ ] **Step 2: Write the failing test**

```swift
@Test
func test_favoriteButtonSavesWhenNotYetFavorited() async {
    let server = Server.testValue()
    let saved = LockIsolated<Document.Id?>(nil)

    @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []

    let store = TestStore(
        initialState: DocumentRowReducer.State(document: Shared(value: .testValue(id: 7)), server: server)
    ) {
        DocumentRowReducer()
    } withDependencies: {
        $0.saveFavorite.execute = { document, _, mode in
            #expect(mode == .add)
            saved.setValue(document.id)
        }
    }

    await store.send(.view(.favoriteButtonTapped))

    #expect(saved.value == 7)
}

@Test
func test_favoriteButtonRemovesWhenAlreadyFavorited() async {
    let server = Server.testValue()
    let removed = LockIsolated<Document.Id?>(nil)

    @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
        .testValue(document: .testValue(id: 7))
    ]

    let store = TestStore(
        initialState: DocumentRowReducer.State(document: Shared(value: .testValue(id: 7)), server: server)
    ) {
        DocumentRowReducer()
    } withDependencies: {
        $0.removeFavorite.execute = { id, _ in removed.setValue(id) }
    }

    await store.send(.view(.favoriteButtonTapped))

    #expect(removed.value == 7)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme DocumentsFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — no `favoriteButtonTapped` case.

- [ ] **Step 4: Add the action and the derived flag**

In `DocumentRowReducer.State`, add `@SharedReader(.favorites(server)) var favorites` (initialised in `init` from `server`) and:

```swift
var isFavorited: Bool { favorites[id: document.id] != nil }
```

Handle `.view(.favoriteButtonTapped)` by calling `removeFavorite` when `isFavorited`, `saveFavorite` otherwise.

- [ ] **Step 5: Add the menu item**

In `DocumentRowView.contextMenu()`, **at the top, above its own `Divider()`** — the A-Z rule cannot hold an item whose label changes with state, so it is anchored the way Delete is anchored at the bottom:

```swift
Button {
    send(.favoriteButtonTapped)
} label: {
    Label(
        store.isFavorited ? .unfavorite : .favorite,
        systemImage: store.isFavorited ? "heart.fill" : "heart"
    )
}

Divider()
```

- [ ] **Step 6: Add the detail toolbar toggle and the snapshot flag**

Add `isOfflineSnapshot: Bool = false` to `DocumentDetailReducer.State`. In `DocumentDetailView`, add the same heart button to the toolbar, and hide the edit button and the delete action when `store.isOfflineSnapshot`.

- [ ] **Step 7: Run tests; re-record the row snapshots**

The context menu is not in the row's snapshot (it renders on long press), so references should be unchanged. Confirm with `git status Snapshots/`. If the detail snapshots changed, re-record with the `SNAPSHOT_RECORD` procedure and look at them.

- [ ] **Step 8: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: favorite a document from its row menu and its detail toolbar"
```

---

### Task 10: The tab, and refreshing on launch and foreground

**Files:**
- Modify: `Modules/AppFeature/AppTab.swift`, `MainReducer.swift`, `MainView.swift`, `AppReducer.swift`, `AppReducer+Effect.swift`
- Modify: `Modules/AppFeature/Resources/Localizable.xcstrings`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` (add `.target(.favoritesFeature)` to `.appFeature` and `.appFeatureTests`)
- Test: `Modules/AppFeatureTests/AppReducerTests.swift`

**Interfaces:**
- Consumes: `FavoriteListReducer`, `RefreshFavoritesUseCase`.
- Produces: `AppTab.favorites`, `MainReducer.State.favoriteList`.

- [ ] **Step 1: Add the string**

To `Modules/AppFeature/Resources/Localizable.xcstrings`: `favorites` — en `Favorites`, de `Favoriten`. Byte-identical to the copy in `FavoritesFeature`.

- [ ] **Step 2: Write the failing test**

```swift
@Test
func test_didBecomeActive_refreshesFavorites() async {
    let refreshed = LockIsolated(false)

    let store = TestStore(initialState: AppReducer.State(main: .testValue())) {
        AppReducer()
    } withDependencies: {
        $0.refreshFavorites.execute = { force, _ in
            #expect(force == false)
            refreshed.setValue(true)
            return FavoriteRefreshResult()
        }
    }

    await store.send(.didBecomeActive)
    await store.finish()

    #expect(refreshed.value)
}

// The automatic path is silent: a failure must not surface anything.
@Test
func test_didBecomeActive_swallowsARefreshFailure() async {
    let store = TestStore(initialState: AppReducer.State(main: .testValue())) {
        AppReducer()
    } withDependencies: {
        $0.refreshFavorites.execute = { _, _ in throw ApiError.testValue() }
    }

    await store.send(.didBecomeActive)
    await store.finish()
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — `refreshFavorites` never called.

- [ ] **Step 4: Add the tab**

`AppTab` gains `case favorites`. `MainReducer.State` gains `var favoriteList: FavoriteListReducer.State` (built from `server`) with a `Scope`. `MainView` gains, between Documents and Settings:

```swift
FavoriteListView(
    store: store.scope(state: \.favoriteList, action: \.favoriteList)
)
.tabItem { Label(.favorites, systemImage: "heart.fill") }
.tag(AppTab.favorites)
```

- [ ] **Step 5: Add the automatic refresh**

In `AppReducer+Effect.swift`:

```swift
static func runRefreshFavorites(server: Server) -> Self {
    @Dependency(\.refreshFavorites.execute) var refreshFavorites

    // Silent by design: the user did not ask for this one, so neither success nor failure is
    // surfaced. Only pull-to-refresh and "Redownload all" report.
    return .run { _ in
        _ = try? await refreshFavorites(false, server)
    }
    .cancellable(id: CancelID.refreshFavorites)
}
```

Merge it into `case .didBecomeActive` beside `.runRefreshStatistics(server:)`, and into `bootstrap`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Tuist Modules/AppFeature Modules/AppFeatureTests
git commit -m "feat: a Favorites tab, refreshed on launch and on foreground"
```

---

### Task 11: The Settings screen

Rebase onto `main` first if PR #30 has merged; this task edits the section it reorders.

**Files:**
- Create: `Modules/SettingsFeature/FavoriteSettings/FavoriteSettingsReducer.swift`, `FavoriteSettingsView.swift`
- Modify: `Modules/SettingsFeature/SettingList/SettingListReducer.swift`, `SettingListView.swift`
- Modify: `Modules/SettingsFeature/Resources/Localizable.xcstrings`
- Test: `Modules/SettingsFeatureTests/FavoriteSettings/FavoriteSettingsReducerTests.swift`

**Interfaces:**
- Consumes: `FavoritesStore.totalByteCount`, `FavoritesStore.deleteAll`, `RefreshFavoritesUseCase`, `DeleteConfirmationPresenter`.
- Produces: `SettingListReducer.Path.State.favoriteSettings(FavoriteSettingsReducer.State)`.

- [ ] **Step 1: Add the strings**

| key | en | de |
|---|---|---|
| `favorites` | `Favorites` | `Favoriten` |
| `redownloadAll` | `Redownload all` | `Alle erneut laden` |
| `removeAllFavorites` | `Remove all favorites` | `Alle Favoriten entfernen` |
| `storageUsed` | `Storage used` | `Belegter Speicher` |

- [ ] **Step 2: Write the failing test**

```swift
@Test
func test_removeAllClearsRecordsAndFiles() async {
    let server = Server.testValue()
    let deleted = LockIsolated(false)

    @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = [
        .testValue(document: .testValue(id: 7))
    ]

    let store = TestStore(initialState: FavoriteSettingsReducer.State(server: server)) {
        FavoriteSettingsReducer()
    } withDependencies: {
        $0.deleteConfirmation.present = { _, _ in true }
        $0.favoritesStore.deleteAll = { _ in deleted.setValue(true) }
    }

    await store.send(.view(.removeAllButtonTapped))
    await store.receive(\.removed) { $0.totalByteCount = 0 }

    #expect(deleted.value)
    #expect($favorites.wrappedValue.isEmpty)
}

@Test
func test_redownloadAllForcesPhaseTwo() async {
    let forced = LockIsolated<Bool?>(nil)

    let store = TestStore(initialState: FavoriteSettingsReducer.State(server: .testValue())) {
        FavoriteSettingsReducer()
    } withDependencies: {
        $0.refreshFavorites.execute = { force, _ in forced.setValue(force); return .init() }
    }

    await store.send(.view(.redownloadAllButtonTapped)) { $0.isWorking = true }
    await store.receive(\.refreshResult) { $0.isWorking = false }

    #expect(forced.value == true)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme SettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL — `cannot find 'FavoriteSettingsReducer' in scope`.

- [ ] **Step 4: Write the reducer and view**

The screen shows `ByteCountFormatter.string(fromByteCount:countStyle:)` of `totalByteCount`, loaded `.onAppear`, and two buttons. "Remove all favorites" goes through `@Dependency(\.deleteConfirmation.present)` and, on confirmation, calls `favoritesStore.deleteAll(server)` then clears the shared array.

- [ ] **Step 5: Add the row**

In `SettingListView`'s last section, alphabetically between Diagnostics and GitHub:

```swift
NavigationLink(
    state: SettingListReducer.Path.State.favoriteSettings(FavoriteSettingsReducer.State(server: store.server))
) {
    Label(.favorites, systemImage: "heart")
}
.listRowBackground(Color.m3SurfaceContainer)
```

- [ ] **Step 6: Run tests; re-record the Settings snapshot**

The new row changes `SettingListViewTests.testSnapshot`. Re-record with the `SNAPSHOT_RECORD` procedure and look at the result: Diagnostics, Favorites, GitHub, Licenses, Tip jar.

- [ ] **Step 7: Commit**

```bash
git add Modules/SettingsFeature Modules/SettingsFeatureTests Snapshots/SettingsFeatureTests
git commit -m "feat: manage offline favorites from Settings"
```

---

### Task 12: Server cleanup, and the screenshots

**Files:**
- Modify: `Modules/ServersFeature/ServerList/ServerListReducer+Effect.swift` (wherever deletion happens)
- Modify: `Screenshots/Captures/**` (regenerated)
- Test: `Modules/ServersFeatureTests/ServerList/ServerListReducerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test
func test_deletingAServerDeletesItsFavorites() async {
    let deleted = LockIsolated<Server?>(nil)
    // …existing server-deletion test setup…
    // withDependencies: $0.favoritesStore.deleteAll = { deleted.setValue($0) }

    #expect(deleted.value?.id == server.id)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise exec -- xcodebuild test -workspace LessPaper.xcworkspace -scheme ServersFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
Expected: FAIL.

- [ ] **Step 3: Delete the favorites with the server**

Call `favoritesStore.deleteAll(server)` and clear `@Shared(.favorites(server))` in the deletion effect.

- [ ] **Step 4: Run the whole suite**

Run every scheme, or `mise exec -- xcodebuild build-for-testing -workspace LessPaper.xcworkspace -scheme "Less Paper" -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` followed by the per-scheme test runs.
Expected: all green.

- [ ] **Step 5: Re-record the App Store screenshots**

The fourth tab changes the tab bar in all seven screens.

```bash
mise run screenshots:capture   # about an hour
mise run screenshots:frame     # seconds
mise run screenshots:readme
```

Look at `Screenshots/Captures` before committing: every screen should show four tabs, and Settings should show the new Favorites row.

- [ ] **Step 6: Commit**

```bash
git add Modules/ServersFeature Modules/ServersFeatureTests Screenshots docs/images
git commit -m "chore: re-record the App Store captures for the Favorites tab"
```

---

## Self-Review

**Spec coverage.** Record and shared key → Task 1. PDF files, atomic write, size → Task 2. Save/remove → Task 3. Two-phase refresh, `force`, chunking, bounded concurrency, unavailable-on-absence, nothing-marked-on-failure → Task 4. Module → Task 5. `DocumentRowContent` → Task 6. Row with PDF thumbnail, badge, swipe → Task 7. List, search fields, refresh, empty state → Task 8. Context-menu item anchored above its divider, detail toolbar, `isOfflineSnapshot` → Task 9. Tab, launch and foreground refresh, silence → Task 10. Settings screen, size, redownload, remove all, A-Z row placement → Task 11. Server cleanup and screenshots → Task 12.

**Gap found and closed:** the dependency-override wiring was described but untested. Task 8 Step 8 now specifies both the wiring and the test that asserts the detail screen makes no network call — the one the spec calls out as catching a future fourth call, which would otherwise only surface offline.

**Types used consistently:** `FavoriteDocument.isUnavailable` (Tasks 1, 4, 7); `FavoritesStore.writePDF/deletePDF/deleteAll/totalByteCount/pdfURL` (Tasks 2, 3, 11, 12); `RefreshFavoritesUseCase.execute(force:server:)` returning `FavoriteRefreshResult(failed:unavailable:updated:)` (Tasks 4, 8, 10, 11); `favoriteButtonTapped` (Task 9). `unfavorite` is the same key in two catalogues (Tasks 7, 9), as the string convention requires.
