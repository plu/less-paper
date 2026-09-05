# Permission gating implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide the controls a paperless user has no permission to use, across the six
entity-management features and their Settings rows.

**Architecture:** A `ServerPermissions` value — two `@Shared` caches plus the `can(_:)` rule — is
stored in each list, row and settings State. Views read `store.permissions.can(.addTag)`. Because the
caches are `@Shared`, a foreground refresh re-renders rather than going stale. `can(_:)` moves onto
that type and `PermissionsQuery` delegates to it, so the rule has one implementation.

**Tech Stack:** Swift 6, Swift Testing, `swift-composable-architecture` (`@ObservableState`,
`TestStore`), `swift-sharing` (`@Shared`, `FileStorageKey`), `swift-snapshot-testing`, Tuist, mise.

**Spec:** `docs/superpowers/specs/2026-09-05-permission-gating-design.md`

## Global Constraints

- **Gating is presentation, not enforcement.** The server is the security boundary. Every ambiguous
  case resolves toward showing more, never less.
- **Fail open.** `can` returns `true` when the permission cache is `nil`. No gate may invert this.
- **`nil` and `[]` are different.** `nil` = never read → allow everything. `[]` = read and empty →
  allow nothing. The `guard let permissions else { return true }` branch is what separates them.
- **Hiding, not disabling.** A control the user cannot use is not rendered. No "you do not have
  permission" copy anywhere — the app is not enforcing the boundary and must not narrate one.
- **Comments:** Never `///`, never `/** */`. Only `//`, and only where a future reader would
  otherwise wonder why the code is as it is. See `AGENTS.md`. Do not edit prose inside an existing
  `///` block; convert the whole block to `//` if one must be corrected.
- **`@ViewAction` views send with `send`, never `store.send`.** All six list and row views are
  annotated; keep using `send`.
- **The permission cases are exact.** Copy them from the table in Task 3. `changeCustomfield` has a
  lowercase `f`, matching the paperless codename `change_customfield` — it is not a typo and
  "correcting" it is a compile error.
- **Run tests with:** `mise exec -- tuist test <Scheme> -d "iPhone 17 Pro" --no-selective-testing`.
  The flag is required: a plain `tuist test` can exit 0 having run **zero** tests, which is
  indistinguishable from success.
- **Also run `mise run ci:lint`** — formatting, `swiftlint --strict`, implicit-dependency check.
- **Re-recording a snapshot means editing the scheme.** `SNAPSHOT_RECORD=all tuist test` does **not**
  reach the test process; the run then passes having recorded nothing. Flip `isEnabled` to `true` in
  `Tuist/ProjectDescriptionHelpers/Extensions/Dictionary+Extensions.swift`, `tuist generate`, record,
  flip back, regenerate. See `AGENTS.md:461`.
- **New `.swift` files need no Tuist edit** — targets glob their module directory. This plan adds no
  new modules and needs no `Module+Dependencies.swift` change.

## A deliberate deviation from the spec's testing section

The spec says "each feature's list and row get snapshot tests for the gated states", which is
6 features × (2 list states + 4 row states) — roughly 24 new snapshot references, all of them LFS
blobs, for six implementations that are copies of each other.

This plan instead gives **Tags the full snapshot matrix** and the other five **one list snapshot plus
reducer-level assertions**. The reasoning: a snapshot proves the mechanism renders a hidden control
correctly, and that is worth proving once. What differs between the six is *which permission each
one names*, and a snapshot cannot tell `changeTag` from `changeCorrespondent` — only a reducer test
asserting the specific case can. So the coverage that actually catches the spec's own named risk goes
up, and the image count roughly halves.

---

### Task 1: `ServerPermissions`, and one implementation of the rule

**Files:**
- Create: `Modules/ApiInterface/Permissions/ServerPermissions.swift`
- Modify: `Modules/ApiInterface/Permissions/PermissionsQuery.swift`
- Test: Create `Modules/ApiInterfaceTests/Permissions/ServerPermissionsTests.swift`

**Interfaces:**
- Consumes: `SharedReaderKey.permissions(_:)`, `SharedReaderKey.currentUser(_:)`, `Permission`,
  `Server`, `User` — all existing.
- Produces: `ServerPermissions(server:)` with `can(_ permission: Permission) -> Bool`, `Equatable`,
  `Sendable`.

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiInterfaceTests/Permissions/ServerPermissionsTests.swift`:

```swift
@testable import ApiInterface

import Dependencies
import Foundation
import SwiftSharing
import Testing

@Suite
struct ServerPermissionsTests {

    @Test
    func superuserCanDoAnythingWithoutHoldingThePermission() {
        let permissions = write(user: .testValue(isSuperuser: true), permissions: [])

        #expect(permissions.can(.deleteTag))
    }

    @Test
    func nonSuperuserHoldingThePermissionCan() {
        let permissions = write(user: .testValue(isSuperuser: false), permissions: [.changeTag])

        #expect(permissions.can(.changeTag))
    }

    @Test
    func nonSuperuserLackingThePermissionCannot() {
        let permissions = write(user: .testValue(isSuperuser: false), permissions: [.viewTag])

        #expect(!permissions.can(.changeTag))
    }

    // Nothing read yet, so nothing known. Gating is presentation, not enforcement: show the control
    // and let the server refuse it. Deleting this branch hides the whole app from anyone whose
    // paperless does not send the key.
    @Test
    func nilCacheAllowsEverything() {
        let permissions = write(user: .testValue(isSuperuser: false), permissions: nil)

        #expect(permissions.can(.deleteTag))
    }

    // One character apart from the case above and the opposite answer: the server was read and it
    // granted nothing.
    @Test
    func emptyCacheAllowsNothing() {
        let permissions = write(user: .testValue(isSuperuser: false), permissions: [])

        #expect(!permissions.can(.deleteTag))
    }

    private func write(user: User, permissions: [Permission]?) -> ServerPermissions {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var cachedUser: User?

        @Shared(.permissions(server))
        var cachedPermissions: [Permission]?

        $cachedUser.withLock { $0 = user }
        $cachedPermissions.withLock { $0 = permissions }

        return ServerPermissions(server: server)
    }
}
```

`@Shared` file storage is in-memory under a test context and keyed per Swift Testing `Test.ID`, so
each test gets its own store even though every one uses the same fixed `Server.testValue()` id.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL to compile — `ServerPermissions` does not exist.

- [ ] **Step 3: Write `ServerPermissions`**

Create `Modules/ApiInterface/Permissions/ServerPermissions.swift`:

```swift
import Foundation
import SwiftSharing

// What a screen asks about permissions. The two caches are held rather than read through a
// dependency so that a foreground refresh re-renders the screen: @Shared notifies observation, and a
// boolean computed once on appear would not.
public struct ServerPermissions: Equatable, Sendable {

    @Shared public var permissions: [Permission]?

    @Shared public var currentUser: User?

    public init(server: Server) {
        _permissions = Shared(wrappedValue: nil, .permissions(server))
        _currentUser = Shared(wrappedValue: nil, .currentUser(server))
    }

    public func can(_ permission: Permission) -> Bool {
        // Nothing read yet, so nothing to gate on. This branch is why the cache is optional rather
        // than an empty array: contains() on an empty array denies everything, which is the opposite
        // answer to the same question.
        guard let permissions else {
            return true
        }

        // Superuser first, matching the web UI. Django hands a superuser every permission anyway, so
        // this is belt and braces - and it stays true if that ever stops.
        return currentUser?.isSuperuser == true || permissions.contains(permission)
    }
}
```

- [ ] **Step 4: Delegate `PermissionsQuery` to it**

In `Modules/ApiInterface/Permissions/PermissionsQuery.swift`, replace the body of `liveValue.can`
with a call to `ServerPermissions`, keeping the existing memoisation cache exactly as it is — that
cache exists so the client is cheap to call repeatedly, and constructing a `ServerPermissions` per
call would reintroduce the disk I/O it removed.

Read the file first: the memoised pair is currently `(Shared<[Permission]?>, Shared<User?>)`. Change
the memoised value to a `ServerPermissions` and have `can` look it up and call
`serverPermissions.can(permission)`. Update the comment above `can` so it says the rule lives on
`ServerPermissions` and this is the dependency-shaped door to it.

**The five existing tests in `Modules/ApiInterfaceTests/Permissions/PermissionsQueryTests.swift` must
pass unedited.** They are the evidence that moving the rule did not change it. If one needs editing
to accommodate your design, stop and report rather than editing it.

- [ ] **Step 5: Run the tests to verify they pass**

```
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: PASS — both the five new `ServerPermissionsTests` and the five untouched
`PermissionsQueryTests`. `ci:lint` exit 0.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface Modules/ApiInterfaceTests
git commit -m "feat: add ServerPermissions and give the rule one implementation"
```

---

### Task 2: Tags — the pilot, with the full snapshot matrix

Tags is done first and in full so the pattern is proven once. The other five follow it mechanically.

**Files:**
- Modify: `Modules/TagsFeature/TagList/TagListReducer.swift` (State)
- Modify: `Modules/TagsFeature/TagList/TagListView.swift` (toolbar, empty state)
- Modify: `Modules/TagsFeature/TagRow/TagRowReducer.swift` (State)
- Modify: `Modules/TagsFeature/TagRow/TagRowView.swift` (swipe actions)
- Test: Modify `Modules/TagsFeatureTests/TagList/TagListViewTests.swift`
- Test: Modify `Modules/TagsFeatureTests/TagRow/TagRowReducerTests.swift`

**Interfaces:**
- Consumes: `ServerPermissions(server:)` and `can(_:)` from Task 1.
- Produces: the pattern the other five features copy — `var permissions: ServerPermissions` in both
  States, set from `server` in each `init`.

- [ ] **Step 1: Add `permissions` to both States**

`TagListReducer.State` already has an explicit `public init`. Add the stored property beside `server`
and set it in that init:

```swift
        var permissions: ServerPermissions
```

```swift
        public init(
            destination: Destination.State? = nil,
            isLoaded: Bool = false,
            server: Server,
            tags: IdentifiedArrayOf<TagRowReducer.State> = []
        ) {
            self.destination = destination
            self.isLoaded = isLoaded
            self.server = server
            self.tags = tags
            permissions = ServerPermissions(server: server)
        }
```

Keep the rest of that init exactly as it is — read it before editing rather than retyping it.

`TagRowReducer.State` has **no** explicit init; it relies on the synthesised memberwise one, and its
call sites pass `server:` and `tag:`. A stored `permissions` would become a required memberwise
parameter and break all of them, so give it an explicit init that derives the value instead:

```swift
    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Tag.Id { tag.id }

        var isUpdating = false

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        let server: Server

        let tag: Tag

        init(
            isUpdating: Bool = false,
            server: Server,
            tag: Tag
        ) {
            self.isUpdating = isUpdating
            self.server = server
            self.tag = tag
            permissions = ServerPermissions(server: server)
        }
    }
```

The init is **internal, not public** — the synthesised memberwise init it replaces was internal, and
making it public would widen the type's API as a side effect of this change.

Add `import ApiInterface` to either file if it is not already there.

- [ ] **Step 2: Gate the list's two create affordances**

In `Modules/TagsFeature/TagList/TagListView.swift`, wrap the toolbar button:

```swift
        .toolbar {
            if store.permissions.can(.addTag) {
                Button(action: {
                    send(.createTagButtonTapped)
                }) {
                    Label(.createTag, systemImage: "plus")
                }
            }
        }
```

and the empty state's button, leaving the message in place:

```swift
    @ViewBuilder
    private func emptyListView() -> some View {
        if store.tags.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "tag",
                    title: .noTagsFound
                ) {
                    // No call to action for someone who cannot create tags: there is nothing there,
                    // and they cannot change that. Saying why would explain a boundary this app is
                    // not the one enforcing.
                    if store.permissions.can(.addTag) {
                        Button {
                            send(.createTagButtonTapped)
                        } label: {
                            Label(.createTag, systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary())
                    }
                }
            }
        }
    }
```

- [ ] **Step 3: Gate the row's two swipe actions**

In `Modules/TagsFeature/TagRow/TagRowView.swift`:

```swift
    @ViewBuilder
    private func swipeActions() -> some View {
        if store.permissions.can(.changeTag) {
            Button {
                send(.editButtonTapped)
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel(.editTag)
            .tint(.m3Primary)
        }

        if store.permissions.can(.deleteTag) {
            Button {
                send(.deleteButtonTapped)
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel(.deleteTag)
            .tint(.m3Error)
        }
    }
```

- [ ] **Step 4: Write the reducer test that pins the specific permissions**

This is the test that catches a wrong-but-compiling permission case, which a snapshot cannot. Add to
`Modules/TagsFeatureTests/TagRow/TagRowReducerTests.swift`:

```swift
    // A snapshot proves a control is absent; it cannot prove the absence was caused by the right
    // permission. Gating tags on changeCorrespondent would compile, render identically in a
    // "cannot edit" snapshot, and be wrong.
    @Test
    func rowGatesOnTagPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.changeTag] }

        let state = TagRowReducer.State(server: server, tag: .testValue())

        #expect(state.permissions.can(.changeTag))
        #expect(!state.permissions.can(.deleteTag))
        #expect(!state.permissions.can(.changeCorrespondent))
    }
```

Add `import SwiftSharing` and `import ApiInterface` to the test file if absent.

- [ ] **Step 5: Add the snapshot cases**

`Modules/TagsFeatureTests/TagList/TagListViewTests.swift` already has snapshot tests. Read it first
to copy its exact fixture and layout conventions, then add cases covering:

- a populated list where the cache grants `[.viewTag]` only — no toolbar "+", rows with no swipe
  actions
- a populated list where the cache grants `[.viewTag, .changeTag]` — no "+", rows with edit only
- a populated list where the cache grants `[.viewTag, .deleteTag]` — no "+", rows with delete only
- an **empty** list where the cache grants `[.viewTag]` only — the "No tags found" message with no
  create button
- a list with a `nil` cache — every control present, identical to the ungated rendering

Each test seeds `@Shared(.permissions(server))` and `@Shared(.currentUser(server))` before building
the state, exactly as Step 4 does.

**Seed the cache explicitly in every gated case.** A fixture that leaves it `nil` fails open and
renders every control, which would make a "gated" snapshot identical to an ungated one and prove
nothing.

Swipe actions are not visible in a static snapshot — they are revealed by a gesture. So the row-level
snapshot cases above pin the *list* rendering, and the row's gating is pinned by the Step 4 reducer
test. If you find that swipe actions genuinely cannot be captured, say so in your report and rely on
the reducer test rather than inventing a way to force them open.

- [ ] **Step 6: Run the tests; expect the new snapshots to be recorded**

Run: `mise exec -- tuist test TagsFeature -d "iPhone 17 Pro" --no-selective-testing`

A snapshot test with **no** existing reference writes one on its first run and fails; the second run
passes against it. That is the normal path for new cases and needs no scheme edit. **Look at what was
recorded before trusting it** — a reference captures whatever the code produced, bug included.

Existing Tags snapshots must be unaffected: their fixtures have no permission cache, so they fail
open and render exactly as before. If an existing snapshot changes, stop and report — it means the
gating altered a case it should not have.

- [ ] **Step 7: Verify the recorded images**

Run: `mise run snapshots:diff`

Confirm by looking: the view-only list has no "+" in the toolbar; the empty view-only list shows the
message with no button; the `nil`-cache list looks exactly like the pre-existing loaded snapshot.

- [ ] **Step 8: Run the suite and the lint gate**

```
mise exec -- tuist test TagsFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: PASS, exit 0.

- [ ] **Step 9: Commit**

```bash
git add Modules/TagsFeature Modules/TagsFeatureTests Snapshots/TagsFeatureTests
git commit -m "feat: gate tag create, edit and delete on permissions"
```

---

### Task 3: The other five features

Mechanically identical to Task 2, without the snapshot matrix. Each feature gets: `permissions` in
both States, the two create affordances gated, the two swipe actions gated, one reducer test pinning
its specific permissions, and one list snapshot for the view-only case.

**Files:** for each of `CorrespondentsFeature`, `DocumentTypesFeature`, `StoragePathsFeature`,
`CustomFieldsFeature`, `SavedViewsFeature`:
- Modify: `Modules/<F>Feature/<E>List/<E>ListReducer.swift` (State + init)
- Modify: `Modules/<F>Feature/<E>List/<E>ListView.swift` (toolbar + empty state)
- Modify: `Modules/<F>Feature/<E>Row/<E>RowReducer.swift` (State + init)
- Modify: `Modules/<F>Feature/<E>Row/<E>RowView.swift` (swipe actions)
- Test: Modify `Modules/<F>FeatureTests/<E>Row/<E>RowReducerTests.swift`
- Test: Modify `Modules/<F>FeatureTests/<E>List/<E>ListViewTests.swift`

**Interfaces:**
- Consumes: `ServerPermissions` from Task 1, and the exact pattern established in Task 2.
- Produces: nothing later tasks rely on.

- [ ] **Step 1: Read Task 2's result as the template**

Before writing anything, read the committed Tags implementation:
`Modules/TagsFeature/TagList/TagListReducer.swift`, `TagListView.swift`,
`Modules/TagsFeature/TagRow/TagRowReducer.swift` and `TagRowView.swift`. Every feature below is the
same edit with different names. Follow it rather than improvising a second pattern.

Note in particular that the **row** State needs an explicit internal init (the synthesised memberwise
one cannot derive `permissions` from `server`), while the **list** State already has an explicit
`public init` to extend. Check each feature — if a row State already has an explicit init, extend it
instead of adding one.

- [ ] **Step 2: Apply the permission mapping**

Use exactly these cases. They are verified to exist in `Modules/ApiInterface/Shared/Permission.swift`:

| Feature | add | change | delete |
|---|---|---|---|
| Correspondents | `.addCorrespondent` | `.changeCorrespondent` | `.deleteCorrespondent` |
| Document types | `.addDocumentType` | `.changeDocumentType` | `.deleteDocumentType` |
| Storage paths | `.addStoragePath` | `.changeStoragePath` | `.deleteStoragePath` |
| Custom fields | `.addCustomField` | `.changeCustomfield` | `.deleteCustomField` |
| Saved views | `.addSavedView` | `.changeSavedView` | `.deleteSavedView` |

**`changeCustomfield` has a lowercase `f`.** It matches the paperless codename
`change_customfield`. Changing it to `changeCustomField` will not compile.

- [ ] **Step 3: Write each feature's reducer test**

One per feature, in `Modules/<F>FeatureTests/<E>Row/<E>RowReducerTests.swift`. Correspondents shown;
the other four are the same with their own names and permissions from the table:

```swift
    // A snapshot proves a control is absent; it cannot prove the absence was caused by the right
    // permission. Gating correspondents on changeTag would compile and look identical.
    @Test
    func rowGatesOnCorrespondentPermissionsSpecifically() {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var user: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        $user.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.changeCorrespondent] }

        let state = CorrespondentRowReducer.State(server: server, correspondent: .testValue())

        #expect(state.permissions.can(.changeCorrespondent))
        #expect(!state.permissions.can(.deleteCorrespondent))
        #expect(!state.permissions.can(.changeTag))
    }
```

The third expectation is the point: it asserts the gate names *this* feature's permission and not a
neighbour's. Read each row State's initialiser before writing the call — the second parameter differs
per feature (`correspondent:`, `documentType:`, `storagePath:`, `customField:`, `savedView:`).

- [ ] **Step 4: Add one list snapshot per feature**

In each `<E>ListViewTests.swift`, add a single case: a populated list whose cache grants only
`view_<entity>`, so the toolbar "+" is absent. Seed both shared caches explicitly, following Task 2's
fixture shape.

- [ ] **Step 5: Run each scheme**

```
mise exec -- tuist test CorrespondentsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test DocumentTypesFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test StoragePathsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test CustomFieldsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test SavedViewsFeature -d "iPhone 17 Pro" --no-selective-testing
```

New snapshot cases record on the first run and fail, then pass on the second. **Existing snapshots in
these features must not change** — their fixtures have no permission cache and so fail open. If one
does change, stop and report.

- [ ] **Step 6: Verify the recorded images and lint**

```
mise run snapshots:diff
mise run ci:lint
```
Confirm each new reference shows a list with no "+" in its toolbar. `ci:lint` exit 0.

- [ ] **Step 7: Commit**

```bash
git add Modules/CorrespondentsFeature Modules/DocumentTypesFeature Modules/StoragePathsFeature \
        Modules/CustomFieldsFeature Modules/SavedViewsFeature \
        Modules/CorrespondentsFeatureTests Modules/DocumentTypesFeatureTests \
        Modules/StoragePathsFeatureTests Modules/CustomFieldsFeatureTests \
        Modules/SavedViewsFeatureTests Snapshots
git commit -m "feat: gate create, edit and delete across the remaining entity features"
```

---

### Task 4: The Settings rows

**Files:**
- Modify: `Modules/SettingsFeature/SettingList/SettingListReducer.swift` (State)
- Modify: `Modules/SettingsFeature/SettingList/SettingListView.swift` (six NavigationLinks)
- Test: Modify `Modules/SettingsFeatureTests/SettingList/SettingListViewTests.swift`

**Interfaces:**
- Consumes: `ServerPermissions` from Task 1.
- Produces: nothing.

- [ ] **Step 1: Add `permissions` to the State**

`SettingListReducer.State` holds a `server`. Add `var permissions: ServerPermissions` and set it from
`server` in the existing initialiser, following the shape Task 2 used for `TagListReducer.State`.
Read the file first — its init has several parameters and they must survive unchanged.

- [ ] **Step 2: Gate the six entity links**

In `SettingListView.swift`, wrap each of the six entity `NavigationLink`s — correspondents, custom
fields, document types, saved views, storage paths, tags — in its `view_` check. The correspondents
one, as the pattern:

```swift
                    if store.permissions.can(.viewCorrespondent) {
                        NavigationLink(
                            state: SettingListReducer.Path.State.correspondentList(CorrespondentListReducer.State(server: store.server))
                        ) {
                            Label(.correspondents, systemImage: "person")
                        }
                        .listRowBackground(Color.m3SurfaceContainer)
                    }
```

with `.viewCustomField`, `.viewDocumentType`, `.viewSavedView`, `.viewStoragePath` and `.viewTag` for
the rest.

**Do not gate `pdfPasswordList` or `trashList`**, which sit in the same `Section`. PDF passwords are
stored on device and have no server permission at all. Trash is `delete_document` and belongs with
the documents work in the follow-up project.

A `Section` whose every row is hidden renders as nothing, so a user with no entity permissions sees
the section vanish rather than an empty box.

- [ ] **Step 3: Add the snapshot cases**

In `SettingListViewTests.swift`, read the existing fixtures first, then add:

- a settings list whose cache grants `[.viewTag]` only — one entity row plus the ungated PDF
  passwords and trash rows
- a settings list whose cache grants `[]` — no entity rows at all, PDF passwords and trash still
  present

Seed both shared caches explicitly.

- [ ] **Step 4: Run the tests**

Run: `mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro" --no-selective-testing`

New cases record on the first run and fail, then pass on the second. Existing settings snapshots must
be unchanged — their fixtures have no permission cache and fail open.

- [ ] **Step 5: Verify the images and lint**

```
mise run snapshots:diff
mise run ci:lint
```

Confirm by looking that the `[.viewTag]` case shows Tags but not Correspondents, and that PDF
passwords and Trash are present in **both** new references. That second check is the one that catches
gating a row that has no business being gated.

- [ ] **Step 6: Run every affected scheme**

```
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test TagsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test CorrespondentsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test DocumentTypesFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test StoragePathsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test CustomFieldsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test SavedViewsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: all PASS, `ci:lint` exit 0.

- [ ] **Step 7: Commit**

```bash
git add Modules/SettingsFeature Modules/SettingsFeatureTests Snapshots/SettingsFeatureTests
git commit -m "feat: hide settings rows for entities the user cannot view"
```
