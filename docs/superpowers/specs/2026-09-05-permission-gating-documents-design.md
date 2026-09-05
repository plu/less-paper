# Hiding what the user cannot do to a document

Gate the document, note and trash affordances on the permissions the app already holds, and close
the three places where an entity can still be created by someone without the permission to create
one.

## Context

[Global permission gating](2026-09-05-permission-gating-design.md) shipped the rule and applied it
to the six entity-management screens. It deliberately held back `DocumentsFeature` and
`TrashFeature` — "so the pattern is established on the six regular cases first and reviewed once,
rather than debated across two dissimilar surfaces at the same time". This is that follow-up.

Everything that project decided still holds and is not re-argued here: gating is **presentation,
not enforcement**; the rule **fails open** when the permission cache has never been read; the gate
lives in **State**, as a named computed property the view reads; and a control the user cannot use
is **hidden, not disabled**.

`ServerPermissions` and `can(_:)` need no changes, and neither does `Permission` — all 72 cases
already exist, including `addDocument`, `changeDocument`, `deleteDocument`, `viewNote`, `addNote`
and `deleteNote`. This project only adds callers.

`canViewNotes` sits on `DocumentDetailReducer.State` rather than on the notes reducer, because the
detail view is what decides whether to render the section at all — a gate held inside the section
it is meant to hide could not hide it.

### What Project 2 did not have to decide

Every screen Project 2 touched stayed useful: hiding the "+" on the tag list still left a list of
tags. Documents and trash break that assumption in two ways, and both are new decisions rather than
applications of the old ones.

A **section can become dead** rather than merely reduced. Without `view_note` the notes endpoint
answers 403, so the section has nothing to show and cannot acquire anything. Without
`delete_document` the trash screen still loads — the endpoint is not permission-gated, verified —
but every action on it fails.

And **a permission the previous project already gated is honoured in one place and ignored in two.**
The document form and the share sheet both offer "create tag" inline. Project 2 hid the tag list's
create button for a user without `add_tag`; these two buttons stayed. The share-sheet copy was
found during Project 2's review and recorded as inherited work.

## Decisions

**A dead screen loses its entrance.** The Settings *Trash* row is gated on `delete_document`, and
the notes section is hidden entirely without `view_note`. Project 2 hid the six entity rows on
exactly this reasoning; the difference is only that here the whole destination goes, not a control
inside it. A user is never walked into a screen where nothing works, and no permission is ever
reported as an error.

**Trash is gated on `delete_document` by intent, not by what the server enforces.** The endpoint
answers 200 for a user without it, and a restore of a non-existent id returns 400 rather than 403 —
so paperless does not apply the model permission at that view. That does not change what to hide:
the gate says "this user does not delete documents", which is true, and the app has never claimed
to be the boundary. It is recorded here so nobody discovers the 200 later and reads it as evidence
the gate is wrong.

**Notes carry their own permission type.** `view_note`, `add_note` and `delete_note`, not
`change_document`. Every seed user today holds `view_document` and no note permission at all, so
every one of them gets a 403 from the notes endpoint — which is what makes the missing gate visible
in the first place.

**Notes gates are named for the noun.** `DocumentNotesReducer.State` already has a `canCreate`, and
it means the draft is non-empty and not currently saving — nothing to do with permissions. Project
2's convention would put a second, unrelated `canCreate` beside it. The note gates are therefore
`canAddNote` and `canDeleteNote`, and the existing `canCreate` is left alone. This is the one place
2b deviates from the naming Project 2 established, and it deviates because copying it would produce
two properties one word apart meaning different things.

**Share, favourite, preview and view stay ungated.** Sharing downloads the file and opens the iOS
share sheet; it creates no share link, so `add_sharelink` is not involved. Favourites are stored
through `favoritesStore` against a downloaded copy — device-local, like the PDF passwords Project 2
left alone for the same reason. A user who can see a document can already do all four.

**Selection mode is gated on being able to do anything with a selection.** The entry point into
bulk edit is shown when the user holds `change_document` or `delete_document`; the individual
actions in the bottom toolbar are then gated separately. Gating the entry on `change_document`
alone would hide bulk delete from someone who can delete but not edit.

## Architecture

```
ApiInterface
  ServerPermissions          unchanged - this project only adds callers
        ^
        | held in State
        |
DocumentsFeature
  DocumentListReducer.State      canImport, canScan, canSelect
  DocumentRowReducer.State       canEdit, canDelete
  DocumentDetailReducer.State    canEdit, canViewNotes
  DocumentSelection…State        canBulkEdit, canBulkDelete, canMerge
  DocumentNotesReducer.State     canAddNote, canDeleteNote
  DocumentFormReducer.State      canCreateTag, canCreateCorrespondent, canCreateDocumentType,
                                 canCreateStoragePath, canCreateCustomField
TrashFeature
  TrashListReducer.State         canRestore, canDeleteForever, canEmptyTrash
ShareFeature
  ShareFormReducer.State         canCreateTag
SettingsFeature
  SettingListReducer.State       canViewTrash          [the row Project 2 left ungated]
```

## Changes

### The permission for each affordance

| Affordance | Where | Permission |
|---|---|---|
| Import | list toolbar | `add_document` |
| Scan | list toolbar | `add_document` |
| Select (enter bulk edit) | list toolbar | `change_document` **or** `delete_document` |
| Bulk edit correspondent, document type, storage path, tags, title | bottom toolbar | `change_document` |
| Bulk merge | bottom toolbar | `add_document` |
| Bulk delete | bottom toolbar | `delete_document` |
| Edit | row context menu, detail | `change_document` |
| Delete | row context menu | `delete_document` |
| Notes section entrance | the document detail toolbar's viewer menu | `view_note` |
| Add note | the document form's note composer | `add_note` |
| Delete note | notes | `delete_note` |
| Create tag | document form, share form | `add_tag` |
| Create correspondent | document form | `add_correspondent` |
| Create document type | document form | `add_documenttype` |
| Create storage path | document form | `add_storagepath` |
| Create custom field | document form | `add_customfield` |
| Restore, delete forever, empty trash | trash list and rows | `delete_document` |
| Trash row | `SettingListView` | `delete_document` |
| Share, favourite, preview, view | row, detail | **none** |

`add_documenttype`, `add_storagepath` and `add_customfield` are spelled without the internal
underscore, matching the paperless codenames — the same trap `changeCustomfield` set in Project 2.
Check every case against this table rather than against a neighbouring feature.

### Bulk merge is `add_document`

Merging produces a new document from several existing ones. It is spelled `add_document` rather
than `change_document` because the outcome is a document that did not exist before; a user who may
edit documents but not create them should not be offered it.

### The seed fixture

`docker/seed/seed.json` gains the scenario users this project needs. Today `permission_entities`
covers the six entity types only, and `permission_baseline` grants `view_document` to everyone, so
no user exercises a single gate in this project. The new users cover: documents readable but not
writable, `change_document` without `delete_document` and its mirror, `add_document` alone, and the
note permissions independent of the document ones.

## Testing

**Per-feature reducer tests, as Project 2 established.** Each gate is asserted through the named
State property rather than through `can(_:)` directly, so the test evaluates the same expression the
view does. Each feature also asserts that a **neighbouring** permission is denied — the check that
catches a control gated on the wrong case, which is this project's central risk exactly as it was
the last one's.

**Two assertions this project needs that Project 2 did not.** The Settings trash row and the notes
section entrance are *entrances*, so each gets a test that the destination is absent, not merely
that a button inside it is. The trash row gets that test as a snapshot, because it is a row in a
rendered list. The notes entrance does not: it is an item inside the document detail toolbar's
viewer menu, a nested dropdown this harness never expands, so no image can show it present or
absent — the reducer test asserting `canViewNotes` is the only assertion this gate gets. And
selection mode gets a test for each half of its `or`: `change_document` alone and `delete_document`
alone must both show it, because an `and` would pass a test that only ever grants both.

**Snapshots only where they discriminate.** Project 2 measured that this repo's
`.image(layout: .device)` harness renders no nav-bar or toolbar chrome, and deleted five references
that had come out byte-identical to their baselines. That finding applies unchanged to the document
list's toolbar, the row context menu, and the document detail toolbar's notes entrance, so none of
those get a snapshot — a recorded reference for the notes entrance came back byte-identical to its
ungated baseline, confirming the same finding rather than being an exception to it. The Settings
trash row and the document form's note composer are what actually sit in a rendered body and change
the image, so those two get snapshots: the composer's disappears along with its send button when
`add_note` is missing, leaving the existing notes intact underneath it.

## Out of scope

- **Object-level permissions.** `user_can_change`, `owner`, `full_perms` — Project 3. A document
  the user may not change because of its owner still shows an edit button after this project.
- **Enforcement.** Unchanged from Project 2: the server is the boundary.
- **Explaining a hidden control.** No "you do not have permission" copy anywhere.
- **Reachability of the app itself.** A user without `view_document` is not designed for here.
  Adding a server no longer fails for a restricted account, which was fixed separately, but what a
  documents app should look like to someone who cannot read documents is its own question.

## Risks

**A wrong permission case silently over-hides**, and this project has more cases than the last one
and four permission types rather than one. The mapping table above is the reference, and the
neighbouring-permission assertion in each feature's tests is what catches a control gated on the
wrong case.

**The view call site is still unreachable by tests.** Project 2's final review recorded that no test
reaches a view's actual gate expression, because the snapshot harness cannot see chrome; moving each
gate to a named State property narrowed that to the single `if` in the view. The same residue
applies here and is not re-solved.

**Row snapshots may not observe a seeded permission.** Project 2's final review proved that per-test
isolation holds because `ServerPermissions` is constructed on the test's own task, and that a
`Shared` built from a **detached** task resolves under a process-global registry instead. Document
rows are built by the reducer inside `.task { onAppear }`, which is that shape. A row snapshot that
renders ungated despite a seeded cache is this, not a broken gate.
