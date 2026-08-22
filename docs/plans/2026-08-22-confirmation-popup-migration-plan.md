# Confirmation popup migration — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Design: [2026-08-22-confirmation-popup-migration.md](2026-08-22-confirmation-popup-migration.md)

**Goal:** Remove every remaining `ConfirmationDialogState` and `.confirmationDialog` from `Modules/`
by routing the six list-row delete confirmations through one shared `DeleteConfirmationPresenter`
that shows `ConfirmationPopupView`.

**Architecture:** A single `@DependencyClient` in `Components`, registered as `\.deleteConfirmation`,
takes an entity title and a record name and returns whether the user confirmed. Each row reducer
drops its `Destination` machinery and instead returns a `runConfirmDelete` effect that awaits the
presenter and sends the row's existing `.delegate` case on confirmation.

**Tech Stack:** Swift 6.1, SwiftUI, ComposableArchitecture (TCA), swift-dependencies
(`@DependencyClient`), SwiftMessages (via `PopupPresenter`), Swift Testing, XCTest for XCUITests,
Tuist, mise.

## Global Constraints

- **Comments:** never `///` or `/** */`. Only `//`, and only when a future reader would otherwise
  stop and wonder why the code is the way it is. See `AGENTS.md`.
- **`@ViewAction` views send with `send`, never `store.send`.** All six row views carry the macro.
- **No `.confirmationDialog`, `.alert`, or `ConfirmationDialogState`** in new code. See `AGENTS.md`.
- **Imports are alphabetical** — `sorted_imports` is enforced by SwiftLint (`.swiftlint.yml:54`).
- **Preserve each type's existing member order**, minus the removed `destination`. Most of these
  types are alphabetical, but `StoragePathRowReducer.State` and `SavedViewRowReducer.State` are not
  — reordering them would change their memberwise init's argument order and break call sites for no
  gain.
- **Run `mise run format` before every commit.** It runs `swiftlint --fix`, `swiftformat` and
  `mise/scripts/attribute_blank_lines.py`.
- **Popup copy is fixed:** title = the entity string (`.deleteTag`, `.deleteCorrespondent`,
  `.deleteDocumentType`, `.deleteSavedView`, `.deleteServer`, `.deleteStoragePath`), message =
  `.deleteConfirmation(name)`, confirm button = `ConfirmationPopupView`'s default `.confirm`
  ("Confirm"), cancel = default `.cancel`. **No new strings are added to
  `Shared/Framework/Resources/Localizable.xcstrings`** — every key already exists, and adding one
  invalidates all ~30 modules' fingerprints.
- **Unit tests:** `tuist test <Scheme> -d "iPhone 17 Pro"`, e.g. `TagsFeature`.
- **XCUITests:** `tuist test <Scheme>App -d "iPhone 17 Pro"`, e.g. `TagsApp`. These need the local
  paperless container: run `mise run docker:start` first.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `Modules/Components/Popup/DeleteConfirmationPresenter.swift` | The one presenter. Builds a destructive `ConfirmationPopupView` from a title and a record name; returns the user's answer. |
| `Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowReducer+Effect.swift` | `runConfirmDelete(name:)` for `CorrespondentRow`. |
| `Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowReducer+Effect.swift` | `runConfirmDelete(name:)` for `DocumentTypeRow`. |
| `Modules/SavedViewsFeature/SavedViewRow/SavedViewRowReducer+Effect.swift` | `runConfirmDelete(name:)` for `SavedViewRow`. |
| `Modules/StoragePathsFeature/StoragePathRow/StoragePathRowReducer+Effect.swift` | `runConfirmDelete(name:)` for `StoragePathRow`. |
| `Modules/TagsFeature/TagRow/TagRowReducer+Effect.swift` | `runConfirmDelete(name:)` for `TagRow`. |

**Deleted:** the six `…RowReducer+ConfirmationDialogState.swift` files.

**Modified:** the six `…RowReducer.swift`, the six `…RowView.swift`, the six
`…RowReducerTests.swift`, the six `…AppTests.swift`, plus `AGENTS.md` and `docs/ideas.md`.

`ServerRowReducer+Effect.swift` already exists and gains a method rather than being created.

---

## Task 1: `DeleteConfirmationPresenter` and `TagRow`

This is the checkpoint task. No existing XCUITest drives a `ConfirmationPopupView`, so this task
proves both halves — the presenter and the XCUITest reach — before the pattern is copied five more
times. Do not start Task 2 until `TagsApp` passes.

**Files:**
- Create: `Modules/Components/Popup/DeleteConfirmationPresenter.swift`
- Create: `Modules/TagsFeature/TagRow/TagRowReducer+Effect.swift`
- Delete: `Modules/TagsFeature/TagRow/TagRowReducer+ConfirmationDialogState.swift`
- Modify: `Modules/TagsFeature/TagRow/TagRowReducer.swift`
- Modify: `Modules/TagsFeature/TagRow/TagRowView.swift`
- Test: `Modules/TagsFeatureTests/TagRow/TagRowReducerTests.swift`
- Test: `Modules/TagsAppTests/TagsAppTests.swift`

**Interfaces:**
- Consumes: `PopupPresenter.present(resolving:)` from `Components/Popup/PopupPresenter+Present.swift`
  — `func present<Result: Sendable>(resolving popup: @escaping @Sendable @MainActor (_ resolve: @escaping @Sendable (Result) -> Void) -> any View) async -> Result?`
- Produces: `DependencyValues.deleteConfirmation: DeleteConfirmationPresenter` with
  `present: @Sendable (_ title: LocalizedStringResource, _ name: String) async -> Bool`.
  **Tasks 2–6 all call exactly this.**

- [ ] **Step 1: Write the failing test**

Replace the whole of `Modules/TagsFeatureTests/TagRow/TagRowReducerTests.swift` with:

```swift
@testable import TagsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct TagRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: TagRowReducer.State(
            server: .testValue(),
            tag: .testValue(name: "Inbox")
        )) {
            TagRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: TagRowReducer.State(
            server: .testValue(),
            tag: .testValue(name: "Inbox")
        )) {
            TagRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteTag)

        #expect(presented.value?.title == .deleteTag)
        #expect(presented.value?.name == "Inbox")
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: TagRowReducer.State(
            server: .testValue(),
            tag: .testValue()
        )) {
            TagRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editTag)
    }
}
```

`Tag.testValue(name:)` already defaults to `"Inbox"` (`Modules/ApiInterface/Tags/Tag.swift:151`);
passing it explicitly is only for readability against the assertion below it.

- [ ] **Step 2: Run the test and watch it fail**

```bash
tuist test TagsFeature -d "iPhone 17 Pro"
```

Expected: compile failure — `value of type 'DependencyValues' has no member 'deleteConfirmation'`.

- [ ] **Step 3: Add the presenter**

Create `Modules/Components/Popup/DeleteConfirmationPresenter.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteConfirmationPresenter: Sendable {
    public var present: @Sendable (
        _ title: LocalizedStringResource,
        _ name: String
    ) async -> Bool = { _, _ in false }
}

extension DeleteConfirmationPresenter: TestDependencyKey {

    public static let previewValue = Self(
        present: { _, _ in false }
    )

    public static let testValue = Self()
}

extension DeleteConfirmationPresenter: DependencyKey {

    public static let liveValue = Self(
        present: present(title:name:)
    )
}

private extension DeleteConfirmationPresenter {

    static func present(title: LocalizedStringResource, name: String) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: title,
                message: .deleteConfirmation(name),
                isDestructive: true,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

public extension DependencyValues {

    var deleteConfirmation: DeleteConfirmationPresenter {
        get { self[DeleteConfirmationPresenter.self] }
        set { self[DeleteConfirmationPresenter.self] = newValue }
    }
}
```

- [ ] **Step 4: Add the effect**

Create `Modules/TagsFeature/TagRow/TagRowReducer+Effect.swift`:

```swift
import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == TagRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteTag, name) else {
                return
            }
            await send(.delegate(.deleteTag))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
```

- [ ] **Step 5: Strip the destination out of the reducer**

Replace the whole of `Modules/TagsFeature/TagRow/TagRowReducer.swift` with:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct TagRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteTag
            case editTag
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Tag.Id { tag.id }

        var isUpdating = false

        let server: Server

        let tag: Tag
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editTag))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.tag.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 6: Delete the dialog state file**

```bash
git rm Modules/TagsFeature/TagRow/TagRowReducer+ConfirmationDialogState.swift
```

- [ ] **Step 7: Drop the dialog from the view**

In `Modules/TagsFeature/TagRow/TagRowView.swift`, delete this line:

```swift
        .confirmationDialog($store.scope(state: \.destination?.confirmation, action: \.destination.confirmation))
```

and change the store declaration from:

```swift
    @Bindable
    var store: StoreOf<TagRowReducer>
```

to:

```swift
    var store: StoreOf<TagRowReducer>
```

`@Bindable` was there only for the dialog scope. `var store: StoreOf<…>` without it is the
established convention — see `Modules/ServersFeature/ServerList/ServerListView.swift:42`.

- [ ] **Step 8: Run the unit tests and watch them pass**

```bash
tuist test TagsFeature -d "iPhone 17 Pro"
```

Expected: PASS. If `TagListReducerTests` fails to compile, it is referencing `destination` on a row
— fix by deleting that argument, not by restoring the destination.

- [ ] **Step 9: Point the XCUITests at the popup**

In `Modules/TagsAppTests/TagsAppTests.swift`, in **both** `testDelete` and `testDeleteFailure`,
replace:

```swift
        app.sheets.buttons["Delete tag"].firstMatch.tap()
```

with:

```swift
        app.buttons["Confirm"].firstMatch.tap()
```

Leave the `XCTAssertTrue(app.staticTexts["Do you really want to delete \"Inbox\"?"]…)` line above
each one untouched — the popup renders that string as a `Text`.

- [ ] **Step 10: Run the XCUITests — the checkpoint**

```bash
mise run docker:start
tuist test TagsApp -d "iPhone 17 Pro"
```

Expected: PASS, including `testDelete` and `testDeleteFailure`.

**If `app.buttons["Confirm"]` is not found**, the popup's SwiftMessages window is not in the
queried hierarchy. Before trying anything else, capture what *is* there by adding
`print(app.debugDescription)` after the `staticTexts` assertion and re-running. Two fallbacks, in
order:

1. Query the popup's own window: `app.windows.buttons["Confirm"].firstMatch.tap()`.
2. Add an accessibility identifier in `Modules/Components/Popup/ConfirmationPopupView.swift` — on
   the confirm `Button`, `.accessibilityIdentifier("confirmationPopupConfirm")`, and on the cancel
   `Button`, `.accessibilityIdentifier("confirmationPopupCancel")` — then query
   `app.buttons["confirmationPopupConfirm"]`. If you take this route, **record it in this plan file
   and use the same identifiers in Tasks 2–6.** Re-record the `ConfirmationPopupViewTests`
   snapshots only if they actually change (`mise run snapshots:diff` shows the delta); an
   identifier alone should not alter rendering.

- [ ] **Step 11: Format and commit**

```bash
mise run format
git add -A
git commit -m "$(cat <<'EOF'
refactor: confirm tag deletes with the custom popup

Adds one DeleteConfirmationPresenter in Components and moves TagRow onto
it. The system dialog renders as a clipped popover when presented from
inside a sheet; the popup does not.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `CorrespondentRow`

**Files:**
- Create: `Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowReducer+Effect.swift`
- Delete: `Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowReducer+ConfirmationDialogState.swift`
- Modify: `Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowReducer.swift`
- Modify: `Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowView.swift`
- Test: `Modules/CorrespondentsFeatureTests/CorrespondentRow/CorrespondentRowReducerTests.swift`
- Test: `Modules/CorrespondentsAppTests/CorrespondentsAppTests.swift`

**Interfaces:**
- Consumes: `DependencyValues.deleteConfirmation.present(_ title: LocalizedStringResource, _ name: String) async -> Bool` from Task 1.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Write the failing test**

Replace the whole of
`Modules/CorrespondentsFeatureTests/CorrespondentRow/CorrespondentRowReducerTests.swift` with:

```swift
@testable import CorrespondentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct CorrespondentRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: CorrespondentRowReducer.State.testValue()) {
            CorrespondentRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let correspondent = Correspondent.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: CorrespondentRowReducer.State.testValue(
            correspondent: correspondent
        )) {
            CorrespondentRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteCorrespondent)

        #expect(presented.value?.title == .deleteCorrespondent)
        #expect(presented.value?.name == correspondent.name)
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: CorrespondentRowReducer.State.testValue()) {
            CorrespondentRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editCorrespondent)
    }
}
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
tuist test CorrespondentsFeature -d "iPhone 17 Pro"
```

Expected: compile failure — `type 'Effect<CorrespondentRowReducer.Action>' has no member 'runConfirmDelete'`, or a failure that the reducer still mutates `destination`.

- [ ] **Step 3: Add the effect**

Create `Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowReducer+Effect.swift`:

```swift
import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == CorrespondentRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteCorrespondent, name) else {
                return
            }
            await send(.delegate(.deleteCorrespondent))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
```

- [ ] **Step 4: Strip the destination out of the reducer**

Replace the whole of
`Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowReducer.swift` with:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct CorrespondentRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteCorrespondent
            case editCorrespondent
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Correspondent.Id { correspondent.id }

        let correspondent: Correspondent

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editCorrespondent))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.correspondent.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 5: Delete the dialog state file**

```bash
git rm Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowReducer+ConfirmationDialogState.swift
```

- [ ] **Step 6: Drop the dialog from the view**

In `Modules/CorrespondentsFeature/CorrespondentRow/CorrespondentRowView.swift`, delete:

```swift
        .confirmationDialog($store.scope(state: \.destination?.confirmation, action: \.destination.confirmation))
```

and change:

```swift
    @Bindable
    var store: StoreOf<CorrespondentRowReducer>
```

to:

```swift
    var store: StoreOf<CorrespondentRowReducer>
```

- [ ] **Step 7: Run the unit tests and watch them pass**

```bash
tuist test CorrespondentsFeature -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 8: Point the XCUITests at the popup**

In `Modules/CorrespondentsAppTests/CorrespondentsAppTests.swift`, in **both** delete tests,
replace `app.sheets.buttons["Delete correspondent"].firstMatch.tap()` with
`app.buttons["Confirm"].firstMatch.tap()` — or with whichever query Task 1 Step 10 established.

- [ ] **Step 9: Run the XCUITests**

```bash
mise run docker:start
tuist test CorrespondentsApp -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
mise run format
git add -A
git commit -m "$(cat <<'EOF'
refactor: confirm correspondent deletes with the custom popup

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `DocumentTypeRow`

**Files:**
- Create: `Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowReducer+Effect.swift`
- Delete: `Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowReducer+ConfirmationDialogState.swift`
- Modify: `Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowReducer.swift`
- Modify: `Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowView.swift`
- Test: `Modules/DocumentTypesFeatureTests/DocumentTypeRow/DocumentTypeRowReducerTests.swift`
- Test: `Modules/DocumentTypesAppTests/DocumentTypesAppTests.swift`

**Interfaces:**
- Consumes: `DependencyValues.deleteConfirmation.present(_ title: LocalizedStringResource, _ name: String) async -> Bool` from Task 1.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Write the failing test**

Replace the whole of
`Modules/DocumentTypesFeatureTests/DocumentTypeRow/DocumentTypeRowReducerTests.swift` with:

```swift
@testable import DocumentTypesFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct DocumentTypeRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: DocumentTypeRowReducer.State.testValue()) {
            DocumentTypeRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let documentType = DocumentType.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: DocumentTypeRowReducer.State.testValue(
            documentType: documentType
        )) {
            DocumentTypeRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteDocumentType)

        #expect(presented.value?.title == .deleteDocumentType)
        #expect(presented.value?.name == documentType.name)
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: DocumentTypeRowReducer.State.testValue()) {
            DocumentTypeRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editDocumentType)
    }
}
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
tuist test DocumentTypesFeature -d "iPhone 17 Pro"
```

Expected: compile failure — no `runConfirmDelete` on `Effect<DocumentTypeRowReducer.Action>`.

- [ ] **Step 3: Add the effect**

Create `Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowReducer+Effect.swift`:

```swift
import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentTypeRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteDocumentType, name) else {
                return
            }
            await send(.delegate(.deleteDocumentType))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
```

- [ ] **Step 4: Strip the destination out of the reducer**

Replace the whole of
`Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowReducer.swift` with:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct DocumentTypeRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteDocumentType
            case editDocumentType
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: DocumentType.Id { documentType.id }

        let documentType: DocumentType

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editDocumentType))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.documentType.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 5: Delete the dialog state file**

```bash
git rm Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowReducer+ConfirmationDialogState.swift
```

- [ ] **Step 6: Drop the dialog from the view**

In `Modules/DocumentTypesFeature/DocumentTypeRow/DocumentTypeRowView.swift`, delete:

```swift
        .confirmationDialog($store.scope(state: \.destination?.confirmation, action: \.destination.confirmation))
```

and change:

```swift
    @Bindable
    var store: StoreOf<DocumentTypeRowReducer>
```

to:

```swift
    var store: StoreOf<DocumentTypeRowReducer>
```

- [ ] **Step 7: Run the unit tests and watch them pass**

```bash
tuist test DocumentTypesFeature -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 8: Point the XCUITests at the popup**

In `Modules/DocumentTypesAppTests/DocumentTypesAppTests.swift`, in **both** delete tests, replace
`app.sheets.buttons["Delete document type"].firstMatch.tap()` with
`app.buttons["Confirm"].firstMatch.tap()` — or with whichever query Task 1 Step 10 established.

- [ ] **Step 9: Run the XCUITests**

```bash
mise run docker:start
tuist test DocumentTypesApp -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
mise run format
git add -A
git commit -m "$(cat <<'EOF'
refactor: confirm document type deletes with the custom popup

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `StoragePathRow`

**Files:**
- Create: `Modules/StoragePathsFeature/StoragePathRow/StoragePathRowReducer+Effect.swift`
- Delete: `Modules/StoragePathsFeature/StoragePathRow/StoragePathRowReducer+ConfirmationDialogState.swift`
- Modify: `Modules/StoragePathsFeature/StoragePathRow/StoragePathRowReducer.swift`
- Modify: `Modules/StoragePathsFeature/StoragePathRow/StoragePathRowView.swift`
- Test: `Modules/StoragePathsFeatureTests/StoragePathRow/StoragePathRowReducerTests.swift`
- Test: `Modules/StoragePathsAppTests/StoragePathsAppTests.swift`

**Interfaces:**
- Consumes: `DependencyValues.deleteConfirmation.present(_ title: LocalizedStringResource, _ name: String) async -> Bool` from Task 1.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Write the failing test**

Replace the whole of
`Modules/StoragePathsFeatureTests/StoragePathRow/StoragePathRowReducerTests.swift` with:

```swift
@testable import StoragePathsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct StoragePathRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: StoragePathRowReducer.State.testValue()) {
            StoragePathRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let storagePath = StoragePath.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: StoragePathRowReducer.State.testValue(
            storagePath: storagePath
        )) {
            StoragePathRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteStoragePath)

        #expect(presented.value?.title == .deleteStoragePath)
        #expect(presented.value?.name == storagePath.name)
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: StoragePathRowReducer.State.testValue()) {
            StoragePathRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editStoragePath)
    }
}
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
tuist test StoragePathsFeature -d "iPhone 17 Pro"
```

Expected: compile failure — no `runConfirmDelete` on `Effect<StoragePathRowReducer.Action>`.

- [ ] **Step 3: Add the effect**

Create `Modules/StoragePathsFeature/StoragePathRow/StoragePathRowReducer+Effect.swift`:

```swift
import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == StoragePathRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteStoragePath, name) else {
                return
            }
            await send(.delegate(.deleteStoragePath))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
```

- [ ] **Step 4: Strip the destination out of the reducer**

Replace the whole of
`Modules/StoragePathsFeature/StoragePathRow/StoragePathRowReducer.swift` with:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct StoragePathRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteStoragePath
            case editStoragePath
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: StoragePath.Id { storagePath.id }

        let storagePath: StoragePath

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editStoragePath))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.storagePath.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
```

`storagePath` stays first, exactly where it is today, so the memberwise init keeps the
`(storagePath:isUpdating:server:)` order that `StoragePathRowReducer+TestValue.swift` and
`StoragePathListReducer` already call. Only `destination` is removed.

- [ ] **Step 5: Delete the dialog state file**

```bash
git rm Modules/StoragePathsFeature/StoragePathRow/StoragePathRowReducer+ConfirmationDialogState.swift
```

- [ ] **Step 6: Drop the dialog from the view**

In `Modules/StoragePathsFeature/StoragePathRow/StoragePathRowView.swift`, delete:

```swift
        .confirmationDialog($store.scope(state: \.destination?.confirmation, action: \.destination.confirmation))
```

and change:

```swift
    @Bindable
    var store: StoreOf<StoragePathRowReducer>
```

to:

```swift
    var store: StoreOf<StoragePathRowReducer>
```

- [ ] **Step 7: Run the unit tests and watch them pass**

```bash
tuist test StoragePathsFeature -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 8: Point the XCUITests at the popup**

In `Modules/StoragePathsAppTests/StoragePathsAppTests.swift`, in **both** delete tests, replace
`app.sheets.buttons["Delete storage path"].firstMatch.tap()` with
`app.buttons["Confirm"].firstMatch.tap()` — or with whichever query Task 1 Step 10 established.

- [ ] **Step 9: Run the XCUITests**

```bash
mise run docker:start
tuist test StoragePathsApp -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
mise run format
git add -A
git commit -m "$(cat <<'EOF'
refactor: confirm storage path deletes with the custom popup

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `SavedViewRow`

`docs/ideas.md` listed five rows and missed this one. It is structurally identical to the rest.

**Files:**
- Create: `Modules/SavedViewsFeature/SavedViewRow/SavedViewRowReducer+Effect.swift`
- Delete: `Modules/SavedViewsFeature/SavedViewRow/SavedViewRowReducer+ConfirmationDialogState.swift`
- Modify: `Modules/SavedViewsFeature/SavedViewRow/SavedViewRowReducer.swift`
- Modify: `Modules/SavedViewsFeature/SavedViewRow/SavedViewRowView.swift`
- Test: `Modules/SavedViewsFeatureTests/SavedViewRow/SavedViewRowReducerTests.swift`
- Test: `Modules/SavedViewsAppTests/SavedViewsAppTests.swift`

**Interfaces:**
- Consumes: `DependencyValues.deleteConfirmation.present(_ title: LocalizedStringResource, _ name: String) async -> Bool` from Task 1.
- Produces: nothing other tasks depend on.

`Modules/SavedViewsFeatureTests/SavedViewRow/SavedViewRowViewTests.swift` builds its store from
`.testValue(savedView:)` and never touches `destination`, so it needs no change and its four
snapshots must not move.

- [ ] **Step 1: Write the failing test**

Replace the whole of `Modules/SavedViewsFeatureTests/SavedViewRow/SavedViewRowReducerTests.swift`
with:

```swift
@testable import SavedViewsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct SavedViewRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: SavedViewRowReducer.State.testValue()) {
            SavedViewRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let savedView = SavedView.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: SavedViewRowReducer.State.testValue(
            savedView: savedView
        )) {
            SavedViewRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteSavedView)

        #expect(presented.value?.title == .deleteSavedView)
        #expect(presented.value?.name == savedView.name)
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: SavedViewRowReducer.State.testValue()) {
            SavedViewRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate, .editSavedView)
    }
}
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
tuist test SavedViewsFeature -d "iPhone 17 Pro"
```

Expected: compile failure — no `runConfirmDelete` on `Effect<SavedViewRowReducer.Action>`.

- [ ] **Step 3: Add the effect**

Create `Modules/SavedViewsFeature/SavedViewRow/SavedViewRowReducer+Effect.swift`:

```swift
import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == SavedViewRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteSavedView, name) else {
                return
            }
            await send(.delegate(.deleteSavedView))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
```

- [ ] **Step 4: Strip the destination out of the reducer**

Replace the whole of `Modules/SavedViewsFeature/SavedViewRow/SavedViewRowReducer.swift` with:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct SavedViewRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteSavedView
            case editSavedView
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: SavedView.Id { savedView.id }

        let savedView: SavedView

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editSavedView))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.savedView.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
```

`savedView` stays first, exactly where it is today, so the memberwise init keeps the
`(savedView:isUpdating:server:)` order that `SavedViewRowReducer+TestValue.swift` and
`SavedViewListReducer` already call. Only `destination` is removed.

- [ ] **Step 5: Delete the dialog state file**

```bash
git rm Modules/SavedViewsFeature/SavedViewRow/SavedViewRowReducer+ConfirmationDialogState.swift
```

- [ ] **Step 6: Drop the dialog from the view**

In `Modules/SavedViewsFeature/SavedViewRow/SavedViewRowView.swift`, delete:

```swift
        .confirmationDialog($store.scope(state: \.destination?.confirmation, action: \.destination.confirmation))
```

and change:

```swift
    @Bindable
    var store: StoreOf<SavedViewRowReducer>
```

to:

```swift
    var store: StoreOf<SavedViewRowReducer>
```

- [ ] **Step 7: Run the unit tests and watch them pass**

```bash
tuist test SavedViewsFeature -d "iPhone 17 Pro"
```

Expected: PASS, including all four `SavedViewRowViewTests` snapshots unchanged. If a snapshot fails,
stop — the row's rendering should not have moved, and a diff means something beyond the dialog was
removed. Inspect with `mise run snapshots:diff`.

- [ ] **Step 8: Point the XCUITests at the popup**

In `Modules/SavedViewsAppTests/SavedViewsAppTests.swift`, in **both** delete tests, replace
`app.sheets.buttons["Delete saved view"].firstMatch.tap()` with
`app.buttons["Confirm"].firstMatch.tap()` — or with whichever query Task 1 Step 10 established.

- [ ] **Step 9: Run the XCUITests**

```bash
mise run docker:start
tuist test SavedViewsApp -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
mise run format
git add -A
git commit -m "$(cat <<'EOF'
refactor: confirm saved view deletes with the custom popup

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `ServerRow`

The only row with existing behaviour beyond delete/edit: it also selects a server, already has a
`+Effect.swift` file, and sends its delete delegate with `animation: .default`. **That animation
must survive.**

**Files:**
- Modify: `Modules/ServersFeature/ServerRow/ServerRowReducer+Effect.swift`
- Delete: `Modules/ServersFeature/ServerRow/ServerRowReducer+ConfirmationDialogState.swift`
- Modify: `Modules/ServersFeature/ServerRow/ServerRowReducer.swift`
- Modify: `Modules/ServersFeature/ServerRow/ServerRowView.swift`
- Test: `Modules/ServersFeatureTests/ServerRow/ServerRowReducerTests.swift`
- Test: `Modules/ServersAppTests/ServersAppTests.swift`

**Interfaces:**
- Consumes: `DependencyValues.deleteConfirmation.present(_ title: LocalizedStringResource, _ name: String) async -> Bool` from Task 1.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Write the failing test**

In `Modules/ServersFeatureTests/ServerRow/ServerRowReducerTests.swift`, **delete**
`test_destination_confirmation_deleteButtonTapped` and `test_view_deleteButtonTapped` entirely, and
insert these two in their place (keep `test_view_editButtonTapped` and all three `serverTapped`
tests exactly as they are):

```swift
    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: ServerRowReducer.State(
            server: .testValue()
        )) {
            ServerRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let server = Server.testValue()
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: ServerRowReducer.State(
            server: server
        )) {
            ServerRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deleteServer)

        #expect(presented.value?.title == .deleteServer)
        #expect(presented.value?.name == server.alias)
    }
```

While in this file, fix the `AGENTS.md` violation above
`test_view_serverTapped_selectsEvenWhenSyncFails` — change:

```swift
    /// Being offline must not leave the user stranded on the server list.
```

to:

```swift
    // Being offline must not leave the user stranded on the server list.
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
tuist test ServersFeature -d "iPhone 17 Pro"
```

Expected: compile failure — no `runConfirmDelete` on `Effect<ServerRowReducer.Action>`.

- [ ] **Step 3: Add the effect to the existing file**

In `Modules/ServersFeature/ServerRow/ServerRowReducer+Effect.swift`, add `import Components` to the
import block (alphabetically: `ApiInterface`, `Components`, `ComposableArchitecture`,
`SwiftSharing`), add this method **above** `runSelectServer` so the methods stay alphabetical, and
add the new case to the existing `CancelID` enum:

```swift
    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteServer, name) else {
                return
            }
            await send(.delegate(.deleteServer), animation: .default)
        }
        .cancellable(id: CancelID.confirmDelete)
    }
```

```swift
private enum CancelID {
    case confirmDelete
    case selectServer
}
```

- [ ] **Step 4: Strip the destination out of the reducer**

Replace the whole of `Modules/ServersFeature/ServerRow/ServerRowReducer.swift` with:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct ServerRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case serverSelected
        case view(View)

        public enum Delegate {
            case deleteServer
            case editServer
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
            case serverTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: String { server.id }

        var isSelecting = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editServer))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.server.alias)
                case .serverTapped:
                    guard !state.isSelecting else {
                        return .none
                    }
                    state.isSelecting = true
                    return .runSelectServer(server: state.server)
                }
            case .serverSelected:
                state.isSelecting = false
                return .none
            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 5: Delete the dialog state file**

```bash
git rm Modules/ServersFeature/ServerRow/ServerRowReducer+ConfirmationDialogState.swift
```

- [ ] **Step 6: Drop the dialog from the view**

In `Modules/ServersFeature/ServerRow/ServerRowView.swift`, delete this line from inside the
`Button`'s label closure:

```swift
            .confirmationDialog($store.scope(state: \.destination?.confirmation, action: \.destination.confirmation))
```

and change:

```swift
    @Bindable
    var store: StoreOf<ServerRowReducer>
```

to:

```swift
    var store: StoreOf<ServerRowReducer>
```

- [ ] **Step 7: Run the unit tests and watch them pass**

```bash
tuist test ServersFeature -d "iPhone 17 Pro"
```

Expected: PASS, all six `ServerRowReducerTests` including the three `serverTapped` tests.

- [ ] **Step 8: Point the XCUITest at the popup**

In `Modules/ServersAppTests/ServersAppTests.swift` (one occurrence, around line 43), replace
`app.sheets.buttons["Delete server"].firstMatch.tap()` with
`app.buttons["Confirm"].firstMatch.tap()` — or with whichever query Task 1 Step 10 established.

- [ ] **Step 9: Run the XCUITests**

```bash
mise run docker:start
tuist test ServersApp -d "iPhone 17 Pro"
```

Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
mise run format
git add -A
git commit -m "$(cat <<'EOF'
refactor: confirm server deletes with the custom popup

Keeps the delete delegate's .default animation, which the removed
destination case carried.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Close the loop in the docs and sweep

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/ideas.md`

**Interfaces:**
- Consumes: Tasks 1–6 complete.
- Produces: nothing.

- [ ] **Step 1: Prove nothing is left**

```bash
grep -rn "ConfirmationDialogState\|\.confirmationDialog\|\.alert(" --include=*.swift Modules Shared
```

Expected: **no output.** Any hit is a task that was not finished — go back and finish it. (`.alert(`
is in the sweep because `AGENTS.md` bans it alongside the dialog; if a legitimate pre-existing
`.alert` turns up that is outside this migration's scope, note it in `docs/ideas.md` rather than
silently changing it.)

- [ ] **Step 2: Update `AGENTS.md`**

In the section "Confirmations use `ConfirmationPopupView`, never the system dialog", delete the
closing paragraph, which is now false:

```markdown
Some list rows — `CorrespondentRow`, `DocumentTypeRow`, `StoragePathRow`, `TagRow`, `ServerRow` —
still carry the old `ConfirmationDialogState` destination. They are the thing being migrated away
from, not a pattern to copy.
```

Replace it with:

```markdown
There is one shared presenter for the common case — deleting a named record.
`Components/Popup/DeleteConfirmationPresenter.swift` takes the entity title and the record's name
and renders `Delete tag` over `Do you really want to delete "Inbox"?`. Reach for it before writing
a new presenter; write your own only when the popup needs custom content, as
`DocumentBulkEditConfirmationPresenter` does.
```

Also update the two example presenter names in that section — `DocumentDeleteConfirmationPresenter`
and `DocumentNoteDeleteConfirmationPresenter` are still the right things to copy for a *bespoke*
presenter, so leave that sentence alone.

- [ ] **Step 3: Update `docs/ideas.md`**

Delete the entire section beginning
`## Migrate the remaining system confirmation dialogs to `ConfirmationPopupView`` down to and
including its `Surfaced during:` line and the `---` separator above it. The idea has been picked up;
`docs/plans/2026-08-22-confirmation-popup-migration.md` now holds it.

- [ ] **Step 4: Run the full unit test suite**

```bash
mise run ci:test
```

Expected: PASS. This skips the XCUITest targets (`--skip-ui-tests`), which Tasks 1–6 already ran
individually.

- [ ] **Step 5: Lint**

```bash
mise run ci:lint
```

Expected: PASS, including `tuist inspect dependencies --only implicit` — the five features now
import `Components` in their new `+Effect.swift` files, and every one of them already declares
`Components` as a dependency, so this should be clean. If it is not, add the missing declaration in
`Tuist/ProjectDescriptionHelpers/Module+Targets.swift`.

- [ ] **Step 6: Commit**

```bash
mise run format
git add -A
git commit -m "$(cat <<'EOF'
docs: record the confirmation popup as the only confirmation

Every system dialog is gone from Modules/, so AGENTS.md no longer needs
its list of rows still to migrate, and the idea leaves ideas.md.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Notes for the implementer

**Why the `.cancellable(id:)` is safe six times over.** Each feature declares its own `private enum
CancelID` in its own file, so the ids do not collide across modules. Within a list, TCA's
`.forEach(\.rows, action: \.rows)` scopes each element's effects under that element's id, so two
rows confirming at once cancel independently. This mirrors `DocumentRowReducer+Effect.swift`, which
has run this way in a list since #148.

**Why there is no test for `DeleteConfirmationPresenter` itself.** Its `liveValue` only resolves
when a human taps a button in a live `ConfirmationPopupView`, which a unit test cannot do — the
same reason `DocumentDeleteConfirmationPresenter` and `DocumentNoteDeleteConfirmationPresenter`
have none. The view is covered by `ComponentsTests/Popup/ConfirmationPopupViewTests`, the
resolve/dismiss plumbing by `ComponentsTests/Popup/PopupPresenterTests`, and the wiring by each
row's reducer tests. The XCUITests in Tasks 1–6 are what exercise the three together.

**If a list reducer stops compiling** after a row's `State` loses `destination`, the fix is always
to drop the argument at the call site. No parent reducer reads or writes a row's destination today
— they only match `case …(.element(id:, action: .delegate(…)))`.
