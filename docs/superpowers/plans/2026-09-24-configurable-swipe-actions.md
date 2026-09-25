# Configurable Swipe Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give both document lists a leading and a trailing swipe, each built from a catalogue of actions the user picks in Settings, per screen, stored once for the whole app.

**Architecture:** The action enum and the stored configuration live in `Components`, which both `SettingsFeature` and `DocumentsFeature` already depend on. `DocumentsFeature` owns the two rules `Components` cannot know — whether an action applies to this document and user, and whether the edge may full-swipe — in a pure value (`DocumentSwipeActionPlan`) that a thin `ViewBuilder` renders. Clear-inbox-tags moves from `DocumentListReducer` down to `DocumentRowReducer` first, so every action is reachable from one store.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-sharing (`FileStorageKey`), swift-snapshot-testing, Swift Testing, Tuist.

**Spec:** `docs/superpowers/specs/2026-09-24-configurable-swipe-actions-design.md`

## Global Constraints

- **Comments are `//` only.** Never `///`, never `/** */`. Comment only what a reader would otherwise stop and wonder about. See `AGENTS.md`.
- **`@ViewAction` views call `send`, never `store.send`.** Views without the macro (including `View` extensions) use `store.send(.view(…))`.
- **Every user-facing string goes in the owning module's own `Localizable.xcstrings`**, in `en` and `de`, `"extractionState": "manual"`, keys sorted alphabetically. There is no shared catalogue. A module may only use strings from its own catalogue.
- **No swipe button takes `role: .destructive`** — it removes the row before the server or the confirmation has agreed (`TrashRowView.swift:43`).
- **Maximum 2 actions per edge** (`DocumentSwipeActionSettings.maximumActionsPerEdge`).
- **Run tests with the full command**, which carries flags a hand-typed run does not:
  ```
  export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c 'tuist test <SCHEME> -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
  ```
- **`mise run ci:lint` before pushing.** A green test run checks none of what it checks.
- **Record a new snapshot reference** with `mise run snapshots:record <SCHEME> --only <Suite>`; the run ending in `TEST FAILED` is the success case. Look at what was recorded before trusting it.

## Review Focus

Five conditions the spec implies that no obvious happy-path test would catch. Each has a test assigned to the task that owns the code.

1. **Every configured action on an edge is forbidden for this user** — the edge must not swipe open at all, rather than opening onto an empty tray. (Task 4)
2. **A configuration file written by a newer build names an unknown action** — the unknown one is dropped and the rest of the preference survives; it must not throw away the whole file. (Task 2)
3. **Delete is configured first on an edge** — a full swipe must not fire it; that edge sets `allowsFullSwipe: false`. (Task 4)
4. **A swipe attempted while multi-select is running** — no actions at all, because the row already carries a tap gesture and a checkmark. (Task 4)
5. **Clear-inbox-tags configured on the Documents list, on a document with no inbox tag** — omitted, so the swipe cannot claim to have cleared tags it never touched. (Task 4)

---

### Task 1: `DocumentSwipeAction` in Components

**Files:**
- Create: `Modules/Components/SwipeActions/DocumentSwipeAction.swift`
- Modify: `Modules/Components/Resources/Localizable.xcstrings`
- Test: `Modules/ComponentsTests/SwipeActions/DocumentSwipeActionTests.swift`

**Interfaces:**
- Consumes: `Localizable` protocol from `Modules/Components/Localizable.swift`.
- Produces: `public enum DocumentSwipeAction: String, CaseIterable, Codable, Equatable, Sendable` with cases `clearInboxTags, delete, edit, favorite, openNotes, preview, share`; `var localized: LocalizedStringResource`; `var systemImage: String`; `var isDestructive: Bool`.

- [ ] **Step 1: Write the failing test**

```swift
@testable import Components

import Foundation
import Testing

@Suite
struct DocumentSwipeActionTests {

    @Test
    func onlyDeleteIsDestructive() async throws {
        let destructive = DocumentSwipeAction.allCases.filter(\.isDestructive)

        #expect(destructive == [.delete])
    }

    // The raw value is what reaches disk, so renaming a case silently drops that action from every
    // stored configuration.
    @Test
    func rawValuesAreStable() async throws {
        #expect(DocumentSwipeAction.allCases.map(\.rawValue) == [
            "clearInboxTags",
            "delete",
            "edit",
            "favorite",
            "openNotes",
            "preview",
            "share"
        ])
    }

    @Test
    func everyActionHasAnIcon() async throws {
        #expect(DocumentSwipeAction.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c 'tuist test Components -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing -- -testLanguage en -testRegion DE -collect-test-diagnostics never'`
Expected: FAIL — `cannot find 'DocumentSwipeAction' in scope`.

- [ ] **Step 3: Add the strings**

Add these keys to `Modules/Components/Resources/Localizable.xcstrings`, keeping keys sorted alphabetically, each with `"extractionState": "manual"` and both `en` and `de`:

| key | en | de |
|---|---|---|
| `swipeActionClearInboxTags` | Clear inbox tags | Posteingangs-Tags entfernen |
| `swipeActionDelete` | Delete | Löschen |
| `swipeActionEdit` | Edit | Bearbeiten |
| `swipeActionFavorite` | Favorite | Favorit |
| `swipeActionOpenNotes` | Notes | Notizen |
| `swipeActionPreview` | Preview | Vorschau |
| `swipeActionShare` | Share | Teilen |

- [ ] **Step 4: Write the implementation**

```swift
// Modules/Components/SwipeActions/DocumentSwipeAction.swift
import Foundation

// String-backed rather than Int: the raw value is what a stored configuration carries, so it has to
// survive a case being added in the middle.
public enum DocumentSwipeAction: String, CaseIterable, Codable, Equatable, Sendable {
    case clearInboxTags
    case delete
    case edit
    case favorite
    case openNotes
    case preview
    case share
}

extension DocumentSwipeAction: Localizable {

    public var localized: LocalizedStringResource {
        switch self {
        case .clearInboxTags:
            .swipeActionClearInboxTags
        case .delete:
            .swipeActionDelete
        case .edit:
            .swipeActionEdit
        case .favorite:
            .swipeActionFavorite
        case .openNotes:
            .swipeActionOpenNotes
        case .preview:
            .swipeActionPreview
        case .share:
            .swipeActionShare
        }
    }

    // Favorite's glyph is the unfilled one here because this is the name of the action, not a report
    // of the document's state. The swipe button fills it in for a document already favorited.
    public var systemImage: String {
        switch self {
        case .clearInboxTags:
            "tray.and.arrow.down"
        case .delete:
            "trash"
        case .edit:
            "square.and.pencil"
        case .favorite:
            "heart"
        case .openNotes:
            "note.text"
        case .preview:
            "eye"
        case .share:
            "square.and.arrow.up"
        }
    }

    // Exists so the full-swipe rule can be applied without the caller matching on the case.
    public var isDestructive: Bool {
        self == .delete
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run the Components test command from Step 2.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/Components/SwipeActions/DocumentSwipeAction.swift Modules/Components/Resources/Localizable.xcstrings Modules/ComponentsTests/SwipeActions/DocumentSwipeActionTests.swift
git commit -m "feat: name the document swipe actions"
```

---

### Task 2: `DocumentSwipeActionSettings` and its storage

**Files:**
- Create: `Modules/Components/SwipeActions/DocumentSwipeActionSettings.swift`
- Test: `Modules/ComponentsTests/SwipeActions/DocumentSwipeActionSettingsTests.swift`

**Interfaces:**
- Consumes: `DocumentSwipeAction` from Task 1.
- Produces: `public struct DocumentSwipeActionSettings` with `var inbox: Edges`, `var documents: Edges`, `static let maximumActionsPerEdge = 2`; `public struct DocumentSwipeActionSettings.Edges` with `var leading: [DocumentSwipeAction]`, `var trailing: [DocumentSwipeAction]`; and `SharedReaderKey.documentSwipeActions`.

- [ ] **Step 1: Write the failing test**

```swift
@testable import Components

import Foundation
import Testing

@Suite
struct DocumentSwipeActionSettingsTests {

    @Test
    func defaultsAreEditLeadingAndClearInboxTrailingOnBothScreens() async throws {
        let settings = DocumentSwipeActionSettings()

        #expect(settings.inbox.leading == [.edit])
        #expect(settings.inbox.trailing == [.clearInboxTags])
        #expect(settings.documents.leading == [.edit])
        #expect(settings.documents.trailing == [.clearInboxTags])
    }

    @Test
    func roundTripsThroughJSON() async throws {
        let settings = DocumentSwipeActionSettings(
            documents: .init(leading: [.favorite], trailing: [.delete, .share]),
            inbox: .init(leading: [.edit, .preview], trailing: [.clearInboxTags])
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: data)

        #expect(decoded == settings)
    }

    // A configuration written by a newer build must cost the user the one action this build cannot
    // name, not the whole preference.
    @Test
    func decodingDropsUnknownActionsAndKeepsTheRest() async throws {
        let json = Data("""
        {
          "documents": { "leading": ["edit"], "trailing": ["share"] },
          "inbox": { "leading": ["teleport", "edit"], "trailing": ["clearInboxTags"] }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.inbox.leading == [.edit])
        #expect(decoded.inbox.trailing == [.clearInboxTags])
        #expect(decoded.documents.leading == [.edit])
        #expect(decoded.documents.trailing == [.share])
    }

    @Test
    func anEdgeOfOnlyUnknownActionsDecodesEmptyRatherThanThrowing() async throws {
        let json = Data("""
        {
          "documents": { "leading": ["teleport"], "trailing": [] },
          "inbox": { "leading": [], "trailing": [] }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.documents.leading.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the Components test command.
Expected: FAIL — `cannot find 'DocumentSwipeActionSettings' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Modules/Components/SwipeActions/DocumentSwipeActionSettings.swift
import Foundation
import SwiftSharing

public struct DocumentSwipeActionSettings: Codable, Equatable, Sendable {

    public struct Edges: Equatable, Sendable {
        public var leading: [DocumentSwipeAction]
        public var trailing: [DocumentSwipeAction]

        public init(
            leading: [DocumentSwipeAction],
            trailing: [DocumentSwipeAction]
        ) {
            self.leading = leading
            self.trailing = trailing
        }
    }

    // A third button is a menu the user has to stop and read, and a full swipe only ever fires the
    // first one anyway. The long-press menu is where the complete list already lives.
    public static let maximumActionsPerEdge = 2

    public var documents: Edges
    public var inbox: Edges

    public init(
        documents: Edges = .init(leading: [.edit], trailing: [.clearInboxTags]),
        inbox: Edges = .init(leading: [.edit], trailing: [.clearInboxTags])
    ) {
        self.documents = documents
        self.inbox = inbox
    }
}

extension DocumentSwipeActionSettings.Edges: Codable {

    private enum CodingKeys: String, CodingKey {
        case leading, trailing
    }

    // Decoded through the raw strings rather than the enum: a synthesised decoder throws on a case
    // it does not know, which would discard the whole preference rather than the one action a newer
    // build named.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leading = try container.decode([String].self, forKey: .leading)
            .compactMap(DocumentSwipeAction.init(rawValue:))
        trailing = try container.decode([String].self, forKey: .trailing)
            .compactMap(DocumentSwipeAction.init(rawValue:))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leading.map(\.rawValue), forKey: .leading)
        try container.encode(trailing.map(\.rawValue), forKey: .trailing)
    }
}

public extension SharedReaderKey
    where Self == FileStorageKey<DocumentSwipeActionSettings>.Default {

    // Not keyed by server, unlike the caches in ApiInterface: this is a preference, and a user's
    // muscle memory does not change when they switch servers. Same shape as the review and tip
    // prompts, which are also app-wide.
    static var documentSwipeActions: Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "document-swipe-actions.json"),
                decoder: JSONDecoder(),
                encoder: JSONEncoder()
            ),
            default: .init()
        ]
    }
}

// Components cannot see ApiInterface, which has its own copy. CertificatesFeature carries a third
// for the same reason.
private extension URL {

    static var applicationGroupDirectory: URL {
        guard let applicationGroupDirectory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.plunien.app.Paperless")
        else {
            return .documentsDirectory
        }
        return applicationGroupDirectory
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the Components test command.
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add Modules/Components/SwipeActions/DocumentSwipeActionSettings.swift Modules/ComponentsTests/SwipeActions/DocumentSwipeActionSettingsTests.swift
git commit -m "feat: store the swipe action configuration app-wide"
```

---

### Task 3: Move clear-inbox-tags into `DocumentRowReducer`

This is the refactor. Behaviour must not change: the same bulk edit, the same undo toast, the same list refresh. Only the owner changes.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+Effect.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/InboxView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Produces on `DocumentRowReducer.State`: `var inboxTags: [Tag.Id]` (the document's tags that are inbox tags).
- Produces on `DocumentRowReducer.Action.View`: `case clearInboxTagsButtonTapped`.
- Produces on `DocumentRowReducer.Action.Delegate`: `case inboxTagsChanged`.
- Removes from `DocumentListReducer`: `inboxTagIds`, `Action.View.clearInboxTagsSwiped`, `Action.inboxTagsCleared/inboxTagsFailed/inboxTagsRestored/inboxTagsUndone`, and the three effects `runClearInboxTags`, `runRestoreInboxTags`, `runPresentInboxTagsCleared`. Keeps `runInboxTagsRefresh` and the `animation` parameter on `runGetDocuments`.

- [ ] **Step 1: Write the failing tests on the row**

Add to `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`. These are the six tests from `ec30000`, retargeted from the list to the row.

```swift
    @Test
    func view_clearInboxTagsButtonTapped_removesOnlyTheInboxTags() async throws {
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        @Shared(.inboxTags(.testValue()))
        var inboxTags
        $inboxTags.withLock { $0 = [5, 7] }

        let store = TestStore(
            initialState: DocumentRowReducer.State.testValue(
                document: .testValue(id: 3, tags: [5, 6, 7, 8])
            )
        ) {
            DocumentRowReducer()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
            $0.toastPresenter.presentAction = { _, _ in false }
        }
        store.exhaustivity = .off

        await store.send(.view(.clearInboxTagsButtonTapped)) {
            $0.isUpdating = true
        }
        await store.receive(\.inboxTagsCleared) {
            $0.isUpdating = false
        }
        await store.receive(\.delegate.inboxTagsChanged)
        await store.finish()

        let sent = try #require(input.value)
        #expect(sent.documents == [3])
        #expect(sent.method == .modifyTags(.init(addTags: [], removeTags: [5, 7])))
    }

    @Test
    func view_clearInboxTagsButtonTapped_withoutInboxTagsDoesNothing() async throws {
        @Shared(.inboxTags(.testValue()))
        var inboxTags
        $inboxTags.withLock { $0 = [5, 7] }

        let store = TestStore(
            initialState: DocumentRowReducer.State.testValue(
                document: .testValue(id: 4, tags: [6, 8])
            )
        ) {
            DocumentRowReducer()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { _, _ in
                Issue.record("A document the inbox tags do not cover must not be written at all")
            }
        }

        await store.send(.view(.clearInboxTagsButtonTapped))
    }

    @Test
    func clearInboxTags_undoPutsTheSameTagsBack() async throws {
        let inputs = LockIsolated<[BulkEditDocumentsInput]>([])
        @Shared(.inboxTags(.testValue()))
        var inboxTags
        $inboxTags.withLock { $0 = [5, 7] }

        let store = TestStore(
            initialState: DocumentRowReducer.State.testValue(
                document: .testValue(id: 3, tags: [5, 6, 7, 8])
            )
        ) {
            DocumentRowReducer()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { input, _ in inputs.withValue { $0.append(input) } }
            $0.toastPresenter.presentAction = { _, _ in true }
        }
        store.exhaustivity = .off

        await store.send(.view(.clearInboxTagsButtonTapped))
        await store.receive(\.inboxTagsUndone)
        await store.receive(\.inboxTagsRestored)
        await store.finish()

        #expect(inputs.value.count == 2)
        #expect(inputs.value.last?.method == .modifyTags(.init(addTags: [5, 7], removeTags: [])))
    }

    @Test
    func clearInboxTags_toastLeftAloneRestoresNothing() async throws {
        let inputs = LockIsolated<[BulkEditDocumentsInput]>([])
        @Shared(.inboxTags(.testValue()))
        var inboxTags
        $inboxTags.withLock { $0 = [5, 7] }

        let store = TestStore(
            initialState: DocumentRowReducer.State.testValue(
                document: .testValue(id: 3, tags: [5, 6, 7, 8])
            )
        ) {
            DocumentRowReducer()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { input, _ in inputs.withValue { $0.append(input) } }
            $0.toastPresenter.presentAction = { _, _ in false }
        }
        store.exhaustivity = .off

        await store.send(.view(.clearInboxTagsButtonTapped))
        await store.finish()

        #expect(inputs.value.count == 1)
    }

    @Test
    func view_clearInboxTagsButtonTapped_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        @Shared(.inboxTags(.testValue()))
        var inboxTags
        $inboxTags.withLock { $0 = [5, 7] }

        let store = TestStore(
            initialState: DocumentRowReducer.State.testValue(
                document: .testValue(id: 3, tags: [5, 6, 7, 8])
            )
        ) {
            DocumentRowReducer()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in toasts.withValue { $0.append(value) } }
        }

        await store.send(.view(.clearInboxTagsButtonTapped)) {
            $0.isUpdating = true
        }
        await store.receive(\.inboxTagsFailed) {
            $0.isUpdating = false
        }

        #expect(toasts.value == [.error("Something went wrong")])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c 'tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing -- -testLanguage en -testRegion DE -collect-test-diagnostics never'`
Expected: FAIL — `type 'DocumentRowReducer.Action.View' has no member 'clearInboxTagsButtonTapped'`.

- [ ] **Step 3: Add the state, actions and effects to the row**

In `DocumentRowReducer.swift`, add to `Action`:

```swift
        case inboxTagsCleared(tags: [Tag.Id])
        case inboxTagsFailed(Error)
        case inboxTagsRestored
        case inboxTagsUndone(tags: [Tag.Id])
```

to `Action.Delegate`:

```swift
            case inboxTagsChanged
```

to `Action.View`, keeping the run alphabetical:

```swift
            case clearInboxTagsButtonTapped
```

to `State`, next to `favorites`:

```swift
        @SharedReader
        var inboxTagIds: [Tag.Id]

        // The document's own tags that are inbox tags. Empty is what makes the swipe action hide
        // rather than clear nothing and claim otherwise.
        var inboxTags: [Tag.Id] {
            document.tags.filter(Set(inboxTagIds).contains)
        }
```

and in `State.init`, next to the `favorites` line:

```swift
            self._inboxTagIds = SharedReader(wrappedValue: [], .inboxTags(server))
```

In the reducer body, add before `case let .view(viewAction):`:

```swift
            case let .inboxTagsCleared(tags: tags):
                state.isUpdating = false
                return .merge(
                    .send(.delegate(.inboxTagsChanged)),
                    .runPresentInboxTagsCleared(tags: tags)
                )
            case let .inboxTagsFailed(error):
                state.isUpdating = false
                return .toast(error)
            case .inboxTagsRestored:
                state.isUpdating = false
                return .send(.delegate(.inboxTagsChanged))
            case let .inboxTagsUndone(tags: tags):
                return .runRestoreInboxTags(
                    document: state.document.id,
                    tags: tags,
                    server: state.server
                )
```

and inside the `view` switch, before `case .deleteButtonTapped:`:

```swift
                case .clearInboxTagsButtonTapped:
                    let tags = state.inboxTags
                    guard !tags.isEmpty else {
                        return .none
                    }
                    state.isUpdating = true
                    return .runClearInboxTags(
                        document: state.document.id,
                        tags: tags,
                        server: state.server
                    )
```

- [ ] **Step 4: Move the three effects onto the row**

Cut `runClearInboxTags`, `runRestoreInboxTags` and `runPresentInboxTagsCleared` out of `DocumentListReducer+Effect.swift` and paste them into `DocumentRowReducer+Effect.swift`, adapted: they no longer send `.isUpdating(ids:isUpdating:)` (the reducer sets `state.isUpdating` directly now), and `runPresentInboxTagsCleared` no longer carries a document id.

```swift
    static func runClearInboxTags(
        document: Document.Id,
        tags: [Tag.Id],
        server: Server
    ) -> Self {
        @Dependency(\.bulkEditDocuments.execute)
        var bulkEditDocuments

        let input = BulkEditDocumentsInput(
            documents: [document],
            method: .modifyTags(.init(addTags: [], removeTags: tags))
        )

        return .run { send in
            try await bulkEditDocuments(input, server)
            await send(.inboxTagsCleared(tags: tags))
        } catch: { error, send in
            await send(.inboxTagsFailed(error))
        }
        .cancellable(id: CancelID.inboxTags(document))
    }

    static func runRestoreInboxTags(
        document: Document.Id,
        tags: [Tag.Id],
        server: Server
    ) -> Self {
        @Dependency(\.bulkEditDocuments.execute)
        var bulkEditDocuments

        let input = BulkEditDocumentsInput(
            documents: [document],
            method: .modifyTags(.init(addTags: tags, removeTags: []))
        )

        return .run { send in
            try await bulkEditDocuments(input, server)
            await send(.inboxTagsRestored)
        } catch: { error, send in
            await send(.inboxTagsFailed(error))
        }
        .cancellable(id: CancelID.inboxTags(document))
    }

    static func runPresentInboxTagsCleared(tags: [Tag.Id]) -> Self {
        @Dependency(\.toastPresenter.presentAction)
        var presentAction

        return .run { send in
            let wasUndone = await presentAction(
                .success(String(localized: .inboxTagsCleared(tags.count))),
                String(localized: .undo)
            )
            guard wasUndone else {
                return
            }
            await send(.inboxTagsUndone(tags: tags))
        }
    }
```

Add `case inboxTags(Document.Id)` to the row's `CancelID`, keeping it alphabetical.

- [ ] **Step 5: Strip the list reducer and answer the delegate**

From `DocumentListReducer.swift` delete `inboxTagIds`, the four `inboxTags*` action cases, the `clearInboxTagsSwiped` view case and all five of their handlers. Add, alongside the other `documents` element handlers:

```swift
            case let .documents(.element(id: id, action: .delegate(.inboxTagsChanged))):
                return .runInboxTagsRefresh(state: state, document: id)
```

From `DocumentListReducer+Effect.swift` delete `runClearInboxTags`, `runRestoreInboxTags` and `runPresentInboxTagsCleared`. Keep `runInboxTagsRefresh` and the `animation` parameter on `runGetDocuments` exactly as they are.

- [ ] **Step 6: Point the existing view at the row action**

In `InboxView.swift`, change the button's send from `send(.clearInboxTagsSwiped(rowStore.document))` to `rowStore.send(.view(.clearInboxTagsButtonTapped))`, and its visibility test from `store.inboxTagIds` to `!rowStore.inboxTags.isEmpty`. Task 5 deletes this method entirely; this step only keeps the build green.

- [ ] **Step 7: Retarget the list tests**

In `DocumentListReducerTests.swift`, delete the five tests that drove `clearInboxTagsSwiped` and the `inboxFilter` helper. Keep the refresh test, rewritten to send the delegate:

```swift
    @Test
    func documents_delegate_inboxTagsChanged_refreshesTheListAndTheBadge() async throws {
        let didGetDocuments = LockIsolated(false)
        let didGetStatistics = LockIsolated(false)
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                didGetDocuments.setValue(true)
                return .testValue()
            }
            $0.getStatistics.execute = { _ in
                didGetStatistics.setValue(true)
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.documents(.element(id: 3, action: .delegate(.inboxTagsChanged))))
        await store.finish()

        #expect(didGetDocuments.value)
        // The tab badge reads inboxDocumentCount, and only a statistics fetch writes it.
        #expect(didGetStatistics.value)
    }
```

- [ ] **Step 8: Run the tests**

Run the DocumentsFeature test command.
Expected: PASS. If a moved test needs *rewriting* rather than retargeting, stop — that is a signal the split is wrong, and the spec says so.

- [ ] **Step 9: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "refactor: move clearing inbox tags onto the document row"
```

---

### Task 4: `DocumentSwipeActionPlan` — which actions, and may it full-swipe

The two rules that cannot live in `Components`, as a pure value so they can be tested without a view.

**Files:**
- Create: `Modules/DocumentsFeature/DocumentRow/DocumentSwipeActionPlan.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentSwipeActionPlanTests.swift`

**Interfaces:**
- Consumes: `DocumentSwipeAction` (Task 1).
- Produces: `struct DocumentSwipeActionPlan: Equatable` with `let actions: [DocumentSwipeAction]` and `let allowsFullSwipe: Bool`, and an initialiser taking `configured:canDelete:canEdit:canViewNotes:hasInboxTags:isSelecting:`.

- [ ] **Step 1: Write the failing test**

```swift
@testable import DocumentsFeature

import Components
import Testing

@Suite
struct DocumentSwipeActionPlanTests {

    @Test
    func keepsConfiguredOrder() async throws {
        let plan = makePlan(configured: [.share, .edit])

        #expect(plan.actions == [.share, .edit])
        #expect(plan.allowsFullSwipe)
    }

    @Test
    func dropsActionsThisUserMayNotPerform() async throws {
        let plan = makePlan(configured: [.edit, .delete], canDelete: false, canEdit: false)

        #expect(plan.actions.isEmpty)
    }

    @Test
    func dropsOpenNotesWithoutThePermission() async throws {
        let plan = makePlan(configured: [.openNotes, .preview], canViewNotes: false)

        #expect(plan.actions == [.preview])
    }

    // Otherwise the swipe reports having cleared tags it never touched.
    @Test
    func dropsClearInboxTagsWhenTheDocumentHasNone() async throws {
        let plan = makePlan(configured: [.clearInboxTags, .share], hasInboxTags: false)

        #expect(plan.actions == [.share])
    }

    // An empty tray reads as a bug; a dead edge reads as "nothing here".
    @Test
    func anEdgeWhoseActionsAreAllHiddenIsEmptyAndDoesNotFullSwipe() async throws {
        let plan = makePlan(configured: [.clearInboxTags], hasInboxTags: false)

        #expect(plan.actions.isEmpty)
        #expect(!plan.allowsFullSwipe)
    }

    @Test
    func aDestructiveFirstActionSuppressesTheFullSwipe() async throws {
        let plan = makePlan(configured: [.delete, .share])

        #expect(plan.actions == [.delete, .share])
        #expect(!plan.allowsFullSwipe)
    }

    // Delete behind a non-destructive action is safe: a full swipe fires only the first.
    @Test
    func aDestructiveSecondActionLeavesTheFullSwipeAlone() async throws {
        let plan = makePlan(configured: [.share, .delete])

        #expect(plan.allowsFullSwipe)
    }

    @Test
    func selectionModeSuppressesEverything() async throws {
        let plan = makePlan(configured: [.edit, .share], isSelecting: true)

        #expect(plan.actions.isEmpty)
        #expect(!plan.allowsFullSwipe)
    }

    private func makePlan(
        configured: [DocumentSwipeAction],
        canDelete: Bool = true,
        canEdit: Bool = true,
        canViewNotes: Bool = true,
        hasInboxTags: Bool = true,
        isSelecting: Bool = false
    ) -> DocumentSwipeActionPlan {
        DocumentSwipeActionPlan(
            configured: configured,
            canDelete: canDelete,
            canEdit: canEdit,
            canViewNotes: canViewNotes,
            hasInboxTags: hasInboxTags,
            isSelecting: isSelecting
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the DocumentsFeature test command.
Expected: FAIL — `cannot find 'DocumentSwipeActionPlan' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Modules/DocumentsFeature/DocumentRow/DocumentSwipeActionPlan.swift
import Components
import Foundation

struct DocumentSwipeActionPlan: Equatable {
    let actions: [DocumentSwipeAction]
    let allowsFullSwipe: Bool
}

extension DocumentSwipeActionPlan {

    init(
        configured: [DocumentSwipeAction],
        canDelete: Bool,
        canEdit: Bool,
        canViewNotes: Bool,
        hasInboxTags: Bool,
        isSelecting: Bool
    ) {
        // Nothing swipes during a selection: the row already carries its own tap gesture and a
        // checkmark, and a swipe on top of that is two ways to mean different things at once.
        guard !isSelecting else {
            self.init(actions: [], allowsFullSwipe: false)
            return
        }

        let actions = configured.filter { action in
            switch action {
            case .clearInboxTags:
                hasInboxTags
            case .delete:
                canDelete
            case .edit:
                canEdit
            case .openNotes:
                canViewNotes
            case .favorite, .preview, .share:
                true
            }
        }

        self.init(
            actions: actions,
            // A full swipe fires the first action only, so it is the first one that decides. An
            // empty edge reads false here, which is what stops it swiping open onto nothing.
            allowsFullSwipe: actions.first.map { !$0.isDestructive } ?? false
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the DocumentsFeature test command.
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature/DocumentRow/DocumentSwipeActionPlan.swift Modules/DocumentsFeatureTests/DocumentRow/DocumentSwipeActionPlanTests.swift
git commit -m "feat: decide which swipe actions a row offers"
```

---

### Task 5: Render the swipe actions in both lists

**Files:**
- Create: `Modules/DocumentsFeature/DocumentRow/DocumentRowSwipeActions.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/InboxView.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListView.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings` (delete the now-unused `clearInboxTags` key)

**Interfaces:**
- Consumes: `DocumentSwipeActionPlan` (Task 4), `DocumentSwipeActionSettings.Edges` (Task 2), `DocumentRowReducer` (Task 3).
- Produces: `func documentSwipeActions(edges:isSelecting:store:) -> some View` on `View`.

- [ ] **Step 1: Write the implementation**

```swift
// Modules/DocumentsFeature/DocumentRow/DocumentRowSwipeActions.swift
import ComposableArchitecture
import Components
import DesignTokens
import SwiftUI

extension View {

    func documentSwipeActions(
        edges: DocumentSwipeActionSettings.Edges,
        isSelecting: Bool,
        store: StoreOf<DocumentRowReducer>
    ) -> some View {
        let leading = DocumentSwipeActionPlan(
            configured: edges.leading,
            canDelete: store.canDelete,
            canEdit: store.canEdit,
            canViewNotes: store.canViewNotes,
            hasInboxTags: !store.inboxTags.isEmpty,
            isSelecting: isSelecting
        )
        let trailing = DocumentSwipeActionPlan(
            configured: edges.trailing,
            canDelete: store.canDelete,
            canEdit: store.canEdit,
            canViewNotes: store.canViewNotes,
            hasInboxTags: !store.inboxTags.isEmpty,
            isSelecting: isSelecting
        )

        return swipeActions(edge: .leading, allowsFullSwipe: leading.allowsFullSwipe) {
            buttons(for: leading, store: store)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: trailing.allowsFullSwipe) {
            buttons(for: trailing, store: store)
        }
    }

    // Never `role: .destructive`, including for Delete: it removes the row the moment the button is
    // tapped, before the confirmation has been answered — the trap TrashRowView documents.
    @ViewBuilder
    private func buttons(
        for plan: DocumentSwipeActionPlan,
        store: StoreOf<DocumentRowReducer>
    ) -> some View {
        ForEach(plan.actions, id: \.self) { action in
            Button {
                store.send(.view(action.rowAction))
            } label: {
                Image(systemName: action.swipeImage(isFavorited: store.isFavorited))
            }
            .accessibilityLabel(action.swipeLabel(isFavorited: store.isFavorited))
            .disabled(store.isBusy)
            .tint(action.isDestructive ? .m3Error : .m3Primary)
        }
    }
}

private extension DocumentSwipeAction {

    var rowAction: DocumentRowReducer.Action.View {
        switch self {
        case .clearInboxTags:
            .clearInboxTagsButtonTapped
        case .delete:
            .deleteButtonTapped
        case .edit:
            .editButtonTapped
        case .favorite:
            .favoriteButtonTapped
        case .openNotes:
            .viewButtonTapped(.notes)
        case .preview:
            .previewButtonTapped
        case .share:
            .shareButtonTapped
        }
    }

    // Favorite is the one action whose button reports state rather than naming itself, the same way
    // the context menu's does: on a document already favorited it has to read as the undo.
    func swipeImage(isFavorited: Bool) -> String {
        guard self == .favorite else {
            return systemImage
        }
        return isFavorited ? "heart.slash" : "heart"
    }

    func swipeLabel(isFavorited: Bool) -> LocalizedStringResource {
        guard self == .favorite, isFavorited else {
            return localized
        }
        return .unfavorite
    }
}
```

- [ ] **Step 2: Apply it in `InboxView`**

Delete `clearInboxTagsButton(for:)` entirely. Replace the `.swipeActions(edge:allowsFullSwipe:)` modifier on the row with:

```swift
                        .documentSwipeActions(
                            edges: swipeActions.inbox,
                            isSelecting: store.documentSelection.isActive,
                            store: rowStore
                        )
```

and add the reader alongside `inboxDocumentCount`:

```swift
    @SharedReader(.documentSwipeActions)
    private var swipeActions: DocumentSwipeActionSettings
```

- [ ] **Step 3: Apply it in `DocumentListView`**

`DocumentListView.swift:100` shadows the outer `store` with its `ForEach` parameter, exactly as
`InboxView` did before `ec30000` renamed it. Rename it here too, or `swipeActions` resolves against
the row store and will not compile:

```swift
        ForEach(Array(store.scope(state: \.documents, action: \.documents))) { rowStore in
            DocumentRowView(store: rowStore)
                .documentSelectionOverlay(
                    document: rowStore.document.id,
                    store: documentSelectionStore
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .onAppear { send(.onRowAppear(rowStore.document)) }
                .padding(.x3)
                .documentSwipeActions(
                    edges: swipeActions.documents,
                    isSelecting: store.documentSelection.isActive,
                    store: rowStore
                )
        }
```

and add the reader as a property on the view:

```swift
    @SharedReader(.documentSwipeActions)
    private var swipeActions: DocumentSwipeActionSettings
```

- [ ] **Step 4: Delete the dead string**

Remove the `clearInboxTags` key from `Modules/DocumentsFeature/Resources/Localizable.xcstrings`. The swipe button now takes its label from `DocumentSwipeAction.localized` in Components. `inboxTagsCleared` and `undo` stay — the row's effect still uses them.

- [ ] **Step 5: Build and run the tests**

Run the DocumentsFeature test command.
Expected: PASS. The `InboxViewTests` snapshots must be unchanged — swipe actions are not visible in a static snapshot. If one changed, something else moved and it needs looking at rather than re-recording.

- [ ] **Step 6: Commit**

```bash
git add Modules/DocumentsFeature
git commit -m "feat: build both lists' swipes from the configuration"
```

---

### Task 6: The settings screen

One screen, four sections — Inbox leading, Inbox trailing, Documents leading, Documents trailing — each listing all seven actions with a checkmark. Tapping toggles; the cap is enforced by refusing a third. The spec calls this a picker over the catalogue; an inline section is that, without a navigation layer for a seven-item choice.

**Files:**
- Create: `Modules/SettingsFeature/SwipeActionSettings/SwipeActionSettingsReducer.swift`
- Create: `Modules/SettingsFeature/SwipeActionSettings/SwipeActionSettingsView.swift`
- Modify: `Modules/SettingsFeature/SettingList/SettingListReducer.swift`
- Modify: `Modules/SettingsFeature/SettingList/SettingListView.swift`
- Modify: `Modules/SettingsFeature/Resources/Localizable.xcstrings`
- Test: `Modules/SettingsFeatureTests/SwipeActionSettings/SwipeActionSettingsReducerTests.swift`
- Test: `Modules/SettingsFeatureTests/SwipeActionSettings/SwipeActionSettingsViewTests.swift`

**Interfaces:**
- Consumes: `DocumentSwipeAction`, `DocumentSwipeActionSettings`, `.documentSwipeActions` (Tasks 1–2).
- Produces: `SwipeActionSettingsReducer` with `State`, `Action.View.actionTapped(screen:edge:action:)` and `.resetButtonTapped`; `enum SwipeActionSettingsReducer.Screen { case documents, inbox }`; `enum SwipeActionSettingsReducer.Edge { case leading, trailing }`.

- [ ] **Step 1: Write the failing test**

```swift
@testable import SettingsFeature

import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(.testDependencies())
struct SwipeActionSettingsReducerTests {

    @Test
    func actionTapped_addsToTheEdge() async throws {
        let store = TestStore(initialState: SwipeActionSettingsReducer.State()) {
            SwipeActionSettingsReducer()
        }
        store.state.$settings.withLock { $0 = .init() }

        await store.send(.view(.actionTapped(screen: .inbox, edge: .leading, action: .share)))

        #expect(store.state.settings.inbox.leading == [.edit, .share])
    }

    @Test
    func actionTapped_removesOneAlreadyThere() async throws {
        let store = TestStore(initialState: SwipeActionSettingsReducer.State()) {
            SwipeActionSettingsReducer()
        }
        store.state.$settings.withLock { $0 = .init() }

        await store.send(.view(.actionTapped(screen: .inbox, edge: .leading, action: .edit)))

        #expect(store.state.settings.inbox.leading.isEmpty)
    }

    // A full swipe only fires the first action, so a third is a menu the user has to read.
    @Test
    func actionTapped_refusesAThirdActionOnAnEdge() async throws {
        let store = TestStore(initialState: SwipeActionSettingsReducer.State()) {
            SwipeActionSettingsReducer()
        }
        store.state.$settings.withLock {
            $0 = .init(inbox: .init(leading: [.edit, .share], trailing: []))
        }

        await store.send(.view(.actionTapped(screen: .inbox, edge: .leading, action: .preview)))

        #expect(store.state.settings.inbox.leading == [.edit, .share])
    }

    @Test
    func resetButtonTapped_restoresTheDefaults() async throws {
        let store = TestStore(initialState: SwipeActionSettingsReducer.State()) {
            SwipeActionSettingsReducer()
        }
        store.state.$settings.withLock {
            $0 = .init(documents: .init(leading: [], trailing: []), inbox: .init(leading: [], trailing: []))
        }

        await store.send(.view(.resetButtonTapped))

        #expect(store.state.settings == DocumentSwipeActionSettings())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: the test command with scheme `SettingsFeature`.
Expected: FAIL — `cannot find 'SwipeActionSettingsReducer' in scope`.

- [ ] **Step 3: Write the reducer**

```swift
// Modules/SettingsFeature/SwipeActionSettings/SwipeActionSettingsReducer.swift
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct SwipeActionSettingsReducer: Sendable {

    public enum Screen: Equatable, Sendable {
        case documents
        case inbox
    }

    public enum Edge: Equatable, Sendable {
        case leading
        case trailing
    }

    @ObservableState
    public struct State: Equatable {

        @Shared(.documentSwipeActions)
        var settings: DocumentSwipeActionSettings

        public init() {}
    }

    public enum Action: ViewAction {
        case view(View)

        public enum View {
            case actionTapped(screen: Screen, edge: Edge, action: DocumentSwipeAction)
            case resetButtonTapped
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case let .actionTapped(screen: screen, edge: edge, action: action):
                    state.$settings.withLock { settings in
                        settings.toggle(action, on: screen, edge: edge)
                    }
                    return .none
                case .resetButtonTapped:
                    state.$settings.withLock { $0 = .init() }
                    return .none
                }
            }
        }
    }
}

extension DocumentSwipeActionSettings {

    mutating func toggle(
        _ action: DocumentSwipeAction,
        on screen: SwipeActionSettingsReducer.Screen,
        edge: SwipeActionSettingsReducer.Edge
    ) {
        var actions = self[screen, edge]
        if let index = actions.firstIndex(of: action) {
            actions.remove(at: index)
        } else {
            // Silently refused rather than dropping the oldest: a tap that quietly evicts an action
            // the user picked a moment ago is worse than one that does nothing visible.
            guard actions.count < Self.maximumActionsPerEdge else {
                return
            }
            actions.append(action)
        }
        self[screen, edge] = actions
    }

    subscript(
        screen: SwipeActionSettingsReducer.Screen,
        edge: SwipeActionSettingsReducer.Edge
    ) -> [DocumentSwipeAction] {
        get {
            switch (screen, edge) {
            case (.documents, .leading): documents.leading
            case (.documents, .trailing): documents.trailing
            case (.inbox, .leading): inbox.leading
            case (.inbox, .trailing): inbox.trailing
            }
        }
        set {
            switch (screen, edge) {
            case (.documents, .leading): documents.leading = newValue
            case (.documents, .trailing): documents.trailing = newValue
            case (.inbox, .leading): inbox.leading = newValue
            case (.inbox, .trailing): inbox.trailing = newValue
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the SettingsFeature test command.
Expected: PASS, 4 tests.

- [ ] **Step 5: Add the strings**

Add to `Modules/SettingsFeature/Resources/Localizable.xcstrings`, sorted, `en` and `de`:

| key | en | de |
|---|---|---|
| `swipeActions` | Swipe actions | Wischgesten |
| `swipeActionsDocumentsLeading` | Documents — swipe right | Dokumente — nach rechts |
| `swipeActionsDocumentsTrailing` | Documents — swipe left | Dokumente — nach links |
| `swipeActionsFooter` | Up to two actions per side. A full swipe runs the first one. | Bis zu zwei Aktionen pro Seite. Eine volle Wischgeste führt die erste aus. |
| `swipeActionsInboxLeading` | Inbox — swipe right | Eingang — nach rechts |
| `swipeActionsInboxTrailing` | Inbox — swipe left | Eingang — nach links |
| `swipeActionsReset` | Reset to defaults | Auf Standard zurücksetzen |

- [ ] **Step 6: Write the view**

```swift
// Modules/SettingsFeature/SwipeActionSettings/SwipeActionSettingsView.swift
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: SwipeActionSettingsReducer.self)
public struct SwipeActionSettingsView: View {

    public var body: some View {
        Form {
            section(.swipeActionsInboxLeading, screen: .inbox, edge: .leading)
            section(.swipeActionsInboxTrailing, screen: .inbox, edge: .trailing)
            section(.swipeActionsDocumentsLeading, screen: .documents, edge: .leading)
            section(.swipeActionsDocumentsTrailing, screen: .documents, edge: .trailing)
            Section {
                Button(role: .destructive) {
                    send(.resetButtonTapped)
                } label: {
                    Text(.swipeActionsReset)
                }
            }
        }
        .navigationTitle(.swipeActions)
        .navigationBarTitleDisplayMode(.inline)
    }

    public init(store: StoreOf<SwipeActionSettingsReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<SwipeActionSettingsReducer>

    @ViewBuilder
    private func section(
        _ title: LocalizedStringResource,
        screen: SwipeActionSettingsReducer.Screen,
        edge: SwipeActionSettingsReducer.Edge
    ) -> some View {
        let selected = store.settings[screen, edge]
        Section {
            ForEach(DocumentSwipeAction.allCases, id: \.self) { action in
                Button {
                    send(.actionTapped(screen: screen, edge: edge, action: action))
                } label: {
                    HStack {
                        Label {
                            Text(action.localized)
                        } icon: {
                            Image(systemName: action.systemImage)
                        }
                        Spacer()
                        // The number rather than a tick: with two slots, which one runs on a full
                        // swipe is the thing the user needs to see.
                        if let index = selected.firstIndex(of: action) {
                            Text("\(index + 1)")
                                .foregroundStyle(Color.m3Primary)
                                .fontWeight(.bold)
                        }
                    }
                }
                .foregroundStyle(Color.m3OnSurface)
            }
        } header: {
            Text(title)
        } footer: {
            Text(.swipeActionsFooter)
        }
    }
}

#Preview {
    NavigationStack {
        SwipeActionSettingsView(
            store: Store(initialState: SwipeActionSettingsReducer.State()) {
                SwipeActionSettingsReducer()
            }
        )
    }
}
```

`DesignTokens` must be imported for `Color.m3Primary` and `Color.m3OnSurface`; add it if the file does not already have it.

- [ ] **Step 7: Wire it into the settings list**

In `SettingListReducer.swift` add to `Path`:

```swift
        case swipeActionSettings(SwipeActionSettingsReducer)
```

In `SettingListView.swift`, alongside the `favoriteSettings` link at line 161:

```swift
                    NavigationLink(
                        state: SettingListReducer.Path.State.swipeActionSettings(SwipeActionSettingsReducer.State())
                    ) {
                        Label(.swipeActions, systemImage: "hand.draw")
                    }
```

and add the matching `case` to the view's `destination` switch.

- [ ] **Step 8: Write the snapshot test**

```swift
@testable import SettingsFeature

import Components
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SwipeActionSettingsViewTests {

    @Test
    func testSnapshot_defaults() async throws {
        assertSnapshot(
            of: view(settings: .init()),
            as: .image(layout: .device(config: .iPhone12)),
            named: "defaults"
        )
    }

    @Test
    func testSnapshot_fullAndEmptyEdges() async throws {
        assertSnapshot(
            of: view(settings: .init(
                documents: .init(leading: [], trailing: []),
                inbox: .init(leading: [.edit, .share], trailing: [.delete])
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "fullAndEmptyEdges"
        )
    }

    private func view(settings: DocumentSwipeActionSettings) -> some View {
        let state = SwipeActionSettingsReducer.State()
        state.$settings.withLock { $0 = settings }
        return NavigationStack {
            SwipeActionSettingsView(
                store: Store(initialState: state) { SwipeActionSettingsReducer() }
            )
        }
    }
}
```

- [ ] **Step 9: Record the snapshots and look at them**

Run: `mise run snapshots:record SettingsFeature --only SettingsFeatureTests/SwipeActionSettingsViewTests`
Then open both PNGs under `Snapshots/SettingsFeatureTests/SwipeActionSettingsViewTests/` and check the numbering, the section titles and that nothing is clipped. A reference records whatever the code produced, bug included.

- [ ] **Step 10: Run the tests**

Run the SettingsFeature test command.
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add Modules/SettingsFeature Modules/SettingsFeatureTests Snapshots/SettingsFeatureTests
git commit -m "feat: choose the document list swipe actions in Settings"
```

---

### Task 7: Whole-branch verification

- [ ] **Step 1: Run every affected scheme**

Run the test command for `Components`, `DocumentsFeature` and `SettingsFeature` in turn.
Expected: all PASS.

- [ ] **Step 2: Run the lint gate**

Run: `mise run ci:lint`
Expected: Success. It is five steps under `set -eou pipefail`, so the first failure hides the rest — fix, rerun, expect a second.

- [ ] **Step 3: Check for warnings the local build tolerates**

Run: `TUIST_WARNINGS_AS_ERRORS=true mise exec -- tuist generate --no-open` then build `DocumentsFeature`, `Components` and `SettingsFeature`.
Expected: no new warnings in the modules touched. A pre-existing one in `FileTaskListReducer.swift:25` is not ours.

- [ ] **Step 4: Drive the app**

Build and run on the simulator. With a document carrying an inbox tag: swipe it both ways on both lists, check the default bindings, change them in Settings, and confirm the change takes effect without relaunching. Then set Delete first on an edge and confirm a full swipe does not fire it.

**This is the only step that can test the gesture.** Neither a `TestStore` nor the simulator automation can drive a real full swipe — the automation's drag starts at the element's centre and never crosses the threshold. Do it by hand.

- [ ] **Step 5: Commit any fixes and push**

```bash
git push -u origin feat/configurable-swipe-actions
```
