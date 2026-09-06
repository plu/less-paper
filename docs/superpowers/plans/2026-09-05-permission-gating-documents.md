# Document and Trash Permission Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide the document, note and trash controls a user has no permission to use, and gate the three inline "create entity" buttons Project 2 gated in one place and left in two others.

**Architecture:** Each list, row, detail and form State gains a `ServerPermissions` value built from the `server` it already holds, plus named `Bool` computed properties the views read. No new types, no changes to `ServerPermissions` or `Permission`. This is Project 2's shipped pattern applied to a wider surface.

**Tech Stack:** Swift 6, swift-composable-architecture, swift-dependencies, swift-sharing, Swift Testing, Tuist, mise.

**Spec:** `docs/superpowers/specs/2026-09-05-permission-gating-documents-design.md`

## Global Constraints

- Gating is **presentation, not enforcement**. The server remains the security boundary.
- The rule **fails open**: `ServerPermissions.can` returns `true` when the permission cache is `nil`. No gate may invert this.
- Controls are **hidden, never disabled** and never replaced with an explanatory message.
- `permissions` is **stored, not computed**: constructing a `ServerPermissions` reads two files and arms two file watchers, so a computed property would do that on every render.
- Every gate is a **named computed property on State**; views read `store.<name>`, never `store.permissions.can(...)`. After this plan, `grep -rn "\.can(" Modules --include=*View.swift` must still return 0.
- Permission codenames have **no internal underscore** for multi-word types: `add_documenttype`, `add_storagepath`, `add_customfield`. The Swift cases are `.addDocumentType`, `.addStoragePath`, `.addCustomField`, and `.changeCustomfield` keeps its lowercase `f`.
- Run `mise run ci:lint` before every commit; it must exit 0.
- Tests need the dev instance: `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000` **and** `--no-selective-testing`, or a cached binary keeps a stale URL and network tests fail on a connection refused.

### Deviation from the spec, decided here

The spec's architecture block lists `canRestore`, `canDeleteForever` and `canEmptyTrash`. All three
resolve to the identical `permissions.can(.deleteDocument)`, and three properties with one body is
the verbatim duplication the review rubric treats as a defect. Task 2 uses a single
`canModifyTrash`. If paperless ever splits restore from purge, splitting the property is a
one-line change at that point.

---

### Task 1: The permission scenario users for documents and notes

**Files:**
- Modify: `docker/seed/seed.json` (`permission_users`)

**Interfaces:**
- Consumes: nothing.
- Produces: seed users used for manual verification only. No Swift code depends on this task.

Today every scenario user holds `view_document` from `permission_baseline` and no `document` or
`note` permission beyond it, so not one of them exercises a gate in this plan.

- [ ] **Step 1: Read the existing fixture**

Read `docker/seed/seed.json` and find `permission_baseline`, `permission_entities` and
`permission_users`. Note that `permissions_for` in `docker/seed/permissions.py` expands
`actions × entities` and unions `permission_baseline`, and that a user may override `entities`.

- [ ] **Step 2: Add the new scenario users**

Append these to `permission_users`, keeping the existing eight untouched. They use the `entities`
override to name `document` and `note` directly rather than widening `permission_entities`, which
would change what every existing user gets.

```json
    {
      "username": "perm-doc-reader",
      "actions": ["view"],
      "entities": ["document"],
      "expect": "Documents visible. No import, no scan, no Select, no edit or delete swipe, no notes section."
    },
    {
      "username": "perm-doc-editor",
      "actions": ["view", "change"],
      "entities": ["document"],
      "expect": "Edit swipe and the bulk edit actions. No delete swipe, no bulk delete, no import, no scan. Select IS offered - it is gated on change OR delete."
    },
    {
      "username": "perm-doc-deleter",
      "actions": ["view", "delete"],
      "entities": ["document"],
      "expect": "Delete swipe, bulk delete, Trash row in Settings and its actions. No edit swipe, no bulk edit actions. Select IS offered. The mirror of perm-doc-editor: run the pair to prove edit and delete are not wired to each other's permission."
    },
    {
      "username": "perm-doc-creator",
      "actions": ["view", "add"],
      "entities": ["document"],
      "expect": "Import, Scan and bulk Merge. No edit swipe, no delete swipe. Select is NOT offered - add_document is not one of its two permissions."
    },
    {
      "username": "perm-notes",
      "actions": ["view", "add", "delete"],
      "entities": ["document", "note"],
      "expect": "Notes section visible with add and delete. Compare against perm-doc-reader, whose notes section is absent entirely."
    }
```

- [ ] **Step 3: Seed and verify**

```bash
mise run docker:seed -- --url http://192.168.64.1:8000
mise run docker:seed -- --url http://192.168.64.1:8000 --verify
```
Expected: the five new users are created, then `Fixture OK`. A second plain run must create nothing.

- [ ] **Step 4: Confirm the permissions actually arrive**

```bash
for u in perm-doc-reader perm-doc-editor perm-doc-deleter perm-doc-creator perm-notes; do
  printf "%-18s " "$u"
  curl -s -u "$u:T0PS3CR3T!!123" http://192.168.64.1:8000/api/ui_settings/ \
    | python3 -c "import sys,json;p=sorted(x for x in json.load(sys.stdin)['permissions'] if 'document' in x or 'note' in x);print(p)"
done
```
Expected: `perm-doc-reader` shows `['view_document']` only; `perm-doc-editor` adds `change_document`; `perm-doc-deleter` adds `delete_document`; `perm-doc-creator` adds `add_document`; `perm-notes` shows the three note codenames alongside the document ones. This is the check that the codenames are real — Django silently ignores one it does not recognise.

- [ ] **Step 5: Commit**

```bash
git add docker/seed/seed.json
git commit -m "feat: seed document and note permission scenarios"
```

---

### Task 2: Trash, and the Settings row that leads to it

**Files:**
- Modify: `Modules/TrashFeature/TrashList/TrashListReducer.swift` (State)
- Modify: `Modules/TrashFeature/TrashList/TrashListView.swift` (toolbar, row construction)
- Modify: `Modules/TrashFeature/TrashList/TrashRowView.swift` (swipe actions)
- Modify: `Modules/SettingsFeature/SettingList/SettingListReducer.swift` (State)
- Modify: `Modules/SettingsFeature/SettingList/SettingListView.swift` (trash row)
- Test: `Modules/TrashFeatureTests/TrashList/TrashListReducerTests.swift`
- Test: `Modules/SettingsFeatureTests/SettingList/SettingListViewTests.swift`

**Interfaces:**
- Consumes: `ServerPermissions(server:)` and `can(_:)` from `ApiInterface`, already shipped.
- Produces: `TrashListReducer.State.canModifyTrash`, `SettingListReducer.State.canViewTrash`.

- [ ] **Step 1: Read the shipped pattern first**

Read `Modules/TagsFeature/TagList/TagListReducer.swift` and `Modules/SettingsFeature/SettingList/SettingListReducer.swift`. The second already holds a `permissions` and six `canView…` properties — this task adds a seventh beside them and changes nothing else there.

- [ ] **Step 2: Add the gate to TrashListReducer.State**

`TrashListReducer.State` has `let server: Server`, a `public init(server:)` and a second internal `init`. Add the stored property and set it in **both** initialisers:

```swift
        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        // Restore, delete forever and empty trash are all delete_document. One property rather
        // than three with identical bodies; split it if paperless ever separates them.
        var canModifyTrash: Bool { permissions.can(.deleteDocument) }
```

In each initialiser add `permissions = ServerPermissions(server: server)`. Do not add an `permissions` parameter and do not reorder any existing parameter — a call site that has to change means the signature moved.

- [ ] **Step 3: Gate the empty-trash toolbar button**

In `TrashListView.swift` the toolbar holds a destructive button sending `.emptyTrashButtonTapped`. Wrap that `ToolbarItem`'s content:

```swift
                if store.canModifyTrash {
                    Button(role: .destructive) {
                        send(.emptyTrashButtonTapped)
                    } label: {
                        // leave the existing label exactly as it is
                    }
                }
```

- [ ] **Step 4: Gate the row swipe actions**

`TrashRowView` takes `deleteForever: () -> Void` and `restore: () -> Void`. Add one stored property and wrap the swipe actions, so the row shows no swipe at all rather than an empty swipe tray:

```swift
    let canModify: Bool
```

```swift
    @ViewBuilder
    private func swipeActions() -> some View {
        if canModify {
            // the two existing buttons, unchanged
        }
    }
```

In `TrashListView.swift`, pass it where the row is built, beside the existing `deleteForever:` and `restore:` arguments:

```swift
                    canModify: store.canModifyTrash,
```

- [ ] **Step 5: Gate the Settings trash row**

`SettingListView` already wraps six entity `NavigationLink`s in `if store.canView…`. The `trashList` link is the one Project 2 deliberately left ungated. Wrap it the same way, and add the property to `SettingListReducer.State` beside the existing six:

```swift
        var canViewTrash: Bool { permissions.can(.deleteDocument) }
```

Leave `pdfPasswordList` ungated — it is stored on device and has no server permission.

- [ ] **Step 6: Write the reducer tests**

In `Modules/TrashFeatureTests/TrashList/TrashListReducerTests.swift`, read the existing tests for how a `Server` fixture is built, then add:

```swift
    // Seeded explicitly, never left nil: a nil cache fails open and renders every control, which
    // would make a "gated" assertion pass whether or not the gate works.
    @Test
    func trashActionsAreHiddenWithoutDeleteDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument] }

        let state = TrashListReducer.State(server: server)

        #expect(!state.canModifyTrash)
        // The neighbour check: gating trash on a document permission it does not need would
        // compile and look identical.
        #expect(!state.permissions.can(.changeDocument))
    }

    @Test
    func trashActionsAreShownWithDeleteDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .deleteDocument] }

        #expect(TrashListReducer.State(server: server).canModifyTrash)
    }

    @Test
    func trashActionsAreShownWhenNothingHasBeenRead() {
        // Fail open. The end-to-end evidence for this is the existing unseeded snapshot, which
        // renders every control; this only re-checks the rule.
        #expect(TrashListReducer.State(server: .testValue()).canModifyTrash)
    }
```

- [ ] **Step 7: Add the Settings snapshot**

`SettingListViewTests.swift` already has `testSnapshot_viewTagOnly` and `testSnapshot_noPermissions` and a `seedPermissions(_:)` helper. Read them, then add a case seeded with `[.viewDocument, .deleteDocument]` asserting the Trash row is present while the six entity rows are not. The Settings rows sit in the rendered list body, so this snapshot does discriminate — unlike toolbar chrome, which this harness does not render.

- [ ] **Step 8: Run the tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test TrashFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: all pass, `ci:lint` exits 0. The new snapshot records on the first run and fails, then passes on the second. Every pre-existing Settings snapshot must be unchanged — if one differs, a row was gated that should not have been.

- [ ] **Step 9: Commit**

```bash
git add Modules/TrashFeature Modules/TrashFeatureTests Modules/SettingsFeature Modules/SettingsFeatureTests Snapshots/SettingsFeatureTests
git commit -m "feat: hide trash actions and the trash settings row without delete_document"
```

---

### Task 3: The document list toolbar

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` (State)
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListTopTrailingToolbar.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: `ServerPermissions(server:)`, `can(_:)`.
- Produces: `DocumentListReducer.State.canImport`, `.canScan`, `.canSelect`.

- [ ] **Step 1: Add the gates to DocumentListReducer.State**

`State` has `let server: Server` and a `public init` at roughly line 144 with several parameters. Add the stored property and assign it in the init body from the existing `server` parameter. **Do not add a parameter and do not reorder the existing ones.**

```swift
        var permissions: ServerPermissions

        var canImport: Bool { permissions.can(.addDocument) }

        var canScan: Bool { permissions.can(.addDocument) }

        // Either permission is enough to make a selection worth having: gating on change alone
        // would hide bulk delete from someone who may delete but not edit.
        var canSelect: Bool {
            permissions.can(.changeDocument) || permissions.can(.deleteDocument)
        }
```

- [ ] **Step 2: Gate the three menu items**

In `DocumentListTopTrailingToolbar.swift`, `defaultActionsMenu` holds buttons sending `.importButtonTapped`, `.scanButtonTapped` and `.toggleSelectionModeButtonTapped`. Wrap each in its gate, leaving `serversMenu` and every label untouched:

```swift
            if store.canImport {
                Button { send(.importButtonTapped) } label: {
                    Label(.import, systemImage: "doc.badge.plus")
                }
            }
            if store.canScan {
                Button { send(.scanButtonTapped) } label: {
                    Label(.scan, systemImage: "camera")
                }
            }
            if store.canSelect {
                Button { send(.toggleSelectionModeButtonTapped) } label: {
                    Label(.select, systemImage: "checklist")
                }
            }
```

- [ ] **Step 3: Write the reducer tests**

Read the existing tests for how a `DocumentListReducer.State` is constructed, then add three. The `canSelect` pair is the important one — an `and` would pass a test that only ever grants both permissions.

```swift
    @Test
    func listActionsAreHiddenWithoutDocumentPermissions() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument] }

        let state = DocumentListReducer.State(server: server)

        #expect(!state.canImport)
        #expect(!state.canScan)
        #expect(!state.canSelect)
        // The neighbour check: gating import on a tag permission would compile and look identical.
        #expect(!state.permissions.can(.addTag))
    }

    @Test
    func selectionIsOfferedWithChangeAlone() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .changeDocument] }

        let state = DocumentListReducer.State(server: server)

        #expect(state.canSelect)
        #expect(!state.canImport)
    }

    @Test
    func selectionIsOfferedWithDeleteAlone() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .deleteDocument] }

        #expect(DocumentListReducer.State(server: server).canSelect)
    }
```

If `DocumentListReducer.State`'s initialiser needs arguments beyond `server`, read the existing tests and use whatever fixture they use — do not invent one.

- [ ] **Step 4: Run the tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: all pass, lint 0. **No snapshot may change.** These are toolbar controls and this harness renders no toolbar chrome, so a changed reference means something in the list body moved.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: gate import, scan and selection on document permissions"
```

---

### Task 4: The bulk edit actions

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentSelection/DocumentSelectionReducer.swift` (State)
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/` — the selection reducer's existing test file

**Interfaces:**
- Consumes: `ServerPermissions(server:)`, `can(_:)`.
- Produces: `DocumentSelectionReducer.State.canBulkEdit`, `.canBulkDelete`, `.canMerge`.

- [ ] **Step 1: Add the gates**

Read `DocumentSelectionReducer.swift` and find its `State` and the `server` it holds. Add the stored `permissions` in the initialiser body as in Task 3, then:

```swift
        var canBulkEdit: Bool { permissions.can(.changeDocument) }

        var canBulkDelete: Bool { permissions.can(.deleteDocument) }

        // Merging produces a document that did not exist, so it is add rather than change: a user
        // who may edit but not create should not be offered it.
        var canMerge: Bool { permissions.can(.addDocument) }
```

If `DocumentSelectionReducer.State` has no explicit initialiser, add an internal one that keeps the synthesised parameter order exactly and assigns `permissions` last, so no call site changes.

- [ ] **Step 2: Gate the bottom toolbar**

In `DocumentListBottomToolbar.swift`, the menu holds `editCorrespondentButtonTapped`, `editDocumentTypeButtonTapped`, `editStoragePathButtonTapped`, `editTagsButtonTapped`, `editTitleButtonTapped`, `mergeSelectedButtonTapped` and `deleteSelectedButtonTapped`. Wrap the five `edit…` buttons in one `if store.documentSelection.canBulkEdit { … }`, the merge button in `if store.documentSelection.canMerge`, and the delete button in `if store.documentSelection.canBulkDelete`. Read the file first for how it reaches the selection state — use whatever accessor is already there rather than introducing a new one.

- [ ] **Step 3: Write the reducer tests**

```swift
    @Test
    func bulkActionsFollowTheirOwnPermissions() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .changeDocument] }

        let state = DocumentSelectionReducer.State(server: server)

        #expect(state.canBulkEdit)
        // change_document must not imply either of the other two.
        #expect(!state.canBulkDelete)
        #expect(!state.canMerge)
    }

    @Test
    func bulkDeleteFollowsDeleteAlone() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .deleteDocument] }

        let state = DocumentSelectionReducer.State(server: server)

        #expect(state.canBulkDelete)
        #expect(!state.canBulkEdit)
    }
```

Use whatever initialiser the existing tests use if `State(server:)` is not available.

- [ ] **Step 4: Run the tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: pass, lint 0, no snapshot changed.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: gate the bulk edit actions on their own permissions"
```

---

### Task 5: Row and detail edit and delete

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift` (State)
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift` (State)
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentDetail/` and the row's existing test file

**Interfaces:**
- Consumes: `ServerPermissions(server:)`, `can(_:)`.
- Produces: `canEdit` and `canDelete` on both `DocumentRowReducer.State` and `DocumentDetailReducer.State`.

- [ ] **Step 1: Add the gates to both States**

Both hold `let server: Server` and both have an explicit `init`. Add to each:

```swift
        var permissions: ServerPermissions

        var canEdit: Bool { permissions.can(.changeDocument) }

        var canDelete: Bool { permissions.can(.deleteDocument) }
```

assigning `permissions = ServerPermissions(server: server)` in each initialiser body without touching any signature.

- [ ] **Step 2: Gate the row controls**

In `DocumentRowView.swift`, wrap the button sending `.editButtonTapped` in `if store.canEdit` and the one sending `.deleteButtonTapped` in `if store.canDelete`.

**Leave `favoriteButtonTapped`, `previewButtonTapped`, `shareButtonTapped` and `viewButtonTapped` alone.** Sharing downloads the file and opens the iOS share sheet rather than creating a share link, and favourites are stored device-locally through `favoritesStore` — neither has a server permission, exactly like the PDF passwords Project 2 left ungated.

- [ ] **Step 3: Gate the detail controls**

In `DocumentDetailView.swift`, wrap the button sending `.editDocumentButtonTapped` in `if store.canEdit`. Leave `favoriteButtonTapped`, `previewButtonTapped`, `viewButtonTapped` and `retryDownloadButtonTapped` alone.

- [ ] **Step 4: Write the reducer tests**

Add to the row's and the detail's existing test files, using whatever fixture they already use to build a State:

```swift
    @Test
    func editAndDeleteFollowTheirOwnPermissions() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .changeDocument] }

        let state = DocumentRowReducer.State(document: .testValue(), server: server)

        #expect(state.canEdit)
        #expect(!state.canDelete)
        // The neighbour check: gating a document control on a tag permission compiles.
        #expect(!state.permissions.can(.changeTag))
    }
```

Repeat the same shape for `DocumentDetailReducer.State` with `canEdit`. Read the existing tests for the real initialiser arguments — `DocumentRowReducer.State` takes more than `document:` and `server:`.

- [ ] **Step 5: Run the tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: pass, lint 0. If a document row snapshot changes, stop and report it: rows are built by the reducer inside `.task { onAppear }`, and Project 2's review proved a `Shared` built from a detached task resolves under a process-global registry, so a row rendering ungated despite a seeded cache is that and not a broken gate.

- [ ] **Step 6: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: gate document edit and delete on change and delete permissions"
```

---

### Task 6: The notes section

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift` (State)
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailView.swift`
- Modify: `Modules/DocumentsFeature/DocumentNotes/DocumentNotesReducer.swift` (State)
- Modify: `Modules/DocumentsFeature/DocumentNotes/DocumentNotesView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentNotes/`

**Interfaces:**
- Consumes: `ServerPermissions(server:)`, `can(_:)`, and `DocumentDetailReducer.State.permissions` added in Task 5.
- Produces: `DocumentDetailReducer.State.canViewNotes`, `DocumentNotesReducer.State.canAddNote` and `.canDeleteNote`.

Notes carry their own permission type — `view_note`, `add_note`, `delete_note` — not `change_document`.

- [ ] **Step 1: Hide the whole section without view_note**

`DocumentDetailReducer.State` already gained `permissions` in Task 5. Add:

```swift
        // The section, not a control inside it: without view_note the endpoint answers 403, so
        // there is nothing to show and nothing that could be added.
        var canViewNotes: Bool { permissions.can(.viewNote) }
```

In `DocumentDetailView.swift`, wrap the notes section in `if store.canViewNotes`. The gate lives on the detail rather than on the notes reducer because the detail is what decides whether to render the section — a gate held inside the section it is meant to hide could not hide it.

- [ ] **Step 2: Add the note gates, named for the noun**

`DocumentNotesReducer.State` **already has a `canCreate`**, and it means the draft is non-empty and not currently saving:

```swift
        var canCreate: Bool {
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
        }
```

**Leave it exactly as it is.** Adding a second `canCreate` meaning "has the add permission" is impossible, and naming the new gate anything close to it would produce two properties one word apart meaning different things. Its initialiser takes `documentId` and `server`; add:

```swift
        var permissions: ServerPermissions

        var canAddNote: Bool { permissions.can(.addNote) }

        var canDeleteNote: Bool { permissions.can(.deleteNote) }
```

and assign `permissions = ServerPermissions(server: server)` in the existing init body.

- [ ] **Step 3: Gate the note controls**

In `DocumentNotesView.swift`, the delete affordance is already an optional closure:

```swift
                        deleteButtonTapped: isReadOnly ? nil : { send(.deleteButtonTapped(note.id)) }
```

Extend that condition rather than adding a second mechanism — `isReadOnly` is the viewer's presentation mode and is not a permission:

```swift
                        deleteButtonTapped: isReadOnly || !store.canDeleteNote
                            ? nil
                            : { send(.deleteButtonTapped(note.id)) }
```

Wrap the draft field and its submit control in `if store.canAddNote`. Read the view first — the existing `canCreate` still governs whether that control is *enabled*, and both conditions apply: `canAddNote` decides whether it exists, `canCreate` whether it is usable.

- [ ] **Step 4: Write the reducer tests**

```swift
    @Test
    func noteGatesFollowNotePermissionsNotDocumentOnes() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .changeDocument, .deleteDocument, .viewNote] }

        let state = DocumentNotesReducer.State(documentId: 1, server: server)

        // Full rights over documents grant nothing over notes.
        #expect(!state.canAddNote)
        #expect(!state.canDeleteNote)
    }

    @Test
    func noteGatesOpenWithNotePermissions() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewNote, .addNote] }

        let state = DocumentNotesReducer.State(documentId: 1, server: server)

        #expect(state.canAddNote)
        #expect(!state.canDeleteNote)
    }
```

Use the real `Document.Id` fixture the existing tests use rather than the literal `1` if they differ.

- [ ] **Step 5: Add a detail snapshot for the hidden section**

The notes section sits in the rendered body, so a snapshot discriminates here where a toolbar one would not. Read the existing `DocumentDetail` view tests, then add one case seeded with `[.viewDocument]` only, asserting the notes section is absent. Confirm by looking at the image that the section is gone and the rest of the detail is unchanged.

- [ ] **Step 6: Run the tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: pass, lint 0. The new snapshot records then passes; no pre-existing snapshot changes.

- [ ] **Step 7: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Snapshots/DocumentsFeatureTests
git commit -m "feat: hide the notes section and its controls on note permissions"
```

---

### Task 7: The inline create-entity buttons

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift` (State)
- Modify: the `DocumentForm` view holding the create buttons — find it with `grep -rn "createTagButtonTapped" Modules/DocumentsFeature --include=*View.swift`
- Modify: `Modules/ShareFeature/ShareForm/ShareFormReducer.swift` (State and `reset()`)
- Modify: `Modules/ShareFeature/ShareForm/ShareFormView.swift:181`
- Test: `Modules/DocumentsFeatureTests/DocumentForm/` and `Modules/ShareFeatureTests/`

**Interfaces:**
- Consumes: `ServerPermissions(server:)`, `can(_:)`.
- Produces: five `canCreate…` properties on `DocumentFormReducer.State`, one on `ShareFormReducer.State`.

These are the same `add_<entity>` permissions Project 2 gated on the six list screens. A user without `add_tag` currently still gets a "create tag" button here and in the share sheet.

- [ ] **Step 1: Add the five gates to DocumentFormReducer.State**

It holds `let server: Server` and an internal `init` at roughly line 119. Add the stored `permissions`, assigned in the init body, and:

```swift
        var canCreateTag: Bool { permissions.can(.addTag) }

        var canCreateCorrespondent: Bool { permissions.can(.addCorrespondent) }

        var canCreateDocumentType: Bool { permissions.can(.addDocumentType) }

        var canCreateStoragePath: Bool { permissions.can(.addStoragePath) }

        var canCreateCustomField: Bool { permissions.can(.addCustomField) }
```

Check every case against the spec's table. `.addDocumentType`, `.addStoragePath` and `.addCustomField` have no internal underscore in their raw values — a neighbouring entity's case compiles and looks identical.

- [ ] **Step 2: Gate the five buttons**

In `Modules/DocumentsFeature/DocumentForm/DocumentFormView.swift` each of these is an `onCreate:` argument to a field component, e.g. at line 231:

```swift
            onCreate: { send(.createTagButtonTapped) },
```

`SingleSelectOptions` declares `onCreate: (() -> Void)? = nil` and renders the control inside `if let onCreate`, so passing `nil` removes it — the same convention the notes view already uses for its optional delete closure. No `if` in the view body is needed:

```swift
            onCreate: store.canCreateTag ? { send(.createTagButtonTapped) } : nil,
```

Do the same for the other four with `canCreateCorrespondent`, `canCreateDocumentType`, `canCreateStoragePath` and `canCreateCustomField`. **Leave the picker itself alone** — selecting an existing tag needs no permission, only creating a new one does.

- [ ] **Step 3: Gate the share sheet's copy, and keep it fresh across a server switch**

`ShareFormReducer.State` differs from every other State in this plan: `server` is a **`var` with `didSet { reset() }`**, because the share sheet lets the user switch servers. A `permissions` assigned only in `init` would answer for the previous server after a switch.

`reset()` already re-binds each `@Shared` for the new server. Rebuild `permissions` there too, and assign it in `init` as well:

```swift
    mutating func reset() {
        input.reset()
        _correspondents = Shared(wrappedValue: [], .correspondents(server))
        _documentTypes = Shared(wrappedValue: [], .documentTypes(server))
        _storagePaths = Shared(wrappedValue: [], .storagePaths(server))
        _tags = Shared(wrappedValue: [], .tags(server))
        // Rebuilt for the same reason as the four above: a gate left pointing at the previous
        // server would answer for the wrong account after a switch.
        permissions = ServerPermissions(server: server)
    }
```

Then wrap the `onCreate:` affordance at `ShareFormView.swift:181` in `if store.canCreateTag`.

- [ ] **Step 4: Write the reducer tests**

```swift
    @Test
    func createButtonsFollowEachEntityAddPermission() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .addTag] }

        let state = DocumentFormReducer.State(server: server)

        #expect(state.canCreateTag)
        // add_tag must not open any of the other four.
        #expect(!state.canCreateCorrespondent)
        #expect(!state.canCreateDocumentType)
        #expect(!state.canCreateStoragePath)
        #expect(!state.canCreateCustomField)
    }
```

Use the real initialiser the existing tests use. Add the equivalent single-gate test for `ShareFormReducer.State.canCreateTag`, plus this one for the server switch, which is what Step 3 exists for:

```swift
    @Test
    func theShareFormGateFollowsAServerSwitch() {
        // Two distinct servers: Server.testValue's id defaults to one fixed UUID string, and two
        // servers sharing an id would resolve to the same cache key and prove nothing.
        let allowed = Server.testValue()
        let denied = Server.testValue(id: "0BE4B0E2-4E0F-4E5E-9E1E-2C7C2F0A9B31")

        @Shared(.permissions(allowed)) var allowedPermissions: [Permission]?
        @Shared(.currentUser(allowed)) var allowedUser: User?
        $allowedUser.withLock { $0 = .testValue(isSuperuser: false) }
        $allowedPermissions.withLock { $0 = [.addTag] }

        @Shared(.permissions(denied)) var deniedPermissions: [Permission]?
        @Shared(.currentUser(denied)) var deniedUser: User?
        $deniedUser.withLock { $0 = .testValue(isSuperuser: false) }
        $deniedPermissions.withLock { $0 = [.viewTag] }

        var state = ShareFormReducer.State(files: [], server: allowed)
        #expect(state.canCreateTag)

        state.server = denied
        #expect(!state.canCreateTag)
    }
```

`Server.testValue` is declared in `Modules/ApiInterface/Shared/Server.swift:47` as
`testValue(alias:headers:id:username:url:)` with every parameter defaulted and `id` a `String`.

- [ ] **Step 5: Run every affected scheme**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test ShareFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test TrashFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: all pass, lint 0.

- [ ] **Step 6: Confirm the global constraint still holds**

```bash
grep -rn "\.can(" Modules --include=*View.swift | wc -l
```
Expected: `0`. Every gate is a named State property; a view calling `can` directly means the enum case now lives in two places.

- [ ] **Step 7: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Modules/ShareFeature Modules/ShareFeatureTests
git commit -m "feat: gate the inline create-entity buttons on add permissions"
```
