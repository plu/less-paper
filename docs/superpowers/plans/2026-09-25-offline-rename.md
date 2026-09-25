# Offline Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the Favorites feature to Offline everywhere — symbols, modules, user-facing copy in both languages, and the files on disk — without costing any existing user their downloaded PDFs or their configured swipe action.

**Architecture:** A rename cannot be split into chunks that each compile unless it is split by *symbol* rather than by module: renaming `FavoriteDocument` breaks every consumer in the same instant. So each task below renames one thing everywhere it appears, including the string keys of whichever module it touches, and ends with a tree that builds. The two pieces of genuine logic — the on-disk migration and the swipe action's decode alias — come first and are test-driven; everything after them is mechanical and is verified by the compiler, the snapshot references and a final grep.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-sharing, swift-snapshot-testing, swift-testing (`@Suite`/`@Test`/`#expect`), Tuist, mise.

**Spec:** `docs/superpowers/specs/2026-09-25-offline-design.md`

## Global Constraints

- **Comments are `//` only.** Never `///`, never `/** */`, anywhere, including test helpers. Comment only what a future reader would otherwise stop and wonder about.
- **Every module owns its strings.** A new key goes in `Modules/<Name>/Resources/Localizable.xcstrings`, in both `en` and `de`, with `"extractionState": "manual"`, keys sorted alphabetically. Two modules showing the same word each get their own key — the duplication is the design.
- **`@ViewAction` views send with `send`, never `store.send`.** Check for the annotation before copying a line between views.
- **Confirmations go through `PopupPresenter`/`ConfirmationPopupView`.** Never `.confirmationDialog`, `.alert` or `ConfirmationDialogState`.
- **Verify against the dev instance:** `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000` before both `tuist generate` and `tuist test`. It is read at generate time.
- **The unit test command, in full** (a hand-typed one is missing flags that cost ten minutes per failing run):
  ```bash
  export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
    'tuist test <Scheme> -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
     -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
  ```
- **`mise run ci:lint` before pushing.** It is five steps under `set -eou pipefail`, so the first failure hides the rest; expect a second failure after fixing a formatting one. `mise run format` fixes the first three mechanically.
- **Copy, verbatim, from the spec's string tables.** Do not invent German.
- **Accelerator, with a caveat:** `mise run rename -o Favorite -n Offline` renames files in the *current directory* whose name contains the old value and rewrites their contents. It does **not** touch files that mention `Favorite` without carrying it in their filename, and it does not recurse. Useful inside `Modules/OfflineFeature/OfflineList/`; never a substitute for the greps each task ends with.

## Review Focus

Five ways this can go wrong that the happy path never exercises. Each has a test, in the task that owns the code.

1. **The migration runs twice.** A second launch must not move anything, and must not throw. — Task 2
2. **Both paths exist.** A user who downgraded and came back has data at the legacy path *and* the new one; the new one is what the app reads, so it must win and the legacy file must be left alone rather than overwritten. — Task 2
3. **A fresh install has no legacy data.** The migration must create nothing and must not throw. — Task 2
4. **More than one server.** Every `<id>-favorites.json` must be renamed, not just the first, and every server's subdirectory must survive the PDF directory move. — Task 2
5. **A stored configuration naming the action twice.** After the alias, `["favorite", "saveOffline"]` decodes to the same case twice, which would draw the same swipe button twice. — Task 1

---

### Task 1: The swipe action becomes `.saveOffline`, and a stored `"favorite"` still works

`DocumentSwipeActionSettings.init(from:)` decodes through raw strings and `compactMap`s them, so an unrecognised value is **dropped** — the `?? defaults` only covers a missing key. Renaming the case without an alias would silently empty the edge of anyone who had configured that swipe.

**Files:**
- Modify: `Modules/Components/SwipeActions/DocumentSwipeAction.swift`
- Modify: `Modules/Components/SwipeActions/DocumentSwipeActionSettings.swift:33-37`
- Modify: `Modules/Components/Resources/Localizable.xcstrings`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentSwipeActionPlan.swift:40`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowSwipeActions.swift`
- Test: `Modules/ComponentsTests/SwipeActions/DocumentSwipeActionSettingsTests.swift`
- Test: `Modules/ComponentsTests/SwipeActions/DocumentSwipeActionTests.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentSwipeActionPlanTests.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`

**Interfaces:**
- Produces: `DocumentSwipeAction.saveOffline` (raw value `"saveOffline"`); `DocumentSwipeAction.init?(storedRawValue: String)`; `LocalizedStringResource.swipeActionOffline`

- [ ] **Step 1: Write the failing tests**

In `Modules/ComponentsTests/SwipeActions/DocumentSwipeActionSettingsTests.swift`, add:

```swift
// `favorite` is what this case's raw value was before the feature was renamed to Offline, and a
// configuration written by any shipped build still says it. Dropping it would not fail loudly -
// the decode below compactMaps - so the user's swipe would simply stop existing.
@Test
func decodingTranslatesTheLegacyFavoriteRawValue() async throws {
    let json = Data("""
    { "leading": ["favorite"], "trailing": ["share"] }
    """.utf8)

    let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

    #expect(decoded.leading == [.saveOffline])
}

// Review Focus 5. A downgrade and an upgrade can leave both spellings in one edge, and the alias
// turns them into the same case - which would draw the same button twice.
@Test
func decodingCollapsesTheLegacyAndCurrentSpellingsOfOneAction() async throws {
    let json = Data("""
    { "leading": ["favorite", "saveOffline"], "trailing": [] }
    """.utf8)

    let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

    #expect(decoded.leading == [.saveOffline])
}
```

And change the existing `decodingToleratesMissingKeys` — which already stores `"favorite"` — so it expects the new case:

```swift
#expect(decoded.leading == [.saveOffline])
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test Components -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: FAIL — `type 'DocumentSwipeAction' has no member 'saveOffline'`.

- [ ] **Step 3: Rename the case and add the alias**

In `DocumentSwipeAction.swift`, rename `case favorite` to `case saveOffline` (keep the list alphabetical: it sorts after `preview`), point `localized` at `.swipeActionOffline`, change `systemImage` from `"heart"` to `"arrow.down.circle"`, and update the comment above `systemImage`, which names the old feature:

```swift
// Save offline's glyph is the unfilled one here because this names the action, not the state of
// any one document. The swipe button swaps it for a document already saved.
```

Add below the `configurable` extension:

```swift
public extension DocumentSwipeAction {

    // `favorite` was this case's raw value before the feature was renamed to Offline, and a
    // stored configuration still carries it. Translated rather than ignored: the settings decode
    // compactMaps, so an unrecognised value is dropped and the user's swipe stops existing rather
    // than falling back to anything.
    init?(storedRawValue: String) {
        switch storedRawValue {
        case "favorite":
            self = .saveOffline
        default:
            self.init(rawValue: storedRawValue)
        }
    }
}
```

In `DocumentSwipeActionSettings.swift`, replace both `compactMap` lines with a call to one helper, so the de-duplication cannot be applied to one edge and forgotten on the other:

```swift
public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = Self()
    leading = try container.decodeIfPresent([String].self, forKey: .leading)
        .map(Self.actions(from:)) ?? defaults.leading
    trailing = try container.decodeIfPresent([String].self, forKey: .trailing)
        .map(Self.actions(from:)) ?? defaults.trailing
}

// De-duplicated, because the legacy alias maps two raw values onto one case: a configuration
// carrying both spellings would otherwise draw the same button twice.
private static func actions(from rawValues: [String]) -> [DocumentSwipeAction] {
    var seen: Set<DocumentSwipeAction> = []
    return rawValues
        .compactMap(DocumentSwipeAction.init(storedRawValue:))
        .filter { seen.insert($0).inserted }
}
```

- [ ] **Step 4: Rename the string key**

In `Modules/Components/Resources/Localizable.xcstrings`, rename `swipeActionFavorite` to `swipeActionOffline` (keys stay sorted alphabetically) and set both values to `Offline`:

```json
"swipeActionOffline" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : { "stringUnit" : { "state" : "translated", "value" : "Offline" } },
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Offline" } }
  }
}
```

- [ ] **Step 5: Fix the consumers so the tree builds**

```bash
grep -rln "\.favorite\b" --include="*.swift" Modules/DocumentsFeature Modules/ComponentsTests Modules/DocumentsFeatureTests
```

In `DocumentSwipeActionPlan.swift:40`, `case .favorite, .preview, .share:` becomes `case .preview, .saveOffline, .share:`. Update `DocumentRowSwipeActions.swift` and the three test files the grep names. Do **not** touch `DocumentRowReducer`'s own `favorite`-named actions yet — those are Task 6.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test Components -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Modules/Components Modules/ComponentsTests Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "refactor: the favorite swipe action becomes save offline

A stored configuration still says \"favorite\", and the settings decode compactMaps - so an
unrecognised raw value is dropped rather than defaulted, and the user's swipe would have stopped
existing. Translated on the way in instead, and de-duplicated, because the alias maps two spellings
onto one case.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: `OfflineStorageMigration`

New code, called by nobody yet. Written first because it must exist before the paths it moves *to* are the ones the app reads.

**Files:**
- Create: `Modules/ApiImplementation/Offline/OfflineStorageMigration.swift`
- Create: `Modules/ApiImplementationTests/Offline/OfflineStorageMigrationTests.swift`

**Interfaces:**
- Consumes: `URL.applicationGroupDirectory` (public, `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift:253`)
- Produces: `OfflineStorageMigration.run(in directory: URL = .applicationGroupDirectory)`

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiImplementationTests/Offline/OfflineStorageMigrationTests.swift`:

```swift
import ApiInterface
import Foundation
import Testing

@testable import ApiImplementation

@Suite
struct OfflineStorageMigrationTests {

    // A directory per test: swift-testing runs a suite's tests in parallel, and these all write.
    private static func directory() throws -> URL {
        let url = URL.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }

    @Test
    func movesTheRecordFileAndThePdfDirectory() async throws {
        let directory = try Self.directory()
        try Self.write("[]", to: directory.appending(component: "7-favorites.json"))
        try Self.write("%PDF", to: directory.appending(path: "Favorites/7/42.pdf"))

        OfflineStorageMigration.run(in: directory)

        let manager = FileManager.default
        #expect(manager.fileExists(atPath: directory.appending(component: "7-offline.json").path))
        #expect(manager.fileExists(atPath: directory.appending(path: "Offline/7/42.pdf").path))
        #expect(!manager.fileExists(atPath: directory.appending(component: "7-favorites.json").path))
        #expect(!manager.fileExists(atPath: directory.appending(path: "Favorites").path))
    }

    // Review Focus 4. One directory move carries every server's PDFs, but the JSON files are one
    // per server and are found by suffix - so a loop that stopped at the first would strand the
    // rest, and nothing would say so.
    @Test
    func movesEveryServersRecordFile() async throws {
        let directory = try Self.directory()
        try Self.write("[]", to: directory.appending(component: "7-favorites.json"))
        try Self.write("[]", to: directory.appending(component: "9-favorites.json"))
        try Self.write("%PDF", to: directory.appending(path: "Favorites/7/1.pdf"))
        try Self.write("%PDF", to: directory.appending(path: "Favorites/9/2.pdf"))

        OfflineStorageMigration.run(in: directory)

        let manager = FileManager.default
        #expect(manager.fileExists(atPath: directory.appending(component: "7-offline.json").path))
        #expect(manager.fileExists(atPath: directory.appending(component: "9-offline.json").path))
        #expect(manager.fileExists(atPath: directory.appending(path: "Offline/7/1.pdf").path))
        #expect(manager.fileExists(atPath: directory.appending(path: "Offline/9/2.pdf").path))
    }

    // Review Focus 1. Every launch runs this.
    @Test
    func runningTwiceChangesNothing() async throws {
        let directory = try Self.directory()
        try Self.write("[{\"id\":1}]", to: directory.appending(component: "7-favorites.json"))
        try Self.write("%PDF", to: directory.appending(path: "Favorites/7/42.pdf"))

        OfflineStorageMigration.run(in: directory)
        OfflineStorageMigration.run(in: directory)

        let records = directory.appending(component: "7-offline.json")
        #expect(try Data(contentsOf: records) == Data("[{\"id\":1}]".utf8))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Offline/7/42.pdf").path))
    }

    // Review Focus 2. A downgrade writes the legacy paths again beside data the new ones already
    // hold. The new path is the one the app reads, so it wins - and the legacy file is left where
    // it is rather than overwritten, because destroying it is the one outcome nobody can undo.
    @Test
    func aNewPathThatAlreadyHasDataIsNotOverwritten() async throws {
        let directory = try Self.directory()
        try Self.write("legacy", to: directory.appending(component: "7-favorites.json"))
        try Self.write("current", to: directory.appending(component: "7-offline.json"))

        OfflineStorageMigration.run(in: directory)

        #expect(try Data(contentsOf: directory.appending(component: "7-offline.json"))
            == Data("current".utf8))
        #expect(try Data(contentsOf: directory.appending(component: "7-favorites.json"))
            == Data("legacy".utf8))
    }

    // Review Focus 3. The ordinary case for every new install, on every launch.
    @Test
    func aDirectoryWithNothingToMigrateIsLeftAlone() async throws {
        let directory = try Self.directory()

        OfflineStorageMigration.run(in: directory)

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        #expect(contents.isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test ApiImplementation -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: FAIL — `cannot find 'OfflineStorageMigration' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Modules/ApiImplementation/Offline/OfflineStorageMigration.swift`:

```swift
import ApiInterface
import Foundation

// Favorites became Offline, and the two paths carrying the old name hold the user's downloaded
// PDFs. Getting this wrong does not throw: the list comes up empty, and the bytes stay on disk
// where nothing will ever read or reclaim them.
//
// No server list is needed, which is the point - this runs before anything that could supply one.
// Every server's PDFs sit inside one `Favorites` directory, so moving it moves all of them, and
// the per-server record files are found by suffix.
public enum OfflineStorageMigration {

    public static func run(in directory: URL = .applicationGroupDirectory) {
        move(
            directory.appending(component: "Favorites"),
            to: directory.appending(component: "Offline")
        )

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        for url in contents where url.lastPathComponent.hasSuffix("-favorites.json") {
            let renamed = url.lastPathComponent
                .replacingOccurrences(of: "-favorites.json", with: "-offline.json")
            move(url, to: directory.appending(component: renamed))
        }
    }

    // A destination that already exists means this has run before, or that a downgrade wrote the
    // legacy path again beside data the new one already holds. The new path is what the app reads,
    // so it wins and the legacy file is left standing: keeping a file nobody reads costs disk,
    // and overwriting the wrong one costs documents.
    //
    // Nothing here throws. A file that cannot be moved must not stop the app from launching.
    private static func move(_ source: URL, to destination: URL) {
        let manager = FileManager.default
        guard manager.fileExists(atPath: source.path),
              !manager.fileExists(atPath: destination.path)
        else {
            return
        }
        try? manager.moveItem(at: source, to: destination)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test ApiImplementation -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: PASS, five tests.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiImplementation/Offline Modules/ApiImplementationTests/Offline
git commit -m "feat: move the offline store off the Favorites paths

Not called yet. It has to exist before the paths it moves to are the ones the app reads.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: The storage layer renames

Symbols and paths only. No user-facing string changes here — those land with the views that show them.

**Files:**
- Rename: `Modules/ApiInterface/Favorites/` → `Modules/ApiInterface/Offline/`
- Rename: `Modules/ApiImplementation/Favorites/` → merge into `Modules/ApiImplementation/Offline/`
- Rename: `Modules/ApiImplementationTests/Favorites/` → merge into `Modules/ApiImplementationTests/Offline/`
- Rename: `Modules/ApiInterfaceTests/Favorites/` → `Modules/ApiInterfaceTests/Offline/`
- Rename: `Modules/ApiInterface/Extensions/JSONCoder+Favorites.swift` → `JSONCoder+Offline.swift`
- Modify: `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift:80-93`
- Modify: every consumer the greps in Step 4 name

**Interfaces:**
- Produces: `OfflineDocument`, `OfflineStore` / `\.offlineStore`, `RefreshOfflineUseCase` / `\.refreshOffline`, `SaveOfflineDocumentUseCase` / `\.saveOfflineDocument`, `RemoveOfflineDocumentUseCase` / `\.removeOfflineDocument`, `SharedReaderKey.offlineDocuments(_ server: Server)`, `JSONEncoder.offlineEncoder`, `JSONDecoder.offlineDecoder`

- [ ] **Step 1: Move the directories and files with git**

```bash
git mv Modules/ApiInterface/Favorites Modules/ApiInterface/Offline
git mv Modules/ApiInterfaceTests/Favorites Modules/ApiInterfaceTests/Offline
git mv Modules/ApiImplementation/Favorites/* Modules/ApiImplementation/Offline/ && rmdir Modules/ApiImplementation/Favorites
git mv Modules/ApiImplementationTests/Favorites/* Modules/ApiImplementationTests/Offline/ && rmdir Modules/ApiImplementationTests/Favorites
git mv Modules/ApiInterface/Extensions/JSONCoder+Favorites.swift Modules/ApiInterface/Extensions/JSONCoder+Offline.swift

git mv Modules/ApiInterface/Offline/FavoriteDocument.swift Modules/ApiInterface/Offline/OfflineDocument.swift
git mv Modules/ApiInterface/Offline/FavoritesStore.swift Modules/ApiInterface/Offline/OfflineStore.swift
git mv Modules/ApiInterface/Offline/RefreshFavoritesUseCase.swift Modules/ApiInterface/Offline/RefreshOfflineUseCase.swift
git mv Modules/ApiInterface/Offline/SaveFavoriteUseCase.swift Modules/ApiInterface/Offline/SaveOfflineDocumentUseCase.swift
git mv Modules/ApiInterface/Offline/RemoveFavoriteUseCase.swift Modules/ApiInterface/Offline/RemoveOfflineDocumentUseCase.swift
git mv Modules/ApiInterfaceTests/Offline/FavoriteDocumentTests.swift Modules/ApiInterfaceTests/Offline/OfflineDocumentTests.swift
git mv Modules/ApiImplementation/Offline/FavoritesStore+Live.swift Modules/ApiImplementation/Offline/OfflineStore+Live.swift
git mv Modules/ApiImplementation/Offline/RefreshFavoritesUseCase.swift Modules/ApiImplementation/Offline/RefreshOfflineUseCase.swift
git mv Modules/ApiImplementation/Offline/SaveFavoriteUseCase.swift Modules/ApiImplementation/Offline/SaveOfflineDocumentUseCase.swift
git mv Modules/ApiImplementation/Offline/RemoveFavoriteUseCase.swift Modules/ApiImplementation/Offline/RemoveOfflineDocumentUseCase.swift
git mv Modules/ApiImplementationTests/Offline/FavoritesStoreTests.swift Modules/ApiImplementationTests/Offline/OfflineStoreTests.swift
git mv Modules/ApiImplementationTests/Offline/RefreshFavoritesUseCaseTests.swift Modules/ApiImplementationTests/Offline/RefreshOfflineUseCaseTests.swift
git mv Modules/ApiImplementationTests/Offline/SaveFavoriteUseCaseTests.swift Modules/ApiImplementationTests/Offline/SaveOfflineDocumentUseCaseTests.swift
git mv Modules/ApiImplementationTests/Offline/RemoveFavoriteUseCaseTests.swift Modules/ApiImplementationTests/Offline/RemoveOfflineDocumentUseCaseTests.swift
```

- [ ] **Step 2: Rename the symbols across the whole tree**

Longest first, so a shorter pattern cannot eat a longer one's prefix:

```bash
files=$(grep -rl "Favorite\|favorite" --include="*.swift" Modules)
gsed -i \
  -e 's/SaveFavoriteUseCase/SaveOfflineDocumentUseCase/g' \
  -e 's/RemoveFavoriteUseCase/RemoveOfflineDocumentUseCase/g' \
  -e 's/RefreshFavoritesUseCase/RefreshOfflineUseCase/g' \
  -e 's/FavoritesStore/OfflineStore/g' \
  -e 's/FavoriteDocument/OfflineDocument/g' \
  -e 's/favoritesStore/offlineStore/g' \
  -e 's/saveFavorite/saveOfflineDocument/g' \
  -e 's/removeFavorite/removeOfflineDocument/g' \
  -e 's/refreshFavorites/refreshOffline/g' \
  -e 's/favoritesEncoder/offlineEncoder/g' \
  -e 's/favoritesDecoder/offlineDecoder/g' \
  $files
```

- [ ] **Step 3: Rename the shared key and both on-disk paths by hand**

In `SharedReaderKey+Extensions.swift`, the key becomes:

```swift
public extension SharedReaderKey
    where Self == FileStorageKey<IdentifiedArrayOf<OfflineDocument>>.Default {

    static func offlineDocuments(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-offline.json"),
                decoder: .offlineDecoder,
                encoder: .offlineEncoder
            ),
            default: []
        ]
    }
}
```

Then, across the tree, `.favorites(server)` becomes `.offlineDocuments(server)`:

```bash
gsed -i 's/\.favorites(\(server\|store\.server\|state\.server\))/.offlineDocuments(\1)/g' \
  $(grep -rl "\.favorites(" --include="*.swift" Modules)
grep -rn "\.favorites(" --include="*.swift" Modules   # must print nothing
```

In `OfflineStore+Live.swift`, the PDF directory:

```swift
private static func directory(_ server: Server) -> URL {
    URL.applicationGroupDirectory
        .appending(component: "Offline")
        .appending(component: "\(server.id)")
}
```

In `JSONCoder+Offline.swift`, update the comment's opening line, which still says *favorites*.

- [ ] **Step 4: Fix what the compiler still objects to**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- tuist generate --no-open
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- tuist build "Less Paper"
```

Local property names (`var favorites`, `favoriteDocuments`, test ids like `"favorites-store-tests-…"`) are not renamed by Step 2 and will not always fail the build. Catch them with:

```bash
grep -rn "favorit" -i --include="*.swift" Modules/ApiInterface Modules/ApiImplementation \
  Modules/ApiInterfaceTests Modules/ApiImplementationTests
```

Rename each to its offline spelling. `isOfflineSnapshot` in `DocumentsFeature` already reads correctly and does not move.

- [ ] **Step 5: Run the storage tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test ApiInterface -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test ApiImplementation -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A Modules
git commit -m "refactor: the offline store, by its own name

Symbols and the two paths on disk. The migration added in the previous commit is what carries a
user's existing files across; it is still not called.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Run the migration at launch

**Files:**
- Modify: `Modules/App/LessPaperApp.swift:19-33`

**Interfaces:**
- Consumes: `OfflineStorageMigration.run(in:)` from Task 2

- [ ] **Step 1: Call it first in `init`**

`@Shared(.offlineDocuments(server))` is opened lazily by whichever state is constructed first, and a read before the move would create an empty file at the new path and strand the old one. So it goes above everything, including `prepareDependencies`:

```swift
init() {
    // Before anything that could read the offline store. `@Shared(.offlineDocuments(server))` is
    // opened lazily by whichever state is built first, and a read that happens before the move
    // creates an empty file at the new path - which strands the user's documents at the old one
    // rather than failing in any way they could report.
    OfflineStorageMigration.run()

    // Before the DEBUG overrides below, which replace this with an in-memory store: the share
    // extension writes the same keys, and two processes reading their own UserDefaults.standard
    // is two review cooldowns rather than one.
    prepareDependencies {
        $0.defaultAppStorage = .appGroup
    }
    ...
}
```

`Modules/App` already depends on `apiImplementation`, so no manifest change is needed, and `import ApiImplementation` is already at the top of the file.

- [ ] **Step 2: Verify it builds**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- tuist build "Less Paper"
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Modules/App/LessPaperApp.swift
git commit -m "feat: migrate the offline files on launch

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: `FavoritesFeature` becomes `OfflineFeature`

**Files:**
- Rename: `Modules/FavoritesFeature` → `Modules/OfflineFeature`, `Modules/FavoritesFeatureTests` → `Modules/OfflineFeatureTests`
- Rename: `Snapshots/FavoritesFeatureTests` → `Snapshots/OfflineFeatureTests`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift:48-49,146,178,256,287`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift:38,55,277,289,297`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift:119,191`
- Modify: `Modules/OfflineFeature/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: `OfflineListReducer`, `OfflineListView`, `OfflineRowReducer`, `OfflineRowView`, `OfflineThumbnail`, `OfflineRefreshResult`, `OfflineListCancelID`

- [ ] **Step 1: Move the module**

```bash
git mv Modules/FavoritesFeature Modules/OfflineFeature
git mv Modules/FavoritesFeatureTests Modules/OfflineFeatureTests
git mv Snapshots/FavoritesFeatureTests Snapshots/OfflineFeatureTests
git mv Modules/OfflineFeature/FavoriteList Modules/OfflineFeature/OfflineList
git mv Modules/OfflineFeature/FavoriteRow Modules/OfflineFeature/OfflineRow
git mv Modules/OfflineFeatureTests/FavoriteList Modules/OfflineFeatureTests/OfflineList
git mv Modules/OfflineFeatureTests/FavoriteRow Modules/OfflineFeatureTests/OfflineRow

for dir in Modules/OfflineFeature/OfflineList Modules/OfflineFeature/OfflineRow \
           Modules/OfflineFeatureTests/OfflineList Modules/OfflineFeatureTests/OfflineRow; do
  for file in "$dir"/Favorite*; do
    git mv "$file" "$dir/$(basename "$file" | gsed 's/^Favorite/Offline/')"
  done
done

# Not caught by the loop above: its name does not start with Favorite. Task 3 rewrote what is
# inside it, not what it is called.
git mv Modules/OfflineFeature/OfflineList/UseCase+FavoritesStore.swift \
       Modules/OfflineFeature/OfflineList/UseCase+OfflineStore.swift
```

- [ ] **Step 2: Rename the symbols**

```bash
gsed -i \
  -e 's/FavoritesFeatureTests/OfflineFeatureTests/g' \
  -e 's/FavoritesFeature/OfflineFeature/g' \
  -e 's/FavoriteListReducer/OfflineListReducer/g' \
  -e 's/FavoriteListView/OfflineListView/g' \
  -e 's/FavoriteListCancelID/OfflineListCancelID/g' \
  -e 's/FavoriteRowReducer/OfflineRowReducer/g' \
  -e 's/FavoriteRowView/OfflineRowView/g' \
  -e 's/FavoriteThumbnail/OfflineThumbnail/g' \
  -e 's/FavoriteRefreshResult/OfflineRefreshResult/g' \
  $(grep -rl "Favorite" --include="*.swift" Modules)

gsed -i \
  -e 's/favoritesFeatureTests/offlineFeatureTests/g' \
  -e 's/favoritesFeature/offlineFeature/g' \
  -e 's/"FavoritesFeatureTests"/"OfflineFeatureTests"/g' \
  -e 's/"FavoritesFeature"/"OfflineFeature"/g' \
  Tuist/ProjectDescriptionHelpers/*.swift
```

Then reposition the two enum cases in `Module.swift` and their entries in all three manifests so the alphabetical ordering holds: `offlineFeature` sorts after `marketingKit` and before `pdfPasswordsFeature`, not where `favoritesFeature` sat.

- [ ] **Step 3: Rename the module's strings**

In `Modules/OfflineFeature/Resources/Localizable.xcstrings`, apply the spec's table. Keys sorted alphabetically:

| Old key | New key | en | de |
|---|---|---|---|
| `favorites` | `offline` | Offline | Offline |
| `favoriteUnavailable` | `offlineUnavailable` | Unavailable | Nicht verfügbar |
| `noFavorites` | `noOfflineDocuments` | Nothing saved offline yet | Noch nichts offline gespeichert |
| `noFavoritesFound` | `noOfflineDocumentsFound` | No offline documents found | Keine Offline-Dokumente gefunden |
| `noFavoritesMessage` | `noOfflineDocumentsMessage` | Documents you save offline stay on this device, ready to read without a connection. | Offline gespeicherte Dokumente bleiben auf diesem Gerät und sind ohne Verbindung lesbar. |
| `unfavorite` | `removeFromOffline` | Remove from Offline | Aus Offline entfernen |
| `favoritesUpToDate` | `offlineUpToDate` | Offline documents are up to date. | Offline-Dokumente sind aktuell. |

The three plural toasts keep their `one`/`other` variations and change only their nouns:

| Old key | New key | en one / other | de one / other |
|---|---|---|---|
| `favoritesRefreshUpdated` | `offlineRefreshUpdated` | One document updated. / %lld documents updated. | Ein Dokument aktualisiert. / %lld Dokumente aktualisiert. |
| `favoritesRefreshFailed` | `offlineRefreshFailed` | One document could not be refreshed. / %lld documents could not be refreshed. | Ein Dokument konnte nicht aktualisiert werden. / %lld Dokumente konnten nicht aktualisiert werden. |
| `favoritesRefreshUnavailable` | `offlineRefreshUnavailable` | One document is no longer on the server. / %lld documents are no longer on the server. | Ein Dokument ist nicht mehr auf dem Server. / %lld Dokumente sind nicht mehr auf dem Server. |

Then update the call sites in `OfflineListView.swift` and `OfflineRowView.swift`, and change the empty state's `systemImage: "heart"` to `systemImage: "arrow.down.circle"`.

- [ ] **Step 4: Sweep the leftovers**

```bash
grep -rn "favorit" -i --include="*.swift" Modules/OfflineFeature Modules/OfflineFeatureTests
```

Rename every local property, test name and comment it prints — `visibleFavorites` → `visibleOfflineDocuments`, `var favorites` → `var offlineDocuments`, `test_searchFiltersOnTitle`'s server ids, and the comments in `OfflineListReducer` that say *favorite* where they now mean *offline document*.

- [ ] **Step 5: Regenerate, build and test**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- tuist generate --no-open
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test OfflineFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: the reducer tests PASS; the **view** tests FAIL on changed snapshots — the tab icon and the empty state have moved. That is the expected outcome here, not a problem; Task 9 re-records them.

- [ ] **Step 6: Commit**

```bash
git add -A Modules Tuist Snapshots
git commit -m "refactor: FavoritesFeature becomes OfflineFeature

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: The document's own button

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift`, `+Effect.swift`, `+TestValue.swift`, `DocumentDetailView.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`, `+Effect.swift`, `DocumentRowView.swift`, `DocumentRowDestinations.swift`
- Modify: `Modules/DocumentsFeature/DocumentViewer/DocumentViewerReducer.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentDetail/`, `DocumentRow/`, `DocumentViewer/`

- [ ] **Step 1: Rename the strings**

In `Modules/DocumentsFeature/Resources/Localizable.xcstrings`:

| Old key | New key | en | de |
|---|---|---|---|
| `favorite` | `saveOffline` | Save offline | Offline speichern |
| `unfavorite` | `removeFromOffline` | Remove from Offline | Aus Offline entfernen |

- [ ] **Step 2: Rename the symbols and the glyph**

```bash
gsed -i \
  -e 's/favoriteButtonTapped/saveOfflineButtonTapped/g' \
  -e 's/isFavorited/isSavedOffline/g' \
  -e 's/favoriteTapped/saveOfflineTapped/g' \
  -e 's/\.unfavorite\b/.removeFromOffline/g' \
  -e 's/\.favorite\b/.saveOffline/g' \
  $(grep -rl "favorit" -i --include="*.swift" Modules/DocumentsFeature Modules/DocumentsFeatureTests)
```

Then by hand, in `DocumentDetailView.swift` and `DocumentRowView.swift`, replace `"heart"` with `"arrow.down.circle"` and `"heart.fill"` with `"arrow.down.circle.fill"`.

- [ ] **Step 3: Sweep and fix what is left**

```bash
grep -rn "favorit" -i --include="*.swift" Modules/DocumentsFeature Modules/DocumentsFeatureTests
```

Rename the remaining properties, test names and comments. `isOfflineSnapshot` stays.

- [ ] **Step 4: Run the tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: reducer tests PASS; view tests FAIL on the changed glyph. Task 9 re-records.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "refactor: a document is saved offline, not favorited

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: The tab, Settings, and the server list

**Files:**
- Modify: `Modules/AppFeature/AppTab.swift`, `MainReducer.swift`, `MainView.swift:30-34`, `AppReducer.swift`, `AppReducer+Effect.swift`
- Modify: `Modules/AppFeature/Resources/Localizable.xcstrings`
- Rename: `Modules/SettingsFeature/FavoriteSettings/` → `OfflineSettings/`, same in `SettingsFeatureTests`
- Rename: `Snapshots/SettingsFeatureTests/FavoriteSettingsViewTests` → `OfflineSettingsViewTests`
- Modify: `Modules/SettingsFeature/SettingList/SettingListView.swift`, `SettingListReducer.swift`
- Modify: `Modules/SettingsFeature/Resources/Localizable.xcstrings`
- Modify: `Modules/ServersFeature/ServerList/ServerListReducer.swift`, `+Effect.swift`, `ServerDetail/ServerDetailView.swift`
- Modify: `Modules/ServersFeature/Resources/Localizable.xcstrings`
- Rename: `Snapshots/ServersFeatureTests/ServerDetailViewTests/testSnapshot_emptyCachesReadUnknownExceptFavorites.1.png`

- [ ] **Step 1: Move the Settings files**

```bash
git mv Modules/SettingsFeature/FavoriteSettings Modules/SettingsFeature/OfflineSettings
git mv Modules/SettingsFeatureTests/FavoriteSettings Modules/SettingsFeatureTests/OfflineSettings
git mv Snapshots/SettingsFeatureTests/FavoriteSettingsViewTests \
       Snapshots/SettingsFeatureTests/OfflineSettingsViewTests
for dir in Modules/SettingsFeature/OfflineSettings Modules/SettingsFeatureTests/OfflineSettings; do
  for file in "$dir"/Favorite*; do
    git mv "$file" "$dir/$(basename "$file" | gsed 's/^Favorite/Offline/')"
  done
done
git mv "Snapshots/ServersFeatureTests/ServerDetailViewTests/testSnapshot_emptyCachesReadUnknownExceptFavorites.1.png" \
       "Snapshots/ServersFeatureTests/ServerDetailViewTests/testSnapshot_emptyCachesReadUnknownExceptOffline.1.png"
```

- [ ] **Step 2: Rename the symbols**

```bash
gsed -i \
  -e 's/FavoriteSettingsReducer/OfflineSettingsReducer/g' \
  -e 's/FavoriteSettingsView/OfflineSettingsView/g' \
  -e 's/favoriteSettings/offlineSettings/g' \
  -e 's/favoriteList/offlineList/g' \
  -e 's/AppTab\.favorites/AppTab.offline/g' \
  -e 's/RefreshFavoritesCancelID/RefreshOfflineCancelID/g' \
  -e 's/emptyCachesReadUnknownExceptFavorites/emptyCachesReadUnknownExceptOffline/g' \
  $(grep -rl "avorit" -i --include="*.swift" Modules/AppFeature Modules/AppFeatureTests \
      Modules/SettingsFeature Modules/SettingsFeatureTests \
      Modules/ServersFeature Modules/ServersFeatureTests)
```

In `AppTab.swift`, rename `case favorites` to `case offline` and keep the declaration order as it is — it mirrors the tab order on screen, not the alphabet.

- [ ] **Step 3: Rename the strings in three catalogues**

`AppFeature`, `SettingsFeature` and `ServersFeature` each hold their own `favorites` key. In all three, rename it to `offline` with the value `Offline` in both `en` and `de`.

`SettingsFeature` additionally needs, matching `OfflineFeature`'s copies exactly:

| Old key | New key | en | de |
|---|---|---|---|
| `removeAllFavorites` | `removeAllOfflineDocuments` | Remove all offline documents | Alle Offline-Dokumente entfernen |
| `favoritesUpToDate` | `offlineUpToDate` | Offline documents are up to date. | Offline-Dokumente sind aktuell. |
| `favoritesRefreshUpdated` | `offlineRefreshUpdated` | One document updated. / %lld documents updated. | Ein Dokument aktualisiert. / %lld Dokumente aktualisiert. |
| `favoritesRefreshFailed` | `offlineRefreshFailed` | One document could not be refreshed. / %lld documents could not be refreshed. | Ein Dokument konnte nicht aktualisiert werden. / %lld Dokumente konnten nicht aktualisiert werden. |
| `favoritesRefreshUnavailable` | `offlineRefreshUnavailable` | One document is no longer on the server. / %lld documents are no longer on the server. | Ein Dokument ist nicht mehr auf dem Server. / %lld Dokumente sind nicht mehr auf dem Server. |

And `swipeActionsLeadingFooter` is **reworded, not renamed** — its last sentence names the old feature:

- en: `Up to two actions. A full swipe runs the first one. In Offline, removing the document always comes first.`
- de: `Bis zu zwei Aktionen. Eine volle Wischgeste führt die erste aus. In Offline steht das Entfernen immer an erster Stelle.`

- [ ] **Step 4: Change the two glyphs**

In `MainView.swift:33`, `Label(.offline, systemImage: "heart.fill")` becomes `Label(.offline, systemImage: "arrow.down.circle.fill")`. In `SettingListView.swift`, the *This device* section's row becomes `Label(.offline, systemImage: "arrow.down.circle")`. The comment above that section names Favorites and needs its first sentence rewritten:

```swift
// Nothing in here reaches the server. Offline documents are files downloaded onto this phone,
// PDF passwords live in its keychain, and the swipe actions are a preference held for the app
// rather than per account - which is why PDF passwords is no longer filed beside the server's own
// lists.
```

- [ ] **Step 5: Sweep, build and test**

```bash
grep -rn "favorit" -i --include="*.swift" Modules/AppFeature Modules/AppFeatureTests \
  Modules/SettingsFeature Modules/SettingsFeatureTests Modules/ServersFeature Modules/ServersFeatureTests
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test AppFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: reducer tests PASS; view tests FAIL on changed snapshots.

- [ ] **Step 6: Commit**

```bash
git add -A Modules Snapshots
git commit -m "feat: the Favorites tab is now Offline

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Screenshots, marketing and the capture filenames

**Files:**
- Modify: `Modules/SnapshotSupport/SnapshotBootstrap.swift`, `SnapshotCorpus.swift`
- Modify: `Modules/AppSnapshots/SnapshotLabels.swift`, `SnapshotTests.swift:75-82`
- Modify: `Modules/MarketingKit/MarketingScreen.swift:11,31-32,52-53`
- Modify: `Modules/MarketingKit/Resources/Localizable.xcstrings`
- Rename: four files under `Screenshots/Captures/*/`, and four snapshot references under `Snapshots/MarketingKitTests/`

- [ ] **Step 1: Rename the symbols and the screen id**

```bash
gsed -i \
  -e 's/favoriteDocumentIds/offlineDocumentIds/g' \
  -e 's/snapshotFavorites/snapshotOfflineDocuments/g' \
  -e 's/marketingFavorites/marketingOffline/g' \
  -e 's/08-Favorites/08-Offline/g' \
  -e 's/case favorites/case offline/g' \
  -e 's/testFavorites/testOffline/g' \
  $(grep -rl "avorit" -i --include="*.swift" Modules/SnapshotSupport Modules/AppSnapshots Modules/MarketingKit)
```

In `SnapshotLabels.swift`, rename the `favorites` property to `offline` and set **both** languages to `"Offline"` — German included; the tab reads the same in both.

In `MarketingScreen.swift`, keep the enum's cases in screen order, so `offline` stays where `favorites` was rather than moving alphabetically.

- [ ] **Step 2: Rename the marketing caption key**

In `Modules/MarketingKit/Resources/Localizable.xcstrings`, rename `marketing.favorites` to `marketing.offline`. **Leave both values exactly as they are** — *Keep what matters, even offline* and *Wichtiges bleibt offline lesbar* already describe the renamed feature.

- [ ] **Step 3: Rename the committed captures**

The framing step resolves `MarketingScreen.fileName` against `Screenshots/Captures/`, and `screenshots:frame` runs on any pull request touching MarketingKit or the captures. Renaming the id without renaming the files turns that job red. The content is stale until the re-record; the names must be right now.

```bash
for file in Screenshots/Captures/*/*-08-Favorites.png; do
  git mv "$file" "${file/08-Favorites/08-Offline}"
done
for file in Snapshots/MarketingKitTests/MarketingScreenshotTests/*Favorites*.png; do
  git mv "$file" "${file/Favorites/Offline}"
done
git status --short Screenshots Snapshots   # expect 4 + 4 renames
```

`verify_captures.py` counts eight screens per device and locale and never reads screen names, so it is unaffected either way.

- [ ] **Step 4: Verify the framing still resolves**

```bash
mise run screenshots:frame
ls fastlane/screenshots/en-US | grep 08-Offline   # expect two, iPhone and iPad
```

- [ ] **Step 5: Commit**

```bash
git add -A Modules Screenshots Snapshots
git commit -m "refactor: the offline screen, in the capture pipeline

The captures keep stale content under their new names so framing resolves; the re-record replaces
them once the search bar has landed too.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Re-record, sweep, and lint

**Files:**
- Modify: every reference under `Snapshots/` whose screen changed

- [ ] **Step 1: Re-record the affected schemes**

```bash
mise run snapshots:record OfflineFeature
mise run snapshots:record DocumentsFeature
mise run snapshots:record SettingsFeature
mise run snapshots:record AppFeature
mise run snapshots:record MarketingKit
```

The run ends in `TEST FAILED` and that is the success case — record mode writes the reference and then raises on every assertion. The task inverts that and fails only if nothing was recorded.

- [ ] **Step 2: Look at what was recorded**

```bash
mise run snapshots:diff
```

A reference records whatever the code produced, bug included — 14 German references once recorded showing English captions. Confirm the tab reads **Offline** in both languages, the glyph is the download arrow and not a heart, and no German screen has picked up English copy.

- [ ] **Step 3: The final sweep**

```bash
grep -rn "favorit" -i --include="*.swift" --include="*.xcstrings" --include="*.json" \
  --include="*.yml" --include="*.txt" . | grep -v "^./Derived" | grep -v "^./docs/"
```

Expected: **no output**. `docs/` is excluded on purpose — the older specs and plans are history and are left alone. If anything else prints, rename it.

- [ ] **Step 4: Lint**

```bash
mise run format
mise run ci:lint
```

It is five steps under `set -eou pipefail`, so the first failure hides the rest. `tuist inspect dependencies --only implicit` is the step a renamed module is most likely to trip, and the one no test can catch; its error names the target and the missing module, and the fix is a line in `Module+Dependencies.swift`.

- [ ] **Step 5: The full unit run**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test "Less Paper" -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   --skip-ui-tests -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: PASS.

- [ ] **Step 6: The UI journeys**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test "Less Paper" -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   --skip-unit-tests -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: PASS. `SettingsJourneyTests` asks for its sections by set and does not care that the Offline row moved; nothing in `AppUITests` navigates by the word *Favorites*.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "test: re-record the references after the offline rename

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
GIT_TERMINAL_PROMPT=0 mise exec -- fnox exec -- git \
  -c 'credential.helper=!f(){ echo username=x-access-token; echo "password=$GH_TOKEN"; };f' \
  push -u origin feat/offline
```
